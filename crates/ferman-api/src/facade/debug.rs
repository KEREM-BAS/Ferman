//! Test-only calls for the bridge: a deliberate panic and a large byte vector.
//!
//! They exist in every build, so the generated bridge code is the same in debug, profile and
//! release builds; only debug builds actually panic.

use super::error::ApiError;
use super::guard::guard;

/// The largest vector [`debug_bytes`] returns: 8 MiB.
pub const DEBUG_BYTES_MAX: u32 = 8 * 1024 * 1024;

/// The technical details [`debug_panic`] returns in a build without debug assertions.
pub const DEBUG_PANIC_RELEASE_DETAILS: &str = "debug_panic panics only in debug builds";

/// Panics inside the API boundary's guard, so the caller gets an internal [`ApiError`] and the app
/// keeps running (ROADMAP M1 step 3).
///
/// Only a debug build panics. A build without debug assertions returns the same kind of error
/// without panicking, with the details [`DEBUG_PANIC_RELEASE_DETAILS`].
///
/// # Errors
///
/// Always returns an internal [`ApiError`]: in a debug build the one made from the caught panic
/// ("panic at the API boundary").
pub async fn debug_panic() -> Result<(), ApiError> {
    guard(|| {
        if cfg!(debug_assertions) {
            deliberate_panic();
        }
        Err(ApiError::internal(DEBUG_PANIC_RELEASE_DETAILS))
    })
}

#[allow(
    clippy::panic,
    reason = "the deliberate panic that tests the API boundary; debug builds only"
)]
fn deliberate_panic() -> ! {
    panic!("deliberate panic from debug_panic")
}

/// Returns a vector of `len` zero bytes, at most [`DEBUG_BYTES_MAX`], for the zero-copy benchmark
/// of the bridge (ARCHITECTURE.md §3.4: a 1 MB vector should cross to Dart in under 0.2 ms).
pub async fn debug_bytes(len: u32) -> Vec<u8> {
    let len = usize::try_from(len.min(DEBUG_BYTES_MAX)).unwrap_or(0);
    vec![0; len]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facade::{ErrorKind, MessageKey, block_on};

    #[test]
    fn debug_panic_returns_an_internal_error() {
        let err = block_on(debug_panic()).unwrap_err();
        assert_eq!(err.kind, ErrorKind::Internal);
        assert_eq!(err.message_key, MessageKey::INTERNAL);
        let expected = if cfg!(debug_assertions) {
            "panic at the API boundary"
        } else {
            DEBUG_PANIC_RELEASE_DETAILS
        };
        assert_eq!(err.details.as_deref(), Some(expected));
    }

    #[test]
    fn debug_bytes_has_the_asked_length() {
        assert_eq!(block_on(debug_bytes(0)).len(), 0);
        let bytes = block_on(debug_bytes(1024 * 1024));
        assert_eq!(bytes.len(), 1024 * 1024);
        assert!(bytes.iter().all(|&byte| byte == 0));
    }

    #[test]
    fn debug_bytes_is_capped_at_8_mib() {
        assert_eq!(block_on(debug_bytes(u32::MAX)).len(), 8 * 1024 * 1024);
        assert_eq!(
            block_on(debug_bytes(DEBUG_BYTES_MAX + 1)).len(),
            8 * 1024 * 1024
        );
    }
}
