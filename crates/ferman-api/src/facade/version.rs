//! The API version and the app version.

use std::fmt;

use serde::Serialize;

/// The version of Ferman: the workspace version, which `app/pubspec.yaml` repeats without its
/// build number (tools/checks compares them).
pub const APP_VERSION: &str = env!("CARGO_PKG_VERSION");

/// The version of the API between the engine and the UI.
///
/// The Dart and Rust glue come from one source in one build, so a mismatch at start-up can only
/// mean a stale native library. The app then shows an error screen instead of crashing
/// (docs/ARCHITECTURE.md §3.9). Before 1.0, any breaking change bumps the version.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize)]
pub struct ApiVersion {
    /// Incremented on a breaking change.
    pub major: u32,
    /// Incremented on a compatible addition.
    pub minor: u32,
}

impl fmt::Display for ApiVersion {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}.{}", self.major, self.minor)
    }
}

/// The API version this library speaks.
pub const API_VERSION: ApiVersion = ApiVersion { major: 0, minor: 1 };

/// Returns the API version this library speaks.
///
/// This is the only synchronous call of the API; every other call is async or a stream
/// (docs/ARCHITECTURE.md §3.1).
#[must_use]
pub const fn api_version() -> ApiVersion {
    API_VERSION
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn api_version_is_the_constant() {
        assert_eq!(api_version(), API_VERSION);
        assert_eq!(API_VERSION, ApiVersion { major: 0, minor: 1 });
    }

    #[test]
    fn api_version_displays_as_major_dot_minor() {
        assert_eq!(API_VERSION.to_string(), "0.1");
        assert_eq!(
            ApiVersion {
                major: 2,
                minor: 13
            }
            .to_string(),
            "2.13"
        );
    }
}
