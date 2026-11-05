/// App-side views of what the engine reports. Feature code uses these, never
/// the generated bridge types (`app/lib/bridge/`), so only `app/lib/engine/`
/// depends on the bridge (ARCHITECTURE §3, ADR 0003).
library;

import 'dart:ui' show Offset, Rect;

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

  /// The text or the document cannot be edited; the message key names the
  /// reason (ARCHITECTURE §6.5).
  notEditable,

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

/// What a [RepairFix] repaired.
enum RepairKind {
  /// The cross-reference table was rebuilt from the objects found.
  crossReferenceRebuilt,

  /// The trailer was missing; the catalog was found among the objects.
  trailerRebuilt,

  /// Streams with a wrong length were read up to their end.
  streamLengthsCorrected,

  /// Objects the cross-reference data names could not be read.
  objectsUnreadable,
}

/// One thing repair did, for a1-9's "What Ferman repaired".
@immutable
class RepairFix {
  /// Creates a fix.
  const new({required this.kind, this.count = 0});

  /// What was repaired.
  final RepairKind kind;

  /// The objects found, the streams corrected or the objects that could
  /// not be read; 0 for [RepairKind.trailerRebuilt].
  final int count;
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

/// The Info dictionary of an [OpenedDocument] (a2-7's Summary).
@immutable
class DocumentInfo {
  /// Creates the facts.
  const new({
    this.title,
    this.author,
    this.subject,
    this.keywords,
    this.creator,
    this.producer,
    this.created,
    this.modified,
  });

  /// `/Title`.
  final String? title;

  /// `/Author`.
  final String? author;

  /// `/Subject`.
  final String? subject;

  /// `/Keywords`.
  final String? keywords;

  /// `/Creator`: the application that made the original.
  final String? creator;

  /// `/Producer`: the application that wrote the PDF.
  final String? producer;

  /// `/CreationDate`, as the file writes it.
  final DateTime? created;

  /// `/ModDate`, as the file writes it.
  final DateTime? modified;
}

/// A font's type (a2-7's Type column).
enum FontType {
  /// Type 1.
  type1,

  /// Multiple Master Type 1.
  multipleMaster,

  /// TrueType.
  trueType,

  /// A composite font (Type 0), usually CID-keyed.
  type0,

  /// Type 3, drawn by content streams.
  type3,

  /// Anything else.
  other,
}

/// A font an [OpenedDocument] uses (a2-7's fonts table).
@immutable
class FontEntry {
  /// Creates a font.
  const new({
    required this.name,
    this.kind = FontType.other,
    this.embedded = false,
    this.subset = false,
  });

  /// Its name, without a subset's `ABCDEF+` tag.
  final String name;

  /// Its type.
  final FontType kind;

  /// Whether its program is in the file.
  final bool embedded;

  /// Whether only the characters the file uses are embedded.
  final bool subset;
}

/// How an encrypted document is encrypted.
enum EncryptionMethod {
  /// RC4, with [Security.keyBits].
  rc4,

  /// AES-128.
  aes128,

  /// AES-256.
  aes256,

  /// Encrypted only in name.
  identity,
}

/// What an encrypted document allows without its owner password
/// (a2-10b's rows).
@immutable
class DocumentPermissions {
  /// Creates the permissions; all allowed by default.
  const new({
    this.print = true,
    this.printHighQuality = true,
    this.modify = true,
    this.annotate = true,
    this.fillForms = true,
    this.copy = true,
    this.accessibility = true,
    this.assemble = true,
  });

  /// Printing.
  final bool print;

  /// Printing at full quality.
  final bool printHighQuality;

  /// Changing the document.
  final bool modify;

  /// Adding comments.
  final bool annotate;

  /// Filling form fields, signature fields included.
  final bool fillForms;

  /// Copying text and images.
  final bool copy;

  /// Text access for screen readers.
  final bool accessibility;

  /// Assembling pages.
  final bool assemble;
}

/// The encryption of an [OpenedDocument] (a2-7's Security, a2-10).
@immutable
class Security {
  /// Creates the facts.
  const new({
    required this.method,
    this.keyBits = 0,
    this.userPasswordRequired = false,
    this.permissions = const DocumentPermissions(),
    this.owner = false,
    this.restricted = false,
  });

