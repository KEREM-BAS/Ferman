/// App-side views of what the engine reports. Feature code uses these, never
/// the generated bridge types (`app/lib/bridge/`), so only `app/lib/engine/`
/// depends on the bridge (ARCHITECTURE §3, ADR 0003).
library;

import 'dart:ui' show Color, Offset, Rect;

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

  /// A save found too little free space (a11-7).
  diskFull,

  /// Another app holds the file, still after the retries (a11-7d, G40).
  fileLocked,

  /// The new file could not replace the original (a11-7d, G40).
  renameFailed,

  /// The disk or network drive went away during a save (a11-7d, G40).
  volumeGone,

  /// The file has other hard links, which replacing it would break.
  hardLinked,

  /// The file belongs to someone else and its owner cannot be kept.
  notOwner,

  /// The file changed on disk since it was opened or saved (a11-7b).
  fileChangedOnDisk,

  /// A change to a signed document waits for
  /// `EngineService.confirmEditSigned` (a3-16a, G35).
  confirmationRequired,

  /// A bug in Ferman, including a caught panic.
  internal,
}

/// An error the engine returned. [messageKey] names the ARB string the UI
/// shows; [details] holds structural facts only. [offersSaveAs] says that a
/// failed save's way out is Save as (ARCHITECTURE §7.8).
@immutable
class EngineException implements Exception {
  /// Creates an exception.
  const new({
    required this.messageKey,
    this.details,
    this.kind = EngineErrorKind.internal,
    this.offersSaveAs = false,
    this.noRecoveryCopy = false,
  });

  /// What kind of failure this is.
  final EngineErrorKind kind;

  /// The ARB key of the message to show, such as `errorInternal`.
  final String messageKey;

  /// Technical details for "Copy technical details".
  final String? details;

  /// Whether the UI offers Save as: a save that failed for a reason another
  /// file avoids.
  final bool offersSaveAs;

  /// On a failed save: the last recovery write failed too, so no recovery
  /// copy of the unsaved edits exists (ARCHITECTURE §7.8).
  final bool noRecoveryCopy;

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
  const new({
    required this.width,
    required this.height,
    this.rotation = 0,
    this.label,
    this.handle,
  });

  /// The width, after the crop box and the page's rotation.
  final double width;

  /// The height, after the crop box and the page's rotation.
  final double height;

  /// The page's rotation in degrees clockwise: 0, 90, 180 or 270.
  final int rotation;

  /// The page label, such as "iv", when the document has labels.
  final String? label;

  /// What names the page while the document is open, whatever moves around
  /// it; history steps hold it. Set by the engine; a page made without one
  /// answers to its index ([OpenedDocument.pageHandle]).
  final int? handle;
}

/// What an annotation is.
enum AnnotationKind {
  /// A highlight.
  highlight,

  /// An underline.
  underline,

  /// A strike-through.
  strikeOut,

  /// A squiggly underline: read and rendered, never created.
  squiggly,

  /// A note on the page, or a reply.
  note,

  /// A text box.
  freeText,

  /// A text box with a leader.
  callout,

  /// Freehand.
  ink,

  /// A rectangle.
  square,

  /// An ellipse.
  circle,

  /// A line, with or without an arrow.
  line,

  /// A polygon.
  polygon,

  /// A stamp.
  stamp,

  /// Any other type: listed, its text editable, its drawing left alone.
  other,
}

/// A colour of a mark, each part from 0 to 1. Marks do not change with theme.
@immutable
class AnnotationColor {
  /// Creates a colour.
  const new(this.red, this.green, this.blue);

  /// Red.
  final double red;

  /// Green.
  final double green;

  /// Blue.
  final double blue;

  /// As a [Color], for a swatch.
  Color get color => Color.from(alpha: 1, red: red, green: green, blue: blue);
}

/// Whether [handle] names an annotation written directly in the file's page:
/// the engine's bit for those, whose handle is their place among the page's, so
/// a change to a neighbour or an undo can give it to another (ferman-core's
/// `direct_handle`).
bool isDirectAnnotationHandle(int handle) => handle >= 4503599627370496;

/// One annotation, in displayed points.
@immutable
class AnnotationInfo {
  /// Creates an annotation.
  const new({
    required this.handle,
    required this.page,
    required this.kind,
    required this.rect,
    required this.thread,
    this.subtype = '',
    this.points = const [],
    this.arrow = false,
    this.color,
    this.opacity = 1,
    this.stroke = 1,
    this.fontSize,
    this.author,
    this.contents,
    this.quote,
    this.rich = false,
    this.created,
    this.modified,
    this.icon,
    this.repliesTo,
    this.state,
    this.resolved = false,
    this.resolvedBy,
    this.resolvedAt,
    this.mentions = const [],
  });

  /// Its identity for the other calls. It stays through edits, undo and saves;
  /// one written directly in the page's array gets a new one with its first
  /// change, which the change returns.
  final int handle;

  /// Its page, by [PageInfo.handle].
  final int page;

  /// What it is.
  final AnnotationKind kind;

  /// The type's name in the file, which names an [AnnotationKind.other].
  final String subtype;

  /// Its box.
  final Rect rect;

  /// Quads (four corners each), strokes, a line's two ends, vertices or a
  /// leader, as [NewAnnotation.points] orders them.
  final List<List<Offset>> points;

  /// A line or callout ends in an arrow.
  final bool arrow;

  /// Its colour.
  final AnnotationColor? color;

  /// Its opacity, from 0 to 1.
  final double opacity;

  /// Its stroke, in points.
  final double stroke;

  /// A text box's font size.
  final double? fontSize;

  /// Its author.
  final String? author;

  /// Its text.
  final String? contents;

  /// The page text under its marks or box, for the panel's quote (a4-2).
  final String? quote;

  /// Rich text goes with it; replacing the text removes it.
  final bool rich;

  /// When it was made: local time when the file gives a zone, else as written.
  final DateTime? created;

  /// When it last changed, as [created].
  final DateTime? modified;

  /// A note's icon or a stamp's name.
  final String? icon;

  /// The annotation it replies to.
  final int? repliesTo;

  /// The top of its thread, its own handle when it is no reply.
  final int thread;

  /// The state it sets, for a state reply, which the panel does not list.
  final String? state;

