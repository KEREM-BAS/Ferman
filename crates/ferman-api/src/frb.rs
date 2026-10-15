//! The Dart surface of the engine (feature `frb`).
//!
//! flutter_rust_bridge codegen scans only this module, so the generated surface stays small. It
//! holds thin wrappers over [`crate::facade`] and nothing else (ADR 0003). The `#[frb]` attributes,
//! the async form of `engine_info` and the generated glue arrive in M1 step 3.

use crate::facade::{self, ApiError, ApiVersion, EngineInfo};

/// Returns the API version this library speaks; the app compares it at start-up.
///
/// See [`facade::api_version`].
#[must_use]
pub fn api_version() -> ApiVersion {
    facade::api_version()
}

/// Returns the versions and build facts of the running engine.
///
/// See [`facade::engine_info`].
///
/// # Errors
///
/// Returns the facade's error unchanged.
pub fn engine_info() -> Result<EngineInfo, ApiError> {
    facade::engine_info()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wrappers_return_what_the_facade_returns() {
        assert_eq!(api_version(), facade::api_version());
        assert_eq!(engine_info(), facade::engine_info());
    }
}