  /// How it is encrypted.
  final EncryptionMethod method;

  /// The key length in bits: RC4's 40 to 128, 128 or 256 for AES, 0 for
  /// none.
  final int keyBits;

  /// Whether opening it needs a password.
  final bool userPasswordRequired;

  /// What the file allows without its owner password.
  final DocumentPermissions permissions;

  /// Whether its owner password was given, which lifts the restrictions
  /// for the session.
  final bool owner;

  /// Whether the restrictions apply now.
  final bool restricted;
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
    this.repairs = const [],
    this.rightToLeft = false,
    this.outline = const [],
    this.attachments = const [],
    this.layers = const [],
    this.layersSwitchable = false,
    this.signatures = const [],
    this.version = '',
    this.fileSize = 0,
    this.info = const DocumentInfo(),
    this.language,
    this.tagged = false,
    this.linearized = false,
    this.fonts = const [],
    this.security,
    this.scripts = 0,
    this.formFields = 0,
    this.scanned = false,
  });

  /// Its handle, until it is closed.
  final int id;

  /// Its pages.
  final List<PageInfo> pages;

  /// Why it opened read-only, if it did.
  final ReadOnlyReason? readOnly;

  /// What repair did, in order; empty unless [readOnly] is
  /// [ReadOnlyReason.repaired].
  final List<RepairFix> repairs;

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

  /// Its PDF version, such as `"1.7"`.
  final String version;

  /// The file's size in bytes.
  final int fileSize;

  /// Its Info dictionary.
  final DocumentInfo info;

  /// Its language (`/Lang`), if it gives one.
  final String? language;

  /// Whether it is tagged (`/MarkInfo /Marked`).
  final bool tagged;

  /// Whether it is linearized for fast web view.
  final bool linearized;

  /// The fonts it uses, each once.
  final List<FontEntry> fonts;

  /// Its encryption; null when it is not encrypted.
  final Security? security;

  /// How many scripts it carries, which Ferman never runs (G100).
  final int scripts;

  /// How many form fields it has (the start screen's Form badge).
  final int formFields;

  /// Whether its first page has no text, most likely a scan (the start
  /// screen's Scanned badge).
  final bool scanned;

  /// This document with [security], as the owner unlock leaves it.
  OpenedDocument withSecurity(Security? security) => OpenedDocument(
    id: id,
    pages: pages,
    readOnly: readOnly,
    repairs: repairs,
    rightToLeft: rightToLeft,
    outline: outline,
    attachments: attachments,
    layers: layers,
    layersSwitchable: layersSwitchable,
    signatures: signatures,
    version: version,
    fileSize: fileSize,
    info: info,
    language: language,
    tagged: tagged,
    linearized: linearized,
    fonts: fonts,
    security: security,
    scripts: scripts,
    formFields: formFields,
    scanned: scanned,
  );
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

/// How a search matches (a2-4a).
@immutable
class SearchOptions {
  /// The defaults: Ignore accents and dotted/dotless i is on for every
  /// document (G61).
  const new({
    this.matchCase = false,
    this.wholeWords = false,
    this.ignoreAccents = true,
    this.bookmarks = false,
  });

  /// Match case.
  final bool matchCase;

  /// Whole words.
  final bool wholeWords;

  /// Ignore accents and dotted/dotless i.
  final bool ignoreAccents;

  /// Look in the bookmarks' titles too (a2-4a, B114).
  final bool bookmarks;

  @override
  bool operator ==(Object other) =>
      other is SearchOptions &&
      other.matchCase == matchCase &&
      other.wholeWords == wholeWords &&
      other.ignoreAccents == ignoreAccents &&
      other.bookmarks == bookmarks;

  @override
  int get hashCode =>
      Object.hash(matchCase, wholeWords, ignoreAccents, bookmarks);
}

/// One match of a search.
@immutable
class SearchMatch {
  /// Creates a match.
  const new({
    required this.page,
    required this.rects,
    required this.snippet,
    required this.snippetStart,
    required this.snippetEnd,
    this.bookmark = false,
  });

  /// Its page, from 0.
  final int page;

  /// One rectangle per line it covers, in the page's displayed points
  /// (y down).
  final List<Rect> rects;

