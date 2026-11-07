//! The one error type the UI sees.

use std::fmt;

/// What kind of failure an [`ApiError`] reports.
///
/// The UI maps each kind to a design state (docs/ARCHITECTURE.md §8.2). The kinds that only the
/// later features produce (for example `Restricted`) arrive with those features.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum ErrorKind {
    /// The caller passed a value the engine cannot accept.
    InvalidInput,
    /// A file or handle does not exist (any more).
    NotFound,
    /// The system does not let Ferman read the file (a1-9d).
    PermissionDenied,
    /// The document is encrypted and its password is needed (a1-8).
    PasswordRequired,
    /// The password does not open the document (a1-8b).
    WrongPassword,
    /// The file is damaged beyond repair (a1-9b).
    Damaged,
    /// The input is not a PDF, or uses something Ferman does not support yet (a1-9c, a1-9b).
    Unsupported,
    /// A resource limit stopped the work, or memory a check before allocating found short (a1-9f).
    ResourceLimit,
    /// Reading or writing failed for a reason without its own kind.
    Io,
    /// The text, or the whole document, cannot be edited; the message key names the reason
    /// (docs/ARCHITECTURE.md §6.5).
    NotEditable,
    /// A save found too little free space, before or while writing (a11-7).
    DiskFull,
    /// Another app holds the file, still after the retries (a11-7d, G40).
    FileLocked,
    /// The new file was written but could not replace the original (a11-7d, G40).
    RenameFailed,
    /// The disk or network drive went away during a save (a11-7d, G40).
    VolumeGone,
    /// The file has other hard links, which replacing it would break; Save as instead (G40).
    HardLinked,
    /// The file belongs to someone else and its owner cannot be kept; Save as instead (G40).
    NotOwner,
    /// The file changed on disk since it was opened or saved (a11-7b): "Keep mine" saves
    /// anyway, "Reload" opens it again.
    FileChangedOnDisk,
    /// A change to a signed document waits for [`Engine::confirm_edit_signed`]
    /// (docs/ARCHITECTURE.md §6.9, a3-16a).
    ///
    /// [`Engine::confirm_edit_signed`]: super::Engine::confirm_edit_signed
    ConfirmationRequired,
    /// A bug in Ferman, including a caught panic. The UI shows a generic message and offers
    /// "Copy technical details".
    Internal,
}

impl ErrorKind {
    /// A short, stable, lowercase name for logs and the CLI, such as `"not_found"`.
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::InvalidInput => "invalid_input",
            Self::NotFound => "not_found",
            Self::PermissionDenied => "permission_denied",
            Self::PasswordRequired => "password_required",
            Self::WrongPassword => "wrong_password",
            Self::Damaged => "damaged",
            Self::Unsupported => "unsupported",
            Self::ResourceLimit => "resource_limit",
            Self::Io => "io",
            Self::NotEditable => "not_editable",
            Self::DiskFull => "disk_full",
            Self::FileLocked => "file_locked",
            Self::RenameFailed => "rename_failed",
            Self::VolumeGone => "volume_gone",
            Self::HardLinked => "hard_linked",
            Self::NotOwner => "not_owner",
            Self::FileChangedOnDisk => "file_changed_on_disk",
            Self::ConfirmationRequired => "confirmation_required",
            Self::Internal => "internal",
        }
    }
}

impl fmt::Display for ErrorKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// The key of the message the UI shows for an error.
///
/// Each key is an ARB key in `app/lib/l10n/app_en.arb` (lowerCamelCase, as gen-l10n requires), so
/// the sentence is formatted in Dart in the user's language and no localized text leaves the
/// engine (ADR 0010, ADR 0014). The set is closed: keys are defined here and listed in
/// [`MessageKey::ALL`]. A CI check that every key exists in `app_en.arb` and `app_tr.arb` arrives
/// with the error strings in the ARB files, in the commit whose screens show them (M2).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct MessageKey(&'static str);

