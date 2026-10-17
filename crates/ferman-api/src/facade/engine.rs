//! The engine: the long-lived parts behind the API, started once per process.
//!
//! In M1 the engine owns one part, the render thread of ferman-render, which loads PDFium. The
//! document actors and the job pool join it in M2 (ADR 0009).

use std::ffi::OsString;
use std::future::Future;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use ferman_render::{RenderConfig, RenderThread};

use super::error::ApiError;
use super::guard::{guard, guard_async};
use super::info::{EngineInfo, PdfiumStatus};

/// The environment variable that names the PDFium library to load, for development, CI and the
/// integration tests, as an absolute path such as `$PWD/build/pdfium/linux-x64/lib/libpdfium.so`.
/// A relative value is resolved against the process's current directory, which for `cargo test` is
/// the crate's folder. An empty value is ignored.
pub const PDFIUM_PATH_ENV: &str = "FERMAN_PDFIUM_PATH";

/// Which PDFium library the engine loads.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub enum PdfiumLibrary {
    /// Find it: the file named by [`PDFIUM_PATH_ENV`] if that is set, otherwise the library
    /// bundled next to the executable (docs/ARCHITECTURE.md §12): `<exe dir>/lib/libpdfium.so` on
    /// Linux, `<exe dir>/pdfium.dll` on Windows and `<exe dir>/../Frameworks/libpdfium.dylib` on
    /// macOS. If neither exists, PDFium is not loaded and the status says so.
    #[default]
    Find,
    /// Load this file.
    Path(PathBuf),
    /// Do not load PDFium.
    Disabled,
}

/// How to start the engine.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct EngineConfig {
    /// Which PDFium library to load.
    pub pdfium: PdfiumLibrary,
}

/// The running engine.
///
/// The app uses one engine per process, [`Engine::global`], started on first use. ferman-cli and
/// tests can start their own with [`Engine::start`]. Dropping an engine stops its render thread
/// cleanly (the global one lives until the process ends).
#[derive(Debug)]
pub struct Engine {
    /// The render thread, or why it could not start.
    render: Result<RenderThread, String>,
}

/// The engine behind the free functions of the facade and the `frb` module.
static GLOBAL: OnceLock<Engine> = OnceLock::new();

impl Engine {
    /// Starts an engine: resolves the PDFium library and starts the render thread, which loads it.
    ///
    /// Starting never fails. A missing or broken PDFium library, or a render thread the operating
    /// system would not start, shows up in [`PdfiumStatus`], so the app can show an error screen
    /// instead of crashing.
    #[must_use]
    pub fn start(config: EngineConfig) -> Self {
        let pdfium_library = match config.pdfium {
            PdfiumLibrary::Find => find_pdfium_library(),
            PdfiumLibrary::Path(path) => Some(path),
            PdfiumLibrary::Disabled => None,
        };
        if pdfium_library.is_none() {
            tracing::info!("no PDFium library to load");
        }
        let render = RenderThread::start(RenderConfig { pdfium_library }).map_err(|err| {
            tracing::error!(error = %err, "the render thread did not start");
            err.to_string()
        });
        Self { render }
    }

    /// The engine of this process, started with [`EngineConfig::default`] on first use.
    pub fn global() -> &'static Self {
        GLOBAL.get_or_init(|| Self::start(EngineConfig::default()))
    }

    /// Whether PDFium is loaded, as the render thread reports it.
    ///
    /// The request goes to the render thread at once; the returned future only awaits the reply,
    /// so an async API function never blocks on it. The future does not borrow the engine.
    pub fn pdfium_status(&self) -> impl Future<Output = PdfiumStatus> + Send + 'static {
        let reply = match &self.render {
            Ok(render) => Ok(render.status()),
            Err(reason) => Err(reason.clone()),
        };
        async move {
            match reply {
                Ok(status) => match status.await {
                    Ok(status) => PdfiumStatus::from(status),
                    Err(err) => PdfiumStatus::Failed {
                        reason: err.to_string(),
                    },
                },
                Err(reason) => PdfiumStatus::Failed { reason },
            }
        }
    }

    /// The versions and build facts of this engine, with its PDFium status.
    ///
    /// # Errors
    ///
    /// Returns an internal [`ApiError`] if gathering the facts panics; nothing else can fail.
    pub async fn info(&self) -> Result<EngineInfo, ApiError> {
        guard_async(async { Ok(EngineInfo::new(self.pdfium_status().await)) }).await
    }
}