  /// The line it starts on.
  final String snippet;

  /// Where it starts in [snippet], in UTF-16 code units.
  final int snippetStart;

  /// Where it ends in [snippet], in UTF-16 code units.
  final int snippetEnd;

  /// Whether it is in a bookmark's title, [snippet], pointing at [page];
  /// it has no [rects].
  final bool bookmark;
}

/// What a running search reports.
@immutable
sealed class SearchUpdate {
  const new();
}

/// The matches of one page.
final class SearchMatches extends SearchUpdate {
  /// Creates the update.
  const new(this.matches);

  /// The page's matches, in order.
  final List<SearchMatch> matches;
}

/// How far the search has read (a2-4c).
final class SearchProgress extends SearchUpdate {
  /// Creates the update.
  const new({required this.searched, required this.pages});

  /// Pages read.
  final int searched;

  /// Pages in the document.
  final int pages;
}

/// The search ended.
final class SearchDone extends SearchUpdate {
  /// Creates the update.
  const new({this.cancelled = false, this.textless = false});

  /// Whether it was cancelled.
  final bool cancelled;

  /// Whether no page had text: a scan without a text layer (a2-3m).
  final bool textless;
}

/// Why text cannot be edited (ARCHITECTURE §6.5); the canvas's tooltip
/// and the Edit panel's callout say so (a3-11, a3-19, G39).
enum NotEditableReason {
  /// The page has only images: a scan (a3-11).
  imageOnly,

  /// The glyphs have no usable Unicode mapping.
  unknownText,

  /// The text is drawn as vector shapes (a3-19).
  outlinedText,

  /// The text is invisible, such as recognised text over a scan.
  invisibleText,

  /// The author's permissions forbid changes until the owner password
  /// unlocks them (G27).
  restricted,

  /// The document is read-only (an XFA-only form).
  readOnly,

  /// The document was repaired or its readers disagree.
  damaged,

  /// The text is inside a signature field.
  signatureAppearance,

  /// The text is inside an annotation or a form field.
  annotationOrField,

  /// The page hit a resource limit.
  tooComplexLimits,

  /// An operator is split across two content streams.
  tooComplexSplitOperator,

  /// The text is sheared.
  tooComplexSkewed;

  /// The ARB key of the Edit panel's callout for this reason, the message
  /// key of the engine's [EngineErrorKind.notEditable] error (a3-19).
  String get messageKey => switch (this) {
    imageOnly => 'editBodyImageOnly',
    unknownText => 'editBodyUnknownText',
    outlinedText => 'editBodyOutlinedText',
    invisibleText => 'editBodyInvisibleText',
    restricted => 'editBodyRestricted',
    readOnly => 'editBodyReadOnly',
    damaged => 'editBodyDamaged',
    signatureAppearance => 'editBodySignature',
    annotationOrField => 'editBodyAnnotation',
    tooComplexLimits => 'editBodyLimits',
    tooComplexSplitOperator => 'editBodySplit',
    tooComplexSkewed => 'editBodySkewed',
  };
}

/// How a block's lines sit in its frame.
enum BlockAlignment {
  /// Flush left.
  left,

  /// Flush right.
  right,

  /// Centred.
  center,

  /// Flush on both sides, but for the last line.
  justified,
}

/// The direction a block's text runs in.
enum BlockDirection {
  /// Left to right.
  leftToRight,

  /// Right to left.
  rightToLeft,

  /// Vertical columns, from the right.
  vertical,
}

/// One line of a [TextBlock].
@immutable
class TextLine {
  /// Creates a line.
  const new({
    required this.text,
    required this.bbox,
    required this.baselineStart,
    required this.baselineEnd,
  });

  /// Its text in logical order.
  final String text;

  /// The box of its glyphs, in the page's displayed points (y down).
  final Rect bbox;

  /// Its baseline's start, in visual order.
  final Offset baselineStart;

  /// Its baseline's end.
  final Offset baselineEnd;
}

/// A text block (paragraph frame) of a page (ARCHITECTURE §3.5).
@immutable
class TextBlock {
  /// Creates a block.
  const new({
    required this.id,
    required this.frame,
    required this.lines,
    this.alignment = BlockAlignment.left,
    this.direction = BlockDirection.leftToRight,
    this.notEditable,
  });