impl MessageKey {
    /// Something went wrong inside Ferman; the message offers "Copy technical details".
    pub const INTERNAL: Self = Self("errorInternal");
    /// The file is not there (any more).
    pub const FILE_NOT_FOUND: Self = Self("errorFileNotFound");
    /// The system does not let Ferman read the file.
    pub const FILE_PERMISSION_DENIED: Self = Self("errorFilePermissionDenied");
    /// Reading the file failed.
    pub const FILE_READ: Self = Self("errorFileRead");
    /// The file is not a PDF (a1-9c).
    pub const NOT_PDF: Self = Self("errorNotPdf");
    /// The document needs its password (a1-8).
    pub const PASSWORD_REQUIRED: Self = Self("errorPasswordRequired");
    /// The password is wrong (a1-8b).
    pub const WRONG_PASSWORD: Self = Self("errorWrongPassword");
    /// The file is damaged beyond repair (a1-9b).
    pub const DAMAGED: Self = Self("errorDamaged");
    /// The file stops before its end, probably cut off while downloading or copying (a1-9b).
    pub const DAMAGED_TRUNCATED: Self = Self("errorDamagedTruncated");
    /// The file holds no PDF objects at all (a1-9b).
    pub const DAMAGED_EMPTY: Self = Self("errorDamagedEmpty");
    /// The file uses something Ferman does not support yet.
    pub const UNSUPPORTED: Self = Self("errorUnsupported");
    /// The file is too complex for the resource limits.
    pub const TOO_COMPLEX: Self = Self("errorTooComplex");
    /// There was not enough memory for this document (a1-9f).
    pub const OUT_OF_MEMORY: Self = Self("errorOutOfMemory");

    /// The page is an image, such as a scan (a3-11).
    pub const EDIT_IMAGE_ONLY: Self = Self("editBodyImageOnly");
    /// The text is drawn as vector shapes (a3-19).
    pub const EDIT_OUTLINED_TEXT: Self = Self("editBodyOutlinedText");
    /// The font does not say which letters its glyphs stand for (G39).
    pub const EDIT_UNKNOWN_TEXT: Self = Self("editBodyUnknownText");
    /// The text is invisible, such as recognised text over a scan (G39).
    pub const EDIT_INVISIBLE_TEXT: Self = Self("editBodyInvisibleText");
    /// The author's permissions forbid changes until the owner password (G27).
    pub const EDIT_RESTRICTED: Self = Self("editBodyRestricted");
    /// The document opened read-only, such as an XFA form (G39).
    pub const EDIT_READ_ONLY: Self = Self("editBodyReadOnly");
    /// The document was repaired, or its readers disagree (a1-9).
    pub const EDIT_DAMAGED: Self = Self("editBodyDamaged");
    /// The text is part of a signature (G35).
    pub const EDIT_SIGNATURE: Self = Self("editBodySignature");
    /// The text belongs to an annotation or a form field.
    pub const EDIT_ANNOTATION: Self = Self("editBodyAnnotation");
    /// The page hit a resource limit.
    pub const EDIT_LIMITS: Self = Self("editBodyLimits");
    /// A job's place: page `page` of `pages`.
    pub const JOB_PAGE_OF: Self = Self("jobPageOf");
    /// An operator is split across two content streams.
    pub const EDIT_SPLIT: Self = Self("editBodySplit");
    /// The text is sheared.
    pub const EDIT_SKEWED: Self = Self("editBodySkewed");

