//! The Ferman renderer.
//!
//! ferman-render is the only crate that links PDFium, through pdfium-render with the prebuilt
//! bblanchon/pdfium-binaries tag `chromium/7881` (non-V8, non-XFA). PDFium is a read-only
//! rasteriser: lopdf in ferman-core is the source of truth, and PDFium only reloads the revised
//! bytes after a commit that changes pixels (ADR 0004). Only ferman-api depends on this crate, so
//! PDFium stays behind one door (docs/ARCHITECTURE.md §2.2).
//!
//! Its responsibilities: load the PDFium library at run time from a path in the engine
//! configuration, own the single render thread (PDFium is not thread-safe), load documents from
//! their bytes and read their page sizes, render tiles (a clip rectangle plus a matrix) and
//! thumbnails, run the prioritised tile queue with its wanted sets, and keep the tile, thumbnail
//! and loaded-page caches. Render flags are fixed and documented, because the pixel-diff
//! acceptance tests depend on deterministic output (docs/ARCHITECTURE.md §2.3 and §4).
//!
//! # Use
//!
//! [`RenderThread::start`] starts the thread. [`RenderThread::open_document`] loads a document and
//! returns its id and page sizes; [`RenderThread::open_view`] opens a view of it whose
//! [`ViewEvent`]s go to a [`ViewSink`]; [`RenderThread::request`] replaces the view's wanted set
//! of [`Wanted`] tiles and thumbnails, with a generation; the thread delivers each bitmap as a
//! [`Rendered`] event, or a [`Failed`] one. Every call that answers returns a future that does not
//! borrow the handle, so async API functions never block.
//!
//! # Modules
//!
//! The layout follows docs/ARCHITECTURE.md §2.3 and the threading model of ADR 0009.
//!
//! - `thread` (M1, the queue since M2): [`RenderThread`], the dedicated thread that owns PDFium and
//!   every loaded document; [`RenderConfig`] with the library path and the cache caps;
//!   [`PdfiumStatus`]; [`DocumentId`], [`ViewId`] and [`OpenedDocument`].
//! - `tiles` (M2): what views ask for and get: [`ZoomBucket`] (quarter octaves), [`PageSize`],
//!   [`TileRequest`] on the 512-pixel grid of [`TILE_SIZE`], [`ThumbnailRequest`], [`Item`],
//!   [`Priority`], [`Wanted`], [`Rendered`], [`Failed`] with its [`FailReason`], [`ViewEvent`] and
//!   [`ViewSink`].
//! - `queue` (private, M2): the views' wanted sets, the order of work and the delivery to every
//!   view that wants a bitmap.
//! - `cache` (private, M2): the tile and thumbnail caches, capped by bytes, least recently used
//!   first.
//! - `document` (private, M2): a document in PDFium with its loaded-page cache, and rendering with
//!   the fixed flags it documents.
//! - `library` (private, M1): binding the library and the first call, and the rule that one render
//!   thread uses PDFium at a time, because pdfium-render's `thread_safe` lock covers only part of
//!   its bindings.
//!
//! Only `library`, `document` and `thread` name pdfium-render.
//!
//! Planned: reloading a revised document with new render keys per page (M3), and the render-only
//! appendix for layer visibility (M2 step 4, ADR 0009).
#![forbid(unsafe_code)]

mod cache;
mod document;
mod library;
mod queue;
mod thread;
mod tiles;

pub use thread::{
    DocumentId, OpenedDocument, PdfiumStatus, RenderConfig, RenderThread, THREAD_NAME, ViewId,
};
pub use tiles::{
    FailReason, Failed, Item, MAX_DEVICE_PIXEL_RATIO, MAX_THUMBNAIL_SIZE, MIN_DEVICE_PIXEL_RATIO,
    MIN_THUMBNAIL_SIZE, PageSize, PixelRect, Priority, Rendered, TILE_SIZE, ThumbnailRequest,
    TilePosition, TileRequest, ViewEvent, ViewSink, Wanted, ZoomBucket,
};

/// The version of this crate, reported by `engine_info()` in ferman-api.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// The bblanchon/pdfium-binaries release tag Ferman is built and tested against, as pinned in
/// `tools/pdfium/pdfium.lock` (a test compares the two).
///
/// PDFium has no runtime version API, so this is what `engine_info()` reports for a loaded
/// library. pdfium-render's API level (`pdfium_7881`) matches it, and the two move together
/// (ADR 0004).
pub const PDFIUM_TAG: &str = "chromium/7881";