/// Returns the versions and build facts of the running engine, including whether PDFium is
/// loaded, from the [global](Engine::global) engine.
///
/// # Errors
///
/// Returns an internal [`ApiError`] if starting the engine or gathering the facts panics.
pub async fn engine_info() -> Result<EngineInfo, ApiError> {
    guard(|| Ok(Engine::global()))?.info().await
}

/// The PDFium library to load when the configuration says [`PdfiumLibrary::Find`].
fn find_pdfium_library() -> Option<PathBuf> {
    resolve_pdfium_library(
        std::env::var_os(PDFIUM_PATH_ENV),
        std::env::current_exe().ok().as_deref(),
        std::env::consts::OS,
        Path::is_file,
    )
}

/// The first of: the environment variable's file (even if it does not exist, so a wrong value is
/// reported as a failure, not ignored), then the bundled library if it exists.
fn resolve_pdfium_library(
    env_value: Option<OsString>,
    exe: Option<&Path>,
    os: &str,
    exists: impl Fn(&Path) -> bool,
) -> Option<PathBuf> {
    if let Some(value) = env_value.filter(|value| !value.is_empty()) {
        return Some(PathBuf::from(value));
    }
    let bundled = bundled_pdfium_library(os, exe?.parent()?)?;
    exists(&bundled).then_some(bundled)
}

/// Where the app bundles PDFium next to its executable on `os` (`std::env::consts::OS`).
fn bundled_pdfium_library(os: &str, exe_dir: &Path) -> Option<PathBuf> {
    match os {
        "linux" => Some(exe_dir.join("lib").join("libpdfium.so")),
        "windows" => Some(exe_dir.join("pdfium.dll")),
        "macos" => Some(
            exe_dir
                .join("..")
                .join("Frameworks")
                .join("libpdfium.dylib"),
        ),
        // Web and mobile bundling is decided in phase 5.
        _ => None,
    }
}

