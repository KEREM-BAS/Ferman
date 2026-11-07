//! Documents and views: open and close, and tiles and thumbnails of their pages
//! (docs/ARCHITECTURE.md §3.3, §3.4 and §5.1).
//!
//! [`Engine::open`] reads the file and parses it with ferman-core on a thread of its own, then
//! loads the same bytes into PDFium and compares the two parsers (ADR 0004). A view of an open
//! document ([`Engine::open_view`]) receives its tiles and thumbnails as [`ViewEvent`]s; the view
//! types are ferman-render's, plain data the UI can mirror. A document does not change in M2, so
//! the open result also carries the lists the sidebar shows (a2-3o, a2-3b, a2-3c, a2-14).
//! [`Engine::show_layers`] shows and hides layers through a render-only appendix (ADR 0009), and
//! [`Engine::search`] searches its text; for both the engine keeps every open document's parsed
//! model, with the text of the pages it has read, until the document closes.

use std::collections::HashMap;
use std::panic::AssertUnwindSafe;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::thread;

use ferman_core::recovery::DocumentRecovery;
use ferman_core::revision::RevisionStore;
use ferman_core::save::FileStamp;
use ferman_core::structure::{
    Agreement, Attachment, Direction, FontUse, Info, Layer, OutlineItem, Page, RevisedStructure,
    Scripts, Signature,
};
use ferman_core::{Access, Method, OpenOptions, Password, Permissions, RepairReport, Source};
use ferman_render::{DocumentId, PageRaster, PageSize, RenderThread, ViewId, ViewSink, Wanted};
use ferman_text::extract::PageText;

use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};

/// The stack of the thread that parses a file: lopdf and ferman-core recurse into nested objects,
/// and their nesting limits are measured against it (ADR 0010).
pub(super) const PARSE_STACK: usize = 64 * 1024 * 1024;

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
    /// Whether [`Engine::show_layers`] can show and hide them: it has layers, was not repaired
    /// (its rebuilt table cannot place objects inside object streams).
    pub layers_switchable: bool,
    /// Signature fields, shown neutrally until checking arrives (G31).
    pub signatures: Vec<Signature>,
    /// Whether a change would invalidate a signature, so it waits for
    /// [`Engine::confirm_edit_signed`] (G35).
    pub signed: bool,
    /// The certification signature's `/DocMDP` permission level (1 to 3), when certified.
    pub certification: Option<u8>,
    /// The PDF version in the header, such as `1.7`.
    pub version: String,
    /// The file's size in bytes.
    pub file_size: u64,
    /// The document information dictionary.
    pub info: Info,
    /// `/Lang`, the document's language tag.
    pub language: Option<String>,
    /// Whether it is a tagged PDF.
    pub tagged: bool,
    /// Whether it is linearized for fast web view.
    pub linearized: bool,
    /// The fonts its pages use (fonts inside form XObjects come with the interpreter, M3).
    pub fonts: Vec<FontUse>,
    /// Its encryption and permissions, when it is encrypted (a2-10a, a2-10b).
    pub security: Option<Security>,
    /// The document JavaScript it holds, which Ferman never runs (Q13, G100).
    pub scripts: Scripts,
    /// How many form fields it has (the start screen's Form badge).
    pub form_fields: u32,
    /// Whether its first page has no text: most likely a scan without a text layer (the start
    /// screen's Scanned badge). A page of drawings only says so too.
    pub scanned: bool,
}

/// An encrypted document's security (a2-10b).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Security {
    /// How its strings and streams are encrypted.
    pub method: Method,
    /// Whether opening it needs a password.
    pub user_password_required: bool,
    /// What the file allows without its owner password.
    pub permissions: Permissions,
    /// Whether it was opened, or since unlocked, with its owner password, which lifts the
    /// restrictions for the session ([`Engine::unlock_owner`]).
    pub owner: bool,
}

impl Security {
    /// Whether the restrictions apply now: some permission is withheld and the owner password
    /// was not given.
    #[must_use]
    pub fn restricted(&self) -> bool {
        !self.owner && !self.permissions.all()
    }
}

