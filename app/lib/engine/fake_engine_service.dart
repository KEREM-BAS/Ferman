import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:ferman/engine/engine_service.dart';

/// An [EngineService] for widget tests and goldens: no native library.
class FakeEngineService implements EngineService {
  /// Creates a fake that reports [status].
  new({
    this.fakeStatus = const EngineStatus(
      appVersion: '0.1.0',
      apiVersion: kAppApiVersion,
      isDebugBuild: true,
      pdfium: PdfiumState.loaded,
      pdfiumTag: 'chromium/7881',
    ),
    this.documents = const {},
    this.failingPages = const {},
    this.searchResults = const {},
    this.textless = false,
    this.failures = const {},
    this.passwords = const {},
    this.ownerPasswords = const {},
    this.holds = const {},
    this.pageBlocks = const {},
    this.overflows = const {},
    this.dependents = const {},
    this.missingGlyphs = const {},
    this.sameFonts = const {},
  });

  /// Madde 6 of kira-tr in a3-3a and a3-3b: EB Garamond has no "ğ"; the
  /// same font is not installed, Plex Serif is offered first and IBM Plex
  /// Sans Arabic covers only part of the text.
  static const madde6Glyphs = MissingGlyphs(
    chars: [MissingChar(text: 'ğ', at: 0)],
    font: 'EBGaramond-Regular',
    candidates: [
      FontCandidate(
        origin: FontOrigin.bundled,
        postscriptName: 'IBMPlexSerif-Regular',
        family: 'IBM Plex Serif',
        covered: 1,
        needed: 1,
        similarity: 0.93,
        preview: 'Ğğ İı Şş Çç Öö Üü',
      ),
      FontCandidate(
        origin: FontOrigin.embedded,
        postscriptName: 'IBMPlexSerif',
        family: 'IBM Plex Serif',
        covered: 1,
        needed: 1,
        similarity: 0.9,
        preview: 'ğ',
      ),
      FontCandidate(
        origin: FontOrigin.bundled,
        postscriptName: 'IBMPlexSansArabic',
        family: 'IBM Plex Sans Arabic',
        covered: 0,
        needed: 1,
        similarity: 0.6,
        usable: false,
        preview: 'ı Çç Öö Üü',
      ),
    ],
  );

  /// The same font found on this computer for kira-tr's Madde 6 (a3-17):
  /// "ğ" from EB Garamond.
  static const madde6SameFont = FontSubstitution(
    kind: SubstitutionKind.sameFont,
    chars: 'ğ',
    fromFont: 'EBGaramond-Regular',
    toFont: 'EBGaramond-Regular',
    origin: FontOrigin.installed,
  );

  /// The blocks, by id, whose font lacks [MissingGlyphs.chars]: text with
  /// one of them goes through step 3 with these candidates (the characters'
  /// offsets are the text's own).
  final Map<int, MissingGlyphs> missingGlyphs;

  /// The blocks, by id, whose missing characters step 2 takes from the same
  /// font: text with one of them carries this substitution.
  final Map<int, FontSubstitution> sameFonts;

  /// The settings [setFontSettings] was given last.
  FontSettings fontSettings = const FontSettings();

  /// The fonts named by a committed substitution, by step.
  final Set<(SubstitutionKind, String)> _announced = {};

  /// The overflow of kira-tr's Madde 4 in a3-18: one line over, Extend
  /// blocked by the IBAN line below, Tighten at −0.6%.
  static const ibanOverflow = OverflowPlan(
    over: 1,
    extendBlocked: ExtendBlocked(
      kind: ExtendBlockedKind.block,
      block: 2,
      text: 'IBAN: TR12 0006 4000 0011 2345 6789 01 · Alıcı: Mert Kaya',
    ),
    tightenPercent: 0.6,
    keepHidden: 1,
  );

  /// The blocks, by id, whose text overflows with this plan when an edit
  /// makes it longer.
  final Map<int, OverflowPlan> overflows;

  /// The table cells, by block id, that depend on each block's value; their
  /// frames come from [pageBlocks].
  final Map<int, List<int>> dependents;

  /// What [textBlocks] returns, by page, for every document; other pages
  /// have no blocks. [caretAt] and [selection] treat every character of a
  /// line as equally wide.
  final Map<int, PageBlocks> pageBlocks;

  /// The status [status] returns.
  final EngineStatus fakeStatus;

