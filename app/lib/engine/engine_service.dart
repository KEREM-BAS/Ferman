import 'dart:ui' show Offset;

import 'package:ferman/engine/engine_models.dart';

export 'package:ferman/engine/engine_models.dart';

/// The app's only way to reach the Rust engine. Feature code depends on this
/// interface; the bridge implementation lives in `engine_service_frb.dart`
/// and tests use `FakeEngineService`.
abstract interface class EngineService {
  /// The API version the engine speaks. The only synchronous engine call.
  EngineApiVersion apiVersion();

  /// Versions and build facts of the running engine, including PDFium.
  ///
  /// Throws an [EngineException] when the engine reports an error.
  Future<EngineStatus> status();

  /// Opens the PDF at [path], with [password] if it is encrypted. Without
  /// the password an encrypted file fails with
  /// [EngineErrorKind.passwordRequired]; open it again with the password.
  ///
  /// Throws an [EngineException] with the kind of the file's problem.
  Future<OpenedDocument> open(String path, {String? password});

  /// Closes a document and ends its views.
  Future<void> close(int document);

  /// Lifts [document]'s restrictions for the session with its owner
  /// [password] (a2-10, G106): its security after, or null when it is not
  /// encrypted.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.wrongPassword] for
  /// another password.
  Future<Security?> unlockOwner(int document, String password);

  /// Shows the layers of [document] whose [visible] is true and hides the
  /// others, in the order of its [OpenedDocument.layers], in every view.
  /// Returns every page's new render key: bitmaps with an older one show the
  /// layers as they were.
  ///
  /// Throws an [EngineException] when the document's layers cannot be
  /// switched ([OpenedDocument.layersSwitchable]).
  Future<int> showLayers(int document, List<bool> visible);

  /// Saves the file attached to [document] as its [OpenedDocument.attachments]
  /// at [index] at [path] (a2-3b, B110), written safely: a temp file
  /// flushed, read back and renamed over [path] (ADR 0008). With [staging]
  /// (the macOS App Sandbox's replacement directory) the verified temp file
  /// stays there and its path is returned for the platform to swap in.
  ///
  /// Throws an [EngineException] when it cannot be read or written.
  Future<String?> saveAttachment(
    int document,
    int index,
    String path, {
    String? staging,
  });

  /// Searches [document] for [query]: each page's matches as they are found,
  /// the progress, then [SearchDone]. Cancelling the subscription stops the
  /// search.
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  );

  /// The text blocks of [page] of [document] in reading order, with their
  /// editability (ARCHITECTURE §3.5). The UI hit-tests their frames itself.
  ///
  /// Throws an [EngineException] for a page the document does not have.
  Future<PageBlocks> textBlocks(int document, int page);

  /// The caret in [block] of [page] nearest [point], in the page's displayed
  /// points.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.notFound] for a block
  /// the page does not have.
  Future<BlockCaret> caretAt(int document, int page, int block, Offset point);

  /// What a selection from [anchor] to [focus] on [page] covers, in reading
  /// order; either end may come first.
  Future<PageSelection> selection(
    int document,
    int page,
    BlockPosition anchor,
    BlockPosition focus,
  );

  /// Opens the transaction that edits [block] of [page] of [document]
  /// (ARCHITECTURE §3.6); returns its handle. A document has one at a time.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.notEditable] and the
  /// reason's message for text or a document that cannot be edited, and with
  /// [EngineErrorKind.invalidInput] while another transaction is open.
  Future<int> beginEdit(int document, int page, int block);

  /// Replaces the whole text of the [transaction]'s block with [text], its
  /// lines separated by line feeds, one per line of the block; returns the
  /// page as it would read.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.unsupported] for text
  /// the engine cannot write yet, such as another number of lines.
  Future<EditPreview> applyEdit(int transaction, String text);

  /// Commits the [transaction] as the history step [name], dropping the
  /// steps undone. A transaction that changed nothing adds no step.
  Future<RevisionInfo> commitEdit(int transaction, String name);

  /// Discards the [transaction]; the history does not change.
  Future<RevisionInfo> rollbackEdit(int transaction);

  /// Steps [document] back one step of its history.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] at the
  /// start of the history or while a transaction is open.
  Future<RevisionInfo> undo(int document);

  /// Steps [document] forward one step undone.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] with
  /// nothing to redo or while a transaction is open.
  Future<RevisionInfo> redo(int document);

  /// The history of [document] (a3-10).
  Future<EditHistory> history(int document);

  /// Saves the committed steps of [document] to its file as an incremental
  /// update, written safely (ADR 0008).
  Future<void> save(int document);

  /// Saves [document] as the file at [path]; later saves write there.
  Future<void> saveAs(int document, String path);

  /// Opens a view of [document] that renders nothing until [requestView].
  Future<EngineView> openView(int document);

  /// Replaces what [view] wants rendered, in priority order. A [generation]
  /// no newer than the view's last one is ignored.
  Future<void> requestView(int view, int generation, List<WantedItem> wanted);

  /// Closes a view; its updates end.
  Future<void> closeView(int view);

  /// The order of [texts] in the language of [locale], a BCP 47 tag such as
  /// `tr`: their indices, first to last (ICU4X's collator, ADR 0021). Digits
  /// compare by their value and equal texts keep their order.
  Future<List<int>> collationOrder(String locale, List<String> texts);
}