  /// On top of a thread: whether it is resolved.
  final bool resolved;

  /// Who resolved it.
  final String? resolvedBy;

  /// When, as [created].
  final DateTime? resolvedAt;

  /// The people of the file its text mentions.
  final List<String> mentions;
}

/// A document's annotations.
@immutable
class AnnotationList {
  /// Creates a list.
  const new({
    this.annotations = const [],
    this.people = const [],
    this.truncated = false,
  });

  /// In page order.
  final List<AnnotationInfo> annotations;

  /// The names in the file, for mentions (a4-2).
  final List<String> people;

  /// Whether a limit cut the list or a text short.
  final bool truncated;
}

/// A new annotation, in displayed points.
@immutable
class NewAnnotation {
  /// Creates a new annotation.
  const new({
    required this.kind,
    required this.color,
    required this.author,
    this.rect = Rect.zero,
    this.points = const [],
    this.stroke = 1,
    this.opacity = 1,
    this.contents = '',
    this.fontSize = 12,
    this.arrow = false,
    this.label = '',
    this.meta,
    this.tilt = 0,
    this.icon,
    this.comb,
  });

  /// What it is; never [AnnotationKind.squiggly] or [AnnotationKind.other].
  final AnnotationKind kind;

  /// A note's, text box's, shape's or stamp's box; a callout's text box.
  final Rect rect;

  /// Text markup: each quad's corners, top left, top right, bottom left,
  /// bottom right. Ink: each stroke. Line: its two ends. Polygon: its vertices.
  /// Callout: its leader from the far end.
  final List<List<Offset>> points;

  /// Its colour.
  final AnnotationColor color;

  /// Its stroke, in points.
  final double stroke;

  /// Its opacity, from 0 to 1.
  final double opacity;

  /// Its text.
  final String contents;

  /// Its author.
  final String author;

  /// A text box's, callout's or stamp label's size.
  final double fontSize;

  /// A line ends in an arrow.
  final bool arrow;

  /// A stamp's label, already cased for its language.
  final String label;

  /// The line under a stamp's label: name, date and time as placed.
  final String? meta;

  /// A stamp's turn in degrees; negative turns anticlockwise.
  final double tilt;

  /// A note's icon or a stamp's name.
  final String? icon;

  /// A text box on a comb of this many cells, one character each (Fill
  /// anything, a5-4): from 1 to 256, a text box's only.
  final int? comb;
}

/// What a change to an annotation sets; null leaves it.
@immutable
class AnnotationChange {
  /// Creates a change.
  const new({
    this.contents,
    this.rect,
    this.points,
    this.color,
    this.stroke,
    this.opacity,
    this.fontSize,
  });

  /// New text.
  final String? contents;

  /// A new box: its geometry follows.
  final Rect? rect;

  /// New geometry, as [NewAnnotation.points].
  final List<List<Offset>>? points;

  /// Its colour.
  final AnnotationColor? color;

  /// Its stroke, in points.
  final double? stroke;

  /// Its opacity.
  final double? opacity;

  /// A text box's or callout's font size.
  final double? fontSize;
}

/// What a commit that names an annotation returns.
@immutable
class AnnotationCommit {
  /// Creates a commit.
  const new({required this.handle, required this.revision});

  /// The annotation's handle.
  final int handle;

  /// Where the history stands.
  final RevisionInfo revision;
}

/// What a form field is.
enum FieldKind {
  /// A text field.
  text,

  /// A check box.
  check,

  /// A radio group.
  radio,

  /// A push button: nothing to fill.
  push,

  /// A combo box.
  combo,

  /// A list box.
  list,

  /// A signature field.
  signature,

  /// An unknown type.
  other,
}

/// The format a field's scripts declare (M4 decision 17): read, never run.
enum FieldFormatKind {
  /// None.
  none,

  /// A date in [FieldInfo.datePattern].
  date,

  /// A number with [FieldInfo.decimals].
  number,

  /// A percentage with [FieldInfo.decimals].
  percent,
}

/// Why a value does not meet what its field declares.
enum FieldProblemKind {
  /// Past [FieldProblem.maxLen].
  tooLong,

  /// Not a date in [FieldProblem.pattern].
  notADate,

  /// Not a number.
  notANumber,

  /// Outside [FieldProblem.min] and [FieldProblem.max].
  outOfRange,
}

/// A value's problem with its parameters (a5-2).
@immutable
class FieldProblem {
  /// Creates a problem.
  const new({
    required this.kind,
    this.maxLen,
    this.pattern,
    this.min,
    this.max,
  });

  /// What it is.
  final FieldProblemKind kind;

  /// The most characters, for [FieldProblemKind.tooLong].
  final int? maxLen;

  /// The date pattern, for [FieldProblemKind.notADate].
  final String? pattern;

  /// The least value, for [FieldProblemKind.outOfRange].
  final double? min;

  /// The greatest value, for [FieldProblemKind.outOfRange].
  final double? max;
}

/// One choice of a combo or list box.
@immutable
class FieldOption {
  /// Creates an option.
  const new({required this.export, required this.display});

  /// What the value holds.
  final String export;

  /// What the field shows.
  final String display;
}

/// One place of a field on a page.
@immutable
class FieldWidget {
  /// Creates a widget.
  const new({required this.page, required this.rect, this.onState});

  /// Its page, by [PageInfo.handle].
  final int page;

  /// Its box, in the page's displayed points (y down).
  final Rect rect;

  /// The value that turns a check box or radio button on.
  final String? onState;
}

/// One form field, in tab order (a5-1).
@immutable
class FieldInfo {
  /// Creates a field.
  const new({
    required this.handle,
    required this.name,
    required this.kind,
    this.label,
    this.readOnly = false,
    this.required = false,
    this.multiline = false,
    this.password = false,
    this.comb = false,
    this.multiSelect = false,
    this.editable = false,
    this.values = const [],
    this.options = const [],
    this.maxLen,
    this.widgets = const [],
    this.format = FieldFormatKind.none,
    this.datePattern,
    this.decimals,
    this.min,
    this.max,
    this.problem,
    this.signed = false,
    this.signature,
    this.filled = false,
  });

  /// Its identity; it stays through edits, undo and saves.
  final int handle;

  /// Its full name.
  final String name;

