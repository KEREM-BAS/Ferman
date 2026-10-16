//! The one error type the UI sees.

use std::fmt;

/// What kind of failure an [`ApiError`] reports.
///
/// The UI maps each kind to a design state (docs/ARCHITECTURE.md §8.2). The kinds that only the
/// later features produce (for example `PasswordRequired` or `DiskFull`) arrive with those
/// features.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[non_exhaustive]
pub enum ErrorKind {
    /// The caller passed a value the engine cannot accept.
    InvalidInput,
    /// A file or handle does not exist (any more).
    NotFound,
    /// The input uses something Ferman does not support yet.
    Unsupported,
    /// Reading or writing failed for a reason without its own kind.
    Io,
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
            Self::Unsupported => "unsupported",
            Self::Io => "io",
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
/// [`MessageKey::ALL`]. A CI check that every key exists in `app_en.arb` and `app_tr.arb` does not
/// exist yet; it will be added when the ARB files gain the error strings (M1 step 10).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct MessageKey(&'static str);

impl MessageKey {
    /// Something went wrong inside Ferman; the message offers "Copy technical details".
    pub const INTERNAL: Self = Self("errorInternal");

    /// Every key the engine can return.
    pub const ALL: &'static [Self] = &[Self::INTERNAL];

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
/// or passwords. Message parameters and a retry flag join it when the first call needs them
/// (docs/ARCHITECTURE.md §3.8).
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("{kind} [{message_key}]{}", details_suffix(.details))]
pub struct ApiError {
    /// What kind of failure this is.
    pub kind: ErrorKind,
    /// The ARB key of the message the UI shows.
    pub message_key: MessageKey,
    /// Technical details for "Copy technical details", if any.
    pub details: Option<String>,
}

impl ApiError {
    /// An error of `kind` with the message `message_key` and no details.
    #[must_use]
    pub const fn new(kind: ErrorKind, message_key: MessageKey) -> Self {
        Self {
            kind,
            message_key,
            details: None,
        }
    }

    /// An [`ErrorKind::Internal`] error with the generic message and technical `details`.
    #[must_use]
    pub fn internal(details: impl Into<String>) -> Self {
        Self::new(ErrorKind::Internal, MessageKey::INTERNAL).with_details(details)
    }

    /// The same error with technical `details`.
    #[must_use]
    pub fn with_details(mut self, details: impl Into<String>) -> Self {
        self.details = Some(details.into());
        self
    }
}

fn details_suffix(details: &Option<String>) -> String {
    details
        .as_deref()
        .map(|details| format!(": {details}"))
        .unwrap_or_default()
}

// Engine errors reach the UI as ApiError. Until the engine crates produce errors of their own
// kinds, everything they report is internal; the mapping grows with them (docs/ARCHITECTURE.md
// §8.2). The crate errors carry structural context only, so their text can go into `details`.

impl From<ferman_core::CoreError> for ApiError {
    fn from(err: ferman_core::CoreError) -> Self {
        Self::internal(err.to_string())
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
        Self::internal(err.to_string())
    }
}

impl From<ferman_ops::OpsError> for ApiError {
    fn from(err: ferman_ops::OpsError) -> Self {
        Self::internal(err.to_string())
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
    fn error_can_cross_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<ApiError>();
    }
}
