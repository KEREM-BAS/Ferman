//! The Ferman document model.
//!
//! ferman-core loads PDF bytes and owns the document: the lopdf object model (lopdf is the source of
//! truth, ADR 0004), cross-reference repair, decryption and re-encryption on write, the structure
//! scan, the content-stream lexer and interpreter, the revision store, the incremental writer, the
//! full rewrite, safe writing and the recovery journal. It depends on no other Ferman crate, and it
//! holds no font code: the interpreter asks for glyph advances through a trait that ferman-text
//! implements (docs/ARCHITECTURE.md §2.3).
//!
//! Every PDF is untrusted input. Parsing is bounded by explicit resource limits, and failures are
//! errors, never panics (ADR 0010).
//!
//! # Modules
//!
//! - [`limits`]: the [`Limits`](limits::Limits) struct (nesting, recursion, decoded sizes, operator
//!   count, time), §9.1.
//! - [`filters`]: the stream filters ferman-core decodes itself (ASCIIHex, ASCII85, LZW, Flate and
//!   RunLength, with the PNG and TIFF predictors), bounded by the limits.
//!
//! # Planned modules
//!
//! The layout below follows docs/ARCHITECTURE.md §2.3; each module arrives with the milestone that
//! needs it.
//!
//! - `document`: `Document`, `Snapshot`, `ObjectStore`; reading bytes into an owned buffer with a
//!   SHA-256 fingerprint, the lopdf model, password unlock, repair by object scan. M2.
//! - `structure`: page tree and inheritance, page labels, outlines, attachments, optional content,
//!   AcroForm and XFA detection, signatures and DocMDP permissions. M2.
//! - `content`: the content-stream lexer and the `Interpreter` with `InterpreterSink`, the
//!   `TextAdvance` trait and `Operator { name, operands, span }`, §6.1. Lexer in M2, full graphics
//!   and text state in M3.
//! - `revision`: the revision store, `RevisionId` and `ChangeSet`, §4.3. M3.
//! - `save`: `SaveMode`, the incremental writer, the full rewrite and `safe_write` (temp file,
//!   flush, verify, atomic rename), §7 and ADR 0008. M3.
//! - `recovery`: the autosave `RecoveryJournal`, §7.6. M3.
#![forbid(unsafe_code)]

pub mod filters;
pub mod limits;

use filters::Filter;
use limits::LimitKind;

/// The version of this crate, reported by `engine_info()` in ferman-api.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Errors from ferman-core.
///
/// Variants carry structural context (object ids, offsets, limits), never document text, typed
/// characters or passwords (ADR 0010).
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum CoreError {
    /// An internal invariant did not hold. This is a bug in Ferman, reported as an error instead of
    /// a panic (ADR 0010).
    #[error("internal error in ferman-core: {context}")]
    Internal {
        /// What ferman-core was doing when the invariant failed.
        context: &'static str,
    },
    /// A resource limit stopped the work (docs/ARCHITECTURE.md §9.1).
    #[error("resource limit reached: {limit} (at most {max})")]
    ResourceLimit {
        /// The limit that was reached.
        limit: LimitKind,
        /// Its value.
        max: u64,
    },
    /// Memory for the work could not be reserved. Checked with `try_reserve` before large
    /// buffers, so one document's request fails instead of the app (ADR 0010).
    #[error("out of memory in ferman-core: {context}")]
    OutOfMemory {
        /// What ferman-core was reserving memory for.
        context: &'static str,
    },
    /// A stream's data cannot be decoded with its filter.
    #[error("damaged {filter} data at offset {offset}: {problem}")]
    DamagedStream {
        /// The filter that failed.
        filter: Filter,
        /// Where the problem was found: in the encoded data, or for a predictor in the data the
        /// filter decompressed.
        offset: usize,
        /// What is wrong.
        problem: &'static str,
    },
    /// A filter's `/DecodeParms` cannot be applied.
    #[error("invalid {filter} parameters: {problem}")]
    InvalidDecodeParams {
        /// The filter whose parameters are invalid.
        filter: Filter,
        /// What is wrong.
        problem: &'static str,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal_error_names_the_crate_and_context() {
        let err = CoreError::Internal {
            context: "revision lookup",
        };
        assert_eq!(
            err.to_string(),
            "internal error in ferman-core: revision lookup"
        );
    }

    #[test]
    fn error_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<CoreError>();
    }
}