  /// The documents [open] opens, by path; any other path is not found.
  final Map<String, OpenedDocument> documents;

  /// The paths whose [open] fails, with the error.
  final Map<String, EngineException> failures;

  /// The passwords of [documents] that need one (a1-8): [open] fails with
  /// `passwordRequired` without it and `wrongPassword` with another.
  final Map<String, String> passwords;

  /// The owner passwords of [documents] by id (a2-10): [unlockOwner]
  /// lifts their restrictions with it and fails with `wrongPassword` with
  /// another.
  final Map<int, String> ownerPasswords;

  /// The paths whose [open] waits for the future, as a slow file does
  /// (a1-7).
  final Map<String, Future<void>> holds;

  /// The documents whose owner password was given.
  final Set<int> ownerUnlocked = {};

  /// Pages whose items fail as damaged.
  final Set<int> failingPages;

  /// What [search] finds, by query: each list is one page's matches.
  final Map<String, List<List<SearchMatch>>> searchResults;

  /// Whether [search] reports that no page has text, as for a scan.
  final bool textless;

  /// The queries and options of every [search], oldest first.
  final List<(String, SearchOptions)> searches = [];

  /// The wanted sets of every [requestView], oldest first.
  final List<List<WantedItem>> requests = [];

  /// The visibilities of every [showLayers], oldest first.
  final List<List<bool>> layerRequests = [];

  /// Each document's render key, from [showLayers].
  final Map<int, int> _renderKeys = {};
  int _lastRenderKey = 0;

  final Map<int, (int, StreamController<ViewUpdate>)> _views = {};
  int _nextView = 1;

  /// How many views are open.
  int get openViewCount => _views.length;

  @override
  EngineApiVersion apiVersion() => fakeStatus.apiVersion;

  @override
  Future<EngineStatus> status() async => fakeStatus;

  @override
  Future<OpenedDocument> open(String path, {String? password}) async {
    await holds[path];
    if (failures[path] case final error?) throw error;
    if (passwords[path] case final expected? when password != expected) {
      throw password == null
          ? const EngineException(
              kind: EngineErrorKind.passwordRequired,
              messageKey: 'errorPasswordRequired',
            )
          : const EngineException(
              kind: EngineErrorKind.wrongPassword,
              messageKey: 'errorWrongPassword',
            );
    }
    return documents[path] ??
        (throw const EngineException(
          kind: EngineErrorKind.notFound,
          messageKey: 'errorFileNotFound',
        ));
  }

  /// The documents closed, oldest first.
  final List<int> closed = [];

  @override
  Future<Security?> unlockOwner(int document, String password) async {
    final opened = documents.values.where((opened) => opened.id == document);
    if (opened.isEmpty) {
      throw const EngineException(
        kind: EngineErrorKind.notFound,
        messageKey: 'errorFileNotFound',
      );
    }
    final security = opened.first.security;
    if (security == null) return null;
    if (ownerPasswords[document] != password) {
      throw const EngineException(
        kind: EngineErrorKind.wrongPassword,
        messageKey: 'errorWrongPassword',
      );
    }
    ownerUnlocked.add(document);
    return Security(
      method: security.method,
      keyBits: security.keyBits,
      userPasswordRequired: security.userPasswordRequired,
      permissions: security.permissions,
      owner: true,
    );
  }

  /// Ends the document's views.
  @override
  Future<void> close(int document) async {
    closed.add(document);
    for (final (owner, updates) in [..._views.values]) {
      if (owner == document) await updates.close();
    }
    _views.removeWhere((_, view) => view.$1 == document);
  }

  /// Records [visible] and gives every page of [document] a new render key.
  @override
  Future<int> showLayers(int document, List<bool> visible) async {
    layerRequests.add(visible);
    return _renderKeys[document] = ++_lastRenderKey;
  }

  /// The attachments [saveAttachment] saved: document, index, path and
  /// staging, oldest first.
  final List<(int, int, String, String?)> savedAttachments = [];

  /// The error [saveAttachment], [save] and [saveAs] throw, if any.
  EngineException? saveFailure;

  /// Records the save; with [staging] it names a staged file there.
  @override
  Future<String?> saveAttachment(
    int document,
    int index,
    String path, {
    String? staging,
  }) async {
    if (saveFailure case final error?) throw error;
    savedAttachments.add((document, index, path, staging));
    return staging == null ? null : '$staging/staged';
  }

