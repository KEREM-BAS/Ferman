//! The pure-Rust facade of the engine.
//!
//! Everything the app and the CLI can ask of the engine goes through this module. In M1 it answers
//! two questions: which API version this library speaks ([`api_version`], the only synchronous call
//! of the API) and what the engine is made of, including whether PDFium is loaded
//! ([`engine_info`], async). Since M2 it opens and closes documents and runs views of their pages
//! ([`Engine::open`], [`Engine::open_view`]); since M3 it gives each page's text blocks, carets
//! and selections ([`Engine::text_blocks`]), and edits them in transactions with undo, redo and
//! saving ([`Engine::begin_edit`], one actor per document); since M4 it runs background jobs
//! ([`Engine::start_job`]). The [`Engine`] owns the long-lived
//! parts (the render thread that loads PDFium); the free functions use the process's
//! [global](Engine::global) engine.
//! Every entry point runs inside [`guard`] or [`guard_async`], which turn a panic into an
//! [`ApiError`] as a last resort (ADR 0010). [`debug_panic`] and [`debug_bytes`] exist for the
//! bridge tests. Synchronous callers (ferman-cli, tests) await with [`block_on`].

mod blocking;
mod debug;
mod document;
mod edit;
mod engine;
mod error;
mod guard;
mod info;
mod jobs;
mod recovery;
mod search;
mod text;
mod version;

pub use blocking::block_on;
pub use debug::{DEBUG_BYTES_MAX, DEBUG_PANIC_RELEASE_DETAILS, debug_bytes, debug_panic};
pub use document::{DocumentStructure, OpenedDocument, PageInfo, ReadOnly, Security};
pub use edit::{
    ConfirmationToken, DependentCell, EditPreview, FontSettings, FontSubstitution, History,
    HistoryStep, MissingGlyphInfo, Reverted, RevisionInfo, TransactionId,
};
pub use engine::{Engine, EngineConfig, PDFIUM_PATH_ENV, PdfiumLibrary, engine_info};
pub use error::{ApiError, ErrorKind, MessageKey};
pub use guard::{guard, guard_async};
pub use info::{BuildProfile, CrateVersion, EngineInfo, PdfiumStatus};
pub use jobs::{
    JOB_STALE, JobChange, JobEvent, JobId, JobOutput, JobResult, JobRun, JobSink, JobSnapshot,
    JobStop,
};
pub use recovery::{RecoverableDocument, RestoredDocument};
pub use search::{SearchEvent, SearchId, SearchMatch, SearchSink};
pub use text::{BlockInfo, Caret, FontCoverage, LineInfo, PageBlocks, Selection, TextPosition};
pub use version::{API_VERSION, APP_VERSION, ApiVersion, api_version};

// The engine types the API passes through as they are: plain data, no lopdf or PDFium inside.
pub use ferman_core::structure::{
    Agreement, Attachment, Direction, FontKind, FontUse, Info, Layer, OpGate, OutlineItem, PdfDate,
    Scripts, Signature,
};
pub use ferman_core::{
    DocumentOp, Method, Password, Permissions, Repair, RepairReport, XrefProblem,
};
pub use ferman_fonts::{Coverage, Embedding, FontOrigin};
pub use ferman_render::{
    DocumentId, FailReason, Failed, Item, MAX_THUMBNAIL_SIZE, PageSize, PixelRect, Priority,
    Rendered, ThumbnailRequest, TilePosition, TileRequest, ViewEvent, ViewId, ViewSink, Wanted,
    ZoomBucket,
};
pub use ferman_render::{EDIT_MARGIN, PageRaster, PixelDiff, RESOLUTIONS, compare, device_region};
pub use ferman_text::{
    Alignment, BlockFont, BlockId, BlockStyle, BlockStyleInfo, Choice, Complexity, Editability,
    Extend, ExtendBlocked, FontCandidate, Keep, MissingReason, NotEditableReason, OverflowPlan,
    SearchOptions, Substitution, SubstitutionKind, TextDirection, Tighten, TightenShort,
    collation_order,
};