  /// The name a reader shows (`/TU`).
  final String? label;

  /// What it is.
  final FieldKind kind;

  /// It cannot be changed.
  final bool readOnly;

  /// It counts in the required count.
  final bool required;

  /// A text field of many lines.
  final bool multiline;

  /// A text field that hides what is typed.
  final bool password;

  /// A comb of [maxLen] cells.
  final bool comb;

  /// A list box that takes several values.
  final bool multiSelect;

  /// A combo box that takes any text.
  final bool editable;

  /// Its value: text, export values, or the on-state of a button.
  final List<String> values;

  /// A choice's options.
  final List<FieldOption> options;

  /// The most characters.
  final int? maxLen;

  /// Its places, in tab order.
  final List<FieldWidget> widgets;

  /// The format it declares.
  final FieldFormatKind format;

  /// The date pattern it declares.
  final String? datePattern;

  /// The decimals it declares.
  final int? decimals;

  /// The least value it declares.
  final double? min;

  /// The greatest value it declares.
  final double? max;

  /// How its value fails what it declares.
  final FieldProblem? problem;

  /// A signature field holds a digital signature.
  final bool signed;

  /// The stamp of the simple signature on it (M4 decisions 20 and 21).
  final int? signature;

  /// It counts as filled.
  final bool filled;

  /// The same field holding [values].
  FieldInfo withValues(List<String> values) => FieldInfo(
    handle: handle,
    name: name,
    kind: kind,
    label: label,
    readOnly: readOnly,
    required: required,
    multiline: multiline,
    password: password,
    comb: comb,
    multiSelect: multiSelect,
    editable: editable,
    values: values,
    options: options,
    maxLen: maxLen,
    widgets: widgets,
    format: format,
    datePattern: datePattern,
    decimals: decimals,
    min: min,
    max: max,
    signed: signed,
    signature: signature,
    filled: values.isNotEmpty || signed || signature != null,
  );

  /// This field signed by the simple signature [stamp], or none.
  FieldInfo withSignature(int? stamp) => FieldInfo(
    handle: handle,
    name: name,
    kind: kind,
    label: label,
    readOnly: readOnly,
    required: required,
    multiline: multiline,
    password: password,
    comb: comb,
    multiSelect: multiSelect,
    editable: editable,
    values: values,
    options: options,
    maxLen: maxLen,
    widgets: widgets,
    format: format,
    datePattern: datePattern,
    decimals: decimals,
    min: min,
    max: max,
    problem: problem,
    signed: signed,
    signature: stamp,
    filled: values.isNotEmpty || signed || stamp != null,
  );
}

/// A document's form.
@immutable
class FormInfo {
  /// Creates a form.
  const new({
    this.fields = const [],
    this.required = 0,
    this.requiredLeft = 0,
    this.problems = 0,
    this.hasXfa = false,
    this.truncated = false,
  });

  /// In tab order.
  final List<FieldInfo> fields;

  /// Required fields.
  final int required;

  /// Required fields not yet filled (a5-1's "13 required left").
  final int requiredLeft;

  /// Fields whose value fails what they declare: Finish waits for none.
  final int problems;

  /// The form has XFA, which the first change removes with a notice.
  final bool hasXfa;

  /// Whether a limit cut the list short.
  final bool truncated;
}

/// What setting a field's value returns.
@immutable
class FieldCommit {
  /// Creates a commit.
  const new({
    required this.revision,
    this.problem,
    this.fonts = const [],
    this.marked = false,
    this.xfaRemoved = false,
    this.asksFont = false,
  });

  /// Where the history stands.
  final RevisionInfo revision;

  /// How the new value fails what the field declares.
  final FieldProblem? problem;

  /// The families it was drawn in because its font could not: say so once.
  final List<String> fonts;

  /// What its font cannot draw was left out: mark the field.
  final bool marked;

  /// XFA left the form: say so.
  final bool xfaRemoved;

  /// Ask each time: nothing was written; ask, then call again with a choice.
  final bool asksFont;
}

/// What to do when a value has characters its field's font cannot draw
/// (a11-1c, M4 decision 18).
enum MissingFont {
  /// Bundled IBM Plex, said once.
  bundled,

  /// Ask first, writing nothing.
  ask,

  /// Keep the field's font and mark the field.
  keep,
}

/// What each side of a page gives up, in displayed points.
@immutable
class PageMargins {
  /// Creates the margins.
  const new({this.top = 0, this.bottom = 0, this.left = 0, this.right = 0});

  /// The top side.
  final double top;

  /// The bottom side.
  final double bottom;

  /// The left side.
  final double left;

  /// The right side.
  final double right;
}

/// What a new page size does to the content (a6-4).
enum PageFit {
  /// Stays at its size, in the middle of the new page.
  centre,

  /// Scaled to fit the new page, and centred on it.
  scale,
}

/// How a page label range writes its numbers (a6-5).
enum PageLabelStyle {
  /// No number: the prefix alone.
  none,

  /// 1, 2, 3.
  decimal,

  /// I, II, III.
  romanUpper,

  /// i, ii, iii.
  romanLower,

  /// A, B, C.
  lettersUpper,

  /// a, b, c.
  lettersLower,
}

/// One range of a document's page labels (a6-5).
@immutable
class PageLabelRange {
  /// Creates a range.
  const new({
    required this.start,
    this.style = PageLabelStyle.decimal,
    this.prefix = '',
    this.first = 1,
  });

  /// The index of its first page, from 0.
  final int start;

  /// How it writes its numbers.
  final PageLabelStyle style;

  /// What comes before each number.
  final String prefix;

  /// The number of its first page, from 1.
  final int first;
}

/// What a commit, undo or redo changed of a document's lists.
@immutable
class DocumentStructure {
  /// Creates the lists.
  const new({
    required this.pages,
    this.outline = const [],
    this.attachments = const [],
  });

  /// Its pages.
  final List<PageInfo> pages;

  /// The outline in reading order, each item followed by its children.
  final List<OutlineEntry> outline;

  /// Its embedded files.
  final List<Attachment> attachments;
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

/// What Properties says about a font beyond its status (a2-7, FmDocPanel).
@immutable
class FontCoverage {
  /// Creates a font's coverage.
  const new({required this.name, this.shownAs, this.missingLetters = ''});

