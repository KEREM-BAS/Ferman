//! Documents and views: open and close, and tiles and thumbnails of their pages
//! (docs/ARCHITECTURE.md §3.3, §3.4 and §5.1).
//!
//! [`Engine::open`] reads the file and parses it with ferman-core on a thread of its own, then
//! loads the same bytes into PDFium and compares the two parsers (ADR 0004). A view of an open
//! document ([`Engine::open_view`]) receives its tiles and thumbnails as [`ViewEvent`]s; the view
//! types are ferman-render's, plain data the UI can mirror. A document does not change in M2, so
//! the open result also carries the lists the sidebar shows (a2-3o, a2-3b, a2-3c, a2-14).

use std::path::PathBuf;
use std::sync::Arc;
use std::thread;

use ferman_core::structure::{Agreement, Attachment, Direction, Layer, OutlineItem, Signature};
use ferman_core::{OpenOptions, Password, RepairReport, Source};
use ferman_render::{DocumentId, PageSize, RenderThread, ViewId, ViewSink, Wanted};

use super::engine::Engine;
use super::error::ApiError;
use super::guard::{guard, guard_async};

/// The stack of the thread that parses a file: lopdf and ferman-core recurse into nested objects,
/// and their nesting limits are measured against it (ADR 0010).
const PARSE_STACK: usize = 64 * 1024 * 1024;

/// The name of that thread, as debuggers and crash reports show it.
const PARSE_THREAD: &str = "ferman-open";

/// A document the engine opened.
#[derive(Debug, Clone, PartialEq)]
pub struct OpenedDocument {
    /// Its handle, until [`Engine::close`].
    pub id: DocumentId,
    /// Why it opened read-only, if it did.
    pub read_only: Option<ReadOnly>,
    /// The order of pages in spreads (`/ViewerPreferences /Direction`).
    pub direction: Direction,
    /// Its pages, as PDFium lays them out.
    pub pages: Vec<PageInfo>,
    /// The outline (bookmarks).
    pub outline: Vec<OutlineItem>,
    /// Embedded files and file attachment annotations, never opened automatically.
    pub attachments: Vec<Attachment>,
    /// Optional content groups (layers), in the order the document gives them.
    pub layers: Vec<Layer>,
    /// Signature fields, shown neutrally until checking arrives (G31).
    pub signatures: Vec<Signature>,
}

/// One page of an [`OpenedDocument`].
#[derive(Debug, Clone, PartialEq)]
pub struct PageInfo {
    /// Its size in points as displayed, after the crop box and `/Rotate`.
    pub size: PageSize,
    /// Its label (`/PageLabels`), such as "iv", when the document has labels.
    pub label: Option<String>,
}

/// Why a document opened read-only (docs/ARCHITECTURE.md §5.2). In M2 every document is
/// view-only, because the writer arrives in M3; these are the reasons the UI says so.
#[derive(Debug, Clone, PartialEq)]
pub enum ReadOnly {
    /// ferman-core repaired it (a1-9), or could not read some of its objects.
    Repaired(RepairReport),
    /// lopdf and PDFium see different pages (G102).
    ParsersDisagree(Agreement),
    /// An XFA-only form, which Ferman shows only as PDFium's fallback page (a11-7c).
    XfaOnly,
}