/// Errors from ferman-render.
///
/// Variants carry structural context (page index, tile key), never rendered content or the library
/// path: their text reaches `engine_info()`, which ends up in bug reports (ADR 0010,
/// docs/ARCHITECTURE.md §8.4). The local log records the path.
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum RenderError {
    /// A ferman-core operation failed.
    #[error(transparent)]
    Core(#[from] ferman_core::CoreError),
    /// The operating system could not start the render thread.
    #[error("cannot start the render thread: {source}")]
    ThreadStart {
        /// The error from the operating system.
        source: std::io::Error,
    },
    /// The render thread is no longer running, so it cannot answer.
    #[error("the render thread has stopped")]
    ThreadStopped,
    /// The PDFium library could not be loaded or a function in it could not be found.
    #[error("cannot load the PDFium library: {reason}")]
    PdfiumLoad {
        /// The operating system's or pdfium-render's message, with the library path replaced by a
        /// placeholder.
        reason: String,
    },
    /// PDFium was bound, but the first call into it failed.
    #[error("PDFium was bound, but a first call into it failed: {reason}")]
    PdfiumProbe {
        /// What failed, without the library path.
        reason: String,
    },
    /// This process already bound PDFium from another file. pdfium-render binds one library per
    /// process and cannot unbind it.
    #[error("PDFium is already bound to another library in this process")]
    PdfiumAlreadyBound,
    /// Another render thread of this process holds PDFium. pdfium-render guards only part of its
    /// calls, so only one render thread may use PDFium at a time.
    #[error("PDFium is in use by another render thread of this process")]
    PdfiumInUse,
    /// PDFium is not loaded, so no document can be opened.
    #[error("PDFium is not available: {reason}")]
    PdfiumUnavailable {
        /// Why: the load failure, without the library path, or that no library was given.
        reason: String,
    },
    /// No open document or view has this id.
    #[error("no such {what}")]
    NotFound {
        /// What was looked for: `"document"` or `"view"`.
        what: &'static str,
    },
    /// The document is encrypted and PDFium needs its password to open it.
    #[error("the document needs a password")]
    PasswordRequired,
    /// The password given does not open the document.
    #[error("the password is wrong")]
    WrongPassword,
    /// The document's security handler is one PDFium does not have.
    #[error("the document uses a security handler PDFium does not support")]
    UnsupportedSecurity,
    /// PDFium cannot read the document.
    #[error("the document is damaged: {reason}")]
    Damaged {
        /// PDFium's error, without document content.
        reason: String,
    },
    /// Memory for the work could not be reserved.
    #[error("out of memory in ferman-render: {context}")]
    OutOfMemory {
        /// What ferman-render was reserving memory for.
        context: &'static str,
    },
    /// An internal invariant did not hold. This is a bug in Ferman, reported as an error instead of
    /// a panic (ADR 0010).
    #[error("internal error in ferman-render: {context}")]
    Internal {
        /// What ferman-render was doing when the invariant failed.
        context: &'static str,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal_error_names_the_crate_and_context() {
        let err = RenderError::Internal {
            context: "tile queue",
        };
        assert_eq!(
            err.to_string(),
            "internal error in ferman-render: tile queue"
        );
    }

    #[test]
    fn core_errors_pass_through_unchanged() {
        let err = RenderError::from(ferman_core::CoreError::Internal {
            context: "snapshot",
        });
        assert_eq!(err.to_string(), "internal error in ferman-core: snapshot");
    }

    #[test]
    fn pdfium_tag_matches_the_pin_in_tools_pdfium() {
        let lock =
            std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tools/pdfium/pdfium.lock");
        let text = std::fs::read_to_string(&lock).unwrap();
        let tags: Vec<&str> = text
            .lines()
            .filter_map(|line| line.strip_prefix("tag "))
            .map(str::trim)
            .collect();
        assert_eq!(tags, [PDFIUM_TAG], "{}", lock.display());
    }

    #[test]
    fn errors_never_need_a_path_to_explain_themselves() {
        assert_eq!(
            RenderError::PdfiumAlreadyBound.to_string(),
            "PDFium is already bound to another library in this process"
        );
        assert_eq!(
            RenderError::ThreadStopped.to_string(),
            "the render thread has stopped"
        );
    }

    #[test]
    fn error_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<RenderError>();
    }
}
