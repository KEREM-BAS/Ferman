//! The Dart surface of the engine (feature `frb`).
//!
//! flutter_rust_bridge codegen scans only this module, so the generated surface stays small. It
//! holds thin wrappers over [`crate::facade`] and mirrors of the facade's data types, and nothing
//! else (ADR 0003, docs/ARCHITECTURE.md §2.3).
//!
//! The mirrors are plain structs and enums without data, with public fields, no references and no
//! generics, so FRB translates them into plain Dart classes and enums. Enums that carry data (the
//! facade's [`facade::PdfiumStatus`]) become a struct with a state enum and optional fields, so the
//! Dart side needs no freezed code generation; [`facade::MessageKey`] becomes a `String`, because
//! its `&'static str` cannot cross (docs/ARCHITECTURE.md §8.2). The conversions are private
//! functions, which FRB does not scan. The mirrors reuse the facade's type names: codegen matches
//! types by bare name across the crate, which works only because the facade is hidden from it
//! (`frb(ignore)` on the module in `lib.rs`).
//!
//! Every function is async except [`api_version`], the version check at start-up.

use std::path::PathBuf;

use crate::facade;
use crate::frb_generated::StreamSink;

/// The version of the API between the engine and the UI.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ApiVersion {
    /// Incremented on a breaking change.
    pub major: u32,
    /// Incremented on a compatible addition.
    pub minor: u32,
}

/// The build profile of the engine library.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BuildProfile {
    /// Built with debug assertions on.
    Debug,
    /// Built with debug assertions off.
    Release,
}

/// One engine crate and its version.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CrateVersion {
    /// The crate name, such as `"ferman-core"`.
    pub name: String,
    /// The crate version, such as `"0.1.0"`.
    pub version: String,
}

/// Whether PDFium is loaded: the state of a [`PdfiumStatus`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PdfiumState {
    /// No PDFium library was found or configured.
    NotLoaded,
    /// PDFium is loaded and a real call into it succeeded.
    Loaded,
    /// A library was found or configured but it did not load or did not work.
    Failed,
}

/// Whether the PDFium library is loaded.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PdfiumStatus {
    /// Not loaded, loaded or failed.
    pub state: PdfiumState,
    /// For [`PdfiumState::Loaded`]: the pinned build tag, such as `"chromium/7881"`.
    pub tag: Option<String>,
    /// For [`PdfiumState::Failed`]: technical text for "Copy technical details", in English and
    /// without the library path. The UI shows its own localized message.
    pub reason: Option<String>,
}

/// Versions and build facts of the running engine, for the About screen and bug reports.
#[derive(Debug, Clone, PartialEq, Eq)]
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

/// What kind of failure an [`ApiError`] reports. The UI maps each kind to a design state.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorKind {
    /// The caller passed a value the engine cannot accept.
    InvalidInput,
    /// A file or handle does not exist (any more).
    NotFound,
    /// The system does not let Ferman read the file.
    PermissionDenied,
    /// The document is encrypted and its password is needed.
    PasswordRequired,
    /// The password does not open the document.
    WrongPassword,
    /// The file is damaged beyond repair.
    Damaged,
    /// The input is not a PDF, or uses something Ferman does not support yet.
    Unsupported,
    /// A resource limit stopped the work, or memory ran short.
    ResourceLimit,
    /// Reading or writing failed for a reason without its own kind.
    Io,
    /// A bug in Ferman, including a caught panic.
    Internal,
}

/// The error every fallible call returns; Dart receives it as an exception.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ApiError {
    /// What kind of failure this is.
    pub kind: ErrorKind,
    /// The ARB key of the message the UI shows, such as `"errorInternal"`.
    pub message_key: String,
    /// Technical details for "Copy technical details": structural facts only.
    pub details: Option<String>,
}

/// Why a document opened read-only (ARCHITECTURE §5.2). In M2 every document is view-only; this is
/// the reason the UI states.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReadOnlyReason {
    /// Ferman repaired it (a1-9), or could not read some of its objects.
    Repaired,
    /// The two parsers see different pages (G102).
    ParsersDisagree,
    /// An XFA-only form (a11-7c).
    XfaOnly,
}

/// One thing repair did, for a1-9's "What Ferman repaired".
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RepairFix {
    /// What was repaired.
    pub kind: RepairKind,
    /// The objects found (`CrossReferenceRebuilt`), the streams corrected
    /// (`StreamLengthsCorrected`) or the objects that could not be read (`ObjectsUnreadable`);
    /// 0 for `TrailerRebuilt`.
    pub count: u32,
}

/// What a [`RepairFix`] repaired.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RepairKind {
    /// The cross-reference table was rebuilt from the objects found in the file.
    CrossReferenceRebuilt,
    /// The trailer was missing, and the catalog was found among the objects.
    TrailerRebuilt,
    /// Streams whose `/Length` was wrong were read up to their `endstream`.
    StreamLengthsCorrected,
    /// Objects the cross-reference data names could not be read.
    ObjectsUnreadable,
}

/// One page of an [`OpenedDocument`], in points as displayed.
#[derive(Debug, Clone, PartialEq)]
pub struct PageInfo {
    /// The width, after the crop box and `/Rotate`.
    pub width: f32,
    /// The height, after the crop box and `/Rotate`.
    pub height: f32,
    /// The page label, such as "iv", when the document has labels.
    pub label: Option<String>,
}

/// A document the engine opened.
#[derive(Debug, Clone, PartialEq)]
pub struct OpenedDocument {
    /// Its handle, until [`close`].
    pub id: u64,
    /// Why it opened read-only, if it did.
    pub read_only: Option<ReadOnlyReason>,
    /// What repair did, in order; empty unless `read_only` is `Repaired`.
    pub repairs: Vec<RepairFix>,
    /// Whether spreads run right to left (`/Direction /R2L`).
    pub right_to_left: bool,
    /// Its pages.
    pub pages: Vec<PageInfo>,
    /// The outline in reading order, each item followed by its children.
    pub outline: Vec<OutlineEntry>,
    /// Embedded files, never opened automatically.
    pub attachments: Vec<Attachment>,
    /// Layers, in the order the document gives them.
    pub layers: Vec<Layer>,
    /// Whether [`show_layers`] can show and hide them: not for a repaired document, or one that
    /// needed a password (Q22).
    pub layers_switchable: bool,
    /// Signature fields.
    pub signatures: Vec<Signature>,
    /// The PDF version in the header, such as "1.7".
    pub version: String,
    /// The file's size in bytes.
    pub file_size: u64,
    /// The document information dictionary.
    pub info: DocumentInfo,
    /// `/Lang`, the document's language tag.
    pub language: Option<String>,
    /// Whether it is a tagged PDF.
    pub tagged: bool,
    /// Whether it is linearized for fast web view.
    pub linearized: bool,
    /// The fonts its pages use, each name once.
    pub fonts: Vec<FontEntry>,
    /// Its encryption and permissions, when it is encrypted (a2-10a, a2-10b).
    pub security: Option<Security>,
    /// How many JavaScript actions it holds; Ferman never runs them (G100).
    pub scripts: u32,
    /// How many form fields it has (the Form badge).
    pub form_fields: u32,
    /// Whether its first page has no text, most likely a scan (the Scanned badge).
    pub scanned: bool,
}