  /// Its id on its page.
  final int id;

  /// Its frame, in the page's displayed points (y down).
  final Rect frame;

  /// Its lines, from the first.
  final List<TextLine> lines;

  /// How its lines sit.
  final BlockAlignment alignment;

  /// The direction its text runs in.
  final BlockDirection direction;

  /// Why it cannot be edited; null when it can.
  final NotEditableReason? notEditable;

  /// Its text: the lines joined by line feeds.
  String get text => lines.map((line) => line.text).join('\n');
}

/// A page's text blocks.
@immutable
class PageBlocks {
  /// Creates the blocks of a page.
  const new({this.blocks = const [], this.empty});

  /// Its blocks in reading order.
  final List<TextBlock> blocks;

  /// Why a page without blocks has no text to edit:
  /// [NotEditableReason.imageOnly] or [NotEditableReason.outlinedText].
  final NotEditableReason? empty;
}

/// A caret in a block.
@immutable
class BlockCaret {
  /// Creates a caret.
  const new({required this.index, required this.rect});

  /// Its index in the block's [TextBlock.text], in characters (code
  /// points).
  final int index;

  /// Its box, of no width across its line, in the page's displayed points.
  final Rect rect;
}

/// A caret index in one block of a page.
@immutable
class BlockPosition {
  /// Creates a position.
  const new({required this.block, required this.index});

  /// The block's [TextBlock.id].
  final int block;

  /// The caret index in its text, in characters (code points).
  final int index;

  @override
  bool operator ==(Object other) =>
      other is BlockPosition && other.block == block && other.index == index;

  @override
  int get hashCode => Object.hash(block, index);
}

/// What a selection on a page covers.
@immutable
class PageSelection {
  /// Creates a selection.
  const new({this.page = 0, this.quads = const [], this.text = ''});

  /// Its page, from 0. The engine's reply leaves it 0; the canvas sets it.
  final int page;

  /// The boxes to highlight, in the page's displayed points.
  final List<Rect> quads;

  /// Its text for copying.
  final String text;
}

/// What a block's page would read after an edit is applied
/// (ARCHITECTURE §3.6); the preview is not on the undo stack.
@immutable
class EditPreview {
  /// Creates a preview.
  const new({
    required this.page,
    this.missing = const [],
    this.glyphs,
    this.substitutions = const [],
    this.overflowing = false,
    this.overflow,
    this.chosen,
    this.dependents = const [],
  });

  /// The page's blocks with the new text, or with the text before when
  /// characters are [missing].
  final PageBlocks page;

  /// The characters no font could draw, in the order they first appear: the
  /// text was not applied, and [glyphs] says why (ARCHITECTURE §6.7).
  final List<String> missing;

  /// Missing-glyph step 3: the characters, why the same font did not draw
  /// them and the candidates (a3-3a, a3-3b). Drawn provisionally in the
  /// closest candidate until `chooseFont` or `keepAsIs` when
  /// [MissingGlyphs.drawn], else not drawn (they are in [missing]).
  final MissingGlyphs? glyphs;

  /// The substitutions the applied text makes (steps 2 and 3).
  final List<FontSubstitution> substitutions;

  /// Whether a line of a left-aligned block rewritten line by line runs past
  /// its frame.
  final bool overflowing;

  /// The overflow choices, when the text needs more lines than the block's
  /// frame holds (a3-4, ARCHITECTURE §6.8).
  final OverflowPlan? overflow;

  /// The choice the preview shows and a commit keeps: [OverflowChoice.keep]
  /// until `resolveOverflow` picks another.
  final OverflowChoice? chosen;

  /// The table cells whose values likely depend on the edited one (a3-9):
  /// tinted, with "Totals don't update"; the engine never changes them.
  final List<DependentCell> dependents;
}

/// Where a font comes from: the groups of the a3-3b picker.
enum FontOrigin {
  /// Embedded in this document.
  embedded,

  /// Installed on this computer.
  installed,

  /// Included with Ferman.
  bundled,
}

/// A font's embedding permission (`OS/2.fsType`, ADR 0006).
enum FontEmbedding {
  /// Installable embedding.
  installable,

