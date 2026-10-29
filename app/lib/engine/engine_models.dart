/// App-side views of what the engine reports. Feature code uses these, never
/// the generated bridge types (`app/lib/bridge/`), so only `app/lib/engine/`
/// depends on the bridge (ARCHITECTURE §3, ADR 0003).
library;

import 'package:flutter/foundation.dart';

/// The API version the app was built against. The engine must report the
/// same major version at start-up (ARCHITECTURE §3.8).
const EngineApiVersion kAppApiVersion = EngineApiVersion(major: 0, minor: 1);

/// The version of the API between the engine and the UI.
@immutable
class EngineApiVersion {
  /// Creates a version.
  const new({required this.major, required this.minor});

  /// Incremented on a breaking change.
  final int major;

  /// Incremented on a compatible addition.
  final int minor;

  /// Whether an app built for this version can talk to an engine that
  /// reports [engine]: same major version, and the engine at least as new.
  bool acceptsEngine(EngineApiVersion engine) =>
      engine.major == major && engine.minor >= minor;

  @override
  bool operator ==(Object other) =>
      other is EngineApiVersion && other.major == major && other.minor == minor;

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => '$major.$minor';
}

/// Whether PDFium, the page rasteriser, is loaded.
enum PdfiumState {
  /// No library was found or loading was not attempted.
  notLoaded,

  /// The library is bound and a real PDFium call succeeded.
  loaded,

  /// Loading failed; [EngineStatus.pdfiumReason] says why.
  failed,
}

/// Versions and build facts of the running engine.
@immutable
class EngineStatus {
  /// Creates a status.
  const new({
    required this.appVersion,
    required this.apiVersion,
    required this.isDebugBuild,
    required this.pdfium,
    this.pdfiumTag,
    this.pdfiumReason,
  });

  /// The engine's version, such as `0.1.0`.
  final String appVersion;

  /// The API version the engine speaks.
  final EngineApiVersion apiVersion;

  /// Whether the engine library was built with debug assertions.
  final bool isDebugBuild;

  /// Whether PDFium is loaded.
  final PdfiumState pdfium;

  /// The PDFium build tag when [pdfium] is [PdfiumState.loaded], such as
  /// `chromium/7881`.
  final String? pdfiumTag;

  /// Why loading failed when [pdfium] is [PdfiumState.failed]. Never holds a
  /// file path.
  final String? pdfiumReason;
}

/// What kind of failure an [EngineException] reports. The UI maps each kind
/// to a design state (ARCHITECTURE §8.2).
enum EngineErrorKind {
  /// The app passed a value the engine cannot accept.
  invalidInput,

  /// A file or handle does not exist (any more).
  notFound,

  /// The system does not let Ferman read the file (a1-9d).
  permissionDenied,

  /// The document is encrypted and its password is needed (a1-8).
  passwordRequired,

  /// The password does not open the document (a1-8b).
  wrongPassword,

  /// The file is damaged beyond repair (a1-9b).
  damaged,

  /// Not a PDF, or something Ferman does not support yet (a1-9c, a1-9b).
  unsupported,

  /// A resource limit stopped the work, or memory ran short (a1-9f).
  resourceLimit,

  /// Reading or writing failed for a reason without its own kind.
  io,

  /// A bug in Ferman, including a caught panic.
  internal,
}

/// An error the engine returned. [messageKey] names the ARB string the UI
/// shows; [details] holds structural facts only.
@immutable
class EngineException implements Exception {
  /// Creates an exception.
  const new({
    required this.messageKey,
    this.details,
    this.kind = EngineErrorKind.internal,
  });

  /// What kind of failure this is.
  final EngineErrorKind kind;

  /// The ARB key of the message to show, such as `errorInternal`.
  final String messageKey;

  /// Technical details for "Copy technical details".
  final String? details;

  @override
  String toString() =>
      'EngineException($messageKey${details == null ? '' : ': $details'})';
}

