//! Ferman document operations.
//!
//! ferman-ops holds the operations beyond text editing: organize pages (insert, delete, rotate,
//! move, extract, replace), combine and split, annotations, form filling with appearance streams,
//! simple (non-cryptographic) signatures, compress, flatten and version-history snapshots, then in
//! phase 2 watermark, header and footer, Bates numbering, redaction with verification and removal
//! of hidden information (docs/ARCHITECTURE.md §2.3).
//!
//! Each operation is a function from a snapshot and its parameters to a `ChangeSet` that the
//! document actor in ferman-api commits. Long operations run as cancellable jobs. Operations that
//! need pixels get them from ferman-api, never from PDFium directly. As the brief says, the crate
//! splits into more crates as it grows (signing, OCR, conversion, PDF/A, ADR 0003).
//!
//! # Planned modules
//!
//! The crate is a skeleton in M1. Operations start in M4, one module per family:
//!
//! - `pages`: insert, delete, rotate, move, duplicate, extract, replace, crop and page labels.
//! - `combine`: combine and split.
//! - `annotations`: annotation types with appearance streams, replies and flattening.
//! - `forms`: AcroForm filling, appearance generation and validation without running scripts.
//! - `signatures`: simple typed, drawn and image signatures.
//! - `compress`: presets, image recompression and unused-object removal, as a job.
//! - `history`: version-history snapshots.
#![forbid(unsafe_code)]

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
