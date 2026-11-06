import 'dart:ui' show Offset, Rect;

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

  /// The folder [startRecovery] was given, or null before it: where the
  /// recovery copies are kept (a11-1c's Saving group).
  String? get recoveryRoot;

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
  /// document saves to a new name beside it, with [suffix] in the app's
  /// language in place of "recovered" (a11-7f).
  Future<RestoredDocument> restoreRecovered(
    String session,
    String document, {
    String? password,
    String? suffix,
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

  /// What the fonts of [document] need said beyond their status (a2-7): the
  /// family drawn instead of one that is not embedded and which of [letters]
  /// a subset cannot draw in an edit, read from the first page each font is
  /// used on. A font with nothing to say has no entry.
  Future<List<FontCoverage>> fontCoverage(int document, String letters);

  /// Sets the language of the [transaction]'s block to [tag], stored as
  /// `/Lang` around its operators; the transaction stays open (a3-14).
  ///
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] for a
  /// tag that is not one, [EngineErrorKind.unsupported] for a block that
  /// cannot be marked.
  Future<EditPreview> setBlockLanguage(int transaction, String tag);

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

  /// Gives the [transaction]'s block [style] (a3-2), laid out again in its
  /// frame; what the transaction set before stays. A font that cannot draw
  /// the block leaves it as it was, and [EditPreview.missing] names what the
  /// font lacks.
  ///
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] for
  /// numbers out of range and [EngineErrorKind.unsupported] for a style the
  /// block cannot take (a vertical block, another font for right-to-left
  /// text or in a form).
  Future<EditPreview> setBlockStyle(int transaction, BlockStyle style);

  /// Moves the [transaction]'s block by [by], in the page's displayed points.
  ///
  /// Throws an [EngineException] as [setBlockStyle] does.
  Future<EditPreview> moveBlock(int transaction, Offset by);

  /// Gives the [transaction]'s block the box [frame], in the page's displayed
  /// points, its text reflowed in it (B016). Text that no longer fits comes
  /// back with [EditPreview.overflow], as [applyEdit] gives it.
  ///
  /// Throws an [EngineException] as [setBlockStyle] does.
  Future<EditPreview> resizeBlock(int transaction, Rect frame);

  /// What the text panel shows of [block] of [page]; null for a block without
  /// glyphs on the page.
  Future<BlockStyleInfo?> blockStyle(int document, int page, int block);

  /// The fonts the text panel's font field offers for [block], best first.
  Future<List<FontCandidate>> blockFonts(int document, int page, int block);

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

  /// Reverts history step [step] of [document] alone, as the new step [name]
  /// that Undo takes back (a3-12). When later steps depend on it, nothing
  /// changes and they come back, unless [withDependents] reverts them too
  /// (a3-12b).
  ///
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] for a
  /// step that does not apply or while a transaction is open.
  Future<Reverted> revert(
    int document,
    int step,
    String name, {
    bool withDependents = false,
  });

  /// Takes [document] back to how it opened, as the new step [name] that
  /// Undo takes back (a3-12b).
  Future<RevisionInfo> revertAll(int document, String name);

  /// The history of [document] (a3-10).
  Future<EditHistory> history(int document);

  /// Writes [text] to [path] through the safe write (a3-12's Export list);
  /// with [staging], as [saveAttachment], the staged file's path comes back.
  Future<String?> saveText(String path, String text, {String? staging});

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
  ///
  /// With [staging] (the macOS App Sandbox's replacement directory, ADR 0008)
  /// this and every save below stops short of the file: the checked temp file
  /// stays there and its path is returned for the platform to swap in, and
  /// [finishSave] ends the save.
  /// "Reload" is closing the document and opening it again.
  Future<String?> save(
    int document, {
    bool overChange = false,
    String? staging,
  });

  /// Ends a save staged with `staging` once the platform tried the swap:
  /// [swapped], it counts as saved; otherwise [document] and its edits stay
  /// as they were and the staged file goes. Whether the last recovery write
  /// failed ([EngineException.noRecoveryCopy]).
  Future<bool> finishSave(int document, {required bool swapped});

  /// Saves [document] as the file at [path]; later saves write there.
  Future<String?> saveAs(int document, String path, {String? staging});

  /// Saves a copy of [document] as the file at [path]; later saves still
  /// write to its own file.
  Future<String?> saveCopy(int document, String path, {String? staging});

  /// Writes a repaired [document] (a1-9) rewritten whole as the file at
  /// [path] (B103). Its own damaged file only with [replaceOriginal], the
  /// person's confirmation; otherwise [EngineErrorKind.invalidInput].
  Future<String?> saveRepairedCopy(
    int document,
    String path, {
    bool replaceOriginal = false,
    String? staging,
  });

  /// Optimize and clean: the file of [document] rewritten whole, without
  /// earlier revisions and unreferenced objects (ARCHITECTURE §7.3). Ask
  /// [wouldBreakSignatures] and warn first; a signed document needs
  /// [confirmEditSigned].
  Future<String?> optimizeAndClean(int document, {String? staging});

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
  Future<String?> saveUnsignedCopy(
    int document,
    String path, {
    String? staging,
  });

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
  String? get recoveryRoot => null;

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
    String? suffix,
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
  Future<List<FontCoverage>> fontCoverage(int document, String letters) async =>
      throw error;

  @override
  Future<EditPreview> setBlockLanguage(int transaction, String tag) async =>
      throw error;

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
  Future<EditPreview> setBlockStyle(int transaction, BlockStyle style) async =>
      throw error;

  @override
  Future<EditPreview> moveBlock(int transaction, Offset by) async =>
      throw error;

  @override
  Future<EditPreview> resizeBlock(int transaction, Rect frame) async =>
      throw error;

  @override
  Future<BlockStyleInfo?> blockStyle(int document, int page, int block) async =>
      throw error;

  @override
  Future<List<FontCandidate>> blockFonts(
    int document,
    int page,
    int block,
  ) async => throw error;

  @override
  Future<RevisionInfo> undo(int document) async => throw error;

  @override
  Future<RevisionInfo> redo(int document) async => throw error;

  @override
  Future<Reverted> revert(
    int document,
    int step,
    String name, {
    bool withDependents = false,
  }) async => throw error;

  @override
  Future<RevisionInfo> revertAll(int document, String name) async =>
      throw error;

  @override
  Future<EditHistory> history(int document) async => throw error;

  @override
  Future<String?> saveText(String path, String text, {String? staging}) async =>
      throw error;

  @override
  Future<String?> save(
    int document, {
    bool overChange = false,
    String? staging,
  }) async => throw error;

  @override
  Future<bool> finishSave(int document, {required bool swapped}) async =>
      throw error;

  @override
  Future<String?> saveAs(int document, String path, {String? staging}) async =>
      throw error;

  @override
  Future<String?> saveCopy(
    int document,
    String path, {
    String? staging,
  }) async => throw error;

  @override
  Future<String?> saveRepairedCopy(
    int document,
    String path, {
    bool replaceOriginal = false,
    String? staging,
  }) async => throw error;

  @override
  Future<String?> optimizeAndClean(int document, {String? staging}) async =>
      throw error;

  @override
  Future<bool> wouldBreakSignatures(int document) async => throw error;

  @override
  Future<int> confirmEditSigned(int document) async => throw error;

  @override
  Future<String?> saveUnsignedCopy(
    int document,
    String path, {
    String? staging,
  }) async => throw error;

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
