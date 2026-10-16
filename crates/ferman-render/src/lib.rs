//! The Ferman renderer.
//!
//! ferman-render is the only crate that links PDFium, through pdfium-render with the prebuilt
//! bblanchon/pdfium-binaries tag `chromium/7881` (non-V8, non-XFA). PDFium is a read-only
//! rasteriser: lopdf in ferman-core is the source of truth, and PDFium only reloads the revised
//! bytes after a commit that changes pixels (ADR 0004). Only ferman-api depends on this crate, so
//! PDFium stays behind one door (docs/ARCHITECTURE.md §2.2).
//!
//! Its responsibilities: load the PDFium library at run time from a path in the engine
//! configuration, own the single render thread (PDFium is not thread-safe), render tiles (a clip
//! rectangle plus a matrix) and thumbnails, answer page-size queries, reload a document when a new
//! revision changes pixels, run the prioritised and cancellable tile queue, and keep the tile and
//! thumbnail caches. Render flags are fixed and documented, because the pixel-diff acceptance tests
//! depend on deterministic output (docs/ARCHITECTURE.md §2.3 and §4).
//!
//! # Modules
//!
//! The layout follows docs/ARCHITECTURE.md §2.3 and the threading model of ADR 0009 (Proposed).
//!
//! - `thread` (M1 step 3): [`RenderThread`], the dedicated thread that owns PDFium. It binds the
//!   library at run time from the path in [`RenderConfig`] (pdfium-render 0.9.4, API level
//!   `pdfium_7881`, `thread_safe` on as a second guard) and reports [`PdfiumStatus::Loaded`] with
//!   the pinned tag [`PDFIUM_TAG`] only after a real PDFium call succeeds. Requests go over a
//!   channel; each reply is a oneshot future, so async API functions never block. No PDF parsing
//!   or rendering yet.
//! - `library` (private): binding and the first call; the only module that names pdfium-render.
//!
//! Planned, each with the milestone that needs it:
//!
//! - `renderer`: `Renderer` and `ViewSession`; open a snapshot's bytes, page sizes, reload after a
//!   pixel-changing revision. M2.
//! - `tiles`: `TileRequest`, `Tile`, `TileKey` and `ZoomBucket`; 512 × 512 tiles in quarter-octave
//!   zoom buckets, and the prioritised, cancellable queue with wanted-set semantics. M2.
//! - `thumbnails`: `Thumbnail` rendering for the sidebar. M2.
//! - `cache`: the tile, thumbnail and loaded-page caches with their invalidation rules, §4.7. M2.
#![forbid(unsafe_code)]

mod library;
mod thread;

pub use thread::{PdfiumStatus, RenderConfig, RenderThread, THREAD_NAME};

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
