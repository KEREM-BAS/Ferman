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
//! - [`source`]: a document's bytes, read into an owned buffer with their SHA-256 (§5.1).
//! - [`sniff`]: the `%PDF-` header, and what a file that is not a PDF looks like (a1-9c).
//! - [`document`]: [`open`] and the [`Document`]: ferman-core's own cross-reference reader, repair
//!   ([`repair`]) and security handler ([`security`]) around the lopdf model, §5.1 and §5.2.
//! - [`structure`]: pages and labels, outline, attachments, layers, forms and XFA, signatures,
//!   scripts, fonts and document information, and the two-parser check of G102.
//! - `content` (private): the content-stream lexer, operators with their operands and byte spans,
//!   read leniently, with inline images (§6.1).
//! - `appendix` (private): render-only appendices, the bytes after a document's that PDFium
//!   renders and nobody saves: [`Document::layer_appendix`] shows and hides layers (ADR 0009).
//!
//! # Planned modules
//!
//! The layout below follows docs/ARCHITECTURE.md §2.3; each module arrives with the milestone that
//! needs it.
//!
//! - The `Interpreter` with `InterpreterSink` and the `TextAdvance` trait over `content`, §6.1:
//!   text state in M2, full graphics state in M3.
//! - `revision`: the revision store, `RevisionId` and `ChangeSet`, §4.3. M3.
//! - `save`: `SaveMode`, the incremental writer, the full rewrite and `safe_write` (temp file,
//!   flush, verify, atomic rename), §7 and ADR 0008. M3.
//! - `recovery`: the autosave `RecoveryJournal`, §7.6. M3.
#![forbid(unsafe_code)]

mod appendix;
// shortcut: only the fuzz target and the tests read it until the interpreter (commit 11d).
#[cfg_attr(not(feature = "fuzzing"), allow(dead_code))]
mod content;
pub mod document;
pub mod filters;
#[cfg(feature = "fuzzing")]
#[doc(hidden)]
pub mod fuzzing;
pub mod limits;
pub mod repair;
pub mod security;
pub mod sniff;
pub mod source;
pub mod structure;
mod syntax;
mod text_string;
mod xref;

pub use document::{Document, OpenOptions, open};
pub use repair::{Diagnosis, LikelyCause, Repair, RepairReport, XrefProblem};
pub use security::{Access, EncryptionInfo, Method, Password, Permissions};
pub use sniff::FileKind;
pub use source::Source;

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
    /// The file could not be opened or read.
    #[error("the file could not be read: {kind}")]
    Io {
        /// What the system reported.
        kind: std::io::ErrorKind,
    },
    /// The file is not a PDF: it has no `%PDF-` header in its first kilobyte (a1-9c).
    #[error("not a PDF ({kind:?})")]
    NotPdf {
        /// What the file looks like instead.
        kind: FileKind,
    },
    /// PDF syntax that cannot be read, at an offset into the file.
    #[error("malformed PDF syntax at offset {offset}: {problem}")]
    Syntax {
        /// Where the problem is, from the `%PDF-` header.
        offset: u64,
        /// What is wrong.
        problem: &'static str,
    },
    /// The file is damaged beyond repair (a1-9b).
    #[error("the file cannot be opened ({:?})", .0.likely_cause)]
    Damaged(Box<Diagnosis>),
    /// The document is encrypted and its user password is needed (a1-8).
    #[error("a password is needed")]
    PasswordRequired,
    /// The password given opens neither as the user nor as the owner password (a1-8b).
    #[error("the password is wrong")]
    WrongPassword,
    /// Something in the file that Ferman does not support yet.
    #[error("not supported: {0}")]
    Unsupported(Unsupported),
}

/// What [`CoreError::Unsupported`] is about.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum Unsupported {
    /// Encryption for certificates (`/Adobe.PubSec`) instead of passwords, until P3.
    CertificateSecurity,
    /// A security handler other than the standard one.
    SecurityHandler,
    /// A standard security handler revision other than 2 to 6, or an unknown `/V`.
    EncryptionRevision,
    /// A crypt filter method other than `V2`, `AESV2`, `AESV3` and `Identity`.
    CryptFilter,
    /// A stream filter that ferman-core needs to decode itself but does not.
    Filter,
    /// A file of 4 GiB or more, which lopdf 0.45 cannot address.
    FileSize,
}

impl std::fmt::Display for Unsupported {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::CertificateSecurity => "certificate security",
            Self::SecurityHandler => "a security handler other than the standard one",
            Self::EncryptionRevision => "this encryption revision",
            Self::CryptFilter => "this crypt filter",
            Self::Filter => "this stream filter",
            Self::FileSize => "files of 4 GiB or more",
        })
    }
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
