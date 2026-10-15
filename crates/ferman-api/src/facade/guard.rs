//! The last-resort panic guard at the API boundary.

use std::any::Any;
use std::panic::{self, UnwindSafe};

use super::error::ApiError;

/// The technical details of an error made from a caught panic.
///
/// A fixed sentence: a panic payload is free text from any crate (an unwrapped error can embed
/// document text), and details may be copied into a public issue (docs/ARCHITECTURE.md §8.4).
const PANIC_DETAILS: &str = "panic at the API boundary";

/// Runs `f` and turns a panic inside it into an [`ApiError`] of kind
/// [`ErrorKind::Internal`](super::ErrorKind::Internal) with the message key
/// [`MessageKey::INTERNAL`](super::MessageKey::INTERNAL).
///
/// Library code never panics on purpose (ADR 0010); this is the safety net at the entry points of
/// the API, so a bug reaches the UI as an error instead of taking the app down. It is the only
/// place Ferman uses `catch_unwind`, which is why the release profile keeps `panic = "unwind"`.
///
/// The panic payload is free text from any crate and can hold document text, so it never goes
/// into the error or the release log (docs/ARCHITECTURE.md §8.4). The error's details are the
/// fixed sentence "panic at the API boundary". The local log records that a panic was caught; only
/// a debug build adds the payload, at debug level. The default panic hook still writes the panic
/// to standard error, which is not one of the log files.
///
/// # Errors
///
/// Returns the error `f` returns, or an internal error if `f` panics.
pub fn guard<T>(f: impl FnOnce() -> Result<T, ApiError> + UnwindSafe) -> Result<T, ApiError> {
    panic::catch_unwind(f).unwrap_or_else(|payload| {
        tracing::error!("caught a panic at the API boundary");
        if cfg!(debug_assertions) {
            tracing::debug!(
                panic = panic_message(payload.as_ref()),
                "panic payload (debug build only)"
            );
        }
        Err(ApiError::internal(PANIC_DETAILS))
    })
}

/// The text of a panic payload; `panic!` produces a `&str` or a `String`.
fn panic_message(payload: &(dyn Any + Send)) -> &str {
    if let Some(message) = payload.downcast_ref::<&'static str>() {
        message
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message
    } else {
        "a panic without a text message"
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facade::{ErrorKind, MessageKey};

    #[test]
    fn a_panic_becomes_an_internal_error() {
        let result: Result<(), ApiError> = guard(|| panic!("boom"));
        let err = result.unwrap_err();
        assert_eq!(err.kind, ErrorKind::Internal);
        assert_eq!(err.message_key, MessageKey::INTERNAL);
        assert_eq!(err.details.as_deref(), Some(PANIC_DETAILS));
    }

    #[test]
    fn the_panic_payload_never_reaches_the_error() {
        // An unwrapped error can carry document text into the payload.
        fn read_clause() -> Result<(), String> {
            Err(String::from("Kira bedeli aylık 12.500 TL ödenir"))
        }
        let result: Result<(), ApiError> = guard(|| {
            read_clause().unwrap();
            Ok(())
        });
        let err = result.unwrap_err();
        assert_eq!(err.details.as_deref(), Some(PANIC_DETAILS));
        assert!(!err.to_string().contains("Kira"), "{err}");
    }

    #[test]
    fn a_panic_without_text_is_still_caught() {
        let result: Result<(), ApiError> = guard(|| panic::panic_any(42_u8));
        assert_eq!(result.unwrap_err().details.as_deref(), Some(PANIC_DETAILS));
    }

    #[test]
    fn panic_message_reads_str_and_string_payloads() {
        let text: Box<dyn Any + Send> = Box::new("boom");
        assert_eq!(panic_message(text.as_ref()), "boom");
        let formatted: Box<dyn Any + Send> = Box::new(format!("page {} out of range", 3));
        assert_eq!(panic_message(formatted.as_ref()), "page 3 out of range");
        let other: Box<dyn Any + Send> = Box::new(42_u8);
        assert_eq!(
            panic_message(other.as_ref()),
            "a panic without a text message"
        );
    }

    #[test]
    fn results_pass_through_unchanged() {
        assert_eq!(guard(|| Ok(7)), Ok(7));
        let err = ApiError::internal("no trailer");
        let expected = err.clone();
        assert_eq!(guard(move || Err::<(), _>(err)), Err(expected));
    }
}