  /// [FontEntry.name] of the font.
  final String name;

  /// The family a font that is not embedded is drawn in, when it is another
  /// font.
  final String? shownAs;

  /// For a subset, the letters asked about that an edit cannot draw in it.
  final String missingLetters;
}

/// What the user asks to do to a document.
enum DocumentOp {
  /// Editing text on a page.
  editText,

  /// Inserting, moving, rotating and deleting pages.
  organize,

  /// Adding or changing comments.
  comment,

  /// Filling in form fields, signing a signature field included.
  fill,

  /// Printing, which changes nothing in the file.
  print,
}

/// What an operation may do to a document as it stands (G35).
enum OpGate {
  /// Allowed, and no signature is concerned.
  unaffected,

  /// Allowed, and what the signatures allow: a certification and the
  /// signatures stay valid.
  keepsSignatures,

  /// Possible only by invalidating a signature.
  breaksSignatures,

  /// The document's permissions forbid it, or the document cannot be changed.
  forbidden,
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

  /// Whether the restrictions forbid changing the document now.
  bool get forbidsEditing => restricted && !permissions.modify;
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
    this.signed = false,
    this.certification,
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

  /// Whether a change would invalidate a signature, so it waits for
  /// `EngineService.confirmEditSigned` (G35).
  final bool signed;

  /// The certification signature's DocMDP level (1 to 3), when certified.
  final int? certification;

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

  /// The handle of page [index].
  int pageHandle(int index) => pages.elementAtOrNull(index)?.handle ?? index;

  /// Where the page with [handle] is now; null once it is gone.
  int? pageIndexOf(int handle) {
    for (var i = 0; i < pages.length; i++) {
      if ((pages[i].handle ?? i) == handle) return i;
    }
    return null;
  }

  /// This document with [security], as the owner unlock leaves it.
  OpenedDocument withSecurity(Security? security) =>
      _copy(security: () => security);

  /// This document with [structure], as a revision leaves it.
  OpenedDocument withStructure(DocumentStructure structure) => _copy(
    pages: structure.pages,
    outline: structure.outline,
    attachments: structure.attachments,
  );

  OpenedDocument _copy({
    List<PageInfo>? pages,
    List<OutlineEntry>? outline,
    List<Attachment>? attachments,
    Security? Function()? security,
  }) => OpenedDocument(
    id: id,
    pages: pages ?? this.pages,
    readOnly: readOnly,
    repairs: repairs,
    rightToLeft: rightToLeft,
    outline: outline ?? this.outline,
    attachments: attachments ?? this.attachments,
    layers: layers,
    layersSwitchable: layersSwitchable,
    signatures: signatures,
    signed: signed,
    certification: certification,
    version: version,
    fileSize: fileSize,
    info: info,
    language: language,
    tagged: tagged,
    linearized: linearized,
    fonts: fonts,
    security: security == null ? this.security : security(),
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

/// How long a finished job offers its result (a11-6b), as the engine keeps it.
const Duration jobResultKept = Duration(hours: 1);

/// How long a quit waits for the jobs it cancelled; a job that has not reached
/// its next step by then leaves its temp folder to the next launch's sweep, and
/// never a partial output.
const Duration jobQuitWait = Duration(seconds: 5);

/// Where a job stands (a11-6b).
enum JobState {
  /// It works.
  running,

  /// It is parked between two steps.
  paused,

  /// It finished: the last update.
  done,

  /// It failed: the last update.
  failed,

  /// It was cancelled: the last update.
  cancelled,
}

/// A file a job finished.
@immutable
class JobOutputFile {
  /// Creates a file.
  const new({required this.path, this.staged});

  /// Where it belongs.
  final String path;

  /// Under the macOS App Sandbox, the verified file waiting for the swap into
  /// [path], which is not touched yet.
  final String? staged;
}

/// The paper of an image's own page (G152), from the region setting.
enum ImagePaper {
  /// 595.28 × 841.89 pt.
  a4,

  /// 612 × 792 pt.
  letter,
}

/// One input of Combine or Create PDF.
@immutable
class CombineInput {
  /// A PDF or image at [path], with [pages] by index in the order to take them,
  /// null for all.
  const new file(String this.path, {this.password, this.pages, this.bookmark})
    : blankWidth = 0,
      blankHeight = 0;

  /// A blank page of [blankWidth] by [blankHeight] points.
  const new blank(this.blankWidth, this.blankHeight, {this.bookmark})
    : path = null,
      password = null,
      pages = null;

  /// Where the file is; null for a blank page.
  final String? path;

  /// What opens it.
  final String? password;

  /// Its pages, null for all.
  final List<int>? pages;

  /// A blank page's width, in points.
  final double blankWidth;

  /// A blank page's height, in points.
  final double blankHeight;

  /// The title of a bookmark for its first page.
  final String? bookmark;
}

/// Whether an input can be used, for its row in a6-3 (G45).
enum CombineInputStatus {
  /// It can.
  ready,

  /// It needs its password.
  passwordRequired,

  /// The password does not open it.
  wrongPassword,

  /// It forbids assembling, which only its owner password lifts.
  ownerPasswordRequired,

  /// Its page range names a page it does not have, or a page twice.
  badRange,

  /// Neither a PDF nor an image Ferman can read, or the file is gone.
  unreadable,
}

/// One input's row in a6-3.
@immutable
class CombineFileInfo {
  /// Creates a row.
  const new({
    required this.status,
    this.image = false,
    this.pages = 0,
    this.selected = 0,
    this.bytes = 0,
    this.encrypted = false,
    this.signed = false,
  });

  /// Whether it can be used; the numbers are zero if not.
  final CombineInputStatus status;

  /// Whether it is an image, "converted to 1 page".
  final bool image;

  /// Its pages in all.
  final int pages;

  /// How many of them it adds.
  final int selected;

  /// About what it adds to the output, in bytes.
  final int bytes;

  /// Whether it is encrypted: the output will not be.
  final bool encrypted;

  /// Whether it is signed: the output carries no signature.
  final bool signed;
}

/// What a6-3 shows before anything is written.
@immutable
class CombinePreview {
  /// Creates a preview.
  const new({this.files = const [], this.pages = 0, this.bytes = 0});

  /// A row per input, in order.
  final List<CombineFileInfo> files;

  /// The pages of the output.
  final int pages;

  /// About how large it comes out, in bytes.
  final int bytes;
}

/// The ways to split a6-2 draws.
enum SplitKind {
  /// A new file every so many pages.
  everyPages,

  /// One file per top-level bookmark; the pages before the first are a file of
  /// their own.
  topBookmarks,

  /// Files of at most so many bytes, as estimated.
  size,

  /// A new file at each blank page, which goes.
  blankPages,
}

/// One file of a split: its plan, and what the job takes back.
@immutable
class SplitFile {
  /// Creates a file.
  const new({
    required this.name,
    required this.first,
    required this.last,
    this.bytes = 0,
    this.overLimit = false,
  });

  /// Its name, with `.pdf`, safe in any folder.
  final String name;

  /// Its first page, as an index.
  final int first;

  /// Its last page, as an index.
  final int last;

  /// About how large it comes out, in bytes, at the high end.
  final int bytes;

  /// Whether one page alone is over the size asked for.
  final bool overLimit;
}

/// What a6-2 shows before anything is written.
@immutable
class SplitPreview {
  /// Creates a preview.
  const new({
    this.files = const [],
    this.bookmarks = 0,
    this.blankPages = 0,
    this.encrypted = false,
    this.signed = false,
  });

  /// The files.
  final List<SplitFile> files;

  /// How many top-level bookmarks go to a page.
  final int bookmarks;

  /// How many pages count as blank.
  final int blankPages;

  /// Whether the document is encrypted: the files will not be.
  final bool encrypted;

  /// Whether it is signed: the files carry no signature.
  final bool signed;
}

/// What a running job reports. The first update has its handle, the last says
/// how it ended.
@immutable
class JobUpdate {
  /// Creates an update.
  const new({
    required this.job,
    required this.state,
    this.progress,
    this.messageKey,
    this.params = const {},
    this.outputs = const [],
    this.revision,
    this.error,
  });

  /// The job's handle.
  final int job;

  /// Where it stands.
  final JobState state;

  /// How far it is, 0 to 1; null when unknown.
  final double? progress;

  /// The ARB key of where it is, such as `jobPageOf`.
  final String? messageKey;

  /// The key's parameters.
  final Map<String, String> params;

  /// The files it wrote ([JobState.done]).
  final List<JobOutputFile> outputs;

  /// How many steps of the document's history it read ([JobState.done]): edits
  /// since are not in its result.
  final int? revision;

  /// Why it failed ([JobState.failed]).
  final EngineException? error;
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
    this.comments = true,
    this.fields = false,
  });

