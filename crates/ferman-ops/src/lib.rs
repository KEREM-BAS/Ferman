//! Ferman document operations.
//!
//! ferman-ops plans the operations beyond text editing and generates their appearances: organize
//! pages (insert, delete, rotate, move, extract, replace), combine and split, annotations, form
//! filling with appearance streams, simple (non-cryptographic) signatures, compress, flatten and
//! version-history snapshots, then in phase 2 watermark, header and footer, Bates numbering,
//! redaction with verification and removal of hidden information (docs/ARCHITECTURE.md §2.3).
//!
//! Each operation sits above ferman-core's primitives, which alone name lopdf and build a
//! `ChangeSet` (ADR 0003, question 11 of the M4 plan); the document actor in ferman-api commits
//! it. Long operations run as cancellable jobs. Operations that need pixels get them from
//! ferman-api, never from PDFium directly. As the brief says, the crate splits into more crates
//! as it grows (signing, OCR, conversion, PDF/A, ADR 0003).
//!
//! # Planned modules
//!
//! Operations start in M4, one module per family; [`pages`] holds the page operations,
//! [`combine`] and [`split`] what writes files from pages, and [`images`] what several of them
//! need from an image file:
//!
//! - `pages`: rotate, delete, move, duplicate, insert blank, page size, crop and page labels.
//! - `combine`: combine, extract, insert from a file and replace.
//! - `split`: split planning.
//! - [`annotations`]: annotation types with appearance streams, replies and flattening.
//! - [`links`]: link annotations, and which targets may be offered.
//! - [`summary`]: the comment summary as PDF and CSV.
//! - [`forms`]: AcroForm filling, appearance generation and validation without running scripts.
//! - [`fill`]: Fill anything's lines, boxes and combs on a page without fields.
//! - [`signatures`]: simple typed, drawn and image signatures.
//! - [`compress`]: presets, the estimate, image recompression and unused-object removal; the job
//!   is ferman-api's.
//! - [`document`]: the outline, the document information and attached files.
//!
//! Version history needs no operation here: ferman-core's `versions` keeps the saved bytes, and
//! ferman-api's actor calls it from its saves (ADR 0022).
#![forbid(unsafe_code)]

pub mod annotations;
pub mod combine;
pub mod compress;
pub mod document;
pub mod fill;
pub mod forms;
pub mod images;
pub mod links;
pub mod pages;
pub mod signatures;
pub mod split;
pub mod summary;

/// The version of this crate, reported by `engine_info()` in ferman-api.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Errors from ferman-ops.
///
/// Variants carry structural context (page indices, object ids), never document text (ADR 0010).
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum OpsError {
    /// A ferman-core operation failed.
    #[error(transparent)]
    Core(#[from] ferman_core::CoreError),
    /// A ferman-text operation failed.
    #[error(transparent)]
    Text(#[from] ferman_text::TextError),
    /// A ferman-fonts operation failed.
    #[error(transparent)]
    Font(#[from] ferman_fonts::FontError),
    /// Image bytes that no decoder Ferman has can read, or a JPEG a PDF cannot carry as it is.
    #[error("the image cannot be read")]
    UnreadableImage,
    /// Text that no font Ferman can embed here has; the annotation is not written, so nothing
    /// is substituted silently (ADR 0006).
    #[error("no font has the text")]
    NoFontForText,
    /// A field's value has characters its font cannot draw, and the settings say to ask first
    /// (decision 18). Nothing is written.
    #[error("a font must be chosen for the field")]
    FontChoiceNeeded,
    /// An internal invariant did not hold. This is a bug in Ferman, reported as an error instead of
    /// a panic (ADR 0010).
    #[error("internal error in ferman-ops: {context}")]
    Internal {
        /// What ferman-ops was doing when the invariant failed.
        context: &'static str,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal_error_names_the_crate_and_context() {
        let err = OpsError::Internal {
            context: "page move",
        };
        assert_eq!(err.to_string(), "internal error in ferman-ops: page move");
    }

    #[test]
    fn lower_errors_pass_through_unchanged() {
        let err = OpsError::from(ferman_text::TextError::Internal { context: "reflow" });
        assert_eq!(err.to_string(), "internal error in ferman-text: reflow");
    }

    #[test]
    fn error_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<OpsError>();
    }
}
