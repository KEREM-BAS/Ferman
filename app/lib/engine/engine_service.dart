import 'dart:typed_data';
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

  /// Copies [document] as its revisions stand now to the new file [output] as
  /// a background job (ARCHITECTURE §3.7). The stream's first update has the
  /// job's handle and its last says how it ended; cancelling the subscription
  /// does not stop the job. With [staging] (the macOS App Sandbox) the file
  /// waits there for the swap.
  Stream<JobUpdate> copyDocumentJob(
    int document,
    String output, {
    String? staging,
  });

  /// Commits the change a job prepared ([insertPagesJob], [replacePagesJob]) as
  /// one step; refused if the document moved since the job read it.
  Future<RevisionInfo> applyJobChange(int job);

  /// What Combine would write for [files], with a row per input (a6-3).
  Future<CombinePreview> combinePreview(
    List<CombineInput> files, {
    required bool keepForms,
  });

  /// Writes [files] as the new file [output] as a job: Combine, and Create PDF
  /// from a blank page or files. An output is unencrypted and carries no
  /// signature.
  Stream<JobUpdate> combineJob(
    List<CombineInput> files, {
    required bool keepForms,
    required ImagePaper paper,
    required String output,
    String? staging,
  });

  /// Writes [pages] of [document] as the new file [output] as a job, which
  /// reports the revision it read.
  Stream<JobUpdate> extractPagesJob(
    int document,
    List<int> pages, {
    required String output,
    String? staging,
  });

  /// The files a split of [document] would write (a6-2). [amount] is the pages
  /// per file for [SplitKind.everyPages] and the bytes for [SplitKind.size].
  /// [template] takes `{document}`, `{bookmark}` and `{n}`. With [folder],
  /// names stay free in it.
  Future<SplitPreview> splitPreview(
    int document, {
    required SplitKind kind,
    required String template,
    int amount = 0,
    String? folder,
  });

  /// Writes [files], as [splitPreview] planned them, into [folder] as a job,
  /// which reports the revision it read.
  Stream<JobUpdate> splitJob(
    int document,
    List<SplitFile> files, {
    required String folder,
    String? staging,
  });

  /// Reads [pages] (null for all) of the PDF or image at [path] as a job; once
  /// done, [applyJobChange] inserts them after the page [after], or first when
  /// null, as one step.
  Stream<JobUpdate> insertPagesJob(
    int document, {
    required String path,
    required int? after,
    required ImagePaper paper,
    required String name,
    String? password,
    List<int>? pages,
  });

  /// Reads [sourcePages] (null for all) of the PDF at [path] as a job; once
  /// done, [applyJobChange] puts them in the place of [pages] as one step, each
  /// keeping a replaced page's handle, bookmarks and label.
  Stream<JobUpdate> replacePagesJob(
    int document,
    List<int> pages, {
    required String path,
    required String name,
    String? password,
    List<int>? sourcePages,
  });

  /// Parks a job at its next step.
  Future<void> pauseJob(int job);

  /// Lets a paused job go on.
  Future<void> resumeJob(int job);

  /// Cancels a job at its next step; it leaves nothing.
  Future<void> cancelJob(int job);

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

  /// The font families bundled with Ferman and installed on this computer,
  /// bundled first and then by name, scanned off the UI isolate (a11-1d).
  Future<List<InstalledFont>> installedFonts();

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

  /// The annotations of [document] as its committed revisions leave them, in
  /// page order. Links, form widgets and popups are not listed.
  Future<AnnotationList> annotations(int document);

  /// Creates [annotation] on [page], by [PageInfo.handle], as the one step
  /// [name] of the history. Throws an [EngineException] with
  /// [EngineErrorKind.notEditable] when the document's permissions forbid
  /// comments (ask [opGate] with [DocumentOp.comment]),
  /// [EngineErrorKind.confirmationRequired] for a signed document before
  /// [confirmEditSigned], [EngineErrorKind.invalidInput] for a value out of
  /// range or while a transaction is open, and [EngineErrorKind.unsupported]
  /// for text no font here has. So do the other annotation calls.
  Future<AnnotationCommit> addAnnotation(
    int document,
    int page,
    NewAnnotation annotation,
    String name,
  );

  /// Applies [change] to annotation [handle] as one step. Only what changes is
  /// written; a stamp takes a new box and text, an unknown type text only.
  Future<AnnotationCommit> updateAnnotation(
    int document,
    int handle,
    AnnotationChange change,
    String name,
  );

  /// Deletes annotation [handle], with its popup and replies, as one step.
  Future<RevisionInfo> deleteAnnotation(int document, int handle, String name);

  /// Shows or hides every markup annotation of [document] in every view (a4-5):
  /// render-only, never saved. Widgets, links and signatures stay. Returns
  /// every page's new render key.
  Future<int> showComments(int document, {required bool visible});

  /// Flattens annotations [handles] with their replies as a job (a4-5b): with
  /// [copy] it first writes the document as it stands to that new file, and if
  /// that fails nothing changes. Its change waits for [applyJobChange], which
  /// asks for a signed document's confirmation.
  Stream<JobUpdate> flattenAnnotationsJob(
    int document,
    List<int> handles, {
    required String name,
    String? copy,
    String? staging,
  });

  /// Writes the comments of [document] to the new file [output] as a job
  /// (a4-4).
  Stream<JobUpdate> commentSummaryJob(
    int document,
    SummaryFormat format,
    SummaryOptions options, {
    required String output,
    String? staging,
  });

  /// The links of [document] as its committed revisions leave them (a3-6).
  Future<LinkList> links(int document);

  /// The topmost link of the page [page] at [point], in displayed points. It
  /// follows nothing.
  Future<LinkInfo?> linkAt(int document, int page, Offset point);

  /// Creates [link] on the page [page] as one step. Only a web address, an
  /// e-mail address or a page of this document can be its target.
  Future<AnnotationCommit> addLink(
    int document,
    int page,
    NewLink link,
    String name,
  );

  /// Applies [change] to link [handle] as one step; an action Ferman does not
  /// know stays unless the change replaces it.
  Future<AnnotationCommit> updateLink(
    int document,
    int handle,
    LinkChange change,
    String name,
  );

  /// Deletes link [handle] as one step.
  Future<RevisionInfo> deleteLink(int document, int handle, String name);

  /// Replies to annotation [handle] as [author], as one step. Mentions are
  /// text: nothing is sent to anyone.
  Future<AnnotationCommit> replyToAnnotation(
    int document,
    int handle, {
    required String author,
    required String text,
    required String name,
  });

  /// Resolves or reopens the thread of annotation [handle] as [author], as one
  /// step; a thread already so adds none.
  Future<RevisionInfo> setAnnotationResolved(
    int document,
    int handle, {
    required String author,
    required bool resolved,
    required String name,
  });

  /// The form of [document] as its committed revisions leave it, in tab order
  /// (a5-1). Reading generates nothing, so opening changes nothing.
  Future<FormInfo> formFields(int document);

  /// Sets field [handle] to [values] as the one step [name]: text, export
  /// values or a button's on-state, none to empty it. Call it on blur, on Tab
  /// or at the end of a drag, never per keystroke (M4 decision 16).
  /// [missing] answers Ask each time; null follows the font settings. Throws
  /// an [EngineException] as [addAnnotation] does, with
  /// [EngineErrorKind.invalidInput] for a read-only field or a value it cannot
  /// hold; ask [opGate] with [DocumentOp.fill] and the field's name first.
  Future<FieldCommit> setFieldValue(
    int document,
    int handle,
    List<String> values, {
    required String name,
    MissingFont? missing,
  });

  /// Empties every field that holds a value and can change, as one step.
  /// Signatures stay. A list box's options are drawn by the font policy as
  /// a value is, [missing] answering Ask each time.
  Future<FieldCommit> clearForm(
    int document,
    String name, {
    MissingFont? missing,
  });

  /// Finish (G47): every field becomes page content as it looks, as one step;
  /// a digitally signed field stays. A field it draws an appearance for
  /// follows the font policy as [setFieldValue] does, [missing] answering Ask
  /// each time, and the commit says which fonts it took. It asks what editing
  /// asks.
  Future<FieldCommit> finishForm(
    int document,
    String name, {
    MissingFont? missing,
  });

  /// The lines, boxes, check boxes and combs drawn on [page] of [document],
  /// by [PageInfo.handle], for Fill anything (a5-4). Nothing is written; what
  /// is placed on them is a text box ([NewAnnotation.comb] for a comb) or a
  /// mark through [addAnnotation].
  Future<FillTargets> fillTargets(int document, int page);

  /// Whether each typed-signature style can write every letter of [text], in
  /// a5-3's order (M4 decision 23): a style that cannot is not offered.
  Future<List<HandwritingStyle>> handwritingStyles(String text);

  /// Places [signature] on [page] as the one step [name]: a stamp annotation
  /// whose [AnnotationInfo.icon] is [signatureStampName] or
  /// [initialsStampName], naming [NewSignature.field] when it signs one, never
  /// a digital signature. Throws as [addAnnotation] does, and
  /// [EngineErrorKind.unsupported] for a letter its style cannot draw or an
  /// image with no ink.
  Future<AnnotationCommit> addSignature(
    int document,
    int page,
    NewSignature signature,
    String name,
  );

  /// The saved signatures and initials in [directory], a folder of the app
  /// data directory apart from `settings.json` (M4 decision 22), by name.
  Future<List<SavedSignatureFile>> savedSignatures(String directory);

  /// Writes [bytes] as the saved signature [name] in [directory] through the
  /// safe write. [name] takes letters, digits, `-`, `_` and `.`, not first.
  Future<void> writeSavedSignature(
    String directory,
    String name,
    Uint8List bytes,
  );

  /// Deletes the saved signature [name] in [directory].
  Future<void> deleteSavedSignature(String directory, String name);

  /// Turns [pages] of [document], by [PageInfo.handle], by [quarterTurns]
  /// quarter turns, clockwise when positive, as the one step [name] of its
  /// history. Throws an [EngineException] with [EngineErrorKind.notEditable]
  /// when the document's permissions forbid assembling (ask [opGate] with
  /// [DocumentOp.organize]), [EngineErrorKind.confirmationRequired] for a
  /// signed document before [confirmEditSigned], and
  /// [EngineErrorKind.invalidInput] for a page it does not have or while a
  /// transaction is open. So do the other page operations.
  Future<RevisionInfo> rotatePages(
    int document,
    List<int> pages,
    int quarterTurns,
    String name,
  );

  /// Deletes [pages] as one step: they stay in the file until Remove edit
  /// history or Optimize and clean, and what referred to them no longer does.
  /// Throws an [EngineException] with [EngineErrorKind.invalidInput] when no
  /// page would be left.
  Future<RevisionInfo> deletePages(int document, List<int> pages, String name);

  /// Moves [pages], together and in document order, before the page [before],
  /// or to the end when null, as one step. Labels travel with their pages.
  Future<RevisionInfo> movePages(
    int document,
    List<int> pages,
    int? before,
    String name,
  );

  /// Copies [pages] as one step: the copies of pages next to each other
  /// follow the last of them.
  Future<RevisionInfo> duplicatePages(
    int document,
    List<int> pages,
    String name,
  );

  /// Inserts [count] blank pages of [width] by [height] points after the page
  /// [after], or first when null, as one step.
  Future<RevisionInfo> insertBlankPages(
    int document, {
    required int? after,
    required int count,
    required double width,
    required double height,
    required String name,
  });

  /// Gives [pages] the displayed size [width] by [height] points as one step,
  /// with the content as [fit] says (a6-4).
  Future<RevisionInfo> setPageSize(
    int document,
    List<int> pages, {
    required double width,
    required double height,
    required PageFit fit,
    required String name,
  });

  /// Crops each page of [crops], by handle, by its margins as one step:
  /// negative margins give back up to the media box. What is outside stays in
  /// the file, hidden (G57); undo is the way back.
  Future<RevisionInfo> cropPages(
    int document,
    Map<int, PageMargins> crops,
    String name,
  );

  /// The white around the content of each of [pages], for "Remove white
  /// margins" (a6-4): null for a page with no content.
  Future<List<PageMargins?>> whiteMargins(int document, List<int> pages);

  /// The page label ranges of [document], in page order (a6-5).
  Future<List<PageLabelRange>> pageLabelRanges(int document);

  /// Makes [ranges] the page labels of [document] as one step; none removes
  /// them. Throws an [EngineException] with [EngineErrorKind.invalidInput] for
  /// ranges out of order, past the last page or numbered from 0.
  Future<RevisionInfo> setPageLabels(
    int document,
    List<PageLabelRange> ranges,
    String name,
  );

  /// Makes [items] the outline of [document] (a2-3a: rename, add, nest,
  /// reorder, delete) as one step. Throws an [EngineException] with
  /// [EngineErrorKind.invalidInput] for items that cannot apply, and as
  /// [setPageLabels] otherwise ([DocumentOp.organize]).
  Future<RevisionInfo> setOutline(
    int document,
    List<OutlineEdit> items,
    String name,
  );

  /// Makes [info] the information of [document] (a2-7), in `/Info` and its
  /// XMP, as one step ([DocumentOp.modify]). Throws an [EngineException] with
  /// [EngineErrorKind.invalidInput] for a file without an `/Info` object.
  Future<RevisionInfo> setInfo(int document, InfoEdit info, String name);

  /// Attaches the file at [path] to [document] as [fileName] (a2-3b), one
  /// step ([DocumentOp.modify]); its bytes are read now.
  Future<RevisionInfo> attachFile(
    int document,
    String path,
    String fileName,
    String name,
  );

  /// Takes attachment [index] of [OpenedDocument.attachments] out of
  /// [document], one step ([DocumentOp.modify]). A file attachment
  /// annotation's is a comment: [EngineErrorKind.invalidInput].
  Future<RevisionInfo> removeAttachment(int document, int index, String name);

  /// Draws the form widgets of [document] in every view, or leaves them to
  /// Fill & Sign's overlay, which draws each field (B203): render-only, never
  /// saved. Returns every page's new render key, 0 when nothing changes.
  Future<int> showFormWidgets(int document, {required bool visible});

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

  /// Saves [document] as the file at [path] with Save as's [options]
  /// (a1-11); later saves write there, unless the comments are left out.
  Future<String?> saveAs(
    int document,
    String path, {
    SaveAsOptions options = const SaveAsOptions(),
    String? staging,
  });

  /// Saves a copy of [document] as the file at [path] with Save as's
  /// [options]; later saves still write to its own file.
  Future<String?> saveCopy(
    int document,
    String path, {
    SaveAsOptions options = const SaveAsOptions(),
    String? staging,
  });

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
  /// earlier revisions and unreferenced objects (ARCHITECTURE §7.3), as an
  /// engine job (ADR 0009) whose end this awaits. Ask [wouldBreakSignatures]
  /// and warn first; a signed document needs [confirmEditSigned].
  Future<String?> optimizeAndClean(int document, {String? staging});

  /// What Compress would do to [document] as it stands, with each preset's
  /// estimated size (a9-1).
  Future<CompressAnalysis> compressAnalysis(int document);

  /// Compresses [document] with [preset] into the new file [output] as a job.
  /// A signed document needs [unsign], the warning accepted. The last
  /// update's params are facts: `before`, `after`, `written` (a larger result
  /// writes nothing and keeps the original), `recompressed`, `unreadable`.
  Stream<JobUpdate> compressJob(
    int document, {
    required CompressPreset preset,
    required String output,
    bool unsign = false,
    String? staging,
  });

  /// "Keep versions" (a11-1c): off, saves keep no version (ADR 0022).
  Future<void> setVersionsEnabled({required bool enabled});

  /// The versions of [document]'s file, newest first (a9-8).
  Future<List<VersionInfo>> versions(int document);

  /// Opens [version] of [document] read-only from its bytes for the
  /// preview; close it as any document. An encrypted one needs [password].
  Future<OpenedDocument> openVersion(
    int document,
    int version, {
    String? password,
  });

  /// Makes [version] the file of [document] again (decision 27): unsaved
  /// work is kept as a version first, the file is replaced whole after the
  /// external-change check; the app then opens the file again.
  Future<String?> restoreVersion(int document, int version, {String? staging});

  /// The pages of [document] to print (a9-6), all when [pages] is empty, by
  /// handle, rendered one by one in memory for the platform's print channel;
  /// without [includeComments] the markup annotations are hidden. Cancelling
  /// the subscription ends the print. Throws [EngineErrorKind.notEditable]
  /// when the document forbids printing.
  Stream<PrintPage> printPages(
    int document, {
    List<int> pages = const [],
    bool includeComments = true,
  });

  /// Whether [optimizeAndClean] would break signatures of [document] (G35).
  Future<bool> wouldBreakSignatures(int document);

  /// What [op] may do to [document] as it stands (G35). A change to a signed
  /// document needs [confirmEditSigned] even when it keeps the signatures.
  /// [fields] are the full names of the form fields a [DocumentOp.fill] fills,
  /// empty when not known yet.
  Future<OpGate> opGate(
    int document,
    DocumentOp op, {
    List<String> fields = const [],
  });

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

  /// Starts the host AI clients connect to (ADR 0019) in the app data
  /// directory, and returns the folder `ferman-mcp` takes. Throws an
  /// [EngineException] when it cannot listen there, and on the web.
  Future<String> startMcpHost();

  /// Stops the host: every client disconnects and its open transactions
  /// roll back.
  Future<void> stopMcpHost();

  /// The connected AI clients, oldest first.
  Future<List<McpClient>> mcpClients();

  /// Lets [client] change documents, or makes it read only again. Throws an
  /// [EngineException] with [EngineErrorKind.notFound] once it disconnected.
  Future<void> grantClientEdit(int client, {required bool mayEdit});

  /// Every request a client makes of the user, from now on; it replaces the
  /// stream before. Without a listener the engine declines them.
  Stream<ClientRequest> clientRequests();

  /// Whether [request] still waits for the user's answer: false once
  /// answered, or once its client disconnected.
  Future<bool> clientRequestPending(int request);

  /// The user's answer to [request]; nothing happens for one that is gone.
  Future<void> answerClientRequest(int request, {required bool allow});

  /// Every step a client commits, in any document, from now on; it replaces
  /// the stream before.
  Stream<ClientChange> clientChanges();
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
  Stream<JobUpdate> copyDocumentJob(
    int document,
    String output, {
    String? staging,
  }) => Stream.error(error);

  @override
  Future<RevisionInfo> applyJobChange(int job) async => throw error;

  @override
  Future<CombinePreview> combinePreview(
    List<CombineInput> files, {
    required bool keepForms,
  }) async => throw error;

  @override
  Stream<JobUpdate> combineJob(
    List<CombineInput> files, {
    required bool keepForms,
    required ImagePaper paper,
    required String output,
    String? staging,
  }) => Stream.error(error);

  @override
  Stream<JobUpdate> extractPagesJob(
    int document,
    List<int> pages, {
    required String output,
    String? staging,
  }) => Stream.error(error);

  @override
  Future<SplitPreview> splitPreview(
    int document, {
    required SplitKind kind,
    required String template,
    int amount = 0,
    String? folder,
  }) async => throw error;

  @override
  Stream<JobUpdate> splitJob(
    int document,
    List<SplitFile> files, {
    required String folder,
    String? staging,
  }) => Stream.error(error);

  @override
  Stream<JobUpdate> insertPagesJob(
    int document, {
    required String path,
    required int? after,
    required ImagePaper paper,
    required String name,
    String? password,
    List<int>? pages,
  }) => Stream.error(error);

  @override
  Stream<JobUpdate> replacePagesJob(
    int document,
    List<int> pages, {
    required String path,
    required String name,
    String? password,
    List<int>? sourcePages,
  }) => Stream.error(error);

  @override
  Future<void> pauseJob(int job) async => throw error;

  @override
  Future<void> resumeJob(int job) async => throw error;

  @override
  Future<void> cancelJob(int job) async => throw error;

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
  Future<List<InstalledFont>> installedFonts() async => throw error;

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
  Future<FormInfo> formFields(int document) async => throw error;

  @override
  Future<FillTargets> fillTargets(int document, int page) async => throw error;

  @override
  Future<List<HandwritingStyle>> handwritingStyles(String text) async =>
      throw error;

  @override
  Future<AnnotationCommit> addSignature(
    int document,
    int page,
    NewSignature signature,
    String name,
  ) async => throw error;

  @override
  Future<List<SavedSignatureFile>> savedSignatures(String directory) async =>
      throw error;

  @override
  Future<void> writeSavedSignature(
    String directory,
    String name,
    Uint8List bytes,
  ) async => throw error;

  @override
  Future<void> deleteSavedSignature(String directory, String name) async =>
      throw error;

  @override
  Future<FieldCommit> setFieldValue(
    int document,
    int handle,
    List<String> values, {
    required String name,
    MissingFont? missing,
  }) async => throw error;

  @override
  Future<FieldCommit> clearForm(
    int document,
    String name, {
    MissingFont? missing,
  }) async => throw error;

  @override
  Future<FieldCommit> finishForm(
    int document,
    String name, {
    MissingFont? missing,
  }) async => throw error;

  @override
  Future<AnnotationList> annotations(int document) async => throw error;

  @override
  Future<AnnotationCommit> addAnnotation(
    int document,
    int page,
    NewAnnotation annotation,
    String name,
  ) async => throw error;

  @override
  Future<AnnotationCommit> updateAnnotation(
    int document,
    int handle,
    AnnotationChange change,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> deleteAnnotation(
    int document,
    int handle,
    String name,
  ) async => throw error;

  @override
  Future<int> showComments(int document, {required bool visible}) async =>
      throw error;

  @override
  Stream<JobUpdate> flattenAnnotationsJob(
    int document,
    List<int> handles, {
    required String name,
    String? copy,
    String? staging,
  }) => Stream.error(error);

  @override
  Stream<JobUpdate> commentSummaryJob(
    int document,
    SummaryFormat format,
    SummaryOptions options, {
    required String output,
    String? staging,
  }) => Stream.error(error);

  @override
  Future<LinkList> links(int document) async => throw error;

  @override
  Future<LinkInfo?> linkAt(int document, int page, Offset point) async =>
      throw error;

  @override
  Future<AnnotationCommit> addLink(
    int document,
    int page,
    NewLink link,
    String name,
  ) async => throw error;

  @override
  Future<AnnotationCommit> updateLink(
    int document,
    int handle,
    LinkChange change,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> deleteLink(
    int document,
    int handle,
    String name,
  ) async => throw error;

  @override
  Future<AnnotationCommit> replyToAnnotation(
    int document,
    int handle, {
    required String author,
    required String text,
    required String name,
  }) async => throw error;

  @override
  Future<RevisionInfo> setAnnotationResolved(
    int document,
    int handle, {
    required String author,
    required bool resolved,
    required String name,
  }) async => throw error;

  @override
  Future<RevisionInfo> rotatePages(
    int document,
    List<int> pages,
    int quarterTurns,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> deletePages(
    int document,
    List<int> pages,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> movePages(
    int document,
    List<int> pages,
    int? before,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> duplicatePages(
    int document,
    List<int> pages,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> insertBlankPages(
    int document, {
    required int? after,
    required int count,
    required double width,
    required double height,
    required String name,
  }) async => throw error;

  @override
  Future<RevisionInfo> setPageSize(
    int document,
    List<int> pages, {
    required double width,
    required double height,
    required PageFit fit,
    required String name,
  }) async => throw error;

  @override
  Future<RevisionInfo> cropPages(
    int document,
    Map<int, PageMargins> crops,
    String name,
  ) async => throw error;

  @override
  Future<List<PageMargins?>> whiteMargins(
    int document,
    List<int> pages,
  ) async => throw error;

  @override
  Future<List<PageLabelRange>> pageLabelRanges(int document) async =>
      throw error;

  @override
  Future<RevisionInfo> setPageLabels(
    int document,
    List<PageLabelRange> ranges,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> setOutline(
    int document,
    List<OutlineEdit> items,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> setInfo(
    int document,
    InfoEdit info,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> attachFile(
    int document,
    String path,
    String fileName,
    String name,
  ) async => throw error;

  @override
  Future<RevisionInfo> removeAttachment(
    int document,
    int index,
    String name,
  ) async => throw error;

  @override
  Future<int> showFormWidgets(int document, {required bool visible}) async =>
      throw error;

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
  Future<String?> saveAs(
    int document,
    String path, {
    SaveAsOptions options = const SaveAsOptions(),
    String? staging,
  }) async => throw error;

  @override
  Future<String?> saveCopy(
    int document,
    String path, {
    SaveAsOptions options = const SaveAsOptions(),
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
  Future<CompressAnalysis> compressAnalysis(int document) async => throw error;

  @override
  Stream<JobUpdate> compressJob(
    int document, {
    required CompressPreset preset,
    required String output,
    bool unsign = false,
    String? staging,
  }) => Stream.error(error);

  @override
  Future<void> setVersionsEnabled({required bool enabled}) async => throw error;

  @override
  Future<List<VersionInfo>> versions(int document) async => throw error;

  @override
  Future<OpenedDocument> openVersion(
    int document,
    int version, {
    String? password,
  }) async => throw error;

  @override
  Future<String?> restoreVersion(
    int document,
    int version, {
    String? staging,
  }) async => throw error;

  @override
  Stream<PrintPage> printPages(
    int document, {
    List<int> pages = const [],
    bool includeComments = true,
  }) => Stream.error(error);

  @override
  Future<bool> wouldBreakSignatures(int document) async => throw error;

  @override
  Future<OpGate> opGate(
    int document,
    DocumentOp op, {
    List<String> fields = const [],
  }) async => throw error;

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

  @override
  Future<String> startMcpHost() async => throw error;

  @override
  Future<void> stopMcpHost() async {}

  @override
  Future<List<McpClient>> mcpClients() async => const [];

  @override
  Future<void> grantClientEdit(int client, {required bool mayEdit}) async =>
      throw error;

  @override
  Stream<ClientRequest> clientRequests() => const Stream.empty();

  @override
  Future<bool> clientRequestPending(int request) async => false;

  @override
  Future<void> answerClientRequest(int request, {required bool allow}) async {}

  @override
  Stream<ClientChange> clientChanges() => const Stream.empty();
}