    /// The message for text that cannot be edited for `reason`, the panel callout's (a3-19).
    #[must_use]
    pub fn not_editable(reason: ferman_text::NotEditableReason) -> Self {
        use ferman_text::{Complexity, NotEditableReason as Reason};
        match reason {
            Reason::ImageOnly => Self::EDIT_IMAGE_ONLY,
            Reason::UnknownText => Self::EDIT_UNKNOWN_TEXT,
            Reason::OutlinedText => Self::EDIT_OUTLINED_TEXT,
            Reason::InvisibleText => Self::EDIT_INVISIBLE_TEXT,
            Reason::Restricted => Self::EDIT_RESTRICTED,
            Reason::ReadOnly => Self::EDIT_READ_ONLY,
            Reason::Damaged => Self::EDIT_DAMAGED,
            Reason::SignatureAppearance => Self::EDIT_SIGNATURE,
            Reason::AnnotationOrField => Self::EDIT_ANNOTATION,
            Reason::TooComplex(Complexity::SplitOperator) => Self::EDIT_SPLIT,
            Reason::TooComplex(Complexity::Skewed) => Self::EDIT_SKEWED,
            // A reason added later reads as too complex until it gets its message.
            _ => Self::EDIT_LIMITS,
        }
    }

    /// Every key the engine can return.
    pub const ALL: &'static [Self] = &[
        Self::INTERNAL,
        Self::FILE_NOT_FOUND,
        Self::FILE_PERMISSION_DENIED,
        Self::FILE_READ,
        Self::NOT_PDF,
        Self::PASSWORD_REQUIRED,
        Self::WRONG_PASSWORD,
        Self::DAMAGED,
        Self::DAMAGED_TRUNCATED,
        Self::DAMAGED_EMPTY,
        Self::UNSUPPORTED,
        Self::TOO_COMPLEX,
        Self::OUT_OF_MEMORY,
        Self::EDIT_IMAGE_ONLY,
        Self::EDIT_OUTLINED_TEXT,
        Self::EDIT_UNKNOWN_TEXT,
        Self::EDIT_INVISIBLE_TEXT,
        Self::EDIT_RESTRICTED,
        Self::EDIT_READ_ONLY,
        Self::EDIT_DAMAGED,
        Self::EDIT_SIGNATURE,
        Self::EDIT_ANNOTATION,
        Self::JOB_PAGE_OF,
        Self::EDIT_LIMITS,
        Self::EDIT_SPLIT,
        Self::EDIT_SKEWED,
    ];

    /// The ARB key, for example `"errorInternal"`.
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        self.0
    }
}

impl fmt::Display for MessageKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.0)
    }
}

/// The error every fallible API call returns.
///
/// `message_key` names the sentence the UI shows. `details` is the technical text behind
/// "Copy technical details" (a1-9b): structural facts only, never document text, typed characters
/// or passwords. `offer_save_as` says that a failed save's way out is Save as (docs/ARCHITECTURE.md
/// §7.8). Message parameters join it when the first call needs them (docs/ARCHITECTURE.md §3.8).
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("{kind} [{message_key}]{}", details_suffix(.details))]
pub struct ApiError {
    /// What kind of failure this is.
    pub kind: ErrorKind,
    /// The ARB key of the message the UI shows.
    pub message_key: MessageKey,
    /// Technical details for "Copy technical details", if any.
    pub details: Option<String>,
    /// Whether the UI offers Save as: a save that failed for a reason another file avoids.
    pub offer_save_as: bool,
    /// On a failed save: the last recovery write failed too, so no recovery copy of the unsaved
    /// edits exists (docs/ARCHITECTURE.md §7.8).
    pub no_recovery_copy: bool,
}

impl ApiError {
    /// An error of `kind` with the message `message_key` and no details.
    #[must_use]
    pub const fn new(kind: ErrorKind, message_key: MessageKey) -> Self {
        Self {
            kind,
            message_key,
            details: None,
            offer_save_as: false,
            no_recovery_copy: false,
        }
    }

    /// An [`ErrorKind::Internal`] error with the generic message and technical `details`.
    #[must_use]
    pub fn internal(details: impl Into<String>) -> Self {
        Self::new(ErrorKind::Internal, MessageKey::INTERNAL).with_details(details)
    }

