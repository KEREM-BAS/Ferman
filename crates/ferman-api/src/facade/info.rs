//! What the engine is made of: versions, build profile and PDFium status.

use serde::Serialize;

use super::error::ApiError;
use super::guard::guard;
use super::version::{API_VERSION, APP_VERSION, ApiVersion};

/// Versions and build facts of the running engine, for the About screen, bug reports and
/// `ferman info`.
///
/// It serializes to the JSON that `ferman info --json` prints, with snake_case field names.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct EngineInfo {
    /// The version of Ferman, such as `"0.1.0"`.
    pub app_version: String,
    /// The API version this library speaks.
    pub api_version: ApiVersion,
    /// Whether this is a debug or a release build.
    pub build_profile: BuildProfile,
    /// The engine crates and their versions, from the bottom of the crate graph up.
    pub crates: Vec<CrateVersion>,
    /// Whether the PDFium library is loaded.
    pub pdfium: PdfiumStatus,
}

/// The build profile of the engine library.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum BuildProfile {
    /// Built with debug assertions on.
    Debug,
    /// Built with debug assertions off.
    Release,
}

impl BuildProfile {
    /// The profile this library was built with, judged by `debug_assertions`.
    pub const CURRENT: Self = if cfg!(debug_assertions) {
        Self::Debug
    } else {
        Self::Release
    };

    /// `"debug"` or `"release"`.
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Debug => "debug",
            Self::Release => "release",
        }
    }
}

/// One engine crate and its version.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct CrateVersion {
    /// The crate name, such as `"ferman-core"`.
    pub name: String,
    /// The crate version, such as `"0.1.0"`.
    pub version: String,
}

impl CrateVersion {
    fn new(name: &str, version: &str) -> Self {
        Self {
            name: name.to_owned(),
            version: version.to_owned(),
        }
    }
}

/// Whether the PDFium library is loaded.
///
/// It serializes as `{"state": "not_loaded"}`. The skeleton render thread (M1 step 3) adds a
/// loaded state with the pinned binary's tag; PDFium has no version call of its own.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum PdfiumStatus {
    /// PDFium has not been loaded.
    NotLoaded,
}

/// Returns the versions and build facts of the running engine.
///
/// # Errors
///
/// Returns an internal [`ApiError`] if gathering the facts fails unexpectedly; today nothing can
/// fail except a bug.
pub fn engine_info() -> Result<EngineInfo, ApiError> {
    guard(|| {
        Ok(EngineInfo {
            app_version: APP_VERSION.to_owned(),
            api_version: API_VERSION,
            build_profile: BuildProfile::CURRENT,
            crates: vec![
                CrateVersion::new("ferman-core", ferman_core::VERSION),
                CrateVersion::new("ferman-fonts", ferman_fonts::VERSION),
                CrateVersion::new("ferman-text", ferman_text::VERSION),
                CrateVersion::new("ferman-render", ferman_render::VERSION),
                CrateVersion::new("ferman-ops", ferman_ops::VERSION),
                CrateVersion::new("ferman-api", env!("CARGO_PKG_VERSION")),
            ],
            pdfium: PdfiumStatus::NotLoaded,
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn engine_info_reports_versions_and_profile() {
        let info = engine_info().unwrap();
        assert_eq!(info.app_version, APP_VERSION);
        assert_eq!(info.api_version, API_VERSION);
        assert_eq!(info.build_profile, BuildProfile::CURRENT);
        assert_eq!(info.pdfium, PdfiumStatus::NotLoaded);
        let names: Vec<&str> = info.crates.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(
            names,
            [
                "ferman-core",
                "ferman-fonts",
                "ferman-text",
                "ferman-render",
                "ferman-ops",
                "ferman-api"
            ]
        );
        assert!(info.crates.iter().all(|c| c.version == APP_VERSION));
    }

    #[test]
    fn build_profile_matches_debug_assertions() {
        let expected = if cfg!(debug_assertions) {
            "debug"
        } else {
            "release"
        };
        assert_eq!(BuildProfile::CURRENT.as_str(), expected);
    }
}
