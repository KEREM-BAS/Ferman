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
//! - [`interpret`]: the content interpreter for text: [`Document::page_text`] hands each show
//!   operator and the fonts it uses, as plain [`FontResource`](interpret::FontResource) data, to a
//!   [`TextSink`](interpret::TextSink), which returns the displacement (§6.1).
//! - [`revision`]: the [`RevisionStore`](revision::RevisionStore), an overlay of changed objects
//!   over the opened document, one [`ChangeSet`](revision::ChangeSet) per commit, with undo and
//!   redo (§3.6); the splicer, which replaces byte ranges of content streams
//!   ([`Splice`](revision::Splice)), with copy-on-write for shared streams and forms (§6.6); and
//!   the incremental writer, which appends the changes to the original bytes in the file's own
//!   cross-reference form, encrypted with the document's key (§7.3).
//! - [`save`]: the atomic save sequence of ADR 0008 and docs/ARCHITECTURE.md §7.2:
//!   [`save_pdf`](save::save_pdf) writes a document through a temp file beside it, flushed,
//!   verified, given the original's metadata and swapped in, with every failure of §7.8 a
//!   [`SaveError`] and the external-change check of §7.5 ([`FileStamp`](save::FileStamp));
//!   [`safe_write`](save::safe_write) is the same sequence for other files ("Save attachment
//!   as…", [`Document::attachment_data`]).
//! - `rewrite` (private): the full rewrite, [`RevisionStore::full_rewrite`](revision::RevisionStore::full_rewrite),
//!   for Optimize and clean and a repaired document's copy (§7.3).
//! - `platform` (private): the few file-system calls the standard library lacks
//!   (`ReplaceFileW`, `fcopyfile`, free space, link counts), the crate's only unsafe code
//!   (ADR 0010).
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
//! - The rest of the interpreter (§6.1): clipping, colour, marked content and Type3 glyph
//!   procedures, M3.
//! - `recovery`: the autosave `RecoveryJournal`, §7.6. M3.
// Unsafe code is denied, and allowed only in `platform` (ADR 0010, M3 plan question 1).
#![deny(unsafe_code)]

mod appendix;
mod content;
pub mod document;
pub mod filters;
#[cfg(feature = "fuzzing")]
#[doc(hidden)]
pub mod fuzzing;
mod incremental;
pub mod interpret;
pub mod limits;
#[allow(unsafe_code)]
mod platform;
pub mod repair;
pub mod revision;
mod rewrite;
pub mod save;
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
    /// A change or a write that cannot be made.
    #[error("cannot write: {0}")]
    Write(WriteError),
    /// A save failed (docs/ARCHITECTURE.md §7.8). The target is as it was and no temp file is
    /// left.
    #[error("cannot save: {0}")]
    Save(SaveError),
}

/// What [`CoreError::Save`] is about: why a file could not be saved (docs/ARCHITECTURE.md §7.8).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum SaveError {
    /// Not enough free space, found before writing or while writing (`ENOSPC`,
    /// `ERROR_DISK_FULL`).
    DiskFull,
    /// The file or its folder is read-only, or the system does not let Ferman write there
    /// (`EACCES`, `EPERM`, `EROFS`, `ERROR_ACCESS_DENIED`).
    PermissionDenied,
    /// Another app holds the file, still after the retries (a Windows sharing violation,
    /// `EBUSY`, `ETXTBSY`).
    FileLocked,
    /// The temp file was written but could not replace the target.
    RenameFailed,
    /// The disk or the network drive went away (`EIO`, `ENODEV`, `ENXIO`,
    /// `ERROR_DEV_NOT_EXIST`, a lost network name).
    VolumeGone,
    /// The target has more than one hard link, which replacing it would break.
    HardLinked,
    /// The target belongs to someone else, and the new file could not be given its owner.
    NotOwner,
    /// The file changed on disk since it was opened or last saved (docs/ARCHITECTURE.md §7.5).
    ChangedOnDisk,
    /// What was read back is not what was written, or does not parse.
    Verify,
}

impl SaveError {
    /// Whether the way out is Save as: every failure but a file changed on disk, which a11-7b
    /// resolves instead.
    #[must_use]
    pub const fn offers_save_as(self) -> bool {
        !matches!(self, Self::ChangedOnDisk)
    }
}

impl std::fmt::Display for SaveError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::DiskFull => "the disk is full",
            Self::PermissionDenied => "permission denied",
            Self::FileLocked => "the file is locked by another app",
            Self::RenameFailed => "the original could not be replaced",
            Self::VolumeGone => "the drive is gone",
            Self::HardLinked => "the file has other hard links",
            Self::NotOwner => "the file's owner cannot be kept",
            Self::ChangedOnDisk => "the file changed on disk",
            Self::Verify => "the written file does not read back",
        })
    }
}

/// What [`CoreError::Write`] is about: misuse of the [`RevisionStore`](revision::RevisionStore)
/// or a change it cannot make.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum WriteError {
    /// A transaction is open: a second one cannot begin, and a document cannot be written.
    TransactionOpen,
    /// A change or a commit without a transaction.
    NoTransaction,
    /// Undo at the first revision.
    NothingToUndo,
    /// Redo at the newest revision.
    NothingToRedo,
    /// A page index past the document's pages.
    NoSuchPage,
    /// Two splices of one stream overlap.
    OverlappingSplices,
    /// A splice's range is not inside its stream's decoded data.
    SpliceOutsideStream,
    /// A splice's source is not a stream.
    NotAStream {
        /// Its object number.
        object: u32,
    },
    /// A form spliced without its placement, or with one that is not a single `Do` of that form
    /// in one of the page's content streams.
    Placement,
    /// A page stream spliced, or a placement drawn, in a stream that is not in the page's
    /// `/Contents`.
    NotOnPage,
    /// No object number is left for a new object.
    ObjectNumbers,
    /// A font copy of a name that is not a composite font of the page, or under a name the
    /// page uses already.
    Font,
    /// A repaired document: its rebuilt cross-reference data cannot be extended, so it is saved
    /// as a repaired copy (a full rewrite) instead.
    Repaired,
    /// The system's random number generator failed.
    Random,
}

impl std::fmt::Display for WriteError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::TransactionOpen => f.write_str("a transaction is open"),
            Self::NoTransaction => f.write_str("no transaction is open"),
            Self::NothingToUndo => f.write_str("nothing to undo"),
            Self::NothingToRedo => f.write_str("nothing to redo"),
            Self::NoSuchPage => f.write_str("no such page"),
            Self::OverlappingSplices => f.write_str("splices overlap"),
            Self::SpliceOutsideStream => f.write_str("a splice outside its stream"),
            Self::NotAStream { object } => write!(f, "object {object} is not a stream"),
            Self::Placement => f.write_str("a form without its placement"),
            Self::NotOnPage => f.write_str("a stream that is not on the page"),
            Self::ObjectNumbers => f.write_str("no object number left"),
            Self::Font => f.write_str("a font copy that does not fit the page"),
            Self::Repaired => f.write_str("a repaired document cannot be updated"),
            Self::Random => f.write_str("no random numbers"),
        }
    }
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