/// Why a document opened read-only (ARCHITECTURE §5.2).
enum ReadOnlyReason {
  /// Ferman repaired it (a1-9), or could not read some of its objects.
  repaired,

  /// The two parsers see different pages (G102).
  parsersDisagree,

  /// An XFA-only form (a11-7c).
  xfaOnly,
}

/// One page of an [OpenedDocument], in points as displayed.
@immutable
class PageInfo {
  /// Creates a page.
  const new({required this.width, required this.height, this.label});

  /// The width, after the crop box and the page's rotation.
  final double width;

  /// The height, after the crop box and the page's rotation.
  final double height;

  /// The page label, such as "iv", when the document has labels.
  final String? label;
}

/// One outline item (bookmark) of an [OpenedDocument].
@immutable
class OutlineEntry {
  /// Creates an item.
  const new({
    required this.title,
    this.page,
    this.depth = 0,
    this.open = false,
  });

  /// Its title.
  final String title;

  /// The page it goes to, from 0, when it goes to a page of this document.
  final int? page;

  /// Its nesting, from 0.
  final int depth;

  /// Whether the document shows it open.
  final bool open;
}

/// An embedded file of an [OpenedDocument] (a2-3b), never opened
/// automatically.
@immutable
class Attachment {
  /// Creates an attachment.
  const new({required this.name, this.size, this.modified});

  /// Its file name.
  final String name;

  /// Its size in bytes, when the file gives it.
  final int? size;

  /// When it was last changed, or else created, as the file writes it.
  final DateTime? modified;
}

/// A layer (optional content group) of an [OpenedDocument] (a2-3c).
@immutable
class Layer {
  /// Creates a layer.
  const new({required this.name, this.visible = true, this.locked = false});

  /// Its name.
  final String name;

  /// Whether the document shows it.
  final bool visible;

  /// Whether the document locks its visibility.
  final bool locked;
}

/// A signature field of an [OpenedDocument] (a2-14).
@immutable
class Signature {
  /// Creates a signature field.
  const new({
    required this.field,
    this.signed = false,
    this.signer,
    this.signedAt,
    this.page,
  });

  /// The field's full name.
  final String field;

  /// Whether it holds a signature.
  final bool signed;

  /// The signer's name as the signature writes it.
  final String? signer;

  /// When it was signed, as the signature writes it.
  final DateTime? signedAt;

  /// The page of its widget, from 0.
  final int? page;
}

/// A document the engine opened.
@immutable
class OpenedDocument {
  /// Creates a document.
  const new({
    required this.id,
    required this.pages,
    this.readOnly,
    this.rightToLeft = false,
    this.outline = const [],
    this.attachments = const [],
    this.layers = const [],
    this.layersSwitchable = false,
    this.signatures = const [],
  });

  /// Its handle, until it is closed.
  final int id;

  /// Its pages.
  final List<PageInfo> pages;

  /// Why it opened read-only, if it did.
  final ReadOnlyReason? readOnly;

  /// Whether spreads run right to left (`/Direction /R2L`).
  final bool rightToLeft;

  /// The outline in reading order, each item followed by its children.
  final List<OutlineEntry> outline;

  /// Its embedded files.
  final List<Attachment> attachments;

  /// Its layers, in the order the document gives them.
  final List<Layer> layers;

  /// Whether `EngineService.showLayers` can show and hide them: not for a
  /// repaired document, or one that needed a password (Q22).
  final bool layersSwitchable;

  /// Its signature fields.
  final List<Signature> signatures;
}

/// Something a view wants rendered: a [TileItem] or a [ThumbnailItem].
@immutable
sealed class RenderItem {
  const new({required this.page});

  /// The page, from 0.
  final int page;
}