    /// A [`ErrorKind::NotEditable`] error with the message for `reason`.
    #[must_use]
    pub fn not_editable(reason: ferman_text::NotEditableReason) -> Self {
        Self::new(ErrorKind::NotEditable, MessageKey::not_editable(reason))
            .with_details(format!("{reason:?}"))
    }

    /// The same error of a save: a file error offers Save as, as every [`SaveError`]
    /// does but a file changed on disk.
    ///
    /// [`SaveError`]: ferman_core::SaveError
    #[must_use]
    pub fn of_save(mut self) -> Self {
        self.offer_save_as = matches!(
            self.kind,
            ErrorKind::NotFound
                | ErrorKind::PermissionDenied
                | ErrorKind::Io
                | ErrorKind::DiskFull
                | ErrorKind::FileLocked
                | ErrorKind::RenameFailed
                | ErrorKind::VolumeGone
                | ErrorKind::HardLinked
                | ErrorKind::NotOwner
        );
        self
    }

    /// The same error with technical `details`.
    #[must_use]
    pub fn with_details(mut self, details: impl Into<String>) -> Self {
        self.details = Some(details.into());
        self
    }
}

/// a1-9b's technical details: "expected 2457600 bytes, found 18432 bytes · last complete object
/// 12 0 obj · no trailer". Structural facts only.
fn diagnosis_details(diagnosis: &ferman_core::Diagnosis) -> String {
    let mut parts = vec![match diagnosis.expected_size {
        Some(expected) => format!(
            "expected {expected} bytes, found {} bytes",
            diagnosis.file_size
        ),
        None => format!("{} bytes", diagnosis.file_size),
    }];
    if let Some((number, generation)) = diagnosis.last_complete_object {
        parts.push(format!("last complete object {number} {generation} obj"));
    }
    parts.push(format!("{} objects", diagnosis.objects_found));
    if !diagnosis.has_trailer {
        parts.push("no trailer".to_owned());
    }
    parts.join(" · ")
}

fn details_suffix(details: &Option<String>) -> String {
    details
        .as_deref()
        .map(|details| format!(": {details}"))
        .unwrap_or_default()
}

// Engine errors reach the UI as ApiError (docs/ARCHITECTURE.md §8.2). The crate errors carry
// structural context only, so their text can go into `details`.

