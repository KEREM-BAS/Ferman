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
    /// Signature fields.
    pub signatures: Vec<Signature>,
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

fn opened_document_dto(document: facade::OpenedDocument) -> OpenedDocument {
    OpenedDocument {
        id: document.id.get(),
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
