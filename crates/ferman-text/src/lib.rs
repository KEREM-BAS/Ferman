//! The Ferman text model.
//!
//! ferman-text sits on ferman-core and ferman-fonts. It resolves PDF font resources into a
//! `PdfFont` (dictionary, program, encoding, ToUnicode, widths, vertical metrics), implements the
//! interpreter's `TextAdvance` trait, builds glyph runs, maps glyphs to Unicode, and rebuilds words,
//! lines, blocks, columns, alignment and reading order. It assigns block ids, answers hit tests,
//! decides editability, runs edit operations with line breaking, reflow and bidi, re-encodes text in
//! the font's own encoding and generates the replacement operators for one block, resolves missing
//! glyphs and overflow, extracts search text and keeps the edit journal (docs/ARCHITECTURE.md §2.3
//! and §6).
//!
//! An edit rewrites only the operators of the edited block; every other byte of the page content
//! stays identical (ADR 0005).
//!
//! # Planned modules
//!
//! The crate is a skeleton in M1. The layout below follows docs/ARCHITECTURE.md §2.3; each module
//! arrives with the milestone that needs it.
//!
//! - `font`: `PdfFont` resolution and the `TextAdvance` implementation, positions from the PDF
//!   widths. M2.
//! - `runs`: `GlyphRun` and glyphs to Unicode in the order of §6.3. M2.
//! - `layout`: `PageText`, `TextBlock` and `Line`; words, lines, blocks, columns, alignment and
//!   reading order, bidi for right-to-left scripts. Lines in M2, blocks and columns in M3.
//! - `search`: `SearchIndex`, search text and match quads per page. M2.
//! - `hit`: hit testing and caret stops by `BlockId`. M3.
//! - `edit`: `Editability`, `EditOp` and `BlockEditor`; line breaking, reflow, re-encoding and
//!   operator generation with the state invariant. M3.
//! - `plans`: `MissingGlyphPlan` and `OverflowPlan`, with the amounts computed for the block
//!   (ADR 0006, §6.7 and §6.8). M3.
//! - `journal`: the edit journal behind the review list. M3.
#![forbid(unsafe_code)]

/// The version of this crate, reported by `engine_info()` in ferman-api.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Errors from ferman-text.
///
/// Variants carry structural context (page, block id, operator offset), never document text
/// (ADR 0010).
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum TextError {
    /// A ferman-core operation failed.
    #[error(transparent)]
    Core(#[from] ferman_core::CoreError),
    /// A ferman-fonts operation failed.
    #[error(transparent)]
    Font(#[from] ferman_fonts::FontError),
    /// An internal invariant did not hold. This is a bug in Ferman, reported as an error instead of
    /// a panic (ADR 0010).
    #[error("internal error in ferman-text: {context}")]
    Internal {
        /// What ferman-text was doing when the invariant failed.
        context: &'static str,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal_error_names_the_crate_and_context() {
        let err = TextError::Internal {
            context: "line assembly",
        };
        assert_eq!(
            err.to_string(),
            "internal error in ferman-text: line assembly"
        );
    }

    #[test]
    fn lower_errors_pass_through_unchanged() {
        let err = TextError::from(ferman_fonts::FontError::Internal {
            context: "cmap lookup",
        });
        assert_eq!(
            err.to_string(),
            "internal error in ferman-fonts: cmap lookup"
        );
    }

    #[test]
    fn error_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<TextError>();
    }
}