/// The document information dictionary (a2-7).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DocumentInfo {
    /// `/Title`.
    pub title: Option<String>,
    /// `/Author`.
    pub author: Option<String>,
    /// `/Subject`.
    pub subject: Option<String>,
    /// `/Keywords`.
    pub keywords: Option<String>,
    /// `/Creator`: the application that made the original.
    pub creator: Option<String>,
    /// `/Producer`: the application that wrote the PDF.
    pub producer: Option<String>,
    /// `/CreationDate`.
    pub created: Option<PdfDate>,
    /// `/ModDate`.
    pub modified: Option<PdfDate>,
}

/// A font's type (a2-7's Type column).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FontType {
    /// Type 1.
    Type1,
    /// Multiple Master Type 1.
    MultipleMaster,
    /// TrueType.
    TrueType,
    /// A composite font (Type 0), usually CID-keyed.
    Type0,
    /// Type 3, drawn by content streams.
    Type3,
    /// Anything else.
    Other,
}

/// A font the pages use (a2-7, FmDocPanel's Fonts in this document).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FontEntry {
    /// Its name, without a subset's `ABCDEF+` tag.
    pub name: String,
    /// Its type.
    pub kind: FontType,
    /// Whether its program is in the file.
    pub embedded: bool,
    /// Whether only the characters the file uses are embedded (the name's tag).
    pub subset: bool,
}

/// How an encrypted document is encrypted.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EncryptionMethod {
    /// RC4, with [`Security::key_bits`].
    Rc4,
    /// AES-128.
    Aes128,
    /// AES-256.
    Aes256,
    /// Encrypted only in name.
    Identity,
}

/// What an encrypted document allows without its owner password (a2-10b's rows).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(clippy::struct_excessive_bools)]
pub struct DocumentPermissions {
    /// Printing.
    pub print: bool,
    /// Printing at full quality.
    pub print_high_quality: bool,
    /// Changing the document.
    pub modify: bool,
    /// Adding comments.
    pub annotate: bool,
    /// Filling form fields, signature fields included.
    pub fill_forms: bool,
    /// Copying text and images.
    pub copy: bool,
    /// Text access for screen readers.
    pub accessibility: bool,
    /// Assembling pages.
    pub assemble: bool,
}

/// An encrypted document's security (a2-10a, a2-10b).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Security {
    /// How it is encrypted.
    pub method: EncryptionMethod,
    /// The key length in bits: RC4's 40 to 128, 128 or 256 for AES, 0 for none.
    pub key_bits: u16,
    /// Whether opening it needs a password.
    pub user_password_required: bool,
    /// What the file allows without its owner password.
    pub permissions: DocumentPermissions,
    /// Whether its owner password was given, which lifts the restrictions for the session.
    pub owner: bool,
    /// Whether the restrictions apply now.
    pub restricted: bool,
}

/// One outline item (bookmark) of an [`OpenedDocument`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OutlineEntry {
    /// Its title.
    pub title: String,
    /// The page it goes to, from 0, when it goes to a page of this document.
    pub page: Option<u32>,
    /// Its nesting, from 0.
    pub depth: u32,
    /// Whether the document shows it open.
    pub open: bool,
}

/// A date as the file writes it, without converting its time zone.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PdfDate {
    /// The year.
    pub year: u16,
    /// The month, 1 to 12.
    pub month: u8,
    /// The day, 1 to 31.
    pub day: u8,
    /// The hour, 0 to 23.
    pub hour: u8,
    /// The minute, 0 to 59.
    pub minute: u8,
}

/// An embedded file of an [`OpenedDocument`] (a2-3b).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Attachment {
    /// Its file name.
    pub name: String,
    /// Its size in bytes, when the file gives it.
    pub size: Option<u64>,
    /// When it was last changed, or else created, when the file gives it.
    pub modified: Option<PdfDate>,
}

/// A layer (optional content group) of an [`OpenedDocument`] (a2-3c).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Layer {
    /// Its name.
    pub name: String,
    /// Whether the document shows it.
    pub visible: bool,
    /// Whether the document locks its visibility.
    pub locked: bool,
}

/// A signature field of an [`OpenedDocument`] (a2-14).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Signature {
    /// The field's full name.
    pub field: String,
    /// Whether it holds a signature.
    pub signed: bool,
    /// The signer's name as the signature writes it.
    pub signer: Option<String>,
    /// When it was signed, as the signature writes it.
    pub signed_at: Option<PdfDate>,
    /// The page of its widget, from 0.
    pub page: Option<u32>,
}

/// Whether a [`ViewItem`] is a tile or a thumbnail.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ItemKind {
    /// A 512-pixel tile of a page at a zoom bucket.
    Tile,
    /// The whole page fitted into a square.
    Thumbnail,
}

/// Something a view wants rendered: a tile (`zoom_bucket`, `device_pixel_ratio`, `column`, `row`)
/// or a thumbnail (`size`); the fields of the other kind are 0.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ViewItem {
    /// Tile or thumbnail.
    pub kind: ItemKind,
    /// The page, from 0.
    pub page: u32,
    /// A tile's quarter-octave zoom: the logical zoom is 2^(bucket / 4).
    pub zoom_bucket: i16,
    /// A tile's device pixel ratio, 0.5 to 4.
    pub device_pixel_ratio: f32,
    /// A tile's column on the grid.
    pub column: u32,
    /// A tile's row on the grid.
    pub row: u32,
    /// A thumbnail's side in device pixels, 16 to 1,024.
    pub size: u32,
}

/// How urgent a wanted item is, highest first (ARCHITECTURE §4.5).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Priority {
    /// Tiles on screen.
    Visible,
    /// Tiles just off screen.
    Prefetch,
    /// Thumbnails on screen.
    VisibleThumbnail,
    /// Other thumbnails.
    Thumbnail,
    /// Background work.
    Background,
}