  /// Match case.
  final bool matchCase;

  /// Whole words.
  final bool wholeWords;

  /// Ignore accents and dotted/dotless i.
  final bool ignoreAccents;

  /// Look in the bookmarks' titles too (a2-4a, B114).
  final bool bookmarks;

  /// Look in the annotations' text too (a2-4a, on by default, B128).
  final bool comments;

  /// Look in the form fields' values too (a2-4a, B128).
  final bool fields;

  @override
  bool operator ==(Object other) =>
      other is SearchOptions &&
      other.matchCase == matchCase &&
      other.wholeWords == wholeWords &&
      other.ignoreAccents == ignoreAccents &&
      other.bookmarks == bookmarks &&
      other.comments == comments &&
      other.fields == fields;

  @override
  int get hashCode => Object.hash(
    matchCase,
    wholeWords,
    ignoreAccents,
    bookmarks,
    comments,
    fields,
  );
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
    this.comment,
    this.field,
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

  /// The annotation whose text it is in, [snippet] being that text's line and
  /// [rects] the annotation's box.
  final int? comment;

  /// The form field whose value it is in, [snippet] being that value's line
  /// and [rects] the field's first widget.
  final int? field;
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
    this.language,
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

  /// Its language tag ("en-GB", the PDF's `/Lang`), else the document's;
  /// null with neither.
  final String? language;

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
  const new({
    this.page = 0,
    this.quads = const [],
    this.text = '',
    this.language,
  });

  /// Its page, from 0. The engine's reply leaves it 0; the canvas sets it.
  final int page;

  /// The boxes to highlight, in the page's displayed points.
  final List<Rect> quads;

  /// Its text for copying.
  final String text;

  /// The language tag of the block it ends in, as the canvas knows it; the
  /// engine's reply leaves it null.
  final String? language;
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
    this.language,
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

  /// The block's language tag as a commit leaves it (a3-14).
  final String? language;
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

/// A font a block is set in (a3-2).
@immutable
class BlockFont {
  /// The font [postscriptName] of [origin].
  const new({required this.origin, required this.postscriptName});

  /// Its group.
  final FontOrigin origin;

  /// Its PostScript name.
  final String postscriptName;

  @override
  bool operator ==(Object other) =>
      other is BlockFont &&
      other.origin == origin &&
      other.postscriptName == postscriptName;

  @override
  int get hashCode => Object.hash(origin, postscriptName);
}

/// What to change in a block (a3-2); what is null stays as it is.
@immutable
class BlockStyle {
  /// A change of the fields given.
  const new({
    this.font,
    this.size,
    this.colour,
    this.alignment,
    this.charSpacing,
    this.lineSpacing,
  });

  /// The font the whole block is set in.
  final BlockFont? font;

  /// The font size in points.
  final double? size;

  /// The fill colour, `0xRRGGBB`.
  final int? colour;

  /// How the lines sit.
  final BlockAlignment? alignment;

  /// The space between characters, in percent of the em.
  final double? charSpacing;

  /// The distance between baselines, in multiples of the font size.
  final double? lineSpacing;
}

/// What the text panel shows of a block (a3-2).
@immutable
class BlockStyleInfo {
  /// Creates the block's style.
  const new({
    required this.font,
    required this.family,
    required this.size,
    required this.frame,
    this.bold = false,
    this.italic = false,
    this.boldToggle,
    this.italicToggle,
    this.colour,
    this.documentColours = const [],
    this.alignment = BlockAlignment.left,
    this.charSpacing = 0,
    this.lineSpacing = 1.2,
  });

  /// Its first font's PostScript name, without the subset tag.
  final String font;

  /// Its first font's family.
  final String family;

