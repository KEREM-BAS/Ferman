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

  /// Closes a document and ends its views. Its recovery files stay for the
  /// next launch to offer (ARCHITECTURE §7.6).
  Future<void> close(int document);

  /// Closes a document after "Don't save": as [close], and its recovery
  /// files are deleted.
  Future<void> closeDiscarding(int document);

  /// Starts crash recovery in [root], the app data directory's recovery
  /// folder (`recoveryDirectory`); again with the same root it does nothing.
  /// From then on every edited document keeps a journal there until it is
  /// saved or closed with [closeDiscarding].
  Future<void> startRecovery(String root);

  /// Turns the recovery files on or off ("Save a recovery copy every
  /// minute", a11-1c); off, the engine deletes them within a second.
  Future<void> setRecoveryEnabled({required bool enabled});

  /// The documents that sessions which ended without cleaning up left
  /// recovery files for (a1-12); empty before [startRecovery].
  Future<List<RecoverableDocument>> listRecoverable();

  /// Opens [document] of the crashed [session] with its unsaved changes as
  /// one unsaved step; the file on disk is unchanged. An encrypted one needs
  /// [password] again: [EngineErrorKind.passwordRequired] without it, then
  /// [EngineErrorKind.wrongPassword]. When the original changed, the
  /// document saves to a new name beside it (a11-7f).
  Future<RestoredDocument> restoreRecovered(
    String session,
    String document, {
    String? password,
  });

  /// Deletes the recovery files of [document] of [session], or of the
  /// whole session without one (Discard in a1-12).
  Future<void> discardRecovery(String session, {String? document});

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

  /// Replaces the whole text of the [transaction]'s block with [text]; returns
  /// the page as it would read. One piece per line of a left-aligned or
  /// justified block, separated by line feeds, rewrites the changed lines in
  /// place; any other text is laid out again in the block's frame, a line
  /// feed ending a paragraph. Text that needs more lines than the frame holds
  /// comes back with [EditPreview.overflow] and "Keep and warn" applied, which
  /// a commit keeps unless [resolveOverflow] picks another choice.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.unsupported] for text
  /// the engine cannot write yet, such as right-to-left lines.
  Future<EditPreview> applyEdit(int transaction, String text);

  /// Writes the [transaction]'s newest text again with the overflow
  /// [choice]; the transaction stays open.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] when the
  /// text does not overflow or [choice] is disabled.
  Future<EditPreview> resolveOverflow(int transaction, OverflowChoice choice);

  /// Sets where the fonts for missing glyphs come from, and "Ask each time"
  /// (a11-1c). The fonts are indexed again the next time an edit needs them.
  Future<void> setFontSettings(FontSettings settings);

  /// Draws the characters missing-glyph step 3 offers candidates for in the
  /// candidate [postscriptName] of [origin] (a3-3b); the choice holds for
  /// the rest of the [transaction].
  ///
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] when no
  /// text waits for a font or the font cannot draw every character.
  Future<EditPreview> chooseFont(
    int transaction,
    FontOrigin origin,
    String postscriptName,
  );

  /// Keeps step 3's characters in the closest candidate ("Keep as is"), or
  /// draws them in it after "Ask each time".
  ///
  /// Throws an [EngineException] as [chooseFont] does.
  Future<EditPreview> keepAsIs(int transaction);

  /// Commits the [transaction] as the history step [name], dropping the
  /// steps undone. A transaction that changed nothing adds no step.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] while
  /// step 3's characters wait for [chooseFont] or [keepAsIs]; the
  /// transaction stays open.
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
  /// update, written safely (ADR 0008); after [optimizeAndClean] the file is
  /// rewritten whole.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.fileChangedOnDisk]
  /// when the file changed since it was opened or saved, unless [overChange]
  /// ("Keep mine", a11-7b), and with the save failures of ARCHITECTURE §7.8
  /// ([EngineErrorKind.diskFull], [EngineErrorKind.permissionDenied],
  /// [EngineErrorKind.fileLocked], [EngineErrorKind.renameFailed],
  /// [EngineErrorKind.volumeGone], [EngineErrorKind.hardLinked],
  /// [EngineErrorKind.notOwner], [EngineErrorKind.io]) and
  /// [EngineException.offersSaveAs]. The file and the edits stay as they were.
  /// "Reload" is closing the document and opening it again.
  Future<void> save(int document, {bool overChange = false});

  /// Saves [document] as the file at [path]; later saves write there.
  Future<void> saveAs(int document, String path);

  /// Saves a copy of [document] as the file at [path]; later saves still
  /// write to its own file.
  Future<void> saveCopy(int document, String path);

  /// Writes a repaired [document] (a1-9) rewritten whole as the file at
  /// [path] (B103). Its own damaged file only with [replaceOriginal], the
  /// person's confirmation; otherwise [EngineErrorKind.invalidInput].
  Future<void> saveRepairedCopy(
    int document,
    String path, {
    bool replaceOriginal = false,
  });

  /// Optimize and clean: the file of [document] rewritten whole, without
  /// earlier revisions and unreferenced objects (ARCHITECTURE §7.3). Ask
  /// [wouldBreakSignatures] and warn first; a signed document needs
  /// [confirmEditSigned].
  Future<void> optimizeAndClean(int document);

  /// Whether [optimizeAndClean] would break signatures of [document] (G35).
  Future<bool> wouldBreakSignatures(int document);

  /// Confirms the first change to the signed [document] ("Edit anyway",
  /// a3-16a). Until then [commitEdit] of a change and every write of it throw
  /// an [EngineException] with [EngineErrorKind.confirmationRequired], but for
  /// [saveCopy] of the unchanged file to another path and
  /// [saveUnsignedCopy]. Holds until the document closes; the engine keeps it,
  /// so the returned token is not passed back.
  Future<int> confirmEditSigned(int document);

  /// The working copy of "Edit a copy" (a3-16a): [document] rewritten whole
  /// as the file at [path] without its signatures, which the app then opens
  /// in a new tab. The document and its file stay as they are.
  Future<void> saveUnsignedCopy(int document, String path);

  /// Whether the file of [document] changed on disk since it was opened or
  /// saved; asked when the window regains focus (a11-7b).
  Future<bool> checkExternalChange(int document);

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
  Future<void> closeDiscarding(int document) async => throw error;

  @override
  Future<void> startRecovery(String root) async => throw error;

  @override
  Future<void> setRecoveryEnabled({required bool enabled}) async => throw error;

  @override
  Future<List<RecoverableDocument>> listRecoverable() async => throw error;

  @override
  Future<RestoredDocument> restoreRecovered(
    String session,
    String document, {
    String? password,
  }) async => throw error;

  @override
  Future<void> discardRecovery(String session, {String? document}) async =>
      throw error;

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
  Future<EditPreview> resolveOverflow(
    int transaction,
    OverflowChoice choice,
  ) async => throw error;

  @override
  Future<void> setFontSettings(FontSettings settings) async => throw error;

  @override
  Future<EditPreview> chooseFont(
    int transaction,
    FontOrigin origin,
    String postscriptName,
  ) async => throw error;

  @override
  Future<EditPreview> keepAsIs(int transaction) async => throw error;

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
  Future<void> save(int document, {bool overChange = false}) async =>
      throw error;

  @override
  Future<void> saveAs(int document, String path) async => throw error;

  @override
  Future<void> saveCopy(int document, String path) async => throw error;

  @override
  Future<void> saveRepairedCopy(
    int document,
    String path, {
    bool replaceOriginal = false,
  }) async => throw error;

  @override
  Future<void> optimizeAndClean(int document) async => throw error;

  @override
  Future<bool> wouldBreakSignatures(int document) async => throw error;

  @override
  Future<int> confirmEditSigned(int document) async => throw error;

  @override
  Future<void> saveUnsignedCopy(int document, String path) async => throw error;

  @override
  Future<bool> checkExternalChange(int document) async => throw error;

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