/// One entry of a view's wanted set.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WantedItem {
    /// What to render.
    pub item: ViewItem,
    /// How urgent it is.
    pub priority: Priority,
}

/// Why an item was not rendered; the UI shows a2-13's placeholder with Try again.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FailReason {
    /// The document has no such page.
    NoSuchPage,
    /// A zoom, ratio, position or size the page's raster does not have.
    OutOfRange,
    /// PDFium could not load or render the page.
    PageDamaged,
    /// Memory for the bitmap could not be reserved.
    OutOfMemory,
    /// A bug in Ferman.
    Internal,
}

/// What a [`ViewEvent`] reports.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewEventKind {
    /// The view is open: the first event, with its `view` handle.
    Opened,
    /// A bitmap is ready: `item`, `generation`, `render_key`, the rectangle and the pixels.
    Rendered,
    /// An item could not be rendered: `item`, `generation` and `fail_reason`.
    Failed,
}

/// An event of a view's stream. The stream ends when the view closes, with its document or when
/// the stream is cancelled.
#[derive(Debug, Clone, PartialEq)]
pub struct ViewEvent {
    /// What happened.
    pub kind: ViewEventKind,
    /// The view's handle (`Opened`).
    pub view: u64,
    /// What was asked for (`Rendered`, `Failed`).
    pub item: Option<ViewItem>,
    /// The generation of the wanted set this answers.
    pub generation: u64,
    /// The page's render key when it was rendered.
    pub render_key: u64,
    /// Where the pixels sit in the page's raster, in device pixels.
    pub x: u32,
    /// See `x`.
    pub y: u32,
    /// The bitmap's width in pixels.
    pub width: u32,
    /// The bitmap's height in pixels.
    pub height: u32,
    /// Bytes per row.
    pub stride: u32,
    /// 8-bit BGRA, opaque; it reaches Dart without a copy (the Dco codec).
    pub pixels: Vec<u8>,
    /// Why it failed (`Failed`).
    pub fail_reason: Option<FailReason>,
}

/// How a search matches (a2-4a).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SearchOptions {
    /// Match case.
    pub match_case: bool,
    /// Whole words.
    pub whole_words: bool,
    /// Ignore accents and dotted/dotless i (on by default in the app, G61).
    pub ignore_accents: bool,
    /// Search the bookmarks' titles too (Look in › Bookmarks).
    pub bookmarks: bool,
}

/// A rectangle on a page in displayed points, y down.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PageRect {
    /// The left edge.
    pub left: f32,
    /// The top edge.
    pub top: f32,
    /// The right edge.
    pub right: f32,
    /// The bottom edge.
    pub bottom: f32,
}

/// One match of a search.
#[derive(Debug, Clone, PartialEq)]
pub struct SearchMatch {
    /// Its page, from 0.
    pub page: u32,
    /// One rectangle per line it covers.
    pub rects: Vec<PageRect>,
    /// The line it starts on.
    pub snippet: String,
    /// Where it starts in the snippet, in characters.
    pub snippet_start: u32,
    /// Where it ends in the snippet, in characters.
    pub snippet_end: u32,
    /// Whether it is in a bookmark's title (the snippet), with no rectangles.
    pub bookmark: bool,
}

/// What a search event says.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SearchEventKind {
    /// The search runs: `search` is its handle. The first event.
    Started,
    /// One page's `matches`.
    Matches,
    /// `searched` of `pages` pages read.
    Progress,
    /// It ended; `cancelled` says how. The last event.
    Done,
}

/// An event of a search's stream.
#[derive(Debug, Clone, PartialEq)]
pub struct SearchEvent {
    /// What happened.
    pub kind: SearchEventKind,
    /// The search's handle (`Started`).
    pub search: u64,
    /// One page's matches (`Matches`).
    pub matches: Vec<SearchMatch>,
    /// Pages read (`Progress`).
    pub searched: u32,
    /// Pages in the document (`Progress`).
    pub pages: u32,
    /// Whether it was cancelled (`Done`).
    pub cancelled: bool,
    /// Whether no page had text, a scan (`Done`).
    pub textless: bool,
}

/// A point on a page in displayed points, y down.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PagePoint {
    /// From the left edge.
    pub x: f32,
    /// From the top edge.
    pub y: f32,
}

/// How a block's lines sit in its frame.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Alignment {
    /// Flush left (the top in vertical text).
    Left,
    /// Flush right (the bottom in vertical text).
    Right,
    /// Centred.
    Center,
    /// Flush on both sides, but for the last line.
    Justified,
}

/// The direction a block's text runs in.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TextDirection {
    /// Left to right.
    LeftToRight,
    /// Right to left: Arabic, Persian, Hebrew.
    RightToLeft,
    /// Vertical columns, from the right.
    Vertical,
}

/// Why text cannot be edited (docs/ARCHITECTURE.md §6.5); the UI shows it in the tooltip and the
/// panel callout (a3-11, a3-19, G39). The facade's `TooComplex` comes as one value per cause.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NotEditableReason {
    /// The page has only images: a scan.
    ImageOnly,
    /// The glyphs have no usable Unicode mapping.
    UnknownText,
    /// The text is drawn as vector shapes.
    OutlinedText,
    /// The text is invisible, such as recognised text over a scan.
    InvisibleText,
    /// The author's permissions forbid changes until the owner password unlocks them.
    Restricted,
    /// The document is read-only (an XFA-only form).
    ReadOnly,
    /// The document was repaired or its readers disagree.
    Damaged,
    /// The text is inside a signature field.
    SignatureAppearance,
    /// The text is inside an annotation or a form field.
    AnnotationOrField,
    /// The page hit a resource limit.
    TooComplexLimits,
    /// An operator is split across two content streams.
    TooComplexSplitOperator,
    /// The text is sheared.
    TooComplexSkewed,
}

/// One line of a [`BlockInfo`].
#[derive(Debug, Clone, PartialEq)]
pub struct LineInfo {
    /// Its text in logical order.
    pub text: String,
    /// The box of its glyphs.
    pub bbox: PageRect,
    /// Its baseline's start, in visual order.
    pub baseline_start: PagePoint,
    /// Its baseline's end.
    pub baseline_end: PagePoint,
}

/// A text block (paragraph frame) of a page.
#[derive(Debug, Clone, PartialEq)]
pub struct BlockInfo {
    /// Its id, the same for the same content.
    pub id: u64,
    /// Its frame.
    pub frame: PageRect,
    /// Its lines, from the first.
    pub lines: Vec<LineInfo>,
    /// How its lines sit.
    pub alignment: Alignment,
    /// The direction its text runs in.
    pub direction: TextDirection,
    /// Why it cannot be edited; `None` when it can.
    pub not_editable: Option<NotEditableReason>,
}