impl Engine {
    /// Opens the PDF at `path`, with `password` if it is encrypted.
    ///
    /// An encrypted document opened without its password fails with
    /// [`ErrorKind::PasswordRequired`](super::ErrorKind::PasswordRequired); the UI asks for it and
    /// opens again (a1-8). The password is wiped when the open ends; PDFium keeps its own copy
    /// while the document is open (docs/QUESTIONS.md, Q22).
    ///
    /// # Errors
    ///
    /// Returns the kind the file's problem maps to (docs/ARCHITECTURE.md §8.2): `NotFound`,
    /// `PermissionDenied`, `PasswordRequired`, `WrongPassword`, `Damaged`, `Unsupported` (also for
    /// a file that is not a PDF), `ResourceLimit`, `Io`, or `Internal` when PDFium is not loaded.
    pub async fn open(
        &self,
        path: PathBuf,
        password: Option<Password>,
    ) -> Result<OpenedDocument, ApiError> {
        guard_async(async move {
            let render = self.render()?;
            let (source, model) = parse(path, password.clone()).await?;
            // shortcut: ferman-core parses before PDFium loads, so the first page waits for both;
            // run them side by side if the first-page bench misses its budget.
            let rendered = render
                .open_document(Arc::clone(source.bytes()), password)
                .await?;
            let sizes: Vec<(f32, f32)> = rendered
                .pages
                .iter()
                .map(|page| (page.width, page.height))
                .collect();
            let structure = model.structure();
            let read_only = match (model.repair(), structure.agrees_with(&sizes)) {
                (Some(report), _) => Some(ReadOnly::Repaired(report.clone())),
                (None, Agreement::Agree) if structure.forms.xfa_only => Some(ReadOnly::XfaOnly),
                (None, Agreement::Agree) => None,
                (None, disagreement) => Some(ReadOnly::ParsersDisagree(disagreement)),
            };
            if let Some(ReadOnly::ParsersDisagree(agreement)) = &read_only {
                tracing::warn!(?agreement, "lopdf and PDFium disagree; opening read-only");
            }
            let pages = rendered
                .pages
                .iter()
                .enumerate()
                .map(|(index, &size)| PageInfo {
                    size,
                    label: structure
                        .pages
                        .get(index)
                        .and_then(|page| page.label.clone()),
                })
                .collect();
            Ok(OpenedDocument {
                id: rendered.id,
                read_only,
                direction: structure.direction,
                pages,
                outline: structure.outline.clone(),
                attachments: structure.attachments.clone(),
                layers: structure.layers.clone(),
                signatures: structure.signatures.clone(),
            })
        })
        .await
    }

    /// Closes a document: its views end and PDFium lets it go.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open.
    pub async fn close(&self, document: DocumentId) -> Result<(), ApiError> {
        guard_async(async { Ok(self.render()?.close_document(document).await?) }).await
    }

    /// Opens a view of `document` (the canvas, the thumbnail strip) whose tiles and thumbnails go
    /// to `sink`, called on the render thread. It starts with nothing wanted.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open.
    pub async fn open_view(
        &self,
        document: DocumentId,
        sink: Box<dyn ViewSink>,
    ) -> Result<ViewId, ApiError> {
        guard_async(async { Ok(self.render()?.open_view(document, sink).await?) }).await
    }

    /// Replaces what `view` wants rendered, in priority order. A `generation` no newer than the
    /// view's last one is ignored, so an old set never replaces a newer one.
    ///
    /// # Errors
    ///
    /// Returns `Internal` if the render thread has stopped.
    pub fn request(
        &self,
        view: ViewId,
        generation: u64,
        wanted: Vec<Wanted>,
    ) -> Result<(), ApiError> {
        Ok(self.render()?.request(view, generation, wanted)?)
    }

    /// Closes a view; what it still wanted is dropped.
    ///
    /// # Errors
    ///
    /// Returns `Internal` if the render thread has stopped.
    pub fn close_view(&self, view: ViewId) -> Result<(), ApiError> {
        Ok(self.render()?.close_view(view)?)
    }

    /// The render thread, or an internal error saying why it is not running.
    fn render(&self) -> Result<&RenderThread, ApiError> {
        self.render.as_ref().map_err(ApiError::internal)
    }
}

/// Reads and parses the file on a thread of its own, so a large file never holds an async worker,
/// and a panic in a parser becomes an error ([`guard`]).
async fn parse(
    path: PathBuf,
    password: Option<Password>,
) -> Result<(Source, ferman_core::Document), ApiError> {
    let (reply, receiver) = futures_channel::oneshot::channel();
    thread::Builder::new()
        .name(PARSE_THREAD.to_owned())
        .stack_size(PARSE_STACK)
        .spawn(move || {
            let options = OpenOptions {
                password,
                ..OpenOptions::default()
            };
            let result = guard(move || {
                let source = Source::read(&path)?;
                let model = ferman_core::open(&source, &options)?;
                Ok((source, model))
            });
            // The caller may have stopped waiting; then nobody needs the result.
            let _ = reply.send(result);
        })
        .map_err(|_| ApiError::internal("cannot start the open thread"))?;
    receiver
        .await
        .map_err(|_canceled| ApiError::internal("the open thread stopped"))?
}