  /// Whether its first font is bold.
  final bool bold;

  /// Whether its first font is italic.
  final bool italic;

  /// The face with the bold state turned over that can draw the whole
  /// block; null disables Bold, which is never faked.
  final BlockFont? boldToggle;

  /// The same for Italic.
  final BlockFont? italicToggle;

  /// Its largest font size in points.
  final double size;

  /// Its fill colour, `0xRRGGBB`; null for a pattern or a colour space
  /// without a conversion.
  final int? colour;

  /// The page's text colours, the most used first.
  final List<int> documentColours;

  /// How its lines sit.
  final BlockAlignment alignment;

  /// The space between characters, in percent of the em.
  final double charSpacing;

  /// The distance between baselines, in multiples of the font size.
  final double lineSpacing;

  /// Its box, in the page's displayed points.
  final Rect frame;
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

  /// Step 3's "Keep the original font and mark the character": no other
  /// font, and no glyph; [FontSubstitution.toFont] is the document's font.
  marked,
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
    this.markMissing = false,
    this.keepLines = false,
  });

  /// The directory of the fonts included with Ferman.
  final String? bundledDir;

  /// More directories whose fonts count as installed.
  final List<String> fontDirs;

  /// Whether the fonts installed on this computer are used.
  final bool systemFonts;

  /// "Ask each time" (a11-1c): step 3 waits for a choice.
  final bool askEachTime;

  /// "Keep the original font and mark the character" (a11-1c): step 3 keeps
  /// the characters in their font without a glyph.
  final bool markMissing;

  /// Reflow while typing turned off (a11-1c): only a line feed ends a line.
  final bool keepLines;
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
    this.changedPages,
    this.substitutions = const [],
    this.structure,
  });

  /// How many steps of the history apply: 0 is the document as opened.
  final int current;

  /// The new render key of [changedPages] when the engine reloaded the
  /// document; their bitmaps with an older one show the revision before. Null
  /// when nothing shown changed.
  final int? renderKey;

  /// The pages that got [renderKey], by index; the others keep their key and
  /// bitmaps. Null means every page.
  final List<int>? changedPages;

  /// The substitutions a commit made, for the "Font substituted" toast
  /// (a11-6); empty after anything else.
  final List<FontSubstitution> substitutions;

  /// The document's pages, outline and attachments when this changed them;
  /// null when they are as they were.
  final DocumentStructure? structure;
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
    this.pages = const [],
    this.before = '',
    this.after = '',
    this.reverts = const [],
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

  /// The pages it changed, by [PageInfo.handle], so they are found after a
  /// move; empty for a revert and a step restored from the recovery files.
  final List<int> pages;

  /// The block's text before it: the review list's before (a3-12).
  final String before;

  /// The block's text after it.
  final String after;

  /// The steps this one reverted, by index; empty for an edit.
  final List<int> reverts;
}

/// What a revert did (a3-12b).
@immutable
class Reverted {
  /// Creates the result.
  const new({
    required this.reverted,
    required this.revision,
    this.dependents = const [],
  });

  /// Whether the step was reverted; false when later steps depend on it and
  /// were not asked to go with it.
  final bool reverted;

  /// The steps that depend on it, by index, oldest first.
  final List<int> dependents;

  /// Where the history stands.
  final RevisionInfo revision;
}

/// A document's history for the Undo history panel (a3-10).
@immutable
class EditHistory {
  /// Creates a history.
  const new({
    this.steps = const [],
    this.current = 0,
    this.signatureInvalidated = false,
  });

  /// Every committed step, oldest first.
  final List<HistoryStep> steps;

  /// How many [steps] apply; the rest can be redone.
  final int current;

  /// Whether the document as it stands no longer matches its signatures: the
  /// signature row of the review list (a3-12, G42).
  final bool signatureInvalidated;

  /// The steps that can be redone, next first.
  List<HistoryStep> get redoable => steps.sublist(current);

  /// The indexes of the edits that still count: applied, not reverted, and
  /// not a revert themselves. The review list's rows and the edit count.
  List<int> get live {
    final gone = {for (final step in steps.take(current)) ...step.reverts};
    return [
      for (var i = 0; i < current && i < steps.length; i++)
        if (steps[i].reverts.isEmpty && !gone.contains(i)) i,
    ];
  }
}

/// A document that a session which ended without cleaning up left recovery
/// files for (a1-12).
@immutable
class RecoverableDocument {
  /// Creates the entry.
  const new({
    required this.session,
    required this.document,
    required this.original,
    this.originalChanged = false,
    this.changes = 0,
    this.encrypted = false,
  });

  /// The session's name, for `EngineService.restoreRecovered` and
  /// `EngineService.discardRecovery`.
  final String session;

  /// The document's name in the session.
  final String document;

  /// The file the document saves to.
  final String original;

  /// Whether that file changed on disk since: the restored document opens
  /// under a new name (a11-7f).
  final bool originalChanged;

  /// How many unsaved changes the files hold.
  final int changes;

  /// Whether restoring needs the document's password (a1-8).
  final bool encrypted;

  @override
  bool operator ==(Object other) =>
      other is RecoverableDocument &&
      other.session == session &&
      other.document == document &&
      other.original == original &&
      other.originalChanged == originalChanged &&
      other.changes == changes &&
      other.encrypted == encrypted;

  @override
  int get hashCode => Object.hash(
    session,
    document,
    original,
    originalChanged,
    changes,
    encrypted,
  );
}

/// A document `EngineService.restoreRecovered` opened.
@immutable
class RestoredDocument {
  /// Creates the result.
  const new({
    required this.opened,
    required this.path,
    this.originalChanged = false,
    this.renderKey,
  });

  /// The document, as `EngineService.open` gives it.
  final OpenedDocument opened;

  /// The file it saves to: the original, or a new name beside it when the
  /// original changed.
  final String path;

  /// Whether the original changed on disk since it was opened or saved.
  final bool originalChanged;

  /// Every page's render key with the restored changes; null when the engine
  /// could not reload.
  final int? renderKey;
}

/// What a comment summary is written as (a4-4).
enum SummaryFormat {
  /// CSV, one comment per row.
  csv,

  /// A PDF: numbered markers on each page, with its comments beside it.
  pageAndComments,

  /// A PDF: a list, grouped by page.
  commentsOnly,