impl From<ferman_core::CoreError> for ApiError {
    fn from(err: ferman_core::CoreError) -> Self {
        use ferman_core::CoreError;
        let (kind, key) = match &err {
            CoreError::Io { kind } => match kind {
                std::io::ErrorKind::NotFound => (ErrorKind::NotFound, MessageKey::FILE_NOT_FOUND),
                std::io::ErrorKind::PermissionDenied => (
                    ErrorKind::PermissionDenied,
                    MessageKey::FILE_PERMISSION_DENIED,
                ),
                _ => (ErrorKind::Io, MessageKey::FILE_READ),
            },
            CoreError::NotPdf { .. } => (ErrorKind::Unsupported, MessageKey::NOT_PDF),
            CoreError::PasswordRequired => {
                (ErrorKind::PasswordRequired, MessageKey::PASSWORD_REQUIRED)
            }
            CoreError::WrongPassword => (ErrorKind::WrongPassword, MessageKey::WRONG_PASSWORD),
            CoreError::Damaged(diagnosis) => {
                let key = match diagnosis.likely_cause {
                    ferman_core::LikelyCause::Truncated => MessageKey::DAMAGED_TRUNCATED,
                    ferman_core::LikelyCause::NoObjects => MessageKey::DAMAGED_EMPTY,
                    _ => MessageKey::DAMAGED,
                };
                return Self::new(ErrorKind::Damaged, key)
                    .with_details(diagnosis_details(diagnosis));
            }
            CoreError::Syntax { .. }
            | CoreError::DamagedStream { .. }
            | CoreError::InvalidDecodeParams { .. } => (ErrorKind::Damaged, MessageKey::DAMAGED),
            CoreError::Unsupported(_) => (ErrorKind::Unsupported, MessageKey::UNSUPPORTED),
            CoreError::ResourceLimit { .. } => (ErrorKind::ResourceLimit, MessageKey::TOO_COMPLEX),
            CoreError::OutOfMemory { .. } => (ErrorKind::ResourceLimit, MessageKey::OUT_OF_MEMORY),
            // A call out of order: undo with nothing to undo, a second transaction.
            CoreError::Write(
                ferman_core::WriteError::TransactionOpen
                | ferman_core::WriteError::NoTransaction
                | ferman_core::WriteError::NothingToUndo
                | ferman_core::WriteError::NothingToRedo
                | ferman_core::WriteError::NoSuchPage
                | ferman_core::WriteError::PagePlan
                | ferman_core::WriteError::NoSuchAnnotation
                | ferman_core::WriteError::AnnotationPlan,
            ) => (ErrorKind::InvalidInput, MessageKey::INTERNAL),
            // A block inside a form needs its placement, which the rewriter does not give yet;
            // a repaired document is saved as a repaired copy, later.
            CoreError::Write(
                ferman_core::WriteError::Placement
                | ferman_core::WriteError::Repaired
                | ferman_core::WriteError::PageStateLeaks,
            ) => (ErrorKind::Unsupported, MessageKey::UNSUPPORTED),
            // a11-7, a11-7b and a11-7d draw their own sentences for these kinds; the keys are
            // the nearest of the open's until those screens bring theirs.
            CoreError::Save(save) => {
                use ferman_core::SaveError;
                let kind = match save {
                    SaveError::DiskFull => ErrorKind::DiskFull,
                    SaveError::PermissionDenied => ErrorKind::PermissionDenied,
                    SaveError::FileLocked => ErrorKind::FileLocked,
                    SaveError::RenameFailed => ErrorKind::RenameFailed,
                    SaveError::VolumeGone => ErrorKind::VolumeGone,
                    SaveError::HardLinked => ErrorKind::HardLinked,
                    SaveError::NotOwner => ErrorKind::NotOwner,
                    SaveError::ChangedOnDisk => ErrorKind::FileChangedOnDisk,
                    _ => ErrorKind::Io,
                };
                let key = if kind == ErrorKind::PermissionDenied {
                    MessageKey::FILE_PERMISSION_DENIED
                } else {
                    MessageKey::FILE_READ
                };
                let mut api = Self::new(kind, key).with_details(err.to_string());
                api.offer_save_as = save.offers_save_as();
                return api;
            }
            _ => (ErrorKind::Internal, MessageKey::INTERNAL),
        };
        Self::new(kind, key).with_details(err.to_string())
    }
}

impl From<ferman_fonts::FontError> for ApiError {
    fn from(err: ferman_fonts::FontError) -> Self {
        Self::internal(err.to_string())
    }
}

impl From<ferman_text::TextError> for ApiError {
    fn from(err: ferman_text::TextError) -> Self {
        Self::internal(err.to_string())
    }
}

impl From<ferman_render::RenderError> for ApiError {
    fn from(err: ferman_render::RenderError) -> Self {
        use ferman_render::RenderError;
        let (kind, key) = match err {
            RenderError::Core(err) => return err.into(),
            RenderError::NotFound { .. } => (ErrorKind::NotFound, MessageKey::INTERNAL),
            RenderError::PasswordRequired => {
                (ErrorKind::PasswordRequired, MessageKey::PASSWORD_REQUIRED)
            }
            RenderError::WrongPassword => (ErrorKind::WrongPassword, MessageKey::WRONG_PASSWORD),
            RenderError::UnsupportedSecurity => (ErrorKind::Unsupported, MessageKey::UNSUPPORTED),
            RenderError::Damaged { .. } => (ErrorKind::Damaged, MessageKey::DAMAGED),
            RenderError::OutOfMemory { .. } => {
                (ErrorKind::ResourceLimit, MessageKey::OUT_OF_MEMORY)
            }
            _ => (ErrorKind::Internal, MessageKey::INTERNAL),
        };
        Self::new(kind, key).with_details(err.to_string())
    }
}