/// A page's text blocks.
#[derive(Debug, Clone, PartialEq)]
pub struct PageBlocks {
    /// Its blocks in reading order.
    pub blocks: Vec<BlockInfo>,
    /// Why a page without blocks has no text: `ImageOnly` or `OutlinedText`.
    pub empty: Option<NotEditableReason>,
}

/// A caret in a block.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Caret {
    /// Its index in the block's text (lines joined by line feeds), in characters.
    pub index: u32,
    /// Its box, of no width across its line.
    pub rect: PageRect,
}

/// A caret index in one block of a page.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TextPosition {
    /// The block's id.
    pub block: u64,
    /// The caret index in its text.
    pub index: u32,
}

/// What a selection covers.
#[derive(Debug, Clone, PartialEq)]
pub struct Selection {
    /// The boxes to highlight.
    pub quads: Vec<PageRect>,
    /// Its text for copying.
    pub text: String,
}

/// Returns the API version this library speaks; the app compares it at start-up and shows an
/// error screen on a mismatch.
///
/// The only synchronous call of the API. See [`facade::api_version`].
#[flutter_rust_bridge::frb(sync)]
#[must_use]
pub fn api_version() -> ApiVersion {
    api_version_dto(facade::api_version())
}

/// Returns the versions and build facts of the running engine, including whether PDFium is
/// loaded.
///
/// See [`facade::engine_info`].
///
/// # Errors
///
/// Returns the facade's error, mirrored.
pub async fn engine_info() -> Result<EngineInfo, ApiError> {
    facade::engine_info()
        .await
        .map(engine_info_dto)
        .map_err(api_error_dto)
}

/// Panics inside the API boundary's guard (debug builds only), for the test that a Rust panic
/// reaches Dart as an error and the app keeps running.
///
/// See [`facade::debug_panic`].
///
/// # Errors
///
/// Always returns an internal error.
pub async fn debug_panic() -> Result<(), ApiError> {
    facade::debug_panic().await.map_err(api_error_dto)
}

/// Returns `len` zero bytes, at most 8 MiB, for the zero-copy benchmark of the bridge.
///
/// See [`facade::debug_bytes`].
pub async fn debug_bytes(len: u32) -> Vec<u8> {
    facade::debug_bytes(len).await
}

/// The order of `texts` in the language of `locale`, a BCP 47 tag such as `tr`: their indices,
/// first to last. Digits compare by their value and equal texts keep their order. Sorts the recent
/// files by name and location (ADR 0021).
///
/// See [`facade::collation_order`].
pub async fn collation_order(locale: String, texts: Vec<String>) -> Vec<u32> {
    facade::collation_order(&locale, &texts)
        .into_iter()
        .filter_map(|index| u32::try_from(index).ok())
        .collect()
}

/// Opens the PDF at `path`, with `password` if it is encrypted. Without the password an encrypted
/// file fails with `PasswordRequired`; open it again with the password.
///
/// See [`facade::Engine::open`].
///
/// # Errors
///
/// Returns the facade's error, mirrored.
pub async fn open(path: String, password: Option<String>) -> Result<OpenedDocument, ApiError> {
    engine()?
        .open(PathBuf::from(path), password.map(facade::Password::new))
        .await
        .map(opened_document_dto)
        .map_err(api_error_dto)
}

/// Lifts the restrictions of `document` for this session when `password` is its owner password
/// (a2-10a). Returns its security from then on, `None` when it is not encrypted.
///
/// # Errors
///
/// `WrongPassword` when it is not the owner password; `NotFound` for a document that is not open.
pub async fn unlock_owner(document: u64, password: String) -> Result<Option<Security>, ApiError> {
    engine()?
        .unlock_owner(
            facade::DocumentId::from_raw(document),
            facade::Password::new(password),
        )
        .await
        .map(|security| security.map(security_dto))
        .map_err(api_error_dto)
}

/// Saves the file attached to `document` as its `attachments[index]` at `path` (a2-3b), written
/// safely: a temp file flushed, read back and renamed over `path`. With `staging` (the macOS App
/// Sandbox's replacement directory) the verified temp file stays there and its path is returned
/// for the platform layer to swap in.
///
/// See [`facade::Engine::save_attachment`].
///
/// # Errors
///
/// `NotFound` for a document that is not open; the file errors of the write.
pub async fn save_attachment(
    document: u64,
    index: u32,
    path: String,
    staging: Option<String>,
) -> Result<Option<String>, ApiError> {
    engine()?
        .save_attachment(
            facade::DocumentId::from_raw(document),
            index,
            PathBuf::from(path),
            staging.map(PathBuf::from),
        )
        .await
        .map(|staged| staged.map(|path| path.to_string_lossy().into_owned()))
        .map_err(api_error_dto)
}

/// Closes a document and ends its views.
///
/// # Errors
///
/// `NotFound` for a document that is not open.
pub async fn close(document: u64) -> Result<(), ApiError> {
    engine()?
        .close(facade::DocumentId::from_raw(document))
        .await
        .map_err(api_error_dto)
}

/// Shows the layers of `document` whose `visible` is true and hides the others, in the order of
/// its `layers`, in every view. Returns every page's new render key: tiles and thumbnails with an
/// older one show the layers as they were.
///
/// # Errors
///
/// `InvalidInput` without one value per layer, `Unsupported` when the document's layers cannot be
/// switched (`layers_switchable`), `Internal` when the reload fails.
pub async fn show_layers(document: u64, visible: Vec<bool>) -> Result<u64, ApiError> {
    engine()?
        .show_layers(facade::DocumentId::from_raw(document), visible)
        .await
        .map_err(api_error_dto)
}

/// Opens a view of `document`: its first event is `Opened` with the view's handle, then its
/// tiles and thumbnails as [`request_view`] asks for them.
///
/// # Errors
///
/// `NotFound` for a document that is not open.
pub async fn open_view(document: u64, sink: StreamSink<ViewEvent>) -> Result<(), ApiError> {
    let opened = sink.clone();
    let view = engine()?
        .open_view(
            facade::DocumentId::from_raw(document),
            Box::new(BridgeSink(sink)),
        )
        .await
        .map_err(api_error_dto)?;
    // Nothing is rendered before the first request, which needs this handle, so it comes first.
    // A failed send means Dart cancelled the stream, which closes the view on its next event.
    let _ = opened.add(ViewEvent {
        view: view.get(),
        ..view_event(ViewEventKind::Opened)
    });
    Ok(())
}