  /// A PDF: the full page followed by its comments.
  pageThenList,
}

/// The order of a summary's comments.
enum SummarySort {
  /// Page order.
  page,

  /// Oldest first.
  date,

  /// By author, then page order.
  author,
}

/// What a comment summary holds, and its words in the app's language.
final class SummaryOptions {
  /// The options.
  const new({
    required this.open,
    required this.resolved,
    required this.replies,
    required this.emptyPages,
    required this.sort,
    required this.pageLabel,
    required this.columns,
    required this.kinds,
    required this.openLabel,
    required this.resolvedLabel,
    required this.noComments,
    required this.datePattern,
    required this.paperWidth,
    required this.paperHeight,
  });

  /// Open comments.
  final bool open;

  /// Resolved comments.
  final bool resolved;

  /// Replies under each.
  final bool replies;

  /// Pages without comments.
  final bool emptyPages;

  /// The order.
  final SummarySort sort;

  /// A page's heading, with `{n}` for its number.
  final String pageLabel;

  /// The CSV's header row: page, type, author, date, text, replies, status.
  final List<String> columns;

  /// Each kind's name.
  final Map<AnnotationKind, String> kinds;

  /// The status of an open comment.
  final String openLabel;

  /// The status of a resolved one.
  final String resolvedLabel;

  /// What a page, or a summary, with no comment says.
  final String noComments;

  /// Dates by the region: `yyyy`, `MM`, `dd`, `HH` and `mm` are replaced.
  final String datePattern;

  /// A PDF's paper width, in points.
  final double paperWidth;

  /// A PDF's paper height, in points.
  final double paperHeight;
}

/// A link's border (a3-6).
enum LinkLook {
  /// No line.
  invisible,

  /// A line under it.
  underline,

  /// A thin box.
  box,
}

/// Where a link goes, and whether it may be offered. Only [web] and [mail] can
/// be opened, after the prompt with the full target showing (G145); [page] just
/// goes; the others open nothing.
enum LinkKind {
  /// An `http` or `https` address.
  web,

  /// A `mailto:` address.
  mail,

  /// A page of this document.
  page,

  /// A destination that leads nowhere.
  broken,

  /// Refused: a script.
  script,

  /// Refused: a program or file to launch.
  launch,

  /// Refused: another file.
  file,

  /// Refused: an address of another scheme, or one that does not read cleanly.
  address,

  /// Refused: an action Ferman does not know, kept in the file as it came.
  action,

  /// It does nothing.
  nothing,
}

/// One link, in displayed points.
final class LinkInfo {
  /// A link.
  const new({
    required this.handle,
    required this.page,
    required this.rect,
    required this.kind,
    this.quads = const [],
    this.target = '',
    this.targetPage,
    this.wantedPage,
    this.look = LinkLook.invisible,
    this.color,
  });

  /// Its identity for the other calls.
  final int handle;

  /// Its page's handle.
  final int page;

  /// Its box.
  final Rect rect;

  /// Its text's lines, four corners each.
  final List<List<Offset>> quads;

  /// Where it goes.
  final LinkKind kind;

  /// The address, or what a refused link names: to show, and to open only for
  /// [LinkKind.web] and [LinkKind.mail]. Untrusted text from the document.
  final String target;

  /// The handle of the page, for [LinkKind.page].
  final int? targetPage;

  /// The page a [LinkKind.broken] link names, from 1, when it says.
  final int? wantedPage;

  /// Its border.
  final LinkLook look;

  /// Its colour.
  final AnnotationColor? color;
}

/// A document's links.
final class LinkList {
  /// The list.
  const new({required this.links, this.truncated = false});

  /// In page order.
  final List<LinkInfo> links;

  /// Whether a limit cut the list short.
  final bool truncated;
}

/// Where a new link goes: [page]'s handle when it has one, else [address], web
/// or mail by [mail].
final class LinkDestination {
  /// An address.
  const new address(this.address, {this.mail = false}) : page = null;

  /// A page by its handle.
  const new page(int this.page) : address = '', mail = false;

  /// An `http` or `https` address, or an e-mail address.
  final String address;

  /// Whether [address] is an e-mail address.
  final bool mail;

  /// A page by its handle.
  final int? page;
}

/// A new link, in displayed points.
final class NewLink {
  /// A link.
  const new({
    required this.rect,
    required this.destination,
    required this.color,
    this.quads = const [],
    this.look = LinkLook.invisible,
  });

  /// Its box.
  final Rect rect;

  /// Its text's lines: top left, top right, bottom left and bottom right as the
  /// reader sees them.
  final List<List<Offset>> quads;

  /// Where it goes.
  final LinkDestination destination;

  /// Its border.
  final LinkLook look;

  /// Its colour.
  final AnnotationColor color;
}

/// What a link change sets; null leaves it.
final class LinkChange {
  /// A change.
  const new({this.rect, this.destination, this.look, this.color});

  /// A new box.
  final Rect? rect;

  /// A new target, which replaces what the link did.
  final LinkDestination? destination;

  /// A new border.
  final LinkLook? look;

  /// Its colour.
  final AnnotationColor? color;
}

/// What a place to fill on a page without fields is (a5-4).
enum FillTargetKind {
  /// A line: text goes on its baseline.
  line,

  /// A box to write in.
  box,

  /// A small square: a click checks it.
  check,

  /// A row of equal cells, one character each.
  comb,
}

/// One place to fill, in displayed points.
@immutable
class FillTarget {
  /// Creates a target.
  const new({required this.kind, required this.rect, this.cells = 1});

  /// What it is.
  final FillTargetKind kind;

  /// Its box: a line's stroke, a comb's cells together.
  final Rect rect;

  /// A comb's cells; 1 for the others.
  final int cells;
}

/// The places to fill on a page.
@immutable
class FillTargets {
  /// Creates the list.
  const new({this.targets = const [], this.truncated = false});

  /// From the top down, then left to right.
  final List<FillTarget> targets;

  /// Whether a limit cut the list short.
  final bool truncated;
}

/// A typed-signature style and whether it can write a name (M4 decision
/// 23, G158).
@immutable
class HandwritingStyle {
  /// Creates a style.
  const new({required this.family, required this.covered});