  /// Orders [texts] by their code points, stably: no language rules.
  @override
  Future<List<int>> collationOrder(String locale, List<String> texts) async {
    final order = [for (var i = 0; i < texts.length; i++) i]
      ..sort((a, b) {
        final byText = texts[a].compareTo(texts[b]);
        return byText != 0 ? byText : a.compareTo(b);
      });
    return order;
  }

  /// Reports [searchResults] for [query] page by page, then the progress
  /// over every page and [SearchDone].
  @override
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  ) async* {
    searches.add((query, options));
    final pages = documents.values
        .firstWhere((open) => open.id == document)
        .pages
        .length;
    for (final matches in searchResults[query] ?? const <List<SearchMatch>>[]) {
      yield SearchMatches(matches);
    }
    yield SearchProgress(searched: pages, pages: pages);
    yield SearchDone(textless: textless);
  }

  /// The blocks of [page] of [document] as its applied edits left them.
  PageBlocks _blocks(int document, int page) =>
      _edited[(document, page)] ?? pageBlocks[page] ?? const PageBlocks();

  @override
  Future<PageBlocks> textBlocks(int document, int page) async =>
      _blocks(document, page);

  TextBlock _block(int document, int page, int id) =>
      _blocks(
        document,
        page,
      ).blocks.where((block) => block.id == id).firstOrNull ??
      (throw const EngineException(
        kind: EngineErrorKind.notFound,
        messageKey: 'errorInternal',
      ));

  /// Each document's edited pages, as their committed steps left them.
  final Map<(int, int), PageBlocks> _edited = {};

  /// Each document's committed steps, oldest first, and how many apply.
  final Map<int, ({List<_FakeStep> steps, int current})> _histories = {};

  /// The open transactions.
  final Map<int, _FakeTransaction> _transactions = {};
  int _nextTransaction = 1;

  /// The saves: document and the path of a Save as, oldest first.
  final List<(int, String?)> saves = [];

  /// Opens a transaction on a block of [pageBlocks], as the engine does: one
  /// per document, never for a block that cannot be edited.
  @override
  Future<int> beginEdit(int document, int page, int block) async {
    if (_transactions.values.any((open) => open.document == document)) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    final found = _block(document, page, block);
    if (found.notEditable case final reason?) {
      throw EngineException(
        kind: EngineErrorKind.notEditable,
        messageKey: reason.messageKey,
      );
    }
    final id = _nextTransaction++;
    _transactions[id] = _FakeTransaction(document, page, block);
    return id;
  }

  _FakeTransaction _open(int transaction) =>
      _transactions[transaction] ??
      (throw const EngineException(
        kind: EngineErrorKind.notFound,
        messageKey: 'errorInternal',
      ));

  /// Gives the block one line per line of [text]: the old lines' boxes, and
  /// further lines one line pitch below the last. A block of [overflows]
  /// overflows with its plan whenever its text grows, "Keep and warn" until
  /// [resolveOverflow] picks another choice.
  ///
  /// A block of [missingGlyphs] whose text has one of its characters goes
  /// through step 3: with "Ask each time" and no choice the text is not
  /// applied; otherwise the chosen candidate, or the first usable one
  /// provisionally, draws them. A block of [sameFonts] carries its step 2
  /// substitution.
  @override
  Future<EditPreview> applyEdit(int transaction, String text) async {
    final open = _open(transaction)..requested = text;
    final block = _block(open.document, open.page, open.block);
    final missing = _missing(open, text);
    if (missing != null && !missing.drawn) {
      return _preview(open, missing: missing);
    }
    final same = sameFonts[open.block];
    open
      ..text = text
      ..overflow = text.length > block.text.length
          ? overflows[open.block]
          : null
      ..chosen = open.overflow == null ? null : OverflowChoice.keep
      ..pending = open.chosenFont ? null : missing
      ..substitutions = [
        if (same != null &&
            same.chars.runes.map(String.fromCharCode).any(text.contains))
          same,
        if (missing != null)
          FontSubstitution(
            kind: SubstitutionKind.similar,
            chars: {for (final c in missing.chars) c.text}.join(),
            fromFont: missing.font,
            toFont: open.choice!.postscriptName,
            origin: open.choice!.origin,
          ),
      ];
    return _preview(open, missing: open.pending);
  }

  /// Step 3 for [text] in [open]'s block, the characters at their offsets:
  /// drawn in [_FakeTransaction.choice] (set to the first usable candidate
  /// without one, unless "Ask each time"); null without missing characters.
  MissingGlyphs? _missing(_FakeTransaction open, String text) {
    final template = missingGlyphs[open.block];
    if (template == null) return null;
    final letters = {for (final c in template.chars) c.text};
    final chars = [
      for (final (at, unit) in text.codeUnits.indexed)
        if (letters.contains(String.fromCharCode(unit)))
          MissingChar(text: String.fromCharCode(unit), at: at),
    ];
    if (chars.isEmpty) return null;
    final usable = template.candidates.where((c) => c.usable);
    if (!open.chosenFont) {
      open.choice = fontSettings.askEachTime || usable.isEmpty
          ? null
          : usable.first;
    }
    return MissingGlyphs(
      chars: chars,
      font: template.font,
      reason: template.reason,
      reasonFont: template.reasonFont,
      reasonEmbedding: template.reasonEmbedding,
      bold: template.bold,
      italic: template.italic,
      candidates: template.candidates,
      drawn: open.choice != null,
    );
  }

  @override
  Future<void> setFontSettings(FontSettings settings) async {
    fontSettings = settings;
  }

  /// Draws step 3's characters in the candidate [postscriptName] of [origin]
  /// of [missingGlyphs]; one that is not usable is refused.
  @override
  Future<EditPreview> chooseFont(
    int transaction,
    FontOrigin origin,
    String postscriptName,
  ) {
    final open = _open(transaction);
    final candidate = missingGlyphs[open.block]?.candidates
        .where(
          (c) =>
              c.usable &&
              c.origin == origin &&
              c.postscriptName == postscriptName,
        )
        .firstOrNull;
    return _choose(open, candidate);
  }

  @override
  Future<EditPreview> keepAsIs(int transaction) {
    final open = _open(transaction);
    return _choose(
      open,
      missingGlyphs[open.block]?.candidates.where((c) => c.usable).firstOrNull,
    );
  }

  Future<EditPreview> _choose(_FakeTransaction open, FontCandidate? candidate) {
    final text = open.requested;
    if (candidate == null || text == null || _missing(open, text) == null) {
      return Future.error(
        const EngineException(
          kind: EngineErrorKind.invalidInput,
          messageKey: 'errorInternal',
        ),
      );
    }
    open
      ..choice = candidate
      ..chosenFont = true;
    return applyEdit(_transactionOf(open), text);
  }

  int _transactionOf(_FakeTransaction open) =>
      _transactions.entries.firstWhere((entry) => entry.value == open).key;

  @override
  Future<EditPreview> resolveOverflow(
    int transaction,
    OverflowChoice choice,
  ) async {
    final open = _open(transaction);
    if (open.overflow?.allows(choice) != true) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    open.chosen = choice;
    return _preview(open);
  }

  EditPreview _preview(_FakeTransaction open, {MissingGlyphs? missing}) {
    final before = _blocks(open.document, open.page);
    final block = _block(open.document, open.page, open.block);
    final notApplied = missing != null && !missing.drawn;
    final texts = (open.text ?? block.text).split('\n');
    final last = block.lines.last;
    final pitch = block.lines.length > 1
        ? block.lines[1].bbox.top - block.lines[0].bbox.top
        : last.bbox.height;
    final lines = [
      for (final (i, text) in texts.indexed)
        if (i < block.lines.length)
          TextLine(
            text: text,
            bbox: block.lines[i].bbox,
            baselineStart: block.lines[i].baselineStart,
            baselineEnd: block.lines[i].baselineEnd,
          )
        else
          TextLine(
            text: text,
            bbox: last.bbox.shift(
              Offset(0, pitch * (i - block.lines.length + 1)),
            ),
            baselineStart:
                last.baselineStart +
                Offset(0, pitch * (i - block.lines.length + 1)),
            baselineEnd:
                last.baselineEnd +
                Offset(0, pitch * (i - block.lines.length + 1)),
          ),
    ];
    final edited = TextBlock(
      id: block.id,
      frame: lines
          .map((line) => line.bbox)
          .fold(block.frame, (frame, box) => frame.expandToInclude(box)),
      lines: lines,
      alignment: block.alignment,
      direction: block.direction,
    );
    final page = PageBlocks(
      blocks: [
        for (final other in before.blocks)
          if (other.id == block.id) edited else other,
      ],
      empty: before.empty,
    );
    if (open.text != null) open.applied = page;
    return EditPreview(
      page: open.text == null ? before : page,
      missing: notApplied
          ? [
              for (final c in {for (final c in missing.chars) c.text}) c,
            ]
          : const [],
      glyphs: missing,
      substitutions: [
        for (final substitution in open.substitutions)
          FontSubstitution(
            kind: substitution.kind,
            chars: substitution.chars,
            fromFont: substitution.fromFont,
            toFont: substitution.toFont,
            origin: substitution.origin,
            announced: _announced.contains((
              substitution.kind,
              substitution.toFont,
            )),
          ),
      ],
      overflow: open.overflow,
      chosen: open.chosen,
      dependents: [
        for (final id in dependents[open.block] ?? const <int>[])
          for (final cell in before.blocks.where((b) => b.id == id))
            DependentCell(id: id, frame: cell.frame),
      ],
    );
  }

  ({List<_FakeStep> steps, int current}) _history(int document) =>
      _histories[document] ?? (steps: const [], current: 0);

  /// A new render key for every page of [document], as a reload gives.
  RevisionInfo _reloaded(int document) => RevisionInfo(
    current: _history(document).current,
    renderKey: _renderKeys[document] = ++_lastRenderKey,
  );

  /// Refused while step 3's characters are drawn without a choice; the
  /// transaction stays open.
  @override
  Future<RevisionInfo> commitEdit(int transaction, String name) async {
    final open = _open(transaction);
    if (open.pending != null) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    _transactions.remove(transaction);
    final before = _blocks(open.document, open.page);
    final after = open.applied;
    final history = _history(open.document);
    String texts(PageBlocks page) =>
        page.blocks.map((block) => block.text).join('\u0000');
    if (after == null || texts(after) == texts(before)) {
      return RevisionInfo(current: history.current);
    }
    _edited[(open.document, open.page)] = after;
    _histories[open.document] = (
      steps: [
        ...history.steps.take(history.current),
        _FakeStep(
          HistoryStep(
            name: name,
            time: DateTime.now(),
            hiddenLines: open.chosen == OverflowChoice.keep
                ? open.overflow?.keepHidden ?? 0
                : 0,
            substitutions: open.substitutions,
          ),
          open.page,
          before,
          after,
        ),
      ],
      current: history.current + 1,
    );
    final told = [
      for (final substitution in open.substitutions)
        FontSubstitution(
          kind: substitution.kind,
          chars: substitution.chars,
          fromFont: substitution.fromFont,
          toFont: substitution.toFont,
          origin: substitution.origin,
          announced: !_announced.add((substitution.kind, substitution.toFont)),
        ),
    ];
    final reloaded = _reloaded(open.document);
    return RevisionInfo(
      current: reloaded.current,
      renderKey: reloaded.renderKey,
      substitutions: told,
    );
  }

  @override
  Future<RevisionInfo> rollbackEdit(int transaction) async {
    final open = _open(transaction);
    _transactions.remove(transaction);
    return RevisionInfo(current: _history(open.document).current);
  }

  void _closed(int document, {required bool can}) {
    if (!can || _transactions.values.any((o) => o.document == document)) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
  }

  @override
  Future<RevisionInfo> undo(int document) async {
    final history = _history(document);
    _closed(document, can: history.current > 0);
    final step = history.steps[history.current - 1];
    _edited[(document, step.page)] = step.before;
    _histories[document] = (steps: history.steps, current: history.current - 1);
    return _reloaded(document);
  }

  @override
  Future<RevisionInfo> redo(int document) async {
    final history = _history(document);
    _closed(document, can: history.current < history.steps.length);
    final step = history.steps[history.current];
    _edited[(document, step.page)] = step.after;
    _histories[document] = (steps: history.steps, current: history.current + 1);
    return _reloaded(document);
  }

  @override
  Future<EditHistory> history(int document) async {
    final history = _history(document);
    return EditHistory(
      steps: [for (final step in history.steps) step.step],
      current: history.current,
    );
  }

  /// Makes the next document save ([save], [saveAs], [saveCopy],
  /// [saveRepairedCopy], [optimizeAndClean]) fail with [kind], as the engine
  /// reports it: Save as offered for every failure but a file changed on
  /// disk.
  void failNextSave(EngineErrorKind kind) => _nextSaveFailure = EngineException(
    kind: kind,
    messageKey: kind == EngineErrorKind.permissionDenied
        ? 'errorFilePermissionDenied'
        : 'errorFileRead',
    offersSaveAs: kind != EngineErrorKind.fileChangedOnDisk,
  );

  EngineException? _nextSaveFailure;

  /// Documents whose file changed on disk: [checkExternalChange] says so and
  /// [save] fails with [EngineErrorKind.fileChangedOnDisk] until it saves
  /// over the change.
  final Set<int> changedOnDisk = {};

  /// Documents that are signed, for [wouldBreakSignatures].
  final Set<int> signed = {};

  /// The copies [saveCopy] wrote: document and path.
  final List<(int, String)> copies = [];

  /// The repaired copies: document, path and whether it replaced the
  /// original.
  final List<(int, String, bool)> repairedCopies = [];

  /// The documents [optimizeAndClean] rewrote, oldest first.
  final List<int> optimized = [];

  /// Throws [saveFailure], or the failure [failNextSave] set, once.
  void _saving() {
    if (saveFailure case final error?) throw error;
    if (_nextSaveFailure case final error?) {
      _nextSaveFailure = null;
      throw error;
    }
  }

  /// Records the save; [saveFailure], [failNextSave] and [changedOnDisk]
  /// fail it.
  @override
  Future<void> save(int document, {bool overChange = false}) async {
    _saving();
    if (!overChange && changedOnDisk.contains(document)) {
      throw const EngineException(
        kind: EngineErrorKind.fileChangedOnDisk,
        messageKey: 'errorFileRead',
      );
    }
    changedOnDisk.remove(document);
    saves.add((document, null));
  }

  /// Records the save; [saveFailure] and [failNextSave] fail it.
  @override
  Future<void> saveAs(int document, String path) async {
    _saving();
    saves.add((document, path));
  }

  /// Records the copy; [saveFailure] and [failNextSave] fail it.
  @override
  Future<void> saveCopy(int document, String path) async {
    _saving();
    copies.add((document, path));
  }

  /// Records the repaired copy; [saveFailure] and [failNextSave] fail it.
  @override
  Future<void> saveRepairedCopy(
    int document,
    String path, {
    bool replaceOriginal = false,
  }) async {
    _saving();
    repairedCopies.add((document, path, replaceOriginal));
  }

  /// Records the rewrite; [saveFailure], [failNextSave] and [changedOnDisk]
  /// fail it.
  @override
  Future<void> optimizeAndClean(int document) async {
    _saving();
    if (changedOnDisk.contains(document)) {
      throw const EngineException(
        kind: EngineErrorKind.fileChangedOnDisk,
        messageKey: 'errorFileRead',
      );
    }
    optimized.add(document);
  }

  @override
  Future<bool> wouldBreakSignatures(int document) async =>
      signed.contains(document);

  @override
  Future<bool> checkExternalChange(int document) async =>
      changedOnDisk.contains(document);

  /// The x of the caret before character [at] of [line].
  static double _x(TextLine line, int at) {
    final count = line.text.runes.length;
    return count == 0
        ? line.bbox.left
        : line.bbox.left + line.bbox.width * at.clamp(0, count) / count;
  }

  /// The caret on the line nearest [point], before the nearest character.
  @override
  Future<BlockCaret> caretAt(
    int document,
    int page,
    int block,
    Offset point,
  ) async {
    final found = _block(document, page, block);
    var start = 0;
    var best = (distance: double.infinity, index: 0, rect: Rect.zero);
    for (final line in found.lines) {
      final count = line.text.runes.length;
      final distance = point.dy < line.bbox.top
          ? line.bbox.top - point.dy
          : math.max(0, point.dy - line.bbox.bottom).toDouble();
      if (distance < best.distance) {
        final at = count == 0
            ? 0
            : ((point.dx - line.bbox.left) / line.bbox.width * count)
                  .round()
                  .clamp(0, count);
        final x = _x(line, at);
        best = (
          distance: distance,
          index: start + at,
          rect: Rect.fromLTRB(x, line.bbox.top, x, line.bbox.bottom),
        );
      }
      start += count + 1;
    }
    return BlockCaret(index: best.index, rect: best.rect);
  }

  /// The blocks between [anchor] and [focus] in reading order.
  @override
  Future<PageSelection> selection(
    int document,
    int page,
    BlockPosition anchor,
    BlockPosition focus,
  ) async {
    final blocks = _blocks(document, page).blocks;
    int order(BlockPosition at) => blocks.indexWhere(
      (block) => block.id == _block(document, page, at.block).id,
    );
    final forward =
        order(anchor) < order(focus) ||
        (order(anchor) == order(focus) && anchor.index <= focus.index);
    final (from, to) = forward ? (anchor, focus) : (focus, anchor);
    final quads = <Rect>[];
    final texts = <String>[];
    for (var i = order(from); i <= order(to); i++) {
      final block = blocks[i];
      final low = i == order(from) ? from.index : 0;
      final high = i == order(to) ? to.index : block.text.runes.length;
      texts.add(
        String.fromCharCodes(block.text.runes.skip(low).take(high - low)),
      );
      var start = 0;
      for (final line in block.lines) {
        final count = line.text.runes.length;
        final a = (low - start).clamp(0, count);
        final b = (high - start).clamp(0, count);
        if (a < b) {
          quads.add(
            Rect.fromLTRB(
              _x(line, a),
              line.bbox.top,
              _x(line, b),
              line.bbox.bottom,
            ),
          );
        }
        start += count + 1;
      }
    }
    return PageSelection(quads: quads, text: texts.join('\n'));
  }

  /// A view that answers each wanted item with opaque white pixels of its
  /// size, or as damaged on [failingPages].
  @override
  Future<EngineView> openView(int document) async {
    final id = _nextView++;
    final updates = StreamController<ViewUpdate>();
    _views[id] = (document, updates);
    return EngineView(id: id, updates: updates.stream);
  }

  @override
  Future<void> requestView(
    int view,
    int generation,
    List<WantedItem> wanted,
  ) async {
    requests.add(wanted);
    final (owner, updates) =
        _views[view] ??
        (throw const EngineException(
          kind: EngineErrorKind.notFound,
          messageKey: 'errorInternal',
        ));
    final pages = documents.values
        .firstWhere((document) => document.id == owner)
        .pages;
    for (final WantedItem(:item) in wanted) {
      if (updates.isClosed) return;
      if (failingPages.contains(item.page)) {
        updates.add(
          FailedItem(
            item: item,
            generation: generation,
            reason: RenderFailure.pageDamaged,
          ),
        );
        continue;
      }
      final page = pages[item.page];
      final (width, height) = switch (item) {
        ThumbnailItem(:final size) =>
          page.width >= page.height
              ? (size, math.max(1, (size * page.height / page.width).round()))
              : (math.max(1, (size * page.width / page.height).round()), size),
        TileItem(
          :final zoomBucket,
          :final devicePixelRatio,
          :final column,
          :final row,
        ) =>
          () {
            final scale = math.pow(2, zoomBucket / 4) * devicePixelRatio;
            return (
              math.min(512, (page.width * scale).round() - column * 512),
              math.min(512, (page.height * scale).round() - row * 512),
            );
          }(),
      };
      updates.add(
        RenderedItem(
          item: item,
          generation: generation,
          renderKey: _renderKeys[owner] ?? 0,
          x: item is TileItem ? item.column * 512 : 0,
          y: item is TileItem ? item.row * 512 : 0,
          width: width,
          height: height,
          stride: width * 4,
          pixels: Uint8List(width * height * 4)
            ..fillRange(0, width * height * 4, 255),
        ),
      );
    }
  }

  @override
  Future<void> closeView(int view) async {
    await _views.remove(view)?.$2.close();
  }
}

/// An open transaction of the fake: its block, the newest text and the page
/// it leaves, and its overflow.
final class _FakeTransaction {
  new(this.document, this.page, this.block);

  final int document;
  final int page;
  final int block;
  String? text;
  PageBlocks? applied;
  OverflowPlan? overflow;
  OverflowChoice? chosen;

  /// The newest text asked for, applied or not.
  String? requested;

  /// The candidate step 3 draws in, and whether the app chose it.
  FontCandidate? choice;
  bool chosenFont = false;

  /// Step 3's characters drawn without a choice, and the substitutions made.
  MissingGlyphs? pending;
  List<FontSubstitution> substitutions = const [];
}

/// One committed step of the fake's history: its page before and after.
final class _FakeStep {
  const new(this.step, this.page, this.before, this.after);

  final HistoryStep step;
  final int page;
  final PageBlocks before;
  final PageBlocks after;
}