/// An open document's parsed model, kept for its layers and its search.
#[derive(Debug)]
pub(super) struct Model {
    pub(super) document: ferman_core::Document,
    pub(super) layers_switchable: bool,
    /// Whether the owner password was given since the open ([`Engine::unlock_owner`]); the
    /// model is shared, so ferman-core's own access is not changed.
    pub(super) owner_unlocked: AtomicBool,
    /// Why no block of the document can be edited whatever the password: damaged or read-only.
    pub(super) read_only: Option<ferman_text::NotEditableReason>,
    /// The revisions the document actor last published, with the text model of each page of
    /// them once laid out ([`Engine::text_blocks`]).
    pub(super) revised: Mutex<Revised>,
    /// The file the document saves to, until Save as names another (`edit`).
    pub(super) path: PathBuf,
    /// What the render thread last got (`edit`).
    pub(super) rendered: Mutex<Rendered>,
    /// The file at `path` as it was opened, which a save checks (`edit`); for a restored
    /// document, as its recovery manifest recorded it.
    pub(super) stamp: FileStamp,
    /// A restored document's recovery files, which its actor takes over (`recovery`).
    pub(super) recovery: Mutex<Option<DocumentRecovery>>,
    /// The structure the app last heard of; `None` for the open result's.
    pub(super) shown: Mutex<Option<RevisedStructure>>,
}

/// What the render thread last got.
#[derive(Debug)]
pub(super) struct Rendered {
    /// The serial of the last reload, so an older one never follows a newer one.
    pub(super) serial: u64,
    /// The revisions it shows, which the next reload compares against to find the pages that
    /// changed; `None` when the next reload is for every page.
    pub(super) store: Option<Arc<RevisionStore>>,
}

/// The document as the actor last published it: a snapshot of its committed revisions that
/// readers share without blocking the actor (docs/ARCHITECTURE.md §4.3).
#[derive(Debug)]
pub(super) struct Revised {
    pub(super) store: Arc<RevisionStore>,
    /// How many times the actor published; a layout of an older snapshot is not kept.
    pub(super) generation: u64,
    /// The text model of each page once laid out, by page handle, with `read_only` but without
    /// the author's restrictions, which the owner password can lift.
    pub(super) blocks: HashMap<u64, Arc<ferman_text::PageText>>,
    /// The text of each page once read, by page handle, for searches after the first.
    pub(super) texts: HashMap<u64, Arc<PageText>>,
    /// The layers [`Engine::show_layers`] last showed, which every reload keeps; `None` until it
    /// is first called.
    pub(super) layers: Option<Vec<bool>>,
    /// Whether [`Engine::show_comments`] last hid the comments, which every reload keeps.
    pub(super) comments_hidden: bool,
}

impl Model {
    /// The model of `document`, opened from `path`, with nothing laid out or revised yet.
    pub(super) fn new(
        document: ferman_core::Document,
        path: PathBuf,
        read_only: Option<ferman_text::NotEditableReason>,
        layers_switchable: bool,
        first: Option<Arc<PageText>>,
    ) -> Self {
        let texts = document
            .structure()
            .pages
            .first()
            .map(ferman_core::structure::Page::handle)
            .zip(first)
            .into_iter()
            .collect();
        let store = Arc::new(RevisionStore::new(&document));
        Self {
            read_only,
            revised: Mutex::new(Revised {
                store: Arc::clone(&store),
                generation: 0,
                blocks: HashMap::new(),
                texts,
                layers: None,
                comments_hidden: false,
            }),
            path,
            rendered: Mutex::new(Rendered {
                serial: 0,
                store: Some(store),
            }),
            stamp: document.source().stamp(),
            recovery: Mutex::new(None),
            shown: Mutex::new(None),
            document,
            layers_switchable,
            owner_unlocked: AtomicBool::new(false),
        }
    }
}

