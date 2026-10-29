//! The pure-Rust facade of the engine.
//!
//! Everything the app and the CLI can ask of the engine goes through this module. In M1 it answers
//! two questions: which API version this library speaks ([`api_version`], the only synchronous call
//! of the API) and what the engine is made of, including whether PDFium is loaded
//! ([`engine_info`], async). Since M2 it opens and closes documents and runs views of their pages
//! ([`Engine::open`], [`Engine::open_view`]). The [`Engine`] owns the long-lived parts (the render
//! thread that loads PDFium); the free functions use the process's [global](Engine::global) engine.
//! Every entry point runs inside [`guard`] or [`guard_async`], which turn a panic into an
//! [`ApiError`] as a last resort (ADR 0010). [`debug_panic`] and [`debug_bytes`] exist for the
//! bridge tests. Synchronous callers (ferman-cli, tests) await with [`block_on`].

mod blocking;
mod debug;
mod document;
mod engine;
mod error;
mod guard;
mod info;
mod version;

pub use blocking::block_on;
pub use debug::{DEBUG_BYTES_MAX, DEBUG_PANIC_RELEASE_DETAILS, debug_bytes, debug_panic};
pub use document::{OpenedDocument, PageInfo, ReadOnly};
pub use engine::{Engine, EngineConfig, PDFIUM_PATH_ENV, PdfiumLibrary, engine_info};
pub use error::{ApiError, ErrorKind, MessageKey};
pub use guard::{guard, guard_async};
pub use info::{BuildProfile, CrateVersion, EngineInfo, PdfiumStatus};
pub use version::{API_VERSION, APP_VERSION, ApiVersion, api_version};

// The engine types the API passes through as they are: plain data, no lopdf or PDFium inside.
pub use ferman_core::structure::{
    Agreement, Attachment, Direction, Layer, OutlineItem, PdfDate, Signature,
};
pub use ferman_core::{Password, Repair, RepairReport, XrefProblem};
pub use ferman_render::{
    DocumentId, FailReason, Failed, Item, MAX_THUMBNAIL_SIZE, PageSize, PixelRect, Priority,
    Rendered, ThumbnailRequest, TilePosition, TileRequest, ViewEvent, ViewId, ViewSink, Wanted,
    ZoomBucket,
};
