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
//! similar-font ranking, shaping, subsetting, system font discovery and the registry of fonts
//! bundled with the app. The glyph and shaping caches are not built yet (BACKLOG B167). Missing
//! glyphs are never substituted silently (ADR 0006).
//!
//! # Planned modules
//!
//! The crate is a skeleton in M1. The layout below follows docs/ARCHITECTURE.md §2.3; each module
//! arrives with the milestone that needs it.
//!
//! - `program` (since M3): [`FontProgram`] and [`GlyphId`]; TrueType and OpenType through skrifa,
//!   bare CFF and Type1 through read-fonts. A Type1 built-in encoding stays with `type1`.
//! - `encoding` (since M2): [`BaseEncoding`] (Standard, WinAnsi, MacRoman), [`SimpleEncoding`]
//!   with `/Differences`, and glyph names to text ([`glyph_text`]); since M3 also text back to
//!   codes. MacExpert, PDFDoc, Symbol and ZapfDingbats follow with the fonts that need them.
//! - `type1` (since M2): the minimal clear-text Type1 parser, a program's [`BuiltinEncoding`] from its
//!   clear text ([`builtin_encoding`]).
//! - `cmap` (since M2): [`CMap`], encoding and ToUnicode CMaps read leniently, with `usecmap`
//!   recorded for the caller's depth limit; since M3 also text or CID back to code, the
//!   predefined CMaps bundled from Adobe's cmap-resources ([`CMap::predefined`]), and ToUnicode
//!   CMaps with added entries ([`with_text`]).
//! - `shape` (since M3): [`ShapingFont`] and [`ShapedRun`], harfrust behind the crate-private
//!   `Shaper` trait (ADR 0007), so a change of shaper touches one module.
//! - `subset` (since M3): [`subset()`] through subsetter, with the widths, ToUnicode text, subset
//!   name and descriptor metrics a PDF writer needs, respecting [`Embedding`] (OS/2 `fsType`).
//! - `system` (since M3): [`FontLibrary`], installed fonts through fontdb, the bundled fonts and
//!   embedded programs, from directories or bytes the caller gives (so tests never see the
//!   machine's fonts).
//! - `matching` (since M3): step 2's [`find_same_font`] and step 3's [`rank_similar`] with
//!   [`Coverage`] and similarity (ADR 0006).
#![forbid(unsafe_code)]

pub mod cmap;
pub mod encoding;
mod instance;
pub mod matching;
pub mod program;
pub mod shape;
pub mod subset;
pub mod system;
pub mod type1;

pub use cmap::{CMap, with_text};
pub use encoding::{BaseEncoding, SimpleEncoding, glyph_names, glyph_text};
pub use matching::{
    Candidate, Coverage, SameFont, SameFontQuery, SimilarQuery, StyleMetrics, find_same_font,
    rank_similar, strip_subset_tag,
};
pub use program::{FontProgram, GlyphId};
pub use shape::{Direction, FeatureSetting, ShapeRequest, ShapedGlyph, ShapedRun, ShapingFont};
pub use subset::{Descriptor, Embedding, Subset, SubsetGlyph, SubsetProgram, subset, subset_at};
pub use system::{
    FaceId, FaceInfo, FaceInstance, FontLibrary, FontOrigin, ScanLimits, system_font_dirs,
};
pub use type1::{BuiltinEncoding, builtin_encoding};

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
    /// A font program is larger than the limit (docs/ARCHITECTURE.md §9.1).
    #[error("font program of {size} bytes exceeds the limit of {max}")]
    ProgramTooLarge {
        /// The program's size in bytes.
        size: u64,
        /// The limit in bytes.
        max: u64,
    },
    /// A font program's structure is damaged.
    #[error("damaged font program: {context}")]
    Malformed {
        /// The part that is damaged.
        context: &'static str,
    },
    /// A run of text is longer than the shaping limit.
    #[error("text run of {size} bytes exceeds the shaping limit of {max}")]
    RunTooLong {
        /// The run's length in bytes.
        size: usize,
        /// The limit in bytes.
        max: usize,
    },
    /// The shaper refused a run.
    #[error("the shaper refused the run")]
    Shaping,
    /// The font's embedding permission (`OS/2.fsType`) does not allow a subset.
    #[error("the font's embedding permission ({embedding:?}) does not allow a subset")]
    EmbeddingNotAllowed {
        /// The permission.
        embedding: Embedding,
    },
    /// subsetter could not subset the font (a `CFF2` font, damaged tables).
    #[error("the font could not be subset")]
    Subsetting,
}

/// Fonts for the tests: the bundled IBM Plex files and the corpus fonts.
#[cfg(test)]
#[allow(
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects,
    clippy::panic
)]
pub(crate) mod test_fonts {
    use std::path::PathBuf;

    fn root() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
    }

    /// The bundled fonts, `app/assets/fonts`.
    pub(crate) fn plex_dir() -> PathBuf {
        root().join("app/assets/fonts")
    }

    /// A bundled font file, such as `ibm-plex-sans/IBMPlexSans-Regular.ttf`.
    pub(crate) fn plex(path: &str) -> Vec<u8> {
        std::fs::read(plex_dir().join(path)).unwrap()
    }

    /// A font of `tools/corpus/fonts.lock` from `build/corpus-fonts`, or `None` (with a note)
    /// before `tools/corpus/fetch-fonts.sh` has fetched it.
    pub(crate) fn corpus_font(name: &str) -> Option<Vec<u8>> {
        let path = root().join("build/corpus-fonts").join(name);
        match std::fs::read(&path) {
            Ok(data) => Some(data),
            Err(_) => {
                use std::io::Write as _;
                let _ = writeln!(
                    std::io::stderr(),
                    "skipped: {name} is not in build/corpus-fonts (run tools/corpus/fetch-fonts.sh)"
                );
                None
            }
        }
    }

    /// The embedded program of `tests/corpus/generated/edit-e05-fstype.pdf` (object 5, Flate)
    /// and its font's `/Widths` as characters (WinAnsi, which is Latin-1 outside 128 to 159).
    pub(crate) fn e05_font() -> (Vec<u8>, Vec<(char, f32)>) {
        let pdf = std::fs::read(root().join("tests/corpus/generated/edit-e05-fstype.pdf")).unwrap();
        let find = |needle: &[u8], from: usize| {
            from + pdf[from..]
                .windows(needle.len())
                .position(|w| w == needle)
                .unwrap()
        };
        let object = find(b"5 0 obj", 0);
        let length_at = find(b"/Length ", object) + 8;
        let length: usize = std::str::from_utf8(&pdf[length_at..length_at + 8])
            .unwrap()
            .split(|c: char| !c.is_ascii_digit())
            .next()
            .unwrap()
            .parse()
            .unwrap();
        let start = find(b"stream\n", object) + 7;
        let mut program = Vec::new();
        std::io::Read::read_to_end(
            &mut flate2::read::ZlibDecoder::new(&pdf[start..start + length]),
            &mut program,
        )
        .unwrap();
        let font = find(b"2 0 obj", 0);
        let widths_at = find(b"/Widths[", font) + 8;
        let end = find(b"]", widths_at);
        let widths = std::str::from_utf8(&pdf[widths_at..end])
            .unwrap()
            .split_whitespace()
            .zip(32u8..)
            .filter(|(width, code)| *width != "0" && !(128..160).contains(code))
            .map(|(width, code)| (char::from(code), width.parse().unwrap()))
            .collect();
        (program, widths)
    }
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
