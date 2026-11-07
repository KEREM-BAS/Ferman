//! Compress (a9-1, decisions 25 and 26 of the M4 plan) and printing (a9-6, question 3 and
//! decision 29).
//!
//! [`Engine::compress_analysis`] says what each preset would do and its estimated size, sampled
//! by image bytes; [`Engine::compress_job`] writes the compressed document as a new file in a job
//! that reads the revisions as they stand when it starts. A signed document is written without
//! its signatures, and only when the caller says the warning was accepted (`unsign`); the signed
//! original is never touched. A result no smaller than the file keeps the original and writes
//! nothing; the job's last event carries `before`, `after` and `written` as facts for the app to
//! word (a11-6b's "24,6 MB → 6,9 MB").
//!
//! [`Engine::print_pages`] streams the pages to print one by one, rendered by PDFium from a copy
//! of the document's bytes with its revisions, in memory: an encrypted document never reaches
//! disk as a file, and the password stays on the render thread. It needs the print permission;
//! a document that allows only low-quality printing prints at [`LOW_PRINT_DPI`].
//!
//! shortcut: form fields do not print, because PDFium draws widgets only through its form-fill
//! overlay, which the tiles do not use (B203); print them once the canvas draws them.

use std::panic::AssertUnwindSafe;
use std::path::PathBuf;
use std::sync::Arc;

use ferman_core::{CoreError, DocumentOp};
use ferman_ops::compress::{self, Estimate, Preset};
use ferman_render::{DocumentId, PageSize};

use super::assemble::{free_output, off_the_worker};
use super::engine::Engine;
use super::error::{ApiError, ErrorKind, MessageKey};
use super::guard::{guard, guard_async};
use super::jobs::{JobId, JobSink, JobStop};

/// The resolution of a print, in dots per inch.
pub const PRINT_DPI: u32 = 300;

/// The resolution of a document that allows only low-quality printing.
pub const LOW_PRINT_DPI: u32 = 150;

/// What Compress would do to a document (a9-1).
#[derive(Debug, Clone, PartialEq)]
pub struct CompressAnalysis {
    /// The size of the file now, in bytes: the save of the current revision.
    pub before: u64,
    /// Each preset's estimate, in the order High quality, Balanced, Smallest.
    pub estimates: Vec<(Preset, Estimate)>,
    /// The images it may recompress ("Recompresses 1.842 images").
    pub images: u32,
    /// Images left as they are: formats and colours it does not decode (JPX, JBIG2, CCITT, …).
    pub unreadable: u32,
    /// Masks, and images with a colour-key mask, left as they are.
    pub masks: u32,
    /// Images drawn only through patterns, left as they are.
    pub patterns: u32,
    /// Duplicate font copies merged ("Merges 6 duplicate font copies").
    pub duplicate_fonts: u32,
    /// Pages whose thumbnail goes.
    pub thumbnails: u32,
    /// Whether the document is signed: compressing needs the warning first and removes the
    /// signatures from the copy (decision 25).
    pub signed: bool,
}

/// One page of a print (a9-6).
#[derive(Debug, Clone, PartialEq)]
pub struct PrintPage {
    /// Its index in the document, from 0.
    pub index: u32,
    /// Its size as displayed, in points.
    pub size: PageSize,
    /// The resolution it is rendered at.
    pub dpi: u32,
    /// Its width in device pixels.
    pub width: u32,
    /// Its height in device pixels.
    pub height: u32,
    /// 8-bit BGRA, opaque, `width × 4` bytes per row, the top row first.
    pub pixels: Vec<u8>,
}

/// Receives a print's pages one by one, on the caller's task.
pub trait PrintSink: Send {
    /// Delivers one page; `false` when nobody listens any more, which ends the print.
    fn deliver(&mut self, page: PrintPage) -> bool;
}

impl Engine {
    /// What Compress would do to `document` as its revisions stand now, with each preset's
    /// estimated size.
    ///
    /// # Errors
    ///
    /// `NotFound` for a document that is not open, and the writer's errors.
    pub async fn compress_analysis(
        &self,
        document: DocumentId,
    ) -> Result<CompressAnalysis, ApiError> {
        guard_async(async move {
            let snapshot = self.job_snapshot(document)?;
            off_the_worker(move || {
                let (base, store) = (snapshot.base(), snapshot.store());
                let signed = base.structure().signed();
                let plan = compress::plan(base, store)?;
                let limits = ferman_core::OpenOptions::default().limits;
                let mut go = || Ok::<(), ApiError>(());
                let estimates = [Preset::HighQuality, Preset::Balanced, Preset::Smallest]
                    .into_iter()
                    .map(|preset| {
                        compress::estimate(base, store, &plan, preset, signed, &limits, &mut go)
                            .map(|estimate| (preset, estimate))
                    })
                    .collect::<Result<Vec<_>, ApiError>>()?;
                Ok(CompressAnalysis {
                    before: plan.before,
                    estimates,
                    images: u32::try_from(plan.scan.images.len()).unwrap_or(u32::MAX),
                    unreadable: plan.scan.unreadable,
                    masks: plan.scan.masks,
                    patterns: plan.scan.patterns,
                    duplicate_fonts: plan.duplicate_fonts,
                    thumbnails: plan.thumbnails,
                    signed,
                })
            })
            .await
        })
        .await
    }