/// A 512-pixel tile of a page, on the grid of its raster at [zoomBucket]
/// (the logical zoom is 2^(bucket / 4)) and [devicePixelRatio].
final class TileItem extends RenderItem {
  /// Creates a tile.
  const new({
    required super.page,
    required this.zoomBucket,
    required this.devicePixelRatio,
    required this.column,
    required this.row,
  });

  /// The quarter-octave zoom bucket, -16 to 28.
  final int zoomBucket;

  /// The device pixel ratio, 0.5 to 4.
  final double devicePixelRatio;

  /// The column on the grid.
  final int column;

  /// The row on the grid.
  final int row;

  @override
  bool operator ==(Object other) =>
      other is TileItem &&
      other.page == page &&
      other.zoomBucket == zoomBucket &&
      other.devicePixelRatio == devicePixelRatio &&
      other.column == column &&
      other.row == row;

  @override
  int get hashCode =>
      Object.hash(page, zoomBucket, devicePixelRatio, column, row);
}

/// The whole page fitted into a square of [size] device pixels.
final class ThumbnailItem extends RenderItem {
  /// Creates a thumbnail.
  const new({required super.page, required this.size});

  /// The side of the square, 16 to 1,024.
  final int size;

  @override
  bool operator ==(Object other) =>
      other is ThumbnailItem && other.page == page && other.size == size;

  @override
  int get hashCode => Object.hash(page, size);
}

/// How urgent a wanted item is, highest first (ARCHITECTURE §4.5).
enum RenderPriority {
  /// Tiles on screen, nearest the viewport centre first.
  visible,

  /// Tiles just off screen.
  prefetch,

  /// Thumbnails on screen.
  visibleThumbnail,

  /// Other thumbnails.
  thumbnail,

  /// Background work.
  background,
}

/// One entry of a view's wanted set.
@immutable
class WantedItem {
  /// Creates an entry.
  const new(this.item, this.priority);

  /// What to render.
  final RenderItem item;

  /// How urgent it is.
  final RenderPriority priority;
}

/// Why an item was not rendered; the UI shows a2-13's placeholder.
enum RenderFailure {
  /// The document has no such page.
  noSuchPage,

  /// A zoom, ratio, position or size the page's raster does not have.
  outOfRange,

  /// PDFium could not load or render the page.
  pageDamaged,

  /// Memory for the bitmap could not be reserved.
  outOfMemory,

  /// A bug in Ferman.
  internal,
}

/// What a view receives for an item it wanted.
@immutable
sealed class ViewUpdate {
  const new({required this.item, required this.generation});

  /// What was asked for.
  final RenderItem item;

  /// The generation of the wanted set this answers.
  final int generation;
}

/// A rendered tile or thumbnail.
final class RenderedItem extends ViewUpdate {
  /// Creates a rendered item.
  const new({
    required super.item,
    required super.generation,
    required this.renderKey,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.stride,
    required this.pixels,
  });

  /// The page's render key: keep the newest per page and drop older ones,
  /// so a page never flips back to an old revision.
  final int renderKey;

  /// Where the pixels sit in the page's raster, in device pixels.
  final int x;

  /// See [x].
  final int y;

  /// The bitmap's width in pixels.
  final int width;

  /// The bitmap's height in pixels.
  final int height;

  /// Bytes per row.
  final int stride;

  /// 8-bit BGRA, opaque.
  final Uint8List pixels;
}

/// An item the engine could not render.
final class FailedItem extends ViewUpdate {
  /// Creates a failure.
  const new({
    required super.item,
    required super.generation,
    required this.reason,
  });

  /// Why it failed.
  final RenderFailure reason;
}

/// An open view of a document (the canvas, the thumbnail strip). [updates]
/// ends when the view closes, also when its document closes.
@immutable
class EngineView {
  /// Creates a view.
  const new({required this.id, required this.updates});

  /// Its handle, for `requestView` and `closeView`.
  final int id;

  /// Its rendered and failed items.
  final Stream<ViewUpdate> updates;
}
