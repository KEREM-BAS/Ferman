//! The pure-Rust facade of the engine.
//!
//! Everything the app and the CLI can ask of the engine goes through this module. In M1 it answers
//! two questions: which API version this library speaks ([`api_version`], the only synchronous call
//! of the API) and what the engine is made of ([`engine_info`]). Every entry point runs inside
//! [`guard`], which turns a panic into an [`ApiError`] as a last resort (ADR 0010).

mod error;
mod guard;
mod info;
mod version;

pub use error::{ApiError, ErrorKind, MessageKey};
pub use guard::guard;
pub use info::{BuildProfile, CrateVersion, EngineInfo, PdfiumStatus, engine_info};
pub use version::{API_VERSION, APP_VERSION, ApiVersion, api_version};