/// Replaces what `view` wants rendered, in priority order. A `generation` no newer than the view's
/// last one is ignored.
///
/// # Errors
///
/// `InvalidInput` for a zoom bucket out of range.
pub async fn request_view(
    view: u64,
    generation: u64,
    wanted: Vec<WantedItem>,
) -> Result<(), ApiError> {
    let wanted = wanted
        .into_iter()
        .map(wanted_facade)
        .collect::<Option<Vec<_>>>()
        .ok_or_else(|| {
            api_error_dto(facade::ApiError::new(
                facade::ErrorKind::InvalidInput,
                facade::MessageKey::INTERNAL,
            ))
        })?;
    engine()?
        .request(facade::ViewId::from_raw(view), generation, wanted)
        .map_err(api_error_dto)
}

/// Closes a view; its stream ends.
///
/// # Errors
///
/// `Internal` if the render thread has stopped.
pub async fn close_view(view: u64) -> Result<(), ApiError> {
    engine()?
        .close_view(facade::ViewId::from_raw(view))
        .map_err(api_error_dto)
}

/// Searches `document` for `query`; the stream starts with `Started` and its handle, brings each
/// page's matches and the progress, and ends after `Done`. Cancelling the stream stops the
/// search at its next page with matches or progress.
///
/// # Errors
///
/// `NotFound` for a document that is not open.
pub async fn search(
    document: u64,
    query: String,
    options: SearchOptions,
    sink: StreamSink<SearchEvent>,
) -> Result<(), ApiError> {
    let bookmarks = options.bookmarks;
    let options = facade::SearchOptions {
        match_case: options.match_case,
        whole_words: options.whole_words,
        ignore_accents: options.ignore_accents,
        ..facade::SearchOptions::default()
    };
    engine()?
        .search(
            facade::DocumentId::from_raw(document),
            query,
            options,
            bookmarks,
            Box::new(BridgeSearch(sink)),
        )
        .map(drop)
        .map_err(api_error_dto)
}

/// The text blocks of `page` of `document` in reading order, with their editability.
///
/// See [`facade::Engine::text_blocks`].
///
/// # Errors
///
/// `NotFound` for a document that is not open, `InvalidInput` for a page it does not have.
pub async fn text_blocks(document: u64, page: u32) -> Result<PageBlocks, ApiError> {
    let blocks = engine()?
        .text_blocks(facade::DocumentId::from_raw(document), page)
        .await
        .map_err(api_error_dto)?;
    Ok(PageBlocks {
        blocks: blocks
            .blocks
            .into_iter()
            .map(|block| BlockInfo {
                id: block.id.0,
                frame: rect_dto(block.frame),
                lines: block
                    .lines
                    .into_iter()
                    .map(|line| LineInfo {
                        text: line.text,
                        bbox: rect_dto(line.bbox),
                        baseline_start: point_dto(line.baseline[0]),
                        baseline_end: point_dto(line.baseline[1]),
                    })
                    .collect(),
                alignment: match block.alignment {
                    facade::Alignment::Left => Alignment::Left,
                    facade::Alignment::Right => Alignment::Right,
                    facade::Alignment::Center => Alignment::Center,
                    facade::Alignment::Justified => Alignment::Justified,
                },
                direction: match block.direction {
                    facade::TextDirection::LeftToRight => TextDirection::LeftToRight,
                    facade::TextDirection::RightToLeft => TextDirection::RightToLeft,
                    facade::TextDirection::Vertical => TextDirection::Vertical,
                },
                not_editable: match block.editability {
                    facade::Editability::Editable => None,
                    facade::Editability::NotEditable(reason) => Some(reason_dto(reason)),
                },
            })
            .collect(),
        empty: blocks.empty.map(reason_dto),
    })
}

/// The caret in `block` of `page` nearest `point`.
///
/// See [`facade::Engine::caret_at`].
///
/// # Errors
///
/// `NotFound` for a document that is not open or a block the page does not have.
pub async fn caret_at(
    document: u64,
    page: u32,
    block: u64,
    point: PagePoint,
) -> Result<Caret, ApiError> {
    engine()?
        .caret_at(
            facade::DocumentId::from_raw(document),
            page,
            facade::BlockId(block),
            [point.x, point.y],
        )
        .await
        .map(|caret| Caret {
            index: caret.index,
            rect: rect_dto(caret.rect),
        })
        .map_err(api_error_dto)
}

/// What a selection from `anchor` to `focus` on `page` covers, either end first.
///
/// See [`facade::Engine::selection`].
///
/// # Errors
///
/// `NotFound` for a document that is not open or a block the page does not have.
pub async fn selection(
    document: u64,
    page: u32,
    anchor: TextPosition,
    focus: TextPosition,
) -> Result<Selection, ApiError> {
    let position = |at: TextPosition| facade::TextPosition {
        block: facade::BlockId(at.block),
        index: at.index,
    };
    engine()?
        .selection(
            facade::DocumentId::from_raw(document),
            page,
            position(anchor),
            position(focus),
        )
        .await
        .map(|selection| Selection {
            quads: selection.quads.into_iter().map(rect_dto).collect(),
            text: selection.text,
        })
        .map_err(api_error_dto)
}

/// Hands a search's events to its Dart stream.
struct BridgeSearch(StreamSink<SearchEvent>);

impl facade::SearchSink for BridgeSearch {
    fn deliver(&mut self, event: facade::SearchEvent) -> bool {
        let empty = SearchEvent {
            kind: SearchEventKind::Done,
            search: 0,
            matches: Vec::new(),
            searched: 0,
            pages: 0,
            cancelled: false,
            textless: false,
        };
        let event = match event {
            facade::SearchEvent::Started(id) => SearchEvent {
                kind: SearchEventKind::Started,
                search: id.get(),
                ..empty
            },
            facade::SearchEvent::Matches(matches) => SearchEvent {
                kind: SearchEventKind::Matches,
                matches: matches
                    .into_iter()
                    .map(|found| SearchMatch {
                        page: found.page,
                        rects: found
                            .rects
                            .into_iter()
                            .map(|[left, top, right, bottom]| PageRect {
                                left,
                                top,
                                right,
                                bottom,
                            })
                            .collect(),
                        snippet: found.snippet,
                        snippet_start: found.snippet_range.start,
                        snippet_end: found.snippet_range.end,
                        bookmark: found.bookmark,
                    })
                    .collect(),
                ..empty
            },
            facade::SearchEvent::Progress { searched, pages } => SearchEvent {
                kind: SearchEventKind::Progress,
                searched,
                pages,
                ..empty
            },
            facade::SearchEvent::Done {
                cancelled,
                textless,
            } => SearchEvent {
                cancelled,
                textless,
                ..empty
            },
        };
        self.0.add(event).is_ok()
    }
}