  /// Editable embedding.
  editable,

  /// Preview and print only: never used for new text.
  previewAndPrint,

  /// Restricted licence: never embedded.
  restricted,

  /// The whole font only, no subset.
  noSubsetting,

  /// Bitmaps only.
  bitmapOnly,
}

/// Why the same font did not draw the missing characters (step 2, G37).
enum MissingReason {
  /// The same font is neither installed nor included with Ferman.
  notInstalled,

  /// The same font is installed, but its licence forbids embedding it.
  notEmbeddable,

  /// The document's own font allows at most preview and print, so its
  /// glyphs are not reused for new text.
  restricted,
}

/// A character missing-glyph step 3 draws.
@immutable
class MissingChar {
  /// Creates the character.
  const new({required this.text, required this.at});

  /// The character.
  final String text;

  /// Its offset in the new text, in UTF-16 code units.
  final int at;
}

/// A font step 3 offers (a3-3b).
@immutable
class FontCandidate {
  /// Creates a candidate.
  const new({
    required this.origin,
    required this.postscriptName,
    required this.family,
    required this.covered,
    required this.needed,
    this.similarity = 1,
    this.embedding = FontEmbedding.installable,
    this.usable = true,
    this.preview = '',
  });

  /// Its group.
  final FontOrigin origin;

  /// Its PostScript name, which `chooseFont` takes back.
  final String postscriptName;

  /// Its family, for the picker's row.
  final String family;

  /// How many of the missing characters it has, of [needed].
  final int covered;

  /// How many characters are missing.
  final int needed;

  /// How close its metrics are to the original's, 0 to 1.
  final double similarity;

  /// Its permission.
  final FontEmbedding embedding;

  /// Whether it can draw every missing character (full coverage and a
  /// licence that allows it).
  final bool usable;

  /// The letters of "Ğğ İı Şş Çç Öö Üü" it has.
  final String preview;
}

/// Missing-glyph step 3's characters and candidates.
@immutable
class MissingGlyphs {
  /// Creates the state.
  const new({
    required this.chars,
    required this.font,
    this.reason = MissingReason.notInstalled,
    this.reasonFont,
    this.reasonEmbedding,
    this.bold = false,
    this.italic = false,
    this.candidates = const [],
    this.drawn = false,
  });

  /// The characters, in text order.
  final List<MissingChar> chars;

  /// The font they are missing from.
  final String font;

  /// Why the same font did not draw them.
  final MissingReason reason;

  /// For [MissingReason.notEmbeddable], the installed font's name.
  final String? reasonFont;

  /// For [MissingReason.notEmbeddable] and [MissingReason.restricted], the
  /// permission.
  final FontEmbedding? reasonEmbedding;

  /// Whether the font is bold, so only bold candidates are offered.
  final bool bold;

  /// Whether it is italic, so only italic candidates are offered.
  final bool italic;

  /// The candidates, best first; empty when no font of the original's style
  /// has the characters ("No font has this character", G37).
  final List<FontCandidate> candidates;

  /// Whether the first usable candidate draws them now, provisionally.
  final bool drawn;
}

/// Which missing-glyph step drew substituted characters.
enum SubstitutionKind {
  /// Step 2: the same font, from this computer ("Character added from this
  /// computer", a3-17).
  sameFont,

  /// Step 3: a similar font.
  similar,
}

/// Characters set in another font than their line's (a3-12, a11-6).
@immutable
class FontSubstitution {
  /// Creates the substitution.
  const new({
    required this.kind,
    required this.chars,
    required this.fromFont,
    required this.toFont,
    required this.origin,
    this.announced = false,
  });

  /// The step.
  final SubstitutionKind kind;

  /// The characters, each once.
  final String chars;

  /// The document's font.
  final String fromFont;

  /// The font they are drawn in.
  final String toFont;

  /// Where that font comes from.
  final FontOrigin origin;

  /// Whether the app has been told of this font already: the notice and the
  /// "Font substituted" toast are said once.
  final bool announced;
}

/// Where the fonts for missing glyphs come from (ARCHITECTURE §6.7).
@immutable
class FontSettings {
  /// Creates the settings.
  const new({
    this.bundledDir,
    this.fontDirs = const [],
    this.systemFonts = true,
    this.askEachTime = false,
  });