/// Why the engine could not be used.
enum EngineUnavailableReason {
  /// The engine library could not be loaded.
  libraryMissing,

  /// The engine speaks an API version the app does not accept.
  apiMismatch,

  /// This platform has no engine yet (the web build until phase 5).
  unsupportedPlatform,
}

/// Thrown by [EngineService] calls when the engine cannot be used at all.
class EngineUnavailableException implements Exception {
  /// Creates an exception.
  const new(this.reason, {this.engineApiVersion});

  /// Why the engine is unavailable.
  final EngineUnavailableReason reason;

  /// The version the engine reported, for
  /// [EngineUnavailableReason.apiMismatch].
  final EngineApiVersion? engineApiVersion;

  @override
  String toString() => 'EngineUnavailableException($reason)';
}

/// The [EngineService] used when the engine could not be started: every call
/// throws the [EngineUnavailableException] that explains why, so the app
/// still opens and can tell the person what is wrong.
class UnavailableEngineService implements EngineService {
  /// Creates a service that fails with [error].
  const new(this.error);

  /// Why the engine is unavailable.
  final EngineUnavailableException error;

  @override
  EngineApiVersion apiVersion() => throw error;

  @override
  Future<EngineStatus> status() async => throw error;

  @override
  Future<OpenedDocument> open(String path, {String? password}) async =>
      throw error;

  @override
  Future<void> close(int document) async => throw error;

  @override
  Future<Security?> unlockOwner(int document, String password) async =>
      throw error;

  @override
  Future<int> showLayers(int document, List<bool> visible) async => throw error;

  @override
  Future<String?> saveAttachment(
    int document,
    int index,
    String path, {
    String? staging,
  }) async => throw error;

  @override
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  ) => Stream.error(error);

  @override
  Future<PageBlocks> textBlocks(int document, int page) async => throw error;

  @override
  Future<BlockCaret> caretAt(
    int document,
    int page,
    int block,
    Offset point,
  ) async => throw error;

  @override
  Future<PageSelection> selection(
    int document,
    int page,
    BlockPosition anchor,
    BlockPosition focus,
  ) async => throw error;

  @override
  Future<int> beginEdit(int document, int page, int block) async => throw error;

  @override
  Future<EditPreview> applyEdit(int transaction, String text) async =>
      throw error;

  @override
  Future<RevisionInfo> commitEdit(int transaction, String name) async =>
      throw error;

  @override
  Future<RevisionInfo> rollbackEdit(int transaction) async => throw error;

  @override
  Future<RevisionInfo> undo(int document) async => throw error;

  @override
  Future<RevisionInfo> redo(int document) async => throw error;

  @override
  Future<EditHistory> history(int document) async => throw error;

  @override
  Future<void> save(int document) async => throw error;

  @override
  Future<void> saveAs(int document, String path) async => throw error;

  @override
  Future<EngineView> openView(int document) async => throw error;

  @override
  Future<void> requestView(
    int view,
    int generation,
    List<WantedItem> wanted,
  ) async => throw error;

  @override
  Future<void> closeView(int view) async => throw error;

  @override
  Future<List<int>> collationOrder(String locale, List<String> texts) async =>
      throw error;
}
