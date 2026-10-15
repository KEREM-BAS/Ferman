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
//! # Planned modules
//!
//! The crate is a skeleton in M1 and does not depend on pdfium-render yet. The layout below follows
//! docs/ARCHITECTURE.md §2.3 and the threading model of ADR 0009 (Proposed).
//!
//! - `thread`: the render thread that owns PDFium, loads the bundled library and reports whether it
//!   loaded and which pinned tag it is; every PDFium call runs here, with pdfium-render's
//!   `thread_safe` feature as a second guard. M1 step 3.
//! - `renderer`: `Renderer` and `ViewSession`; open a snapshot's bytes, page sizes, reload after a
//!   pixel-changing revision. M2.
//! - `tiles`: `TileRequest`, `Tile`, `TileKey` and `ZoomBucket`; 512 × 512 tiles in quarter-octave
//!   zoom buckets, and the prioritised, cancellable queue with wanted-set semantics. M2.
//! - `thumbnails`: `Thumbnail` rendering for the sidebar. M2.
//! - `cache`: the tile, thumbnail and loaded-page caches with their invalidation rules, §4.7. M2.
#![forbid(unsafe_code)]

/// The version of this crate, reported by `engine_info()` in ferman-api.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Errors from ferman-render.
///
/// Variants carry structural context (page index, tile key, library path), never rendered content
/// (ADR 0010).
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum RenderError {
    /// A ferman-core operation failed.
    #[error(transparent)]
    Core(#[from] ferman_core::CoreError),
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
    fn error_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<RenderError>();
    }
}