impl From<ferman_ops::OpsError> for ApiError {
    fn from(err: ferman_ops::OpsError) -> Self {
        match err {
            ferman_ops::OpsError::Core(err) => err.into(),
            ferman_ops::OpsError::NoFontForText => {
                Self::new(ErrorKind::Unsupported, MessageKey::UNSUPPORTED)
                    .with_details("no font has the text")
            }
            err => Self::internal(err.to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn internal_error_uses_the_generic_message() {
        let err = ApiError::internal("no trailer");
        assert_eq!(err.kind, ErrorKind::Internal);
        assert_eq!(err.message_key, MessageKey::INTERNAL);
        assert_eq!(err.details.as_deref(), Some("no trailer"));
    }

    #[test]
    fn damage_names_its_cause_and_facts() {
        let diagnosis = ferman_core::Diagnosis {
            likely_cause: ferman_core::LikelyCause::Truncated,
            file_size: 18_432,
            expected_size: Some(2_457_600),
            last_complete_object: Some((12, 0)),
            objects_found: 12,
            has_trailer: false,
        };
        let err = ApiError::from(ferman_core::CoreError::Damaged(Box::new(diagnosis)));
        assert_eq!(err.message_key, MessageKey::DAMAGED_TRUNCATED);
        assert_eq!(
            err.details.as_deref(),
            Some(
                "expected 2457600 bytes, found 18432 bytes · last complete object 12 0 obj \
                 · 12 objects · no trailer"
            )
        );
    }

    #[test]
    fn display_names_kind_key_and_details() {
        assert_eq!(
            ApiError::internal("no trailer").to_string(),
            "internal [errorInternal]: no trailer"
        );
        assert_eq!(
            ApiError::new(ErrorKind::NotFound, MessageKey::INTERNAL).to_string(),
            "not_found [errorInternal]"
        );
    }

    #[test]
    fn message_keys_are_arb_identifiers() {
        assert!(!MessageKey::ALL.is_empty());
        for key in MessageKey::ALL {
            let mut chars = key.as_str().chars();
            let first = chars.next();
            assert!(
                first.is_some_and(|c| c.is_ascii_lowercase()),
                "{key} must start with a lowercase letter"
            );
            assert!(
                chars.all(|c| c.is_ascii_alphanumeric()),
                "{key} must be lowerCamelCase"
            );
        }
    }

    #[test]
    fn open_errors_get_their_kind_and_message() {
        use ferman_core::CoreError;
        for (err, kind, key) in [
            (
                CoreError::Io {
                    kind: std::io::ErrorKind::NotFound,
                },
                ErrorKind::NotFound,
                MessageKey::FILE_NOT_FOUND,
            ),
            (
                CoreError::Io {
                    kind: std::io::ErrorKind::PermissionDenied,
                },
                ErrorKind::PermissionDenied,
                MessageKey::FILE_PERMISSION_DENIED,
            ),
            (
                CoreError::NotPdf {
                    kind: ferman_core::FileKind::Zip,
                },
                ErrorKind::Unsupported,
                MessageKey::NOT_PDF,
            ),
            (
                CoreError::PasswordRequired,
                ErrorKind::PasswordRequired,
                MessageKey::PASSWORD_REQUIRED,
            ),
            (
                CoreError::WrongPassword,
                ErrorKind::WrongPassword,
                MessageKey::WRONG_PASSWORD,
            ),
            (
                CoreError::OutOfMemory { context: "a page" },
                ErrorKind::ResourceLimit,
                MessageKey::OUT_OF_MEMORY,
            ),
        ] {
            let err = ApiError::from(err);
            assert_eq!((err.kind, err.message_key), (kind, key));
        }
        let err = ApiError::from(ferman_render::RenderError::WrongPassword);
        assert_eq!(err.kind, ErrorKind::WrongPassword);
    }

    #[test]
    fn engine_errors_become_internal_errors_with_context() {
        let err = ApiError::from(ferman_core::CoreError::Internal {
            context: "revision lookup",
        });
        assert_eq!(err.kind, ErrorKind::Internal);
        assert_eq!(err.message_key, MessageKey::INTERNAL);
        assert_eq!(
            err.details.as_deref(),
            Some("internal error in ferman-core: revision lookup")
        );
    }

    #[test]
    fn misuse_of_the_revisions_is_invalid_input() {
        use ferman_core::{CoreError, WriteError};
        for write in [
            WriteError::TransactionOpen,
            WriteError::NoTransaction,
            WriteError::NothingToUndo,
            WriteError::NothingToRedo,
            WriteError::NoSuchPage,
            WriteError::PagePlan,
            WriteError::NoSuchAnnotation,
            WriteError::AnnotationPlan,
        ] {
            let err = ApiError::from(CoreError::Write(write));
            assert_eq!(err.kind, ErrorKind::InvalidInput, "{write:?}");
        }
        for write in [
            WriteError::Placement,
            WriteError::Repaired,
            WriteError::PageStateLeaks,
        ] {
            let err = ApiError::from(CoreError::Write(write));
            assert_eq!(err.kind, ErrorKind::Unsupported, "{write:?}");
        }
        let err = ApiError::from(CoreError::Write(WriteError::ObjectNumbers));
        assert_eq!(err.kind, ErrorKind::Internal);
    }

    #[test]
    fn save_failures_get_their_kind_and_the_save_as_offer() {
        use ferman_core::{CoreError, SaveError};
        for (save, kind) in [
            (SaveError::DiskFull, ErrorKind::DiskFull),
            (SaveError::PermissionDenied, ErrorKind::PermissionDenied),
            (SaveError::FileLocked, ErrorKind::FileLocked),
            (SaveError::RenameFailed, ErrorKind::RenameFailed),
            (SaveError::VolumeGone, ErrorKind::VolumeGone),
            (SaveError::HardLinked, ErrorKind::HardLinked),
            (SaveError::NotOwner, ErrorKind::NotOwner),
            (SaveError::Verify, ErrorKind::Io),
        ] {
            let err = ApiError::from(CoreError::Save(save));
            assert_eq!(err.kind, kind, "{save:?}");
            assert!(err.offer_save_as, "{save:?}");
        }
        let err = ApiError::from(CoreError::Save(SaveError::ChangedOnDisk));
        assert_eq!(err.kind, ErrorKind::FileChangedOnDisk);
        assert!(!err.offer_save_as);
        assert_eq!(err.kind.as_str(), "file_changed_on_disk");
        let io = ApiError::from(CoreError::Io {
            kind: std::io::ErrorKind::NotFound,
        });
        assert!(!io.offer_save_as && io.clone().of_save().offer_save_as);
        let misuse = ApiError::from(CoreError::Write(ferman_core::WriteError::TransactionOpen));
        assert!(!misuse.of_save().offer_save_as);
    }

    #[test]
    fn text_that_cannot_be_edited_names_its_reason() {
        use ferman_text::{Complexity, NotEditableReason};
        let err = ApiError::not_editable(NotEditableReason::Restricted);
        assert_eq!(err.kind, ErrorKind::NotEditable);
        assert_eq!(err.message_key, MessageKey::EDIT_RESTRICTED);
        assert_eq!(err.details.as_deref(), Some("Restricted"));
        assert_eq!(
            MessageKey::not_editable(NotEditableReason::TooComplex(Complexity::Skewed)),
            MessageKey::EDIT_SKEWED
        );
        assert!(MessageKey::ALL.contains(&MessageKey::EDIT_LIMITS));
    }

    #[test]
    fn error_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<ApiError>();
    }
}