  /// The directory of the fonts included with Ferman.
  final String? bundledDir;

  /// More directories whose fonts count as installed.
  final List<String> fontDirs;

  /// Whether the fonts installed on this computer are used.
  final bool systemFonts;

  /// "Ask each time" (a11-1c): step 3 waits for a choice.
  final bool askEachTime;
}

/// One of the overflow choices (a3-4).
enum OverflowChoice {
  /// "Extend block by N line(s)".
  extend,

  /// "Tighten spacing slightly (−x%)".
  tighten,

  /// "Keep and warn".
  keep,
}

/// What stands in the way of [OverflowChoice.extend].
enum ExtendBlockedKind {
  /// Another block of the page.
  block,

  /// The page's edge.
  pageEdge,
}

/// Why [OverflowChoice.extend] is disabled (a3-18).
@immutable
class ExtendBlocked {
  /// Creates the reason.
  const new({required this.kind, this.block, this.text = ''});

  /// What is in the way.
  final ExtendBlockedKind kind;

  /// The block in the way, for [ExtendBlockedKind.block].
  final int? block;

  /// Its first line, which the reason names.
  final String text;
}

/// The overflow choices with the amounts the engine computed for the block.
@immutable
class OverflowPlan {
  /// Creates a plan.
  const new({
    required this.over,
    required this.keepHidden,
    this.extendLines,
    this.extendBlocked,
    this.tightenPercent,
    this.tightenShort,
  });

  /// How many lines go past the frame.
  final int over;

  /// The N of "Extend block by N line(s)", when it is available.
  final int? extendLines;

  /// Why Extend is disabled, when it is.
  final ExtendBlocked? extendBlocked;

  /// The x of "Tighten spacing slightly (−x%)", one decimal, when it is
  /// available.
  final double? tightenPercent;

  /// The lines still over at the tightest allowed spacing, when Tighten is
  /// disabled.
  final int? tightenShort;

  /// The lines "Keep and warn" hides.
  final int keepHidden;

  /// Whether [choice] can be picked.
  bool allows(OverflowChoice choice) => switch (choice) {
    OverflowChoice.extend => extendLines != null,
    OverflowChoice.tighten => tightenPercent != null,
    OverflowChoice.keep => true,
  };
}

/// A table cell that likely depends on an edited one.
@immutable
class DependentCell {
  /// Creates the cell.
  const new({required this.id, required this.frame});

  /// Its block's id.
  final int id;

  /// Its frame, in the page's displayed points.
  final Rect frame;
}

/// Where a document's history stands after a commit, rollback, undo or
/// redo.
@immutable
class RevisionInfo {
  /// Creates the position.
  const new({
    required this.current,
    this.renderKey,
    this.substitutions = const [],
  });

  /// How many steps of the history apply: 0 is the document as opened.
  final int current;

  /// Every page's new render key when the engine reloaded the document;
  /// bitmaps with an older one show the revision before. Null when nothing
  /// shown changed.
  final int? renderKey;

  /// The substitutions a commit made, for the "Font substituted" toast
  /// (a11-6); empty after anything else.
  final List<FontSubstitution> substitutions;
}

/// One committed step of a document's history.
@immutable
class HistoryStep {
  /// Creates a step.
  const new({
    required this.name,
    required this.time,
    this.hiddenLines = 0,
    this.substitutions = const [],
  });

  /// Its name as the app gave it at commit.
  final String name;

  /// When it was committed.
  final DateTime time;

  /// The lines "Keep and warn" left hidden past the block's frame: the
  /// warning of the review list and the page thumbnail (a3-12); 0 for none.
  final int hiddenLines;

  /// The characters it set in another font: the review list's font rows
  /// (a3-12).
  final List<FontSubstitution> substitutions;
}

/// A document's history for the Undo history panel (a3-10).
@immutable
class EditHistory {
  /// Creates a history.
  const new({this.steps = const [], this.current = 0});

  /// Every committed step, oldest first.
  final List<HistoryStep> steps;

  /// How many [steps] apply; the rest can be redone.
  final int current;

  /// The steps that can be redone, next first.
  List<HistoryStep> get redoable => steps.sublist(current);
}
