//! The Ferman font layer.
//!
//! ferman-fonts works on font program bytes, encoding tables and CMap bytes. It knows nothing about
//! PDF: it depends on no other Ferman crate, so it can be tested and fuzzed alone
//! (docs/ARCHITECTURE.md §2.2 and §2.3). ferman-text turns PDF font resources into the inputs this
//! crate understands.
//!
//! Its responsibilities: font programs (TrueType and CFF/CFF2 through skrifa and read-fonts, and a
//! minimal Type1 parser for built-in encodings and glyph names), encoding tables, glyph names to
//! Unicode, CMap and ToUnicode parsing with `usecmap` chains, coverage, metric comparison for the
//! similar-font ranking, shaping, subsetting, system font discovery, the registry of fonts bundled
//! with the app, and glyph and shaping caches. Missing glyphs are never substituted silently
//! (ADR 0006).
//!
//! # Planned modules
//!
//! The crate is a skeleton in M1. The layout below follows docs/ARCHITECTURE.md §2.3; each module
//! arrives with the milestone that needs it.
//!
//! - `program`: `FontProgram` and `GlyphId`; TrueType and CFF/CFF2 through skrifa and read-fonts,
//!   and the minimal Type1 parser. M2.
//! - `encoding` (since M2): [`BaseEncoding`] (Standard, WinAnsi, MacRoman), [`SimpleEncoding`]
//!   with `/Differences`, and glyph names to text ([`glyph_text`]). MacExpert, PDFDoc, Symbol and
//!   ZapfDingbats follow with the fonts that need them.
//! - `cmap` (since M2): [`CMap`], encoding and ToUnicode CMaps read leniently, with `usecmap`
//!   recorded for the caller's depth limit; writing in M3.
//! - `shaping`: the internal `Shaper` trait and `ShapedRun`, with harfrust behind it (ADR 0007), so
//!   a change of shaper touches one module. M3.
//! - `subset`: `Subset` through subsetter, respecting embedding permissions (OS/2 `fsType`). M3.
//! - `system`: `SystemFonts` discovery through fontdb, the bundled-font registry, `Coverage`,
//!   `FontMatch` and `SimilarFonts`. M3.
#![forbid(unsafe_code)]

pub mod cmap;
pub mod encoding;

pub use cmap::CMap;
pub use encoding::{BaseEncoding, SimpleEncoding, glyph_text};

/// The version of this crate, reported by `engine_info()` in ferman-api.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Errors from ferman-fonts.
///
/// Variants carry structural context (table names, offsets, glyph counts), never text from a
/// document (ADR 0010).
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum FontError {
    /// An internal invariant did not hold. This is a bug in Ferman, reported as an error instead of
    /// a panic (ADR 0010).
    #[error("internal error in ferman-fonts: {context}")]
    Internal {
        /// What ferman-fonts was doing when the invariant failed.
        context: &'static str,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal_error_names_the_crate_and_context() {
        let err = FontError::Internal {
            context: "cmap lookup",
        };
        assert_eq!(
            err.to_string(),
            "internal error in ferman-fonts: cmap lookup"
        );
    }

    #[test]
    fn error_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<FontError>();
    }
}