impl Model {
    /// The snapshot the actor last published.
    pub(super) fn revised(&self) -> MutexGuard<'_, Revised> {
        self.revised.lock().unwrap_or_else(PoisonError::into_inner)
    }

    /// The pages, outline and attachments of the published revisions when the app has not heard
    /// of them yet.
    pub(super) fn structure_change(&self) -> Option<DocumentStructure> {
        let store = Arc::clone(&self.revised().store);
        let doc = &self.document;
        let mut shown = self.shown.lock().unwrap_or_else(PoisonError::into_inner);
        let (pages, outline, attachments) =
            (store.pages(doc), store.outline(doc), store.attachments(doc));
        let same = match &*shown {
            Some(shown) => {
                shown.pages == pages && shown.outline == outline && shown.attachments == attachments
            }
            None => {
                let opened = doc.structure();
                opened.pages == pages
                    && opened.outline == outline
                    && opened.attachments == attachments
            }
        };
        if same {
            return None;
        }
        *shown = Some(RevisedStructure {
            pages: pages.to_vec(),
            outline: outline.to_vec(),
            attachments: attachments.to_vec(),
        });
        Some(DocumentStructure {
            pages: pages.iter().map(page_info).collect(),
            outline: outline.to_vec(),
            attachments: attachments.to_vec(),
        })
    }

    /// The document's security now, `None` when it is not encrypted.
    pub(super) fn security(&self) -> Option<Security> {
        self.document.encryption().map(|encryption| Security {
            method: encryption.method,
            user_password_required: encryption.user_password_required,
            permissions: encryption.permissions,
            owner: self.document.access() == Access::Owner
                || self.owner_unlocked.load(Ordering::Relaxed),
        })
    }
}

/// One page of an [`OpenedDocument`].
#[derive(Debug, Clone, PartialEq)]
pub struct PageInfo {
    /// Its size in points as displayed, after the crop box and `/Rotate`.
    pub size: PageSize,
    /// Its `/Rotate` in degrees clockwise: 0, 90, 180 or 270.
    pub rotation: u16,
    /// Its label (`/PageLabels`), such as "iv", when the document has labels.
    pub label: Option<String>,
    /// What names it while the document is open, whatever moves around it.
    pub handle: u64,
}

/// `page` as the API gives it.
fn page_info(page: &Page) -> PageInfo {
    PageInfo {
        size: PageSize {
            width: page.size.0,
            height: page.size.1,
        },
        rotation: page.rotation,
        label: page.label.clone(),
        handle: page.handle(),
    }
}