/// A page-space box `[left, top, right, bottom]` as its mirror.
fn rect_dto([left, top, right, bottom]: [f32; 4]) -> PageRect {
    PageRect {
        left,
        top,
        right,
        bottom,
    }
}

/// A page-space point as its mirror.
fn point_dto([x, y]: [f32; 2]) -> PagePoint {
    PagePoint { x, y }
}

/// A reason a block cannot be edited, as its mirror. The facade's enum is non-exhaustive; a
/// reason added later reads as too complex until it gets its mirror.
fn reason_dto(reason: facade::NotEditableReason) -> NotEditableReason {
    use facade::{Complexity, NotEditableReason as Reason};
    match reason {
        Reason::ImageOnly => NotEditableReason::ImageOnly,
        Reason::UnknownText => NotEditableReason::UnknownText,
        Reason::OutlinedText => NotEditableReason::OutlinedText,
        Reason::InvisibleText => NotEditableReason::InvisibleText,
        Reason::Restricted => NotEditableReason::Restricted,
        Reason::ReadOnly => NotEditableReason::ReadOnly,
        Reason::Damaged => NotEditableReason::Damaged,
        Reason::SignatureAppearance => NotEditableReason::SignatureAppearance,
        Reason::AnnotationOrField => NotEditableReason::AnnotationOrField,
        Reason::TooComplex(Complexity::SplitOperator) => NotEditableReason::TooComplexSplitOperator,
        Reason::TooComplex(Complexity::Skewed) => NotEditableReason::TooComplexSkewed,
        _ => NotEditableReason::TooComplexLimits,
    }
}

/// The process's engine, started on first use under the panic guard.
fn engine() -> Result<&'static facade::Engine, ApiError> {
    facade::guard(|| Ok(facade::Engine::global())).map_err(api_error_dto)
}

/// A view's sink: each event goes to the Dart stream; a failed send ends the view.
struct BridgeSink(StreamSink<ViewEvent>);

impl facade::ViewSink for BridgeSink {
    fn deliver(&mut self, event: facade::ViewEvent) -> bool {
        let event = match event {
            facade::ViewEvent::Rendered(rendered) => ViewEvent {
                item: Some(item_dto(rendered.item)),
                generation: rendered.generation,
                render_key: rendered.render_key,
                x: rendered.rect.x,
                y: rendered.rect.y,
                width: rendered.rect.width,
                height: rendered.rect.height,
                stride: rendered.stride,
                pixels: rendered.pixels,
                ..view_event(ViewEventKind::Rendered)
            },
            facade::ViewEvent::Failed(failed) => ViewEvent {
                item: Some(item_dto(failed.item)),
                generation: failed.generation,
                fail_reason: Some(match failed.reason {
                    facade::FailReason::NoSuchPage => FailReason::NoSuchPage,
                    facade::FailReason::OutOfRange => FailReason::OutOfRange,
                    facade::FailReason::PageDamaged => FailReason::PageDamaged,
                    facade::FailReason::OutOfMemory => FailReason::OutOfMemory,
                    facade::FailReason::Internal => FailReason::Internal,
                }),
                ..view_event(ViewEventKind::Failed)
            },
        };
        self.0.add(event).is_ok()
    }
}

/// An event of `kind` with every other field empty.
fn view_event(kind: ViewEventKind) -> ViewEvent {
    ViewEvent {
        kind,
        view: 0,
        item: None,
        generation: 0,
        render_key: 0,
        x: 0,
        y: 0,
        width: 0,
        height: 0,
        stride: 0,
        pixels: Vec::new(),
        fail_reason: None,
    }
}

fn item_dto(item: facade::Item) -> ViewItem {
    match item {
        facade::Item::Tile(tile) => ViewItem {
            kind: ItemKind::Tile,
            page: tile.page,
            zoom_bucket: tile.zoom.get(),
            device_pixel_ratio: tile.device_pixel_ratio,
            column: tile.position.column,
            row: tile.position.row,
            size: 0,
        },
        facade::Item::Thumbnail(thumbnail) => ViewItem {
            kind: ItemKind::Thumbnail,
            page: thumbnail.page,
            zoom_bucket: 0,
            device_pixel_ratio: 0.0,
            column: 0,
            row: 0,
            size: thumbnail.size,
        },
    }
}

/// The facade's wanted item, or `None` for a zoom bucket out of range. Other values out of range
/// are answered by the render thread with a `Failed` event.
fn wanted_facade(wanted: WantedItem) -> Option<facade::Wanted> {
    let item = wanted.item;
    let item = match item.kind {
        ItemKind::Tile => facade::Item::Tile(facade::TileRequest {
            page: item.page,
            zoom: facade::ZoomBucket::new(item.zoom_bucket)?,
            device_pixel_ratio: item.device_pixel_ratio,
            position: facade::TilePosition {
                column: item.column,
                row: item.row,
            },
        }),
        ItemKind::Thumbnail => facade::Item::Thumbnail(facade::ThumbnailRequest {
            page: item.page,
            size: item.size,
        }),
    };
    let priority = match wanted.priority {
        Priority::Visible => facade::Priority::Visible,
        Priority::Prefetch => facade::Priority::Prefetch,
        Priority::VisibleThumbnail => facade::Priority::VisibleThumbnail,
        Priority::Thumbnail => facade::Priority::Thumbnail,
        Priority::Background => facade::Priority::Background,
    };
    Some(facade::Wanted { item, priority })
}

fn repair_fix_dto(repair: &facade::Repair) -> Option<RepairFix> {
    let (kind, count) = match *repair {
        facade::Repair::CrossReferenceRebuilt { objects, .. } => {
            (RepairKind::CrossReferenceRebuilt, objects)
        }
        facade::Repair::TrailerRebuilt => (RepairKind::TrailerRebuilt, 0),
        facade::Repair::StreamLengthsCorrected { streams } => {
            (RepairKind::StreamLengthsCorrected, streams)
        }
        facade::Repair::ObjectsUnreadable { objects, .. } => {
            (RepairKind::ObjectsUnreadable, objects)
        }
        // A repair added later reaches the UI once it has its wording.
        _ => return None,
    };
    Some(RepairFix { kind, count })
}