  /// Its family: Caveat, Dancing Script or Homemade Apple.
  final String family;

  /// It has every letter of the name; one that has not is not offered.
  final bool covered;
}

/// [AnnotationInfo.icon] of a simple signature's stamp, and of initials'.
const String signatureStampName = 'FermanSignature';

/// See [signatureStampName].
const String initialsStampName = 'FermanInitials';

/// What a simple signature is drawn from.
sealed class SignatureInk {
  const new();
}

/// A name typed in a handwriting style.
final class TypedInk extends SignatureInk {
  /// Creates typed ink.
  const new({required this.text, required this.family});

  /// The name.
  final String text;

  /// The style's family, one of [HandwritingStyle.family].
  final String family;
}

/// Strokes from the signature pad, in its units with y down; the engine
/// crops them to their ink.
final class DrawnInk extends SignatureInk {
  /// Creates drawn ink.
  const new({required this.strokes, required this.width});

  /// Each stroke's points.
  final List<List<Offset>> strokes;

  /// The pen's width, in the pad's units.
  final double width;
}

/// A photo or scan: its paper is made transparent and it is cropped to its
/// ink, within the image limits.
final class ImageInk extends SignatureInk {
  /// Creates image ink.
  const new(this.bytes);

  /// The PNG, JPEG, TIFF, WebP or GIF file's bytes.
  final Uint8List bytes;
}

/// A simple signature or initials to place, in displayed points: a stamp
/// annotation, never a digital signature (M4 decisions 20 and 21).
@immutable
class NewSignature {
  /// Creates a signature.
  const new({
    required this.rect,
    required this.ink,
    required this.color,
    required this.author,
    this.tilt = 0,
    this.initials = false,
    this.field,
  });

  /// Its box before its tilt; the ink is fitted into it.
  final Rect rect;

  /// What it is drawn from.
  final SignatureInk ink;

  /// A typed or drawn signature's colour.
  final AnnotationColor color;

  /// Its author.
  final String author;

  /// Its turn in degrees; negative turns anticlockwise.
  final double tilt;

  /// Initials rather than a signature.
  final bool initials;

  /// The full name of the signature field it signs.
  final String? field;
}

/// A saved signature file in the app data directory (M4 decision 22): the
/// app owns its format.
@immutable
class SavedSignatureFile {
  /// Creates a file.
  const new({required this.name, required this.bytes});

  /// Its file name.
  final String name;

  /// What the app wrote.
  final Uint8List bytes;
}

/// Save as's options (a1-11, B138).
@immutable
class SaveAsOptions {
  /// Creates options; the default writes what Save writes.
  const new({this.includeComments = true, this.removeHistory = false});

  /// "Include comments and markup". Without it the file has no markup
  /// annotations and the document keeps its own file, as for a copy.
  final bool includeComments;

  /// "Remove edit history from the file": rewritten whole, without earlier
  /// revisions or deleted pages; it breaks signatures.
  final bool removeHistory;
}

/// a9-1's presets; Custom… has no form drawn (B182).
enum CompressPreset {
  /// Images at 300 ppi, for printing.
  highQuality,

  /// Images at 150 ppi, for sharing and reading on screen.
  balanced,

  /// Images at 96 ppi, for e-mail.
  smallest,
}

/// A preset's estimated result.
@immutable
class CompressEstimate {
  /// Creates an estimate.
  const new({
    required this.preset,
    required this.after,
    this.exact = false,
    this.sampled = 0,
  });

  /// The preset.
  final CompressPreset preset;

  /// The estimated size after, in bytes.
  final int after;

  /// Whether every image was recompressed for it.
  final bool exact;

  /// How many images it recompressed ("Estimated from …").
  final int sampled;
}

/// What Compress would do to a document (a9-1).
@immutable
class CompressAnalysis {
  /// Creates an analysis.
  const new({
    required this.before,
    this.estimates = const [],
    this.images = 0,
    this.unreadable = 0,
    this.masks = 0,
    this.patterns = 0,
    this.duplicateFonts = 0,
    this.thumbnails = 0,
    this.signed = false,
  });

  /// The size now, in bytes.
  final int before;

  /// High quality, Balanced and Smallest, in that order.
  final List<CompressEstimate> estimates;

  /// The images it may recompress.
  final int images;

  /// Images in a format or colour it does not decode, left as they are.
  final int unreadable;

  /// Masks and images with a colour-key mask, left as they are.
  final int masks;

  /// Images drawn only through patterns, left as they are.
  final int patterns;

  /// Duplicate font copies merged.
  final int duplicateFonts;

  /// Pages whose thumbnail goes.
  final int thumbnails;

  /// Whether the document is signed: warn first; the copy has no signatures.
  final bool signed;
}

/// What made a version (a9-8).
enum VersionKind {
  /// The file as it was opened, before the first save.
  opened,

  /// A save.
  saved,

  /// A save with a new simple signature.
  signed,

  /// Unsaved work kept before a restore.
  unsaved,

  /// A restore.
  restored,
}

/// A version as a9-8's timeline shows it.
@immutable
class VersionInfo {
  /// Creates a version.
  const new({
    required this.id,
    required this.kind,
    required this.time,
    required this.size,
    this.edits = 0,
    this.names = const [],
  });

  /// Its id.
  final int id;

  /// What made it.
  final VersionKind kind;

  /// When, in milliseconds since the Unix epoch.
  final int time;

  /// Its size in bytes.
  final int size;

  /// How many edits it holds since the version before.
  final int edits;

  /// Their names; empty for an encrypted document (decision 28).
  final List<String> names;
}

/// One rendered page of a print (a9-6), for the platform's print channel.
@immutable
class PrintPage {
  /// Creates a page.
  const new({
    required this.index,
    required this.widthPoints,
    required this.heightPoints,
    required this.dpi,
    required this.width,
    required this.height,
    required this.pixels,
  });

  /// Its index in the document, from 0.
  final int index;

  /// Its width as displayed, in points.
  final double widthPoints;

  /// Its height as displayed, in points.
  final double heightPoints;

  /// The resolution it is rendered at.
  final int dpi;

  /// Its width in device pixels.
  final int width;

  /// Its height in device pixels.
  final int height;

  /// 8-bit BGRA, opaque, the top row first.
  final Uint8List pixels;
}