impl From<ferman_render::PdfiumStatus> for PdfiumStatus {
    fn from(status: ferman_render::PdfiumStatus) -> Self {
        match status {
            ferman_render::PdfiumStatus::NotLoaded => Self::NotLoaded,
            ferman_render::PdfiumStatus::Loaded { tag } => Self::Loaded {
                tag: tag.to_owned(),
            },
            ferman_render::PdfiumStatus::Failed { reason } => Self::Failed { reason },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::facade::block_on;

    fn engine(pdfium: PdfiumLibrary) -> Engine {
        Engine::start(EngineConfig { pdfium })
    }

    #[test]
    fn a_disabled_pdfium_is_not_loaded() {
        let engine = engine(PdfiumLibrary::Disabled);
        assert_eq!(block_on(engine.pdfium_status()), PdfiumStatus::NotLoaded);
        let info = block_on(engine.info()).unwrap();
        assert_eq!(info.pdfium, PdfiumStatus::NotLoaded);
    }

    #[test]
    fn a_missing_library_fails_without_its_path() {
        let path = std::env::temp_dir()
            .join(format!("ferman-api-missing-{}", std::process::id()))
            .join("libpdfium.so");
        let engine = engine(PdfiumLibrary::Path(path));
        match block_on(engine.pdfium_status()) {
            PdfiumStatus::Failed { reason } => {
                assert!(!reason.contains("ferman-api-missing"), "{reason}");
            }
            other => panic!("expected Failed, got {other:?}"),
        }
    }

    #[test]
    fn the_global_engine_answers() {
        // Its PDFium state depends on FERMAN_PDFIUM_PATH, so only the shape is checked here.
        let info = block_on(engine_info()).unwrap();
        assert_eq!(info.crates.len(), 6);
        assert!(std::ptr::eq(Engine::global(), Engine::global()));
    }

    #[test]
    fn the_environment_variable_wins() {
        let found = resolve_pdfium_library(
            Some(OsString::from("/opt/pdfium/libpdfium.so")),
            Some(Path::new("/app/ferman")),
            "linux",
            |_| true,
        );
        assert_eq!(found, Some(PathBuf::from("/opt/pdfium/libpdfium.so")));
    }

    #[test]
    fn a_named_but_missing_file_is_still_returned() {
        // It then fails to load and the status says why, instead of PDFium silently not loading.
        let found = resolve_pdfium_library(
            Some(OsString::from("/no/such/libpdfium.so")),
            None,
            "linux",
            |_| false,
        );
        assert_eq!(found, Some(PathBuf::from("/no/such/libpdfium.so")));
    }

    #[test]
    fn an_empty_environment_variable_is_ignored() {
        let found = resolve_pdfium_library(
            Some(OsString::new()),
            Some(Path::new("/app/ferman")),
            "linux",
            |_| true,
        );
        assert_eq!(found, Some(PathBuf::from("/app/lib/libpdfium.so")));
    }

    #[test]
    fn the_bundled_library_is_used_only_if_it_exists() {
        let found =
            resolve_pdfium_library(None, Some(Path::new("/app/ferman")), "linux", |_| false);
        assert_eq!(found, None);
        assert_eq!(resolve_pdfium_library(None, None, "linux", |_| true), None);
    }

    #[test]
    fn the_bundled_location_follows_the_platform() {
        let dir = Path::new("/bundle/dir");
        assert_eq!(
            bundled_pdfium_library("linux", dir),
            Some(dir.join("lib").join("libpdfium.so"))
        );
        assert_eq!(
            bundled_pdfium_library("windows", dir),
            Some(dir.join("pdfium.dll"))
        );
        assert_eq!(
            bundled_pdfium_library("macos", dir),
            Some(dir.join("..").join("Frameworks").join("libpdfium.dylib"))
        );
        assert_eq!(bundled_pdfium_library("android", dir), None);
    }

    #[test]
    fn render_statuses_map_one_to_one() {
        assert_eq!(
            PdfiumStatus::from(ferman_render::PdfiumStatus::Loaded {
                tag: ferman_render::PDFIUM_TAG
            }),
            PdfiumStatus::Loaded {
                tag: "chromium/7881".to_owned()
            }
        );
        assert_eq!(
            PdfiumStatus::from(ferman_render::PdfiumStatus::Failed {
                reason: "dlopen failed".to_owned()
            }),
            PdfiumStatus::Failed {
                reason: "dlopen failed".to_owned()
            }
        );
    }

    #[test]
    fn the_engine_can_be_shared_between_threads() {
        fn assert_thread_safe<T: Send + Sync + 'static>() {}
        assert_thread_safe::<Engine>();
    }

    #[test]
    #[ignore = "needs PDFium: tools/pdfium/fetch.sh + FERMAN_PDFIUM_PATH"]
    fn pdfium_from_the_environment_loads() {
        // Find reads FERMAN_PDFIUM_PATH, which this test run sets.
        let engine = engine(PdfiumLibrary::Find);
        assert_eq!(
            block_on(engine.pdfium_status()),
            PdfiumStatus::Loaded {
                tag: "chromium/7881".to_owned()
            }
        );
        let info = block_on(engine_info()).unwrap();
        assert_eq!(
            info.pdfium,
            PdfiumStatus::Loaded {
                tag: "chromium/7881".to_owned()
            }
        );
    }
}