fn opened_document_dto(document: facade::OpenedDocument) -> OpenedDocument {
    let repairs = match &document.read_only {
        Some(facade::ReadOnly::Repaired(report)) => {
            report.repairs.iter().filter_map(repair_fix_dto).collect()
        }
        _ => Vec::new(),
    };
    OpenedDocument {
        id: document.id.get(),
        repairs,
        read_only: document.read_only.map(|reason| match reason {
            facade::ReadOnly::Repaired(_) => ReadOnlyReason::Repaired,
            facade::ReadOnly::ParsersDisagree(_) => ReadOnlyReason::ParsersDisagree,
            facade::ReadOnly::XfaOnly => ReadOnlyReason::XfaOnly,
        }),
        right_to_left: document.direction == facade::Direction::RightToLeft,
        pages: document
            .pages
            .into_iter()
            .map(|page| PageInfo {
                width: page.size.width,
                height: page.size.height,
                label: page.label,
            })
            .collect(),
        outline: outline_dto(document.outline),
        attachments: document
            .attachments
            .into_iter()
            .map(|file| Attachment {
                name: file.name,
                size: file.size,
                modified: file.modified.or(file.created).map(pdf_date_dto),
            })
            .collect(),
        layers: document
            .layers
            .into_iter()
            .map(|layer| Layer {
                name: layer.name,
                visible: layer.visible,
                locked: layer.locked,
            })
            .collect(),
        layers_switchable: document.layers_switchable,
        signatures: document
            .signatures
            .into_iter()
            .map(|signature| Signature {
                field: signature.field,
                signed: signature.signed,
                signer: signature.signer,
                signed_at: signature.signed_at.map(pdf_date_dto),
                page: signature.page,
            })
            .collect(),
        version: document.version,
        file_size: document.file_size,
        info: DocumentInfo {
            title: document.info.title,
            author: document.info.author,
            subject: document.info.subject,
            keywords: document.info.keywords,
            creator: document.info.creator,
            producer: document.info.producer,
            created: document.info.created.map(pdf_date_dto),
            modified: document.info.modified.map(pdf_date_dto),
        },
        language: document.language,
        tagged: document.tagged,
        linearized: document.linearized,
        fonts: fonts_dto(document.fonts),
        security: document.security.map(security_dto),
        scripts: document.scripts.count,
        form_fields: document.form_fields,
        scanned: document.scanned,
    }
}

/// The fonts with their subset tags taken off, each (name, type, embedding) once, in order.
fn fonts_dto(fonts: Vec<facade::FontUse>) -> Vec<FontEntry> {
    let mut entries: Vec<FontEntry> = Vec::new();
    for font in fonts {
        let (subset, name) = subset_tag(&font.name);
        let entry = FontEntry {
            name: name.to_owned(),
            kind: match font.kind {
                facade::FontKind::Type1 => FontType::Type1,
                facade::FontKind::MultipleMaster => FontType::MultipleMaster,
                facade::FontKind::TrueType => FontType::TrueType,
                facade::FontKind::Type0 => FontType::Type0,
                facade::FontKind::Type3 => FontType::Type3,
                _ => FontType::Other,
            },
            embedded: font.embedded,
            subset,
        };
        if !entries.contains(&entry) {
            entries.push(entry);
        }
    }
    entries
}

/// Whether `name` carries a subset tag (six capital letters and `+`, ISO 32000-2 §9.6.4), and the
/// name without it.
fn subset_tag(name: &str) -> (bool, &str) {
    match name.split_once('+') {
        Some((tag, rest)) if tag.len() == 6 && tag.bytes().all(|b| b.is_ascii_uppercase()) => {
            (true, rest)
        }
        _ => (false, name),
    }
}

fn security_dto(security: facade::Security) -> Security {
    let permissions = security.permissions;
    let (method, key_bits) = match security.method {
        facade::Method::Rc4 { bits } => (EncryptionMethod::Rc4, bits),
        facade::Method::Aes128 => (EncryptionMethod::Aes128, 128),
        facade::Method::Aes256 => (EncryptionMethod::Aes256, 256),
        _ => (EncryptionMethod::Identity, 0),
    };
    Security {
        method,
        key_bits,
        user_password_required: security.user_password_required,
        permissions: DocumentPermissions {
            print: permissions.print(),
            print_high_quality: permissions.print_high_quality(),
            modify: permissions.modify(),
            annotate: permissions.annotate(),
            fill_forms: permissions.fill_forms(),
            copy: permissions.copy(),
            accessibility: permissions.extract_for_accessibility(),
            assemble: permissions.assemble(),
        },
        owner: security.owner,
        restricted: security.restricted(),
    }
}

/// The outline flattened in reading order, without recursion: its depth is the file's.
fn outline_dto(items: Vec<facade::OutlineItem>) -> Vec<OutlineEntry> {
    let mut entries = Vec::new();
    let mut stack: Vec<(u32, _)> = items.into_iter().rev().map(|item| (0, item)).collect();
    while let Some((depth, item)) = stack.pop() {
        let facade::OutlineItem {
            title,
            page,
            open,
            children,
        } = item;
        let next = depth.saturating_add(1);
        stack.extend(children.into_iter().rev().map(|child| (next, child)));
        entries.push(OutlineEntry {
            title,
            page,
            depth,
            open,
        });
    }
    entries
}

fn pdf_date_dto(date: facade::PdfDate) -> PdfDate {
    PdfDate {
        year: date.year,
        month: date.month,
        day: date.day,
        hour: date.hour,
        minute: date.minute,
    }
}

fn api_version_dto(version: facade::ApiVersion) -> ApiVersion {
    ApiVersion {
        major: version.major,
        minor: version.minor,
    }
}

fn engine_info_dto(info: facade::EngineInfo) -> EngineInfo {
    EngineInfo {
        app_version: info.app_version,
        api_version: api_version_dto(info.api_version),
        build_profile: match info.build_profile {
            facade::BuildProfile::Debug => BuildProfile::Debug,
            facade::BuildProfile::Release => BuildProfile::Release,
        },
        crates: info
            .crates
            .into_iter()
            .map(|krate| CrateVersion {
                name: krate.name,
                version: krate.version,
            })
            .collect(),
        pdfium: pdfium_status_dto(info.pdfium),
    }
}

fn pdfium_status_dto(status: facade::PdfiumStatus) -> PdfiumStatus {
    match status {
        facade::PdfiumStatus::NotLoaded => PdfiumStatus {
            state: PdfiumState::NotLoaded,
            tag: None,
            reason: None,
        },
        facade::PdfiumStatus::Loaded { tag } => PdfiumStatus {
            state: PdfiumState::Loaded,
            tag: Some(tag),
            reason: None,
        },
        facade::PdfiumStatus::Failed { reason } => PdfiumStatus {
            state: PdfiumState::Failed,
            tag: None,
            reason: Some(reason),
        },
    }
}

