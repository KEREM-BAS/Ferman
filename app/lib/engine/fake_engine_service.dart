import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:ferman/engine/engine_service.dart';
import 'package:flutter/foundation.dart' show listEquals;

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
    this.fontCoverages = const {},
  });

  /// Madde 6 of kira-tr in a3-3a and a3-3b: EB Garamond has no "ğ"; the
  /// same font is not installed, Plex Serif is offered first, then the two
  /// similar fonts a3-3b shows, and IBM Plex Sans Arabic covers only part of
  /// the text.
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
        postscriptName: 'CormorantGaramond-Regular',
        family: 'Cormorant Garamond',
        covered: 1,
        needed: 1,
        similarity: 0.88,
        preview: 'Ğğ İı Şş Çç Öö Üü',
      ),
      FontCandidate(
        origin: FontOrigin.bundled,
        postscriptName: 'CrimsonPro-Regular',
        family: 'Crimson Pro',
        covered: 1,
        needed: 1,
        similarity: 0.86,
        preview: 'Ğğ İı Şş Çç Öö Üü',
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

  /// What [fontCoverage] answers, by document.
  final Map<int, List<FontCoverage>> fontCoverages;

  @override
  Future<List<FontCoverage>> fontCoverage(int document, String letters) async =>
      fontCoverages[document] ?? const [];

  /// The clock of the history's steps; goldens fix it.
  DateTime Function() now = DateTime.now;

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

  /// Each document's pages with a key of their own, newer than the document's.
  final Map<int, Map<int, int>> _pageKeys = {};

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

  /// The documents [closeDiscarding] closed, oldest first.
  final List<int> closedDiscarding = [];

  /// Closes as [close] does, and records the document.
  @override
  Future<void> closeDiscarding(int document) async {
    closedDiscarding.add(document);
    await close(document);
  }

  /// The folder [startRecovery] was given.
  @override
  String? recoveryRoot;

  /// What the a11-1c switch says ([setRecoveryEnabled]).
  bool recoveryEnabled = true;

  /// What [listRecoverable] lists once recovery started; [restoreRecovered]
  /// and [discardRecovery] take documents out.
  final List<RecoverableDocument> recoverable = [];

  /// The documents [restoreRecovered] opens, by document name.
  final Map<String, OpenedDocument> recoveredDocuments = {};

  /// The passwords of [recoverable] documents that are encrypted, by
  /// document name.
  final Map<String, String> recoveryPasswords = {};

  @override
  Future<void> startRecovery(String root) async {
    if (recoveryRoot case final started? when started != root) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    recoveryRoot = root;
  }

  @override
  Future<void> setRecoveryEnabled({required bool enabled}) async =>
      recoveryEnabled = enabled;

  @override
  Future<List<RecoverableDocument>> listRecoverable() async =>
      recoveryRoot == null ? const [] : List.unmodifiable(recoverable);

  /// Opens the [recoveredDocuments] entry, with its [recoveryPasswords]
  /// entry for an encrypted one; a changed original saves to
  /// `<name> (recovered).pdf`, with [suffix] for "recovered".
  @override
  Future<RestoredDocument> restoreRecovered(
    String session,
    String document, {
    String? password,
    String? suffix,
  }) async {
    final found = recoverable.where(
      (found) => found.session == session && found.document == document,
    );
    final opened = recoveredDocuments[document];
    if (recoveryRoot == null || found.isEmpty || opened == null) {
      throw const EngineException(
        kind: EngineErrorKind.notFound,
        messageKey: 'errorFileNotFound',
      );
    }
    if (recoveryPasswords[document] case final expected?
        when password != expected) {
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
    final entry = found.first;
    recoverable.remove(entry);
    final original = entry.original;
    final dot = original.lastIndexOf('.');
    final stem = dot > original.lastIndexOf('/')
        ? original.substring(0, dot)
        : original;
    return RestoredDocument(
      opened: opened,
      path: entry.originalChanged
          ? '$stem (${suffix ?? 'recovered'})${original.substring(stem.length)}'
          : original,
      originalChanged: entry.originalChanged,
      renderKey: ++_lastRenderKey,
    );
  }

  @override
  Future<void> discardRecovery(String session, {String? document}) async {
    if (recoveryRoot == null) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    recoverable.removeWhere(
      (found) =>
          found.session == session &&
          (document == null || found.document == document),
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
    _pageKeys.remove(document);
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
    if (options.comments) {
      final open = documents.values.firstWhere((open) => open.id == document);
      for (final annotation in _annotationsNow(document)) {
        final page = open.pageIndexOf(annotation.page);
        final text = annotation.contents ?? '';
        final at = text.indexOf(query);
        if (page == null || at < 0) continue;
        yield SearchMatches([
          SearchMatch(
            page: page,
            rects: [annotation.rect],
            snippet: text,
            snippetStart: at,
            snippetEnd: at + query.length,
            comment: annotation.handle,
          ),
        ]);
      }
    }
    yield SearchProgress(searched: pages, pages: pages);
    yield SearchDone(textless: textless);
  }

  /// The jobs started and not ended, by handle.
  final Map<int, StreamController<JobUpdate>> _jobs = {};

  /// The arguments of every [copyDocumentJob], oldest first.
  final List<(int document, String output, String? staging)> copyJobs = [];

  /// The jobs [pauseJob], [resumeJob] and [cancelJob] were asked about, in
  /// order, as "pause 1".
  final List<String> jobCalls = [];

  int _nextJob = 1;

  /// Starts a job that waits: drive it with [reportJob] and [endJob].
  @override
  Stream<JobUpdate> copyDocumentJob(
    int document,
    String output, {
    String? staging,
  }) {
    copyJobs.add((document, output, staging));
    return _waitingJob();
  }

  Stream<JobUpdate> _waitingJob() {
    final job = _nextJob++;
    final updates = _jobs[job] = StreamController<JobUpdate>()
      ..add(JobUpdate(job: job, state: JobState.running));
    return updates.stream;
  }

  /// What [combinePreview] answers.
  CombinePreview combinePreviewFound = const CombinePreview();

  /// What [splitPreview] answers.
  SplitPreview splitPreviewFound = const SplitPreview();

  /// The arguments of every job of Combine, Extract, Split, Insert and Replace,
  /// oldest first, as "split 1 /folder".
  final List<String> assembleJobs = [];

  /// The changes waiting for [applyJobChange], by job.
  final Map<int, RevisionInfo Function()> _waitingChanges = {};

  /// How many pages [insertPagesJob]'s change adds, of 100 by 200 points.
  int insertedPages = 1;

  /// Starts a job whose [change] waits for [applyJobChange].
  Stream<JobUpdate> _changeJob(RevisionInfo Function() change) {
    _waitingChanges[_nextJob] = change;
    return _waitingJob();
  }

  @override
  Future<RevisionInfo> applyJobChange(int job) async {
    final change = _waitingChanges.remove(job);
    if (change == null) {
      throw const EngineException(
        kind: EngineErrorKind.notFound,
        messageKey: 'errorInternal',
      );
    }
    return change();
  }

  @override
  Future<CombinePreview> combinePreview(
    List<CombineInput> files, {
    required bool keepForms,
  }) async => combinePreviewFound;

  @override
  Stream<JobUpdate> combineJob(
    List<CombineInput> files, {
    required bool keepForms,
    required ImagePaper paper,
    required String output,
    String? staging,
  }) {
    assembleJobs.add('combine ${files.length} $output');
    return _waitingJob();
  }

  @override
  Stream<JobUpdate> extractPagesJob(
    int document,
    List<int> pages, {
    required String output,
    String? staging,
  }) {
    assembleJobs.add('extract ${pages.length} $output');
    return _waitingJob();
  }

  @override
  Future<SplitPreview> splitPreview(
    int document, {
    required SplitKind kind,
    required String template,
    int amount = 0,
    String? folder,
  }) async => splitPreviewFound;

  @override
  Stream<JobUpdate> splitJob(
    int document,
    List<SplitFile> files, {
    required String folder,
    String? staging,
  }) {
    assembleJobs.add('split ${files.length} $folder');
    return _waitingJob();
  }

  @override
  Stream<JobUpdate> insertPagesJob(
    int document, {
    required String path,
    required int? after,
    required ImagePaper paper,
    required String name,
    String? password,
    List<int>? pages,
  }) {
    assembleJobs.add('insert $path');
    return _changeJob(
      () => _pagesChanged(document, name, [?after], (all) {
        final at = after == null
            ? 0
            : all.indexWhere((page) => page.handle == after) + 1;
        return [
          ...all.take(at),
          for (var i = 0; i < insertedPages; i++) _newPage(100, 200, null),
          ...all.skip(at),
        ];
      }),
    );
  }

  /// The change keeps the first replaced pages' handles and removes the rest,
  /// as one new page for each replaced page would.
  @override
  Stream<JobUpdate> replacePagesJob(
    int document,
    List<int> pages, {
    required String path,
    required String name,
    String? password,
    List<int>? sourcePages,
  }) {
    assembleJobs.add('replace ${pages.length} $path');
    return _changeJob(
      () => _pagesChanged(document, name, pages, (all) => [...all]),
    );
  }

  /// Sends [update] to its job's stream.
  void reportJob(JobUpdate update) => _jobs[update.job]?.add(update);

  /// Sends [update], the job's last, and closes its stream.
  void endJob(JobUpdate update) {
    final updates = _jobs.remove(update.job);
    updates?.add(update);
    unawaited(updates?.close());
  }

  /// Parks the job at once.
  @override
  Future<void> pauseJob(int job) async {
    jobCalls.add('pause $job');
    reportJob(JobUpdate(job: job, state: JobState.paused));
  }

  /// Lets the job go on at once.
  @override
  Future<void> resumeJob(int job) async {
    jobCalls.add('resume $job');
    reportJob(JobUpdate(job: job, state: JobState.running));
  }

  /// Ends the job as cancelled at once.
  @override
  Future<void> cancelJob(int job) async {
    jobCalls.add('cancel $job');
    endJob(JobUpdate(job: job, state: JobState.cancelled));
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

  /// Whether a committed style gives the page's blocks new ids, as the engine
  /// does: an id holds its operator's offset in the stream.
  bool newIdsOnStyle = false;

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
  /// provisionally, draws them; with "Keep the original font and mark the
  /// character" the text applies, marked, and nothing waits. A block of
  /// [sameFonts] carries its step 2 substitution. With reflow off only a new
  /// line overflows.
  @override
  Future<EditPreview> applyEdit(int transaction, String text) async {
    final open = _open(transaction)..requested = text;
    final block = _block(open.document, open.page, open.block);
    final missing = _missing(open, text);
    final marked = fontSettings.markMissing && !open.chosenFont;
    if (missing != null && !missing.drawn && !marked) {
      return _preview(open, missing: missing);
    }
    final same = sameFonts[open.block];
    open
      ..text = text
      ..overflow =
          (fontSettings.keepLines
              ? '\n'.allMatches(text).length >= block.lines.length
              : text.length > block.text.length)
          ? overflows[open.block]
          : null
      ..chosen = open.overflow == null ? null : OverflowChoice.keep
      ..pending = open.chosenFont || marked ? null : missing
      ..substitutions = [
        if (same != null &&
            same.chars.runes.map(String.fromCharCode).any(text.contains))
          same,
        if (missing != null && marked)
          FontSubstitution(
            kind: SubstitutionKind.marked,
            chars: {for (final c in missing.chars) c.text}.join(),
            fromFont: missing.font,
            toFont: missing.font,
            origin: FontOrigin.embedded,
          )
        else if (missing != null)
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

  @override
  Future<EditPreview> setBlockLanguage(int transaction, String tag) async {
    final open = _open(transaction);
    if (tag.isEmpty || tag.contains(' ')) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    open.language = tag;
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
      language: open.language ?? block.language,
    );
    final page = PageBlocks(
      blocks: [
        for (final other in before.blocks)
          if (other.id == block.id) edited else other,
      ],
      empty: before.empty,
    );
    final changed = open.text != null || open.language != null;
    if (changed) open.applied = page;
    return EditPreview(
      page: changed ? page : before,
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
      language: open.language ?? block.language,
    );
  }

  ({List<_FakeStep> steps, int current}) _history(int document) =>
      _histories[document] ?? (steps: const [], current: 0);

  /// The pages, outline and attachments the next commit, undo or redo leaves:
  /// what a change to the document's structure hands the app.
  DocumentStructure? nextStructure;

  /// The pages the next commit, undo or redo reaches; null means every page.
  List<int>? nextChangedPages;

  /// A new render key for [nextChangedPages] of [document], as a reload gives.
  RevisionInfo _reloaded(int document) {
    final structure = nextStructure;
    nextStructure = null;
    if (structure != null) {
      for (final entry in documents.entries.toList()) {
        if (entry.value.id == document) {
          documents[entry.key] = entry.value.withStructure(structure);
        }
      }
    }
    final key = ++_lastRenderKey;
    final changed = nextChangedPages;
    nextChangedPages = null;
    if (changed == null) {
      _renderKeys[document] = key;
      _pageKeys.remove(document);
    } else {
      final pages = _pageKeys[document] ??= {};
      for (final page in changed) {
        pages[page] = key;
      }
    }
    return RevisionInfo(
      current: _history(document).current,
      renderKey: key,
      changedPages: changed,
      structure: structure,
    );
  }

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
    if (open.applied != null) _confirmed(open.document);
    _transactions.remove(transaction);
    final before = _blocks(open.document, open.page);
    final after = open.applied;
    final history = _history(open.document);
    String texts(PageBlocks page) => page.blocks
        .map((block) => '${block.text}${block.language}')
        .join('\u0000');
    if (after == null || (!open.styled && texts(after) == texts(before))) {
      return RevisionInfo(current: history.current);
    }
    _edited[(open.document, open.page)] = newIdsOnStyle && open.styled
        ? PageBlocks(
            blocks: [
              for (final block in after.blocks)
                TextBlock(
                  id: block.id + 100,
                  frame: block.frame,
                  lines: block.lines,
                  alignment: block.alignment,
                  direction: block.direction,
                  language: block.language,
                ),
            ],
          )
        : after;
    _histories[open.document] = (
      steps: [
        ...history.steps.take(history.current),
        _FakeStep(
          HistoryStep(
            name: name,
            time: now(),
            hiddenLines: open.chosen == OverflowChoice.keep
                ? open.overflow?.keepHidden ?? 0
                : 0,
            substitutions: open.substitutions,
            pages: [
              documents.values
                      .where((document) => document.id == open.document)
                      .firstOrNull
                      ?.pageHandle(open.page) ??
                  open.page,
            ],
            before: before.blocks
                .where((block) => block.id == open.block)
                .map((block) => block.text)
                .join(),
            after: after.blocks
                .where((block) => block.id == open.block)
                .map((block) => block.text)
                .join(),
          ),
          open.page,
          before,
          after,
          block: open.block,
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
      changedPages: reloaded.changedPages,
      substitutions: told,
      structure: reloaded.structure,
    );
  }

  /// The styles asked for, oldest first.
  final List<BlockStyle> styles = [];

  /// The block styles [blockStyle] answers with, by block; a block without
  /// one reads as none, so the shell keeps its document panel.
  final Map<int, BlockStyleInfo> blockStyles = {};

  /// The fonts [blockFonts] answers with.
  List<FontCandidate> fonts = const [];

  /// The blocks of a page with the block of [open] in [frame].
  PageBlocks _framed(_FakeTransaction open, Rect frame) {
    final page = open.applied ?? _blocks(open.document, open.page);
    return PageBlocks(
      blocks: [
        for (final block in page.blocks)
          if (block.id == open.block)
            TextBlock(
              id: block.id,
              frame: frame,
              lines: block.lines,
              alignment: block.alignment,
              direction: block.direction,
              notEditable: block.notEditable,
            )
          else
            block,
      ],
      empty: page.empty,
    );
  }

  /// Keeps [style] for [blockStyle]; a font with the name `Missing` draws
  /// nothing and is refused, as a font without the characters is.
  @override
  Future<EditPreview> setBlockStyle(int transaction, BlockStyle style) async {
    final open = _open(transaction);
    if (style.font?.postscriptName == 'Missing') {
      return _preview(
        open,
        missing: const MissingGlyphs(
          chars: [MissingChar(text: 'K', at: 0)],
          font: 'Missing',
        ),
      );
    }
    styles.add(style);
    open.styled = true;
    final info = blockStyles[open.block];
    if (info == null) {
      open.applied ??= _blocks(open.document, open.page);
      return EditPreview(page: open.applied!);
    }
    blockStyles[open.block] = BlockStyleInfo(
      font: style.font?.postscriptName ?? info.font,
      family: style.font?.postscriptName ?? info.family,
      size: style.size ?? info.size,
      frame: info.frame,
      bold: info.bold,
      italic: info.italic,
      boldToggle: info.boldToggle,
      italicToggle: info.italicToggle,
      colour: style.colour ?? info.colour,
      documentColours: info.documentColours,
      alignment: style.alignment ?? info.alignment,
      charSpacing: style.charSpacing ?? info.charSpacing,
      lineSpacing: style.lineSpacing ?? info.lineSpacing,
    );
    open.applied ??= _blocks(open.document, open.page);
    return EditPreview(page: open.applied!);
  }

  @override
  Future<EditPreview> moveBlock(int transaction, Offset by) {
    final open = _open(transaction);
    final block = _block(open.document, open.page, open.block);
    return resizeBlock(transaction, block.frame.shift(by));
  }

  /// The block takes [frame]; an empty one is refused, as the engine refuses
  /// numbers out of range.
  @override
  Future<EditPreview> resizeBlock(int transaction, Rect frame) async {
    final open = _open(transaction);
    if (frame.isEmpty) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    open
      ..styled = true
      ..applied = _framed(open, frame);
    return EditPreview(page: open.applied!);
  }

  /// The block's entry in [blockStyles]: a test that wants the text panel
  /// gives its block one, and its frame follows the block.
  @override
  Future<BlockStyleInfo?> blockStyle(int document, int page, int block) async {
    final kept = blockStyles[block];
    if (kept == null) return null;
    return BlockStyleInfo(
      font: kept.font,
      family: kept.family,
      size: kept.size,
      frame: _block(document, page, block).frame,
      bold: kept.bold,
      italic: kept.italic,
      boldToggle: kept.boldToggle,
      italicToggle: kept.italicToggle,
      colour: kept.colour,
      documentColours: kept.documentColours,
      alignment: kept.alignment,
      charSpacing: kept.charSpacing,
      lineSpacing: kept.lineSpacing,
    );
  }

  @override
  Future<List<FontCandidate>> blockFonts(
    int document,
    int page,
    int block,
  ) async => fonts;

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

  /// What [whiteMargins] finds on every page; null for a page with no content.
  PageMargins? whiteMarginsFound = const PageMargins(
    top: 20,
    bottom: 30,
    left: 25,
    right: 25,
  );

  /// The label ranges [setPageLabels] set, by document.
  final Map<int, List<PageLabelRange>> _labelRanges = {};

  /// The last handle a page made here got; past any page's index.
  int _lastPageHandle = 1 << 32;

  OpenedDocument _openedById(int document) =>
      documents.values.firstWhere((opened) => opened.id == document);

  /// [opened]'s pages, each with its handle.
  List<PageInfo> _handled(OpenedDocument opened) => [
    for (final (index, page) in opened.pages.indexed)
      PageInfo(
        width: page.width,
        height: page.height,
        rotation: page.rotation,
        label: page.label,
        handle: page.handle ?? index,
      ),
  ];

  /// Commits the page list [change] makes of the document's, as the step
  /// [name] on the [touched] pages. shortcut: the blocks stay by page index,
  /// so a page's text does not follow it when it moves; follow it when a test
  /// reads blocks after a move.
  RevisionInfo _pagesChanged(
    int document,
    String name,
    List<int> touched,
    List<PageInfo> Function(List<PageInfo> pages) change,
  ) {
    _closed(document, can: true);
    final opened = _openedById(document);
    final pages = _handled(opened);
    if (touched.any((page) => pages.every((p) => p.handle != page))) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    final after = change(pages);
    if (after.isEmpty) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    _confirmed(document);
    final history = _history(document);
    final blocks = _blocks(document, 0);
    final next = DocumentStructure(
      pages: after,
      outline: opened.outline,
      attachments: opened.attachments,
    );
    _histories[document] = (
      steps: [
        ...history.steps.take(history.current),
        _FakeStep(
          HistoryStep(name: name, time: now(), pages: touched),
          0,
          blocks,
          blocks,
          block: -1,
          structureBefore: DocumentStructure(
            pages: pages,
            outline: opened.outline,
            attachments: opened.attachments,
          ),
          structureAfter: next,
        ),
      ],
      current: history.current + 1,
    );
    nextStructure = next;
    return _reloaded(document);
  }

  PageInfo _resized(
    PageInfo page,
    double width,
    double height, {
    int? rotation,
  }) => PageInfo(
    width: width,
    height: height,
    rotation: rotation ?? page.rotation,
    label: page.label,
    handle: page.handle,
  );

  PageInfo _newPage(double width, double height, String? label) => PageInfo(
    width: width,
    height: height,
    label: label,
    handle: ++_lastPageHandle,
  );

  /// Each document's fields by the history's place they were left at; undo
  /// and redo walk them with the steps.
  final Map<int, Map<int, List<FieldInfo>>> _fieldVersions = {};

  /// The fields a test gives a document before any step.
  final Map<int, List<FieldInfo>> initialFields = {};

  List<FieldInfo> _fieldsNow(int document) {
    final versions = _fieldVersions[document] ?? const {};
    for (var at = _history(document).current; at > 0; at--) {
      final version = versions[at];
      if (version != null) return version;
    }
    return initialFields[document] ?? const [];
  }

  /// One step named [name] that leaves [after], on [pages] by handle.
  RevisionInfo _fieldStep(
    int document,
    String name,
    List<int> pages,
    List<FieldInfo> after,
  ) {
    final info = _pagesChanged(document, name, pages, (all) => [...all]);
    final versions = _fieldVersions[document] ??= {};
    final at = _history(document).current;
    versions
      ..removeWhere((step, _) => step >= at)
      ..[at] = after;
    return info;
  }

  @override
  Future<FormInfo> formFields(int document) async {
    final fields = _fieldsNow(document);
    final required = fields.where((f) => f.required && !f.readOnly);
    return FormInfo(
      fields: fields,
      required: required.length,
      requiredLeft: required.where((f) => !f.filled).length,
      problems: fields.where((f) => f.problem != null).length,
    );
  }

  /// Sets a value as the engine would, without its validation: a read-only,
  /// push-button or signature field is refused.
  @override
  Future<FieldCommit> setFieldValue(
    int document,
    int handle,
    List<String> values, {
    required String name,
    MissingFont? missing,
  }) async {
    final fields = _fieldsNow(document);
    final at = fields.indexWhere((field) => field.handle == handle);
    final field = at < 0 ? null : fields[at];
    if (field == null ||
        field.readOnly ||
        field.kind == FieldKind.push ||
        field.kind == FieldKind.signature) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    if (listEquals(field.values, values)) {
      return FieldCommit(
        revision: RevisionInfo(current: _history(document).current),
      );
    }
    final revision = _fieldStep(
      document,
      name,
      {for (final widget in field.widgets) widget.page}.toList(),
      [...fields]..[at] = field.withValues(values),
    );
    return FieldCommit(revision: revision);
  }

  @override
  Future<RevisionInfo> clearForm(int document, String name) async {
    final fields = _fieldsNow(document);
    return _fieldStep(
      document,
      name,
      [
        for (final field in fields)
          for (final widget in field.widgets) widget.page,
      ],
      [
        for (final field in fields)
          if (field.readOnly ||
              field.kind == FieldKind.signature ||
              field.kind == FieldKind.push)
            field
          else
            field.withValues(const []),
      ],
    );
  }

  @override
  Future<RevisionInfo> finishForm(int document, String name) async {
    final fields = _fieldsNow(document);
    return _fieldStep(
      document,
      name,
      [
        for (final field in fields)
          for (final widget in field.widgets) widget.page,
      ],
      [
        for (final field in fields)
          if (field.signed) field,
      ],
    );
  }

  /// Each document's annotations by the history's place they were left at;
  /// undo and redo walk them with the steps.
  final Map<int, Map<int, List<AnnotationInfo>>> _annotationVersions = {};

  /// The annotations a test gives a document before any step.
  final Map<int, List<AnnotationInfo>> initialAnnotations = {};

  int _lastAnnotationHandle = 1 << 40;

  List<AnnotationInfo> _annotationsNow(int document) {
    final versions = _annotationVersions[document] ?? const {};
    for (var at = _history(document).current; at > 0; at--) {
      final version = versions[at];
      if (version != null) return version;
    }
    return initialAnnotations[document] ?? const [];
  }

  /// One step named [name] that leaves [after], on the page of [page].
  RevisionInfo _annotationStep(
    int document,
    String name,
    int page,
    List<AnnotationInfo> after,
  ) {
    final info = _pagesChanged(document, name, [page], (all) => [...all]);
    final versions = _annotationVersions[document] ??= {};
    final at = _history(document).current;
    versions
      ..removeWhere((step, _) => step >= at)
      ..[at] = after;
    return info;
  }

  AnnotationInfo _annotationNamed(int document, int handle) {
    for (final annotation in _annotationsNow(document)) {
      if (annotation.handle == handle) return annotation;
    }
    throw const EngineException(
      kind: EngineErrorKind.invalidInput,
      messageKey: 'errorInternal',
    );
  }

  @override
  Future<AnnotationList> annotations(int document) async {
    final annotations = _annotationsNow(document);
    return AnnotationList(
      annotations: annotations,
      people: {
        for (final annotation in annotations)
          if (annotation.author case final author? when author.isNotEmpty)
            author,
      }.toList(),
    );
  }

  /// Adds a mark as the engine would list it. A squiggly or unknown type is
  /// refused, as the engine refuses it.
  @override
  Future<AnnotationCommit> addAnnotation(
    int document,
    int page,
    NewAnnotation annotation,
    String name,
  ) async {
    if (annotation.kind == AnnotationKind.squiggly ||
        annotation.kind == AnnotationKind.other) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    final handle = ++_lastAnnotationHandle;
    final added = AnnotationInfo(
      handle: handle,
      page: page,
      kind: annotation.kind,
      rect: annotation.rect,
      points: annotation.points,
      arrow: annotation.arrow,
      color: annotation.color,
      opacity: annotation.opacity,
      stroke: annotation.stroke,
      fontSize: annotation.fontSize,
      author: annotation.author,
      contents: annotation.contents,
      created: now(),
      modified: now(),
      icon: annotation.icon,
      thread: handle,
    );
    final revision = _annotationStep(document, name, page, [
      ..._annotationsNow(document),
      added,
    ]);
    return AnnotationCommit(handle: handle, revision: revision);
  }

  @override
  Future<AnnotationCommit> updateAnnotation(
    int document,
    int handle,
    AnnotationChange change,
    String name,
  ) async {
    final old = _annotationNamed(document, handle);
    final changed = AnnotationInfo(
      handle: handle,
      page: old.page,
      kind: old.kind,
      subtype: old.subtype,
      rect: change.rect ?? old.rect,
      points: change.points ?? old.points,
      arrow: old.arrow,
      color: change.color ?? old.color,
      opacity: change.opacity ?? old.opacity,
      stroke: change.stroke ?? old.stroke,
      fontSize: change.fontSize ?? old.fontSize,
      author: old.author,
      contents: change.contents ?? old.contents,
      quote: old.quote,
      rich: old.rich && change.contents == null,
      created: old.created,
      modified: now(),
      icon: old.icon,
      repliesTo: old.repliesTo,
      thread: old.thread,
      state: old.state,
      resolved: old.resolved,
      resolvedBy: old.resolvedBy,
      resolvedAt: old.resolvedAt,
      mentions: old.mentions,
    );
    final revision = _annotationStep(document, name, old.page, [
      for (final annotation in _annotationsNow(document))
        if (annotation.handle == handle) changed else annotation,
    ]);
    return AnnotationCommit(handle: handle, revision: revision);
  }

  @override
  Future<RevisionInfo> deleteAnnotation(
    int document,
    int handle,
    String name,
  ) async {
    final old = _annotationNamed(document, handle);
    return _annotationStep(document, name, old.page, [
      for (final annotation in _annotationsNow(document))
        if (annotation.handle != handle && annotation.thread != handle)
          annotation,
    ]);
  }

  /// The requests of every [showComments], oldest first.
  final List<bool> commentRequests = [];

  /// What the next [showComments] fails with.
  EngineException? showCommentsFailure;

  @override
  Future<int> showComments(int document, {required bool visible}) async {
    commentRequests.add(visible);
    if (showCommentsFailure case final failure?) throw failure;
    _pageKeys.remove(document);
    return _renderKeys[document] = ++_lastRenderKey;
  }

  @override
  Stream<JobUpdate> flattenAnnotationsJob(
    int document,
    List<int> handles, {
    required String name,
    String? copy,
    String? staging,
  }) {
    assembleJobs.add('flatten ${handles.length} $copy');
    return _waitingJob();
  }

  @override
  Stream<JobUpdate> commentSummaryJob(
    int document,
    SummaryFormat format,
    SummaryOptions options, {
    required String output,
    String? staging,
  }) {
    assembleJobs.add('summary ${format.name} $output');
    return _waitingJob();
  }

  /// Each document's links, as tests set them or the calls change them.
  final Map<int, List<LinkInfo>> fakeLinks = {};
  int _lastLinkHandle = 1 << 40;

  /// The addresses that may be written; anything else is refused, as the
  /// engine refuses it.
  static bool _offered(LinkDestination destination) {
    if (destination.page != null) return true;
    final address = destination.address;
    if (destination.mail) return !address.contains(' ');
    return address.startsWith(RegExp('https?://', caseSensitive: false));
  }

  void _checkDestination(LinkDestination? destination) {
    if (destination != null && !_offered(destination)) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
  }

  static LinkInfo _linkTo(LinkInfo old, LinkChange change) {
    final destination = change.destination;
    return LinkInfo(
      handle: old.handle,
      page: old.page,
      rect: change.rect ?? old.rect,
      quads: old.quads,
      kind: destination == null
          ? old.kind
          : destination.page != null
          ? LinkKind.page
          : destination.mail
          ? LinkKind.mail
          : LinkKind.web,
      target: destination == null
          ? old.target
          : destination.mail
          ? 'mailto:${destination.address}'
          : destination.address,
      targetPage: destination == null ? old.targetPage : destination.page,
      wantedPage: old.wantedPage,
      look: change.look ?? old.look,
      color: change.color ?? old.color,
    );
  }

  @override
  Future<LinkList> links(int document) async =>
      LinkList(links: [...?fakeLinks[document]]);

  @override
  Future<LinkInfo?> linkAt(int document, int page, Offset point) async {
    for (final link in (fakeLinks[document] ?? const <LinkInfo>[]).reversed) {
      if (link.page == page && link.rect.contains(point)) return link;
    }
    return null;
  }

  // shortcut: the fake's links do not follow undo, as its annotations do; add
  // versions when commit 17's Links panel needs them.
  @override
  Future<AnnotationCommit> addLink(
    int document,
    int page,
    NewLink link,
    String name,
  ) async {
    _checkDestination(link.destination);
    final handle = ++_lastLinkHandle;
    (fakeLinks[document] ??= []).add(
      _linkTo(
        LinkInfo(
          handle: handle,
          page: page,
          rect: link.rect,
          kind: LinkKind.nothing,
          quads: link.quads,
        ),
        LinkChange(
          destination: link.destination,
          look: link.look,
          color: link.color,
        ),
      ),
    );
    return AnnotationCommit(
      handle: handle,
      revision: _pagesChanged(document, name, [page], (all) => [...all]),
    );
  }

  @override
  Future<AnnotationCommit> updateLink(
    int document,
    int handle,
    LinkChange change,
    String name,
  ) async {
    _checkDestination(change.destination);
    final links = fakeLinks[document] ?? [];
    final at = links.indexWhere((link) => link.handle == handle);
    if (at < 0) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    links[at] = _linkTo(links[at], change);
    return AnnotationCommit(
      handle: handle,
      revision: _pagesChanged(document, name, [
        links[at].page,
      ], (all) => [...all]),
    );
  }

  @override
  Future<RevisionInfo> deleteLink(int document, int handle, String name) async {
    final links = fakeLinks[document] ?? [];
    final at = links.indexWhere((link) => link.handle == handle);
    if (at < 0) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    final page = links.removeAt(at).page;
    return _pagesChanged(document, name, [page], (all) => [...all]);
  }

  @override
  Future<AnnotationCommit> replyToAnnotation(
    int document,
    int handle, {
    required String author,
    required String text,
    required String name,
  }) async {
    final old = _annotationNamed(document, handle);
    final reply = ++_lastAnnotationHandle;
    final people = (await annotations(document)).people;
    final revision = _annotationStep(document, name, old.page, [
      ..._annotationsNow(document),
      AnnotationInfo(
        handle: reply,
        page: old.page,
        kind: AnnotationKind.note,
        rect: old.rect,
        author: author,
        contents: text,
        created: now(),
        modified: now(),
        repliesTo: old.thread,
        thread: old.thread,
        mentions: [
          for (final person in people)
            if (text.contains('@$person')) person,
        ],
      ),
    ]);
    return AnnotationCommit(handle: reply, revision: revision);
  }

  @override
  Future<RevisionInfo> setAnnotationResolved(
    int document,
    int handle, {
    required String author,
    required bool resolved,
    required String name,
  }) async {
    final old = _annotationNamed(document, handle);
    final top = _annotationNamed(document, old.thread);
    if (top.resolved == resolved) {
      return RevisionInfo(current: _history(document).current);
    }
    return _annotationStep(document, name, old.page, [
      for (final annotation in _annotationsNow(document))
        if (annotation.handle == top.handle)
          AnnotationInfo(
            handle: top.handle,
            page: top.page,
            kind: top.kind,
            subtype: top.subtype,
            rect: top.rect,
            points: top.points,
            arrow: top.arrow,
            color: top.color,
            opacity: top.opacity,
            stroke: top.stroke,
            fontSize: top.fontSize,
            author: top.author,
            contents: top.contents,
            quote: top.quote,
            rich: top.rich,
            created: top.created,
            modified: top.modified,
            icon: top.icon,
            thread: top.thread,
            resolved: resolved,
            resolvedBy: resolved ? author : null,
            resolvedAt: resolved ? now() : null,
            mentions: top.mentions,
          )
        else
          annotation,
      AnnotationInfo(
        handle: ++_lastAnnotationHandle,
        page: top.page,
        kind: AnnotationKind.note,
        rect: top.rect,
        author: author,
        modified: now(),
        repliesTo: top.handle,
        thread: top.handle,
        state: resolved ? 'Completed' : 'None',
      ),
    ]);
  }

  @override
  Future<RevisionInfo> rotatePages(
    int document,
    List<int> pages,
    int quarterTurns,
    String name,
  ) async => _pagesChanged(
    document,
    name,
    pages,
    (all) => [
      for (final page in all)
        if (pages.contains(page.handle))
          _resized(
            page,
            quarterTurns.isOdd ? page.height : page.width,
            quarterTurns.isOdd ? page.width : page.height,
            rotation: (page.rotation + quarterTurns * 90) % 360,
          )
        else
          page,
    ],
  );

  /// Refuses the next deletes when set.
  EngineException? deleteFailure;

  @override
  Future<RevisionInfo> deletePages(
    int document,
    List<int> pages,
    String name,
  ) async {
    if (deleteFailure case final failure?) throw failure;
    return _pagesChanged(
      document,
      name,
      pages,
      (all) => [
        for (final page in all)
          if (!pages.contains(page.handle)) page,
      ],
    );
  }

  @override
  Future<RevisionInfo> movePages(
    int document,
    List<int> pages,
    int? before,
    String name,
  ) async => _pagesChanged(document, name, pages, (all) {
    final moving = [
      for (final page in all)
        if (pages.contains(page.handle)) page,
    ];
    final rest = [
      for (final page in all)
        if (!pages.contains(page.handle)) page,
    ];
    final from = all.indexWhere((page) => page.handle == before);
    final at = from < 0
        ? rest.length
        : rest.indexed
                  .where((entry) => all.indexOf(entry.$2) >= from)
                  .map((entry) => entry.$1)
                  .firstOrNull ??
              rest.length;
    return [...rest.take(at), ...moving, ...rest.skip(at)];
  });

  @override
  Future<RevisionInfo> duplicatePages(
    int document,
    List<int> pages,
    String name,
  ) async => _pagesChanged(document, name, pages, (all) {
    final out = <PageInfo>[];
    final run = <PageInfo>[];
    for (final (index, page) in all.indexed) {
      out.add(page);
      if (pages.contains(page.handle)) {
        run.add(_newPage(page.width, page.height, page.label));
      }
      final next = all.elementAtOrNull(index + 1);
      if (next == null || !pages.contains(next.handle)) {
        out.addAll(run);
        run.clear();
      }
    }
    return out;
  });

  @override
  Future<RevisionInfo> insertBlankPages(
    int document, {
    required int? after,
    required int count,
    required double width,
    required double height,
    required String name,
  }) async => _pagesChanged(document, name, [?after], (all) {
    final at = after == null
        ? 0
        : all.indexWhere((page) => page.handle == after) + 1;
    return [
      ...all.take(at),
      for (var i = 0; i < count; i++) _newPage(width, height, null),
      ...all.skip(at),
    ];
  });

  @override
  Future<RevisionInfo> setPageSize(
    int document,
    List<int> pages, {
    required double width,
    required double height,
    required PageFit fit,
    required String name,
  }) async => _pagesChanged(
    document,
    name,
    pages,
    (all) => [
      for (final page in all)
        if (pages.contains(page.handle))
          _resized(page, width, height)
        else
          page,
    ],
  );

  @override
  Future<RevisionInfo> cropPages(
    int document,
    Map<int, PageMargins> crops,
    String name,
  ) async => _pagesChanged(
    document,
    name,
    crops.keys.toList(),
    (all) => [
      for (final page in all)
        switch (crops[page.handle]) {
          null => page,
          final margins => _resized(
            page,
            page.width - margins.left - margins.right,
            page.height - margins.top - margins.bottom,
          ),
        },
    ],
  );

  @override
  Future<List<PageMargins?>> whiteMargins(
    int document,
    List<int> pages,
  ) async => [for (final _ in pages) whiteMarginsFound];

  @override
  Future<List<PageLabelRange>> pageLabelRanges(int document) async =>
      _labelRanges[document] ?? const [];

  /// shortcut: every numbered style is written in decimal; write them out when
  /// a test reads a roman label.
  @override
  Future<RevisionInfo> setPageLabels(
    int document,
    List<PageLabelRange> ranges,
    String name,
  ) async {
    _labelRanges[document] = ranges;
    return _pagesChanged(
      document,
      name,
      const [],
      (all) => [
        for (final (index, page) in all.indexed)
          PageInfo(
            width: page.width,
            height: page.height,
            handle: page.handle,
            label: switch (ranges
                .where((range) => range.start <= index)
                .lastOrNull) {
              null => null,
              final range when range.style == PageLabelStyle.none =>
                range.prefix,
              final range =>
                '${range.prefix}${range.first + index - range.start}',
            },
          ),
      ],
    );
  }

  @override
  Future<RevisionInfo> undo(int document) async {
    final history = _history(document);
    _closed(document, can: history.current > 0);
    final step = history.steps[history.current - 1];
    _edited[(document, step.page)] = step.before;
    nextStructure = step.structureBefore ?? nextStructure;
    _histories[document] = (steps: history.steps, current: history.current - 1);
    return _reloaded(document);
  }

  @override
  Future<RevisionInfo> redo(int document) async {
    final history = _history(document);
    _closed(document, can: history.current < history.steps.length);
    final step = history.steps[history.current];
    _edited[(document, step.page)] = step.after;
    nextStructure = step.structureAfter ?? nextStructure;
    _histories[document] = (steps: history.steps, current: history.current + 1);
    return _reloaded(document);
  }

  /// The steps asked to revert: a later live step of the same block depends
  /// on an earlier one, or every later one of the page with [dependOnPage].
  @override
  Future<Reverted> revert(
    int document,
    int step,
    String name, {
    bool withDependents = false,
  }) async {
    final history = _history(document);
    final live = EditHistory(
      steps: [for (final item in history.steps) item.step],
      current: history.current,
    ).live;
    _closed(document, can: live.contains(step));
    final asked = history.steps[step];
    final set = [
      for (final index in live)
        if (index == step ||
            (index > step &&
                history.steps[index].page == asked.page &&
                (dependOnPage || history.steps[index].block == asked.block)))
          index,
    ];
    final dependents = [
      for (final index in set)
        if (index != step) index,
    ];
    if (dependents.isNotEmpty && !withDependents) {
      return Reverted(
        reverted: false,
        dependents: dependents,
        revision: RevisionInfo(current: history.current),
      );
    }
    final current = _blocks(document, asked.page);
    final restored = {
      for (final index in set.reversed)
        for (final block in history.steps[index].before.blocks)
          if (block.id == history.steps[index].block) block.id: block,
    };
    final after = PageBlocks(
      blocks: [for (final block in current.blocks) restored[block.id] ?? block],
      empty: current.empty,
    );
    _push(document, name, set, asked.page, current, after);
    _edited[(document, asked.page)] = after;
    nextStructure =
        set
            .map((index) => history.steps[index].structureBefore)
            .nonNulls
            .firstOrNull ??
        nextStructure;
    return Reverted(
      reverted: true,
      dependents: dependents,
      revision: _reloaded(document),
    );
  }

  /// shortcut: the step remembers one page, so Undo after a revert of edits on
  /// several pages brings back only the first, and its page list stays as the
  /// revert left it; tests revert on one page.
  @override
  Future<RevisionInfo> revertAll(int document, String name) async {
    final history = _history(document);
    final live = EditHistory(
      steps: [for (final item in history.steps) item.step],
      current: history.current,
    ).live;
    _closed(document, can: live.isNotEmpty);
    final first = history.steps[live.first];
    final current = _blocks(document, first.page);
    for (final index in live.reversed) {
      final step = history.steps[index];
      _edited[(document, step.page)] = step.before;
    }
    _push(document, name, live, first.page, current, first.before);
    nextStructure =
        live
            .map((index) => history.steps[index].structureBefore)
            .nonNulls
            .firstOrNull ??
        nextStructure;
    return _reloaded(document);
  }

  void _push(
    int document,
    String name,
    List<int> reverts,
    int page,
    PageBlocks before,
    PageBlocks after,
  ) {
    final history = _history(document);
    _histories[document] = (
      steps: [
        ...history.steps.take(history.current),
        _FakeStep(
          HistoryStep(name: name, time: now(), reverts: reverts),
          page,
          before,
          after,
          block: -1,
        ),
      ],
      current: history.current + 1,
    );
  }

  /// Texts [saveText] wrote: path and text, oldest first.
  final List<(String, String)> savedTexts = [];

  /// Whether a later edit of the same page depends on an earlier one, not
  /// only one of the same block.
  bool dependOnPage = false;

  @override
  Future<String?> saveText(String path, String text, {String? staging}) async {
    if (saveFailure case final error?) throw error;
    savedTexts.add((path, text));
    return staging == null ? null : '$staging/staged';
  }

  @override
  Future<EditHistory> history(int document) async {
    final history = _history(document);
    return EditHistory(
      steps: [for (final step in history.steps) step.step],
      current: history.current,
      signatureInvalidated:
          signed.contains(document) &&
          (history.current > 0 || optimized.contains(document)),
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

  /// Documents that are signed: [wouldBreakSignatures] says so, and commits
  /// and writes throw [EngineErrorKind.confirmationRequired] until
  /// [confirmEditSigned].
  final Set<int> signed = {};

  /// What [opGate] says of a document and an operation, when a test sets it.
  /// Otherwise a changing operation on a [signed] document breaks its
  /// signatures, and nothing else is concerned.
  final Map<(int, DocumentOp), OpGate> opGates = {};

  /// The signed documents [confirmEditSigned] confirmed, with their tokens.
  final Map<int, int> confirmations = {};

  /// The working copies [saveUnsignedCopy] wrote: document and path.
  final List<(int, String)> unsignedCopies = [];

  /// Throws while the signed [document] waits for [confirmEditSigned].
  void _confirmed(int document) {
    if (signed.contains(document) && !confirmations.containsKey(document)) {
      throw const EngineException(
        kind: EngineErrorKind.confirmationRequired,
        messageKey: 'errorInternal',
      );
    }
  }

  /// The copies [saveCopy] wrote: document and path.
  final List<(int, String)> copies = [];

  /// The repaired copies: document, path and whether it replaced the
  /// original.
  final List<(int, String, bool)> repairedCopies = [];

  /// The documents [optimizeAndClean] rewrote, oldest first.
  final List<int> optimized = [];

  /// How many transactions are open, none of them lost to the app.
  int get openTransactions => _transactions.length;

  /// Throws [saveFailure], or the failure [failNextSave] set, once.
  void _saving() {
    if (saveFailure case final error?) throw error;
    if (_nextSaveFailure case final error?) {
      _nextSaveFailure = null;
      throw error;
    }
  }

  /// What each staged save will record once [finishSave] says it is in
  /// place.
  final Map<int, void Function()> _staged = {};

  /// Whether [finishSave] reports a failed recovery write.
  bool recoveryWriteFailed = false;

  /// [record] now, or with [staging] a staged file there and [record] at
  /// [finishSave].
  String? _write(int document, String? staging, void Function() record) {
    if (staging == null) {
      record();
      return null;
    }
    _staged[document] = record;
    return '$staging/staged.pdf';
  }

  @override
  Future<bool> finishSave(int document, {required bool swapped}) async {
    final record = _staged.remove(document);
    if (record == null) {
      throw const EngineException(
        kind: EngineErrorKind.invalidInput,
        messageKey: 'errorInternal',
      );
    }
    if (swapped) record();
    return recoveryWriteFailed;
  }

  /// Records the save; [saveFailure], [failNextSave] and [changedOnDisk]
  /// fail it.
  @override
  Future<String?> save(
    int document, {
    bool overChange = false,
    String? staging,
  }) async {
    _confirmed(document);
    _saving();
    if (!overChange && changedOnDisk.contains(document)) {
      throw const EngineException(
        kind: EngineErrorKind.fileChangedOnDisk,
        messageKey: 'errorFileRead',
      );
    }
    return _write(document, staging, () {
      changedOnDisk.remove(document);
      saves.add((document, null));
    });
  }

  /// Records the save; [saveFailure] and [failNextSave] fail it.
  @override
  Future<String?> saveAs(int document, String path, {String? staging}) async {
    if (_history(document).current > 0) _confirmed(document);
    _saving();
    return _write(document, staging, () => saves.add((document, path)));
  }

  /// Records the copy; [saveFailure] and [failNextSave] fail it.
  @override
  Future<String?> saveCopy(int document, String path, {String? staging}) async {
    if (_history(document).current > 0) _confirmed(document);
    _saving();
    return _write(document, staging, () => copies.add((document, path)));
  }

  /// Records the repaired copy; [saveFailure] and [failNextSave] fail it.
  @override
  Future<String?> saveRepairedCopy(
    int document,
    String path, {
    bool replaceOriginal = false,
    String? staging,
  }) async {
    _confirmed(document);
    _saving();
    return _write(
      document,
      staging,
      () => repairedCopies.add((document, path, replaceOriginal)),
    );
  }

  /// Records the rewrite; [saveFailure], [failNextSave] and [changedOnDisk]
  /// fail it.
  @override
  Future<String?> optimizeAndClean(int document, {String? staging}) async {
    _confirmed(document);
    _saving();
    if (changedOnDisk.contains(document)) {
      throw const EngineException(
        kind: EngineErrorKind.fileChangedOnDisk,
        messageKey: 'errorFileRead',
      );
    }
    return _write(document, staging, () => optimized.add(document));
  }

  @override
  Future<bool> wouldBreakSignatures(int document) async =>
      signed.contains(document);

  @override
  Future<OpGate> opGate(
    int document,
    DocumentOp op, {
    List<String> fields = const [],
  }) async =>
      opGates[(document, op)] ??
      (signed.contains(document) && op != DocumentOp.print
          ? OpGate.breaksSignatures
          : OpGate.unaffected);

  @override
  Future<int> confirmEditSigned(int document) async =>
      confirmations[document] ??= confirmations.length + 1;

  /// Records the copy; [saveFailure] and [failNextSave] fail it.
  @override
  Future<String?> saveUnsignedCopy(
    int document,
    String path, {
    String? staging,
  }) async {
    _saving();
    return _write(
      document,
      staging,
      () => unsignedCopies.add((document, path)),
    );
  }

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

  /// The character indices of every selection, oldest first.
  final List<(int, int)> selectionRequests = [];

  /// The blocks between [anchor] and [focus] in reading order.
  @override
  Future<PageSelection> selection(
    int document,
    int page,
    BlockPosition anchor,
    BlockPosition focus,
  ) async {
    selectionRequests.add((anchor.index, focus.index));
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
          renderKey: _pageKeys[owner]?[item.page] ?? _renderKeys[owner] ?? 0,
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
  String? language;
  PageBlocks? applied;

  /// Whether a style, a move or a resize changed the block.
  bool styled = false;
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
  const new(
    this.step,
    this.page,
    this.before,
    this.after, {
    required this.block,
    this.structureBefore,
    this.structureAfter,
  });

  final HistoryStep step;
  final int page;
  final int block;
  final PageBlocks before;
  final PageBlocks after;

  /// A page operation's lists on either side of it.
  final DocumentStructure? structureBefore;
  final DocumentStructure? structureAfter;
}