    /// Compresses `document` as its revisions stand now with `preset` into the new file `output`,
    /// as a job; with `staging` the file waits there for the platform layer's swap. A signed
    /// document needs `unsign`, the warning accepted, and its copy has no signatures. A result no
    /// smaller than the file writes nothing. The last event's facts: `before` and `after` in
    /// bytes, `written` (`true` or `false`), `recompressed` and `unreadable` image counts.
    ///
    /// # Errors
    ///
    /// `InvalidInput` when `output` exists, `ConfirmationRequired` for a signed document without
    /// `unsign`, `NotFound`. The job fails with the writer's errors.
    pub fn compress_job(
        &self,
        document: DocumentId,
        preset: Preset,
        unsign: bool,
        output: PathBuf,
        staging: Option<PathBuf>,
        sink: Box<dyn JobSink>,
    ) -> Result<JobId, ApiError> {
        guard(AssertUnwindSafe(|| {
            free_output(&output)?;
            let snapshot = self.job_snapshot(document)?;
            let signed = snapshot.base().structure().signed();
            if signed && !unsign {
                return Err(ApiError::new(
                    ErrorKind::ConfirmationRequired,
                    MessageKey::INTERNAL,
                ));
            }
            let read = snapshot.clone();
            self.start_job(Some(&read), sink, move |run| {
                run.checkpoint()?;
                let (base, store) = (snapshot.base(), snapshot.store());
                let plan = compress::plan(base, store)?;
                let limits = ferman_core::OpenOptions::default().limits;
                let total = plan.scan.images.len().max(1);
                let mut done = 0usize;
                let compressed = {
                    let mut step = || -> Result<(), JobStop> {
                        run.checkpoint()?;
                        done = done.saturating_add(1);
                        // A progress fraction: precision does not matter.
                        #[allow(clippy::cast_precision_loss)]
                        run.fraction(done as f32 / total as f32);
                        Ok(())
                    };
                    compress::compress(base, store, &plan, preset, signed, &limits, &mut step)?
                };
                run.checkpoint()?;
                let after = u64::try_from(compressed.bytes.len()).unwrap_or(u64::MAX);
                // A larger result keeps the original and says so (decision 25).
                let written = after < plan.before;
                if written {
                    run.output_pdf(output, &compressed.bytes, staging)?;
                }
                run.facts(vec![
                    ("before".to_owned(), plan.before.to_string()),
                    ("after".to_owned(), after.to_string()),
                    ("written".to_owned(), written.to_string()),
                    (
                        "recompressed".to_owned(),
                        compressed.recompressed.to_string(),
                    ),
                    (
                        "unreadable".to_owned(),
                        plan.scan
                            .unreadable
                            .saturating_add(compressed.unreadable)
                            .to_string(),
                    ),
                ]);
                Ok(None)
            })
        }))
    }

    /// Streams `pages` of `document` (by handle, in order; all of them when empty) to `sink` for
    /// the platform's print channel, one rendered page at a time, with the revisions as they
    /// stand and, without `include_comments`, its markup annotations hidden. The rendering is a copy of the document in PDFium, in memory,
    /// closed at the end, and nothing reaches disk. Stops when the sink stops listening.
    ///
    /// # Errors
    ///
    /// `NotEditable` when the document forbids printing and its owner password was not given,
    /// `InvalidInput` for a page it does not have, `NotFound`, and the render thread's errors.
    pub async fn print_pages(
        &self,
        document: DocumentId,
        pages: Vec<u64>,
        include_comments: bool,
        mut sink: Box<dyn PrintSink>,
    ) -> Result<(), ApiError> {
        guard_async(async move {
            let snapshot = self.job_snapshot(document)?;
            let security = snapshot.security();
            if security.is_some_and(|security| {
                !security.owner && !security.permissions.allows(DocumentOp::Print)
            }) {
                return Err(ApiError::not_editable(
                    ferman_text::NotEditableReason::Restricted,
                ));
            }
            let dpi = if security.is_some_and(|security| {
                !security.owner && !security.permissions.print_high_quality()
            }) {
                LOW_PRINT_DPI
            } else {
                PRINT_DPI
            };
            let indices = if pages.is_empty() {
                (0..snapshot.store().pages(snapshot.base()).len()).collect()
            } else {
                pages
                    .iter()
                    .map(|handle| snapshot.store().page_index(snapshot.base(), *handle))
                    .collect::<Option<Vec<usize>>>()
                    .ok_or_else(|| {
                        ApiError::new(ErrorKind::InvalidInput, MessageKey::INTERNAL)
                            .with_details("a page the document does not have")
                    })?
            };
            let appendix = off_the_worker(move || {
                Ok(snapshot
                    .store()
                    .render_appendix(snapshot.base(), None, !include_comments)?)
            })
            .await?;
            let render = self.render()?;
            let copy = render.open_copy(document, Arc::from(appendix)).await?;
            let printed = async {
                for index in indices {
                    let page = u32::try_from(index).unwrap_or(u32::MAX);
                    let size = copy
                        .pages
                        .get(index)
                        .copied()
                        .ok_or(CoreError::Write(ferman_core::WriteError::NoSuchPage))?;
                    let raster =
                        ferman_render::render_page(render, copy.id, page, size, dpi).await?;
                    let delivered = sink.deliver(PrintPage {
                        index: page,
                        size,
                        dpi,
                        width: raster.width,
                        height: raster.height,
                        pixels: raster.pixels,
                    });
                    if !delivered {
                        break;
                    }
                }
                Ok::<(), ApiError>(())
            }
            .await;
            let closed = render.close_document(copy.id).await;
            printed?;
            Ok(closed?)
        })
        .await
    }
}