fn api_error_dto(err: facade::ApiError) -> ApiError {
    ApiError {
        kind: match err.kind {
            facade::ErrorKind::InvalidInput => ErrorKind::InvalidInput,
            facade::ErrorKind::NotFound => ErrorKind::NotFound,
            facade::ErrorKind::PermissionDenied => ErrorKind::PermissionDenied,
            facade::ErrorKind::PasswordRequired => ErrorKind::PasswordRequired,
            facade::ErrorKind::WrongPassword => ErrorKind::WrongPassword,
            facade::ErrorKind::Damaged => ErrorKind::Damaged,
            facade::ErrorKind::Unsupported => ErrorKind::Unsupported,
            facade::ErrorKind::ResourceLimit => ErrorKind::ResourceLimit,
            facade::ErrorKind::Io => ErrorKind::Io,
            facade::ErrorKind::Internal => ErrorKind::Internal,
        },
        message_key: err.message_key.as_str().to_owned(),
        details: err.details,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_subset_tag_is_six_capitals_and_a_plus() {
        assert_eq!(subset_tag("ABCDEF+PlexSans"), (true, "PlexSans"));
        assert_eq!(subset_tag("PlexSans"), (false, "PlexSans"));
        assert_eq!(subset_tag("ABCDEf+PlexSans"), (false, "ABCDEf+PlexSans"));
        assert_eq!(subset_tag("ABC+Plex"), (false, "ABC+Plex"));
    }
    use crate::facade::block_on;

    #[test]
    fn view_items_cross_both_ways() {
        let tile = facade::Item::Tile(facade::TileRequest {
            page: 2,
            zoom: facade::ZoomBucket::new(-3).unwrap(),
            device_pixel_ratio: 2.0,
            position: facade::TilePosition { column: 1, row: 4 },
        });
        let thumbnail = facade::Item::Thumbnail(facade::ThumbnailRequest { page: 0, size: 128 });
        for item in [tile, thumbnail] {
            let wanted = WantedItem {
                item: item_dto(item),
                priority: Priority::Prefetch,
            };
            let back = wanted_facade(wanted).unwrap();
            assert_eq!(back.item, item);
            assert_eq!(back.priority, facade::Priority::Prefetch);
        }
    }

    #[test]
    fn a_zoom_bucket_out_of_range_is_invalid_input() {
        let mut item = item_dto(facade::Item::Thumbnail(facade::ThumbnailRequest {
            page: 0,
            size: 64,
        }));
        item.kind = ItemKind::Tile;
        item.zoom_bucket = 99;
        let wanted = WantedItem {
            item,
            priority: Priority::Visible,
        };
        assert!(wanted_facade(wanted).is_none());
        let err = block_on(request_view(1, 1, vec![wanted])).unwrap_err();
        assert_eq!(err.kind, ErrorKind::InvalidInput);
    }

    #[test]
    fn a_stale_document_is_not_found() {
        let err = block_on(close(u64::MAX)).unwrap_err();
        assert_eq!(err.kind, ErrorKind::NotFound);
    }

    #[test]
    fn every_repair_crosses_with_its_count() {
        let repairs = [
            facade::Repair::CrossReferenceRebuilt {
                objects: 48,
                problem: facade::XrefProblem::NoStartxref,
            },
            facade::Repair::TrailerRebuilt,
            facade::Repair::StreamLengthsCorrected { streams: 2 },
            facade::Repair::ObjectsUnreadable {
                objects: 3,
                first: 7,
            },
        ];
        let fixes: Vec<_> = repairs.iter().filter_map(repair_fix_dto).collect();
        let fix = |kind, count| RepairFix { kind, count };
        assert_eq!(
            fixes,
            [
                fix(RepairKind::CrossReferenceRebuilt, 48),
                fix(RepairKind::TrailerRebuilt, 0),
                fix(RepairKind::StreamLengthsCorrected, 2),
                fix(RepairKind::ObjectsUnreadable, 3),
            ]
        );
    }

    #[test]
    fn api_version_mirrors_the_facade() {
        let version = api_version();
        assert_eq!(version.major, facade::API_VERSION.major);
        assert_eq!(version.minor, facade::API_VERSION.minor);
    }

    #[test]
    fn engine_info_mirrors_the_facade() {
        let info = block_on(engine_info()).unwrap();
        let expected = engine_info_dto(block_on(facade::engine_info()).unwrap());
        assert_eq!(info, expected);
        assert_eq!(info.crates.len(), 6);
    }

    #[test]
    fn pdfium_statuses_become_a_state_and_optional_fields() {
        assert_eq!(
            pdfium_status_dto(facade::PdfiumStatus::NotLoaded),
            PdfiumStatus {
                state: PdfiumState::NotLoaded,
                tag: None,
                reason: None
            }
        );
        assert_eq!(
            pdfium_status_dto(facade::PdfiumStatus::Loaded {
                tag: "chromium/7881".to_owned()
            }),
            PdfiumStatus {
                state: PdfiumState::Loaded,
                tag: Some("chromium/7881".to_owned()),
                reason: None
            }
        );
        assert_eq!(
            pdfium_status_dto(facade::PdfiumStatus::Failed {
                reason: "dlopen failed".to_owned()
            }),
            PdfiumStatus {
                state: PdfiumState::Failed,
                tag: None,
                reason: Some("dlopen failed".to_owned())
            }
        );
    }

    #[test]
    fn errors_carry_the_message_key_as_a_string() {
        let err = api_error_dto(facade::ApiError::internal("no trailer"));
        assert_eq!(
            err,
            ApiError {
                kind: ErrorKind::Internal,
                message_key: "errorInternal".to_owned(),
                details: Some("no trailer".to_owned()),
            }
        );
        assert_eq!(
            api_error_dto(facade::ApiError::new(
                facade::ErrorKind::NotFound,
                facade::MessageKey::INTERNAL
            ))
            .kind,
            ErrorKind::NotFound
        );
    }

    #[test]
    fn a_debug_panic_reaches_the_caller_as_an_internal_error() {
        let err = block_on(debug_panic()).unwrap_err();
        assert_eq!(err.kind, ErrorKind::Internal);
        assert_eq!(err.message_key, "errorInternal");
    }

    #[test]
    fn debug_bytes_is_capped() {
        assert_eq!(block_on(debug_bytes(16)).len(), 16);
        assert_eq!(block_on(debug_bytes(u32::MAX)).len(), 8 * 1024 * 1024);
    }
}