/// What a commit can change of an [`OpenedDocument`]'s lists.
#[derive(Debug, Clone, PartialEq)]
pub struct DocumentStructure {
    /// Its pages.
    pub pages: Vec<PageInfo>,
    /// The outline (bookmarks).
    pub outline: Vec<OutlineItem>,
    /// Embedded files and file attachment annotations.
    pub attachments: Vec<Attachment>,
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
    /// opens again (a1-8). The render thread keeps a copy to reload the document, wiped when the
    /// document closes, and PDFium keeps its own while the document is open (docs/QUESTIONS.md,
    /// Q22).
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
            self.render()?;
            // Versions past 30 days go at each open (ADR 0022).
            self.versions.purge_soon();
            let (source, model, first) = parse(path.clone(), password.clone()).await?;
            self.register(path, password, &source, model, first, |_| {})
                .await
        })
        .await
    }

    /// Loads an opened document's bytes into PDFium, compares the parsers and keeps its model,
    /// changed by `setup` first (a restored document's revisions).
    pub(super) async fn register(
        &self,
        path: PathBuf,
        password: Option<Password>,
        source: &Source,
        model: ferman_core::Document,
        first: Option<Arc<PageText>>,
        setup: impl FnOnce(&mut Model),
    ) -> Result<OpenedDocument, ApiError> {
        {
            let render = self.render()?;
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
                .map(|(index, &size)| {
                    let page = structure.pages.get(index);
                    PageInfo {
                        size,
                        rotation: page.map_or(0, |page| page.rotation),
                        label: page.and_then(|page| page.label.clone()),
                        // Past the file's own pages only when the parsers disagree: read-only.
                        handle: page.map_or(0, Page::handle),
                    }
                })
                .collect();
            let layers_switchable = !structure.layers.is_empty() && model.repair().is_none();
            let mut opened = OpenedDocument {
                id: rendered.id,
                read_only,
                direction: structure.direction,
                pages,
                outline: structure.outline.clone(),
                attachments: structure.attachments.clone(),
                layers: structure.layers.clone(),
                signatures: structure.signatures.clone(),
                signed: structure.signed(),
                certification: structure.certification,
                layers_switchable,
                version: model.version().to_owned(),
                file_size: u64::try_from(source.bytes().len()).unwrap_or(u64::MAX),
                info: structure.info.clone(),
                language: structure.language.clone(),
                tagged: structure.tagged,
                linearized: model.linearized(),
                fonts: structure.fonts.clone(),
                security: model.encryption().map(|encryption| Security {
                    method: encryption.method,
                    user_password_required: encryption.user_password_required,
                    permissions: encryption.permissions,
                    owner: model.access() == Access::Owner,
                }),
                scripts: structure.scripts,
                form_fields: structure.forms.fields,
                scanned: first
                    .as_ref()
                    .is_some_and(|text| text.text.trim().is_empty()),
            };
            let not_editable = opened.read_only.as_ref().map(|read_only| match read_only {
                ReadOnly::Repaired(_) | ReadOnly::ParsersDisagree(_) => {
                    ferman_text::NotEditableReason::Damaged
                }
                ReadOnly::XfaOnly => ferman_text::NotEditableReason::ReadOnly,
            });
            let mut model = Model::new(model, path, not_editable, layers_switchable, first);
            setup(&mut model);
            // A restored document opens as its revisions leave it.
            if let Some(change) = model.structure_change() {
                opened.pages = change.pages;
                opened.outline = change.outline;
                opened.attachments = change.attachments;
            }
            self.models()?.insert(rendered.id, Arc::new(model));
            Ok(opened)
        }
    }

    /// Shows the layers of `document` whose `visible` is true and hides the others, in the order
    /// of [`OpenedDocument::layers`], in every view (a2-3c). PDFium loads the document again with
    /// a render-only appendix after its bytes (ADR 0009); nothing is written. Returns every page's
    /// new render key: bitmaps with an older one show the layers as they were.
    ///
    /// # Errors
    ///
    /// Returns `InvalidInput` when `visible` does not have one value per layer, `Unsupported` for
    /// a document whose layers cannot be switched ([`OpenedDocument::layers_switchable`]), or
    /// `Internal` when the reload fails.
    pub async fn show_layers(
        &self,
        document: DocumentId,
        visible: Vec<bool>,
    ) -> Result<u64, ApiError> {
        guard_async(async move {
            {
                let models = self.models()?;
                let model = models
                    .get(&document)
                    .filter(|model| model.layers_switchable)
                    .ok_or_else(|| {
                        ApiError::new(ErrorKind::Unsupported, MessageKey::UNSUPPORTED)
                            .with_details("no layers to switch")
                    })?;
                if visible.len() != model.document.structure().layers.len() {
                    return Err(ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                        .with_details("one visibility per layer"));
                }
            }
            // The actor builds it over the revisions; a commit that reached the render thread
            // first has it build again, so the reload shown is the newest.
            loop {
                self.render()?;
                let shown = visible.clone();
                let reload = self
                    .ask(document, move |session| session.show_layers(shown))
                    .await?;
                if let Some((key, _)) = self.send_reload(document, reload, true).await {
                    return Ok(key?);
                }
            }
        })
        .await
    }

    /// Shows or hides every markup annotation of `document` in every view (a4-5, decision 12):
    /// PDFium loads it again with a render-only appendix (ADR 0009), combined with the layers.
    /// Widgets, links and signatures stay, nothing is written, and saving does not carry it.
    /// Returns every page's new render key.
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open, `Unsupported` for a repaired one, which the
    /// writer refuses as it does for layers (B111), `Internal` when the reload fails.
    pub async fn show_comments(
        &self,
        document: DocumentId,
        visible: bool,
    ) -> Result<u64, ApiError> {
        guard_async(async move {
            if self
                .models()?
                .get(&document)
                .is_some_and(|model| model.document.repair().is_some())
            {
                return Err(
                    ApiError::new(ErrorKind::Unsupported, MessageKey::UNSUPPORTED)
                        .with_details("a repaired document"),
                );
            }
            // As show_layers: a commit that reached the render thread first has it build again.
            loop {
                self.render()?;
                let reload = self
                    .ask(document, move |session| session.hide_comments(!visible))
                    .await?;
                if let Some((key, _)) = self.send_reload(document, reload, true).await {
                    return Ok(key?);
                }
            }
        })
        .await
    }

    /// Lifts the restrictions of `document` for this session when `password` is its owner
    /// password (a2-10a); the password is wiped when the check ends. Returns the document's
    /// security from then on, `None` for one that is not encrypted. The key check runs on a thread
    /// of its own: revision 6 hashes the password many times.
    ///
    /// # Errors
    ///
    /// Returns `WrongPassword` when it is not the owner password, `NotFound` for a document that
    /// is not open, or `Internal` when a cipher cannot be set up.
    pub async fn unlock_owner(
        &self,
        document: DocumentId,
        password: Password,
    ) -> Result<Option<Security>, ApiError> {
        guard_async(async move {
            let model = self
                .models()?
                .get(&document)
                .cloned()
                .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
            let (reply, receiver) = futures_channel::oneshot::channel();
            let checked = Arc::clone(&model);
            thread::Builder::new()
                .name(PARSE_THREAD.to_owned())
                .spawn(move || {
                    // The check reads the shared model and changes nothing.
                    let result = guard(AssertUnwindSafe(move || {
                        Ok(checked.document.is_owner_password(&password)?)
                    }));
                    let _ = reply.send(result);
                })
                .map_err(|_| ApiError::internal("cannot start the unlock thread"))?;
            let owner = receiver
                .await
                .map_err(|_canceled| ApiError::internal("the unlock thread stopped"))??;
            if !owner {
                return Err(ApiError::new(
                    ErrorKind::WrongPassword,
                    MessageKey::WRONG_PASSWORD,
                ));
            }
            model.owner_unlocked.store(true, Ordering::Relaxed);
            Ok(model.security())
        })
        .await
    }

    /// Saves the file attached to `document` as its `attachments[index]` at `path` (a2-3b,
    /// B110), through ferman-core's safe write (ADR 0008), on a thread of its own: decoding and
    /// writing take a while for a large file. With `staging` (the macOS App Sandbox's replacement
    /// directory) the verified temp file stays there and its path is returned for the platform
    /// layer to swap in; otherwise it replaces `path` and `None` is returned. The file is never
    /// opened or run.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, the core's error for an attachment
    /// that cannot be read, and the file errors of the write (`PermissionDenied`, `NotFound`, …).
    pub async fn save_attachment(
        &self,
        document: DocumentId,
        index: u32,
        path: PathBuf,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        guard_async(async move {
            let model = self
                .models()?
                .get(&document)
                .cloned()
                .ok_or_else(|| ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL))?;
            let index = usize::try_from(index)
                .map_err(|_| ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL))?;
            let (reply, receiver) = futures_channel::oneshot::channel();
            thread::Builder::new()
                .name(PARSE_THREAD.to_owned())
                .spawn(move || {
                    let result = guard(AssertUnwindSafe(move || {
                        let store = Arc::clone(&model.revised().store);
                        let bytes = store.attachment_data(&model.document, index)?;
                        Ok(ferman_core::save::safe_write(
                            &path,
                            &bytes,
                            staging.as_deref(),
                        )?)
                    }));
                    let _ = reply.send(result);
                })
                .map_err(|_| ApiError::internal("cannot start the attachment thread"))?;
            receiver
                .await
                .map_err(|_canceled| ApiError::internal("the attachment thread stopped"))?
        })
        .await
    }

    /// Writes `text` to `path` through the safe write: the review list's export (a3-12). With
    /// `staging`, as [`save_attachment`](Self::save_attachment), the staged path comes back for
    /// the platform layer to swap in.
    ///
    /// # Errors
    ///
    /// The file errors of the write.
    pub async fn save_text(
        &self,
        path: PathBuf,
        text: String,
        staging: Option<PathBuf>,
    ) -> Result<Option<PathBuf>, ApiError> {
        guard_async(async move {
            let (reply, receiver) = futures_channel::oneshot::channel();
            thread::Builder::new()
                .name(PARSE_THREAD.to_owned())
                .spawn(move || {
                    let result = guard(AssertUnwindSafe(move || {
                        Ok(ferman_core::save::safe_write(
                            &path,
                            text.as_bytes(),
                            staging.as_deref(),
                        )?)
                    }));
                    let _ = reply.send(result);
                })
                .map_err(|_| ApiError::internal("cannot start the writing thread"))?;
            receiver
                .await
                .map_err(|_canceled| ApiError::internal("the writing thread stopped"))?
        })
        .await
    }

    /// Closes a document: its views end and PDFium lets it go. Its recovery files stay, for
    /// the next launch to offer; [`close_discarding`](Self::close_discarding) deletes them.
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open.
    pub async fn close(&self, document: DocumentId) -> Result<(), ApiError> {
        self.close_with(document, false).await
    }

    /// Closes a document after "Don't save": as [`close`](Self::close), and its recovery files
    /// are deleted (docs/ARCHITECTURE.md §7.6).
    ///
    /// # Errors
    ///
    /// As [`close`](Self::close).
    pub async fn close_discarding(&self, document: DocumentId) -> Result<(), ApiError> {
        self.close_with(document, true).await
    }

    async fn close_with(&self, document: DocumentId, discard: bool) -> Result<(), ApiError> {
        guard_async(async {
            self.models()?.remove(&document);
            self.end_edits(document, discard).await;
            Ok(self.render()?.close_document(document).await?)
        })
        .await
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

    /// Renders the whole of page `page` (of size `size`) of `document` at `dpi`, tile for tile as
    /// the canvas gets it, for the pixel-diff harness ([`ferman_render::render_page`]).
    ///
    /// # Errors
    ///
    /// Returns `NotFound` for a document that is not open, and the render thread's errors.
    pub async fn render_page(
        &self,
        document: DocumentId,
        page: u32,
        size: PageSize,
        dpi: u32,
    ) -> Result<PageRaster, ApiError> {
        guard_async(async {
            Ok(ferman_render::render_page(self.render()?, document, page, size, dpi).await?)
        })
        .await
    }

    /// The parsed models of the open documents.
    pub(super) fn models(
        &self,
    ) -> Result<MutexGuard<'_, HashMap<DocumentId, Arc<Model>>>, ApiError> {
        self.models
            .lock()
            .map_err(|_poisoned| ApiError::internal("the models' lock is poisoned"))
    }

    /// The render thread, or an internal error saying why it is not running.
    pub(super) fn render(&self) -> Result<&RenderThread, ApiError> {
        self.render.as_ref().map_err(ApiError::internal)
    }
}

/// Reads and parses the file on a thread of its own, so a large file never holds an async worker,
/// and a panic in a parser becomes an error ([`guard`]).
async fn parse(
    path: PathBuf,
    password: Option<Password>,
) -> Result<(Source, ferman_core::Document, Option<Arc<PageText>>), ApiError> {
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
                // The first page's text, for the Scanned badge and the first search; a page
                // that cannot be read says nothing.
                let first = (model.page_count() > 0)
                    .then(|| {
                        ferman_text::text_page(&model, 0, &ferman_text::EditContext::default()).ok()
                    })
                    .flatten()
                    .map(|page| Arc::new(super::search::in_reading_order(&page)));
                Ok((source, model, first))
            });
            // The caller may have stopped waiting; then nobody needs the result.
            let _ = reply.send(result);
        })
        .map_err(|_| ApiError::internal("cannot start the open thread"))?;
    receiver
        .await
        .map_err(|_canceled| ApiError::internal("the open thread stopped"))?
}
