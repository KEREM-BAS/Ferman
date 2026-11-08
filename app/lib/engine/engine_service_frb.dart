import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:ferman/bridge/frb.dart' as bridge;
import 'package:ferman/bridge/frb_generated.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/recovery_directory.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary, Uint32List, Uint64List;
import 'package:path_provider/path_provider.dart';

/// The [EngineService] backed by the Rust engine through flutter_rust_bridge.
/// This file and the generated `app/lib/bridge/` are the only Dart code that
/// touches the bridge (tools/checks imports rule).
class FrbEngineService implements EngineService {
  new _();

  /// Loads the engine library, checks its API version, starts crash
  /// recovery in the app data directory and returns the service. Throws an
  /// [EngineUnavailableException] when the library cannot be loaded or
  /// speaks an API version this app does not accept.
  static Future<FrbEngineService> start() async {
    final library = bundledEngineLibraryPath();
    try {
      // The bridge loads the library once per process; a second start (for
      // example an integration test after the app started) reuses it.
      if (!FermanBridge.instance.initialized) {
        await FermanBridge.init(externalLibrary: ExternalLibrary.open(library));
      }
    } on Object {
      throw const EngineUnavailableException(
        EngineUnavailableReason.libraryMissing,
      );
    }
    final service = FrbEngineService._();
    final engine = service.apiVersion();
    if (!kAppApiVersion.acceptsEngine(engine)) {
      throw EngineUnavailableException(
        EngineUnavailableReason.apiMismatch,
        engineApiVersion: engine,
      );
    }
    await service._startRecovery();
    return service;
  }

  /// The app data directory, where the MCP host listens; null when it
  /// cannot be named.
  String? _appData;

  /// Starts crash recovery in [recoveryDirectory]. Without it the engine
  /// keeps no recovery files, and everything else still works.
  Future<void> _startRecovery() async {
    try {
      final root = recoveryDirectory(
        os: Platform.operatingSystem,
        environment: Platform.environment,
        applicationSupport: Platform.isMacOS
            ? (await getApplicationSupportDirectory()).path
            : null,
      );
      if (root != null) {
        // The recovery folder's parent is the app data directory.
        _appData = root.substring(0, root.lastIndexOf(RegExp(r'[/\\]')));
        await startRecovery(root);
        // Version history beside it in the app data directory (ADR 0022).
        await bridge.startVersions(root: versionsDirectory(root));
      }
    } on Object {
      // No recovery folder: the documents open and save without one.
    }
  }

  @override
  EngineApiVersion apiVersion() {
    final version = bridge.apiVersion();
    return EngineApiVersion(major: version.major, minor: version.minor);
  }

  @override
  Future<EngineStatus> status() async {
    try {
      final info = await bridge.engineInfo();
      return EngineStatus(
        appVersion: info.appVersion,
        apiVersion: EngineApiVersion(
          major: info.apiVersion.major,
          minor: info.apiVersion.minor,
        ),
        isDebugBuild: info.buildProfile == bridge.BuildProfile.debug,
        pdfium: switch (info.pdfium.state) {
          bridge.PdfiumState.notLoaded => PdfiumState.notLoaded,
          bridge.PdfiumState.loaded => PdfiumState.loaded,
          bridge.PdfiumState.failed => PdfiumState.failed,
        },
        pdfiumTag: info.pdfium.tag,
        pdfiumReason: info.pdfium.reason,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<OpenedDocument> open(String path, {String? password}) async {
    try {
      return _opened(await bridge.open(path: path, password: password));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<Security?> unlockOwner(int document, String password) async {
    try {
      return _security(
        await bridge.unlockOwner(
          document: BigInt.from(document),
          password: password,
        ),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> close(int document) => _close(document, discard: false);

  @override
  Future<void> closeDiscarding(int document) => _close(document, discard: true);

  Future<void> _close(int document, {required bool discard}) async {
    try {
      await bridge.close(
        document: BigInt.from(document),
        discardRecovery: discard,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  String? recoveryRoot;

  @override
  Future<void> startRecovery(String root) async {
    try {
      await bridge.startRecovery(root: root);
      recoveryRoot = root;
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> setRecoveryEnabled({required bool enabled}) async {
    try {
      await bridge.setRecoveryEnabled(enabled: enabled);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<List<RecoverableDocument>> listRecoverable() async {
    try {
      return [
        for (final found in await bridge.listRecoverable())
          RecoverableDocument(
            session: found.session,
            document: found.document,
            original: found.original,
            originalChanged: found.originalChanged,
            changes: found.changes,
            encrypted: found.encrypted,
          ),
      ];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<RestoredDocument> restoreRecovered(
    String session,
    String document, {
    String? password,
    String? suffix,
  }) async {
    try {
      final restored = await bridge.restoreRecovered(
        session: session,
        document: document,
        password: password,
        suffix: suffix,
      );
      return RestoredDocument(
        opened: _opened(restored.opened),
        path: restored.path,
        originalChanged: restored.originalChanged,
        renderKey: restored.renderKey?.toSigned(64).toInt(),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> discardRecovery(String session, {String? document}) async {
    try {
      await bridge.discardRecovery(session: session, document: document);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<int> showLayers(int document, List<bool> visible) async {
    try {
      final key = await bridge.showLayers(
        document: BigInt.from(document),
        visible: visible,
      );
      return key.toSigned(64).toInt();
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<String?> saveAttachment(
    int document,
    int index,
    String path, {
    String? staging,
  }) async {
    try {
      return await bridge.saveAttachment(
        document: BigInt.from(document),
        index: index,
        path: path,
        staging: staging,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<List<int>> collationOrder(String locale, List<String> texts) async {
    final order = await bridge.collationOrder(locale: locale, texts: texts);
    return order.toList();
  }

  @override
  Future<String> startMcpHost() async {
    final appData = _appData;
    if (appData == null) {
      throw const EngineException(
        kind: EngineErrorKind.io,
        messageKey: 'errorInternal',
      );
    }
    try {
      return await bridge.startMcpHost(appData: appData);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> stopMcpHost() => bridge.stopMcpHost();

  @override
  Future<List<McpClient>> mcpClients() async => [
    for (final client in await bridge.mcpClients())
      McpClient(
        id: client.id.toInt(),
        name: client.name,
        mayEdit: client.mayEdit,
      ),
  ];

  @override
  Future<void> grantClientEdit(int client, {required bool mayEdit}) async {
    try {
      await bridge.grantClientEdit(
        client: BigInt.from(client),
        mayEdit: mayEdit,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Stream<ClientRequest> clientRequests() => bridge.watchClientRequests().map(
    (request) => ClientRequest(
      id: request.id.toInt(),
      client: request.client.toInt(),
      clientName: request.clientName,
      kind: switch (request.kind) {
        bridge.ClientRequestKind.editSigned => ClientRequestKind.editSigned,
        bridge.ClientRequestKind.save => ClientRequestKind.save,
        bridge.ClientRequestKind.writeFile => ClientRequestKind.writeFile,
        bridge.ClientRequestKind.readFile => ClientRequestKind.readFile,
        bridge.ClientRequestKind.sign => ClientRequestKind.sign,
        bridge.ClientRequestKind.restoreVersion =>
          ClientRequestKind.restoreVersion,
      },
      document: request.document?.toInt(),
      path: request.path,
      version: request.version?.toInt(),
      signer: request.signer,
      page: request.page,
      field: request.field,
    ),
  );

  @override
  Future<bool> clientRequestPending(int request) =>
      bridge.clientRequestPending(request: BigInt.from(request));

  @override
  Future<void> answerClientRequest(int request, {required bool allow}) =>
      bridge.answerClientRequest(request: BigInt.from(request), allow: allow);

  @override
  Stream<ClientChange> clientChanges() => bridge.watchClientChanges().map(
    (change) => ClientChange(
      document: change.document.toInt(),
      client: change.client,
      revision: _revisionOf(change.revision),
    ),
  );

  /// The engine's first event names the view; every later one is an update.
  /// Cancelling [EngineView.updates] cancels the engine's stream, which ends
  /// the view.
  @override
  Future<EngineView> openView(int document) {
    final opened = Completer<EngineView>();
    final updates = StreamController<ViewUpdate>();
    final subscription = bridge
        .openView(document: BigInt.from(document))
        .listen(
          (event) {
            if (event.kind == bridge.ViewEventKind.opened) {
              opened.complete(
                EngineView(id: event.view.toInt(), updates: updates.stream),
              );
            } else if (_update(event) case final update?) {
              updates.add(update);
            }
          },
          onError: (Object error) {
            final exception = error is bridge.ApiError
                ? _exception(error)
                : error;
            opened.isCompleted
                ? updates.addError(exception)
                : opened.completeError(exception);
          },
          onDone: () {
            if (!opened.isCompleted) {
              opened.completeError(
                const EngineException(messageKey: 'errorInternal'),
              );
            }
            unawaited(updates.close());
          },
        );
    updates.onCancel = subscription.cancel;
    return opened.future;
  }

  @override
  Future<void> requestView(
    int view,
    int generation,
    List<WantedItem> wanted,
  ) async {
    try {
      await bridge.requestView(
        view: BigInt.from(view),
        generation: BigInt.from(generation),
        wanted: [
          for (final entry in wanted)
            bridge.WantedItem(
              item: _item(entry.item),
              priority: switch (entry.priority) {
                RenderPriority.visible => bridge.Priority.visible,
                RenderPriority.prefetch => bridge.Priority.prefetch,
                RenderPriority.visibleThumbnail =>
                  bridge.Priority.visibleThumbnail,
                RenderPriority.thumbnail => bridge.Priority.thumbnail,
                RenderPriority.background => bridge.Priority.background,
              },
            ),
        ],
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  ) => bridge
      .search(
        document: BigInt.from(document),
        query: query,
        options: bridge.SearchOptions(
          matchCase: options.matchCase,
          wholeWords: options.wholeWords,
          ignoreAccents: options.ignoreAccents,
          bookmarks: options.bookmarks,
          comments: options.comments,
          fields: options.fields,
        ),
      )
      .handleError(
        (Object error) => throw _exception(error as bridge.ApiError),
        test: (error) => error is bridge.ApiError,
      )
      .map(
        (event) => switch (event.kind) {
          bridge.SearchEventKind.started => null,
          bridge.SearchEventKind.matches => SearchMatches([
            for (final found in event.matches)
              SearchMatch(
                page: found.page,
                rects: [
                  for (final rect in found.rects)
                    Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom),
                ],
                snippet: found.snippet,
                snippetStart: _units(found.snippet, found.snippetStart),
                snippetEnd: _units(found.snippet, found.snippetEnd),
                bookmark: found.bookmark,
                comment: found.comment?.toInt(),
                field: found.field?.toInt(),
              ),
          ]),
          bridge.SearchEventKind.progress => SearchProgress(
            searched: event.searched,
            pages: event.pages,
          ),
          bridge.SearchEventKind.done => SearchDone(
            cancelled: event.cancelled,
            textless: event.textless,
          ),
        },
      )
      .where((update) => update != null)
      .cast<SearchUpdate>();

  @override
  Stream<JobUpdate> copyDocumentJob(
    int document,
    String output, {
    String? staging,
  }) => _jobUpdates(
    bridge.startCopyDocumentJob(
      document: BigInt.from(document),
      output: output,
      staging: staging,
    ),
  );

  /// [events] as the app gets them.
  Stream<JobUpdate> _jobUpdates(Stream<bridge.JobEvent> events) => events
      .handleError(
        (Object error) => throw _exception(error as bridge.ApiError),
        test: (error) => error is bridge.ApiError,
      )
      .map(
        (event) => JobUpdate(
          job: event.job.toInt(),
          state: switch (event.state) {
            bridge.JobState.running => JobState.running,
            bridge.JobState.paused => JobState.paused,
            bridge.JobState.done => JobState.done,
            bridge.JobState.failed => JobState.failed,
            bridge.JobState.cancelled => JobState.cancelled,
          },
          progress: event.progress,
          messageKey: event.messageKey,
          params: {for (final (key, value) in event.params) key: value},
          outputs: [
            for (final output in event.outputs)
              JobOutputFile(path: output.path, staged: output.staged),
          ],
          revision: event.revision,
          error: switch (event.error) {
            final error? => _exception(error),
            null => null,
          },
        ),
      );

  static bridge.PaperSize _paper(ImagePaper paper) => switch (paper) {
    ImagePaper.a4 => bridge.PaperSize.a4,
    ImagePaper.letter => bridge.PaperSize.letter,
  };

  static bridge.CombineInput _combineInput(CombineInput input) =>
      bridge.CombineInput(
        path: input.path,
        password: input.password,
        pages: switch (input.pages) {
          final pages? => Uint32List.fromList(pages),
          null => null,
        },
        blankWidth: input.blankWidth,
        blankHeight: input.blankHeight,
        bookmark: input.bookmark,
      );

  @override
  Future<RevisionInfo> applyJobChange(int job) =>
      _revision(() => bridge.applyJobChange(job: BigInt.from(job)));

  @override
  Future<CombinePreview> combinePreview(
    List<CombineInput> files, {
    required bool keepForms,
  }) async {
    try {
      final preview = await bridge.combinePreview(
        files: [for (final file in files) _combineInput(file)],
        keepForms: keepForms,
      );
      return CombinePreview(
        files: [
          for (final row in preview.files)
            CombineFileInfo(
              status: switch (row.status) {
                bridge.InputStatus.ready => CombineInputStatus.ready,
                bridge.InputStatus.passwordRequired =>
                  CombineInputStatus.passwordRequired,
                bridge.InputStatus.wrongPassword =>
                  CombineInputStatus.wrongPassword,
                bridge.InputStatus.ownerPasswordRequired =>
                  CombineInputStatus.ownerPasswordRequired,
                bridge.InputStatus.badRange => CombineInputStatus.badRange,
                bridge.InputStatus.unreadable => CombineInputStatus.unreadable,
              },
              image: row.image,
              pages: row.pages,
              selected: row.selected,
              bytes: row.bytes.toInt(),
              encrypted: row.encrypted,
              signed: row.signed,
            ),
        ],
        pages: preview.pages,
        bytes: preview.bytes.toInt(),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Stream<JobUpdate> combineJob(
    List<CombineInput> files, {
    required bool keepForms,
    required ImagePaper paper,
    required String output,
    String? staging,
  }) => _jobUpdates(
    bridge.startCombineJob(
      files: [for (final file in files) _combineInput(file)],
      keepForms: keepForms,
      paper: _paper(paper),
      output: output,
      staging: staging,
    ),
  );

  @override
  Stream<JobUpdate> extractPagesJob(
    int document,
    List<int> pages, {
    required String output,
    String? staging,
  }) => _jobUpdates(
    bridge.startExtractPagesJob(
      document: BigInt.from(document),
      pages: _handles(pages),
      output: output,
      staging: staging,
    ),
  );

  @override
  Future<SplitPreview> splitPreview(
    int document, {
    required SplitKind kind,
    required String template,
    int amount = 0,
    String? folder,
  }) async {
    try {
      final preview = await bridge.splitPreview(
        document: BigInt.from(document),
        kind: switch (kind) {
          SplitKind.everyPages => bridge.SplitKind.everyPages,
          SplitKind.topBookmarks => bridge.SplitKind.topBookmarks,
          SplitKind.size => bridge.SplitKind.size,
          SplitKind.blankPages => bridge.SplitKind.blankPages,
        },
        amount: BigInt.from(amount),
        template: template,
        folder: folder,
      );
      return SplitPreview(
        files: [
          for (final file in preview.files)
            SplitFile(
              name: file.name,
              first: file.first,
              last: file.last,
              bytes: file.bytes.toInt(),
              overLimit: file.overLimit,
            ),
        ],
        bookmarks: preview.bookmarks,
        blankPages: preview.blankPages,
        encrypted: preview.encrypted,
        signed: preview.signed,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Stream<JobUpdate> splitJob(
    int document,
    List<SplitFile> files, {
    required String folder,
    String? staging,
  }) => _jobUpdates(
    bridge.startSplitJob(
      document: BigInt.from(document),
      files: [
        for (final file in files)
          bridge.SplitOutput(
            name: file.name,
            first: file.first,
            last: file.last,
          ),
      ],
      folder: folder,
      staging: staging,
    ),
  );

  @override
  Stream<JobUpdate> insertPagesJob(
    int document, {
    required String path,
    required int? after,
    required ImagePaper paper,
    required String name,
    String? password,
    List<int>? pages,
  }) => _jobUpdates(
    bridge.startInsertPagesJob(
      document: BigInt.from(document),
      path: path,
      password: password,
      pages: switch (pages) {
        final pages? => Uint32List.fromList(pages),
        null => null,
      },
      after: after == null ? null : BigInt.from(after),
      paper: _paper(paper),
      name: name,
    ),
  );

  @override
  Stream<JobUpdate> replacePagesJob(
    int document,
    List<int> pages, {
    required String path,
    required String name,
    String? password,
    List<int>? sourcePages,
  }) => _jobUpdates(
    bridge.startReplacePagesJob(
      document: BigInt.from(document),
      pages: _handles(pages),
      path: path,
      password: password,
      sourcePages: switch (sourcePages) {
        final pages? => Uint32List.fromList(pages),
        null => null,
      },
      name: name,
    ),
  );

  @override
  Future<void> pauseJob(int job) async {
    try {
      await bridge.pauseJob(job: BigInt.from(job));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> resumeJob(int job) async {
    try {
      await bridge.resumeJob(job: BigInt.from(job));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> cancelJob(int job) async {
    try {
      await bridge.cancelJob(job: BigInt.from(job));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  /// The UTF-16 offset of the character at [chars] in [text].
  static int _units(String text, int chars) => text.runes
      .take(chars)
      .fold(0, (units, rune) => units + (rune > 0xFFFF ? 2 : 1));

  @override
  Future<PageBlocks> textBlocks(int document, int page) async {
    try {
      final blocks = await bridge.textBlocks(
        document: BigInt.from(document),
        page: page,
      );
      return _pageBlocks(blocks);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<BlockCaret> caretAt(
    int document,
    int page,
    int block,
    Offset point,
  ) async {
    try {
      final caret = await bridge.caretAt(
        document: BigInt.from(document),
        page: page,
        block: _wireBlockId(block),
        point: bridge.PagePoint(x: point.dx, y: point.dy),
      );
      return BlockCaret(index: caret.index, rect: _rect(caret.rect));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<PageSelection> selection(
    int document,
    int page,
    BlockPosition anchor,
    BlockPosition focus,
  ) async {
    bridge.TextPosition position(BlockPosition at) =>
        bridge.TextPosition(block: _wireBlockId(at.block), index: at.index);
    try {
      final selection = await bridge.selection(
        document: BigInt.from(document),
        page: page,
        anchor: position(anchor),
        focus: position(focus),
      );
      return PageSelection(
        quads: [for (final quad in selection.quads) _rect(quad)],
        text: selection.text,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<int> beginEdit(int document, int page, int block) async {
    try {
      final transaction = await bridge.beginEdit(
        document: BigInt.from(document),
        page: page,
        block: _wireBlockId(block),
      );
      return transaction.toInt();
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<EditPreview> applyEdit(int transaction, String text) async {
    try {
      final preview = await bridge.applyEdit(
        transaction: BigInt.from(transaction),
        text: text,
      );
      return _preview(preview);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<EditPreview> setBlockLanguage(int transaction, String tag) async {
    try {
      final preview = await bridge.setBlockLanguage(
        transaction: BigInt.from(transaction),
        tag: tag,
      );
      return _preview(preview);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<EditPreview> resolveOverflow(
    int transaction,
    OverflowChoice choice,
  ) async {
    try {
      final preview = await bridge.resolveOverflow(
        transaction: BigInt.from(transaction),
        choice: switch (choice) {
          OverflowChoice.extend => bridge.OverflowChoice.extend,
          OverflowChoice.tighten => bridge.OverflowChoice.tighten,
          OverflowChoice.keep => bridge.OverflowChoice.keep,
        },
      );
      return _preview(preview);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<List<FontCoverage>> fontCoverage(int document, String letters) async {
    try {
      final coverage = await bridge.fontCoverage(
        document: BigInt.from(document),
        letters: letters,
      );
      return [
        for (final font in coverage)
          FontCoverage(
            name: font.name,
            shownAs: font.shownAs,
            missingLetters: font.missingLetters,
          ),
      ];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> setFontSettings(FontSettings settings) async {
    try {
      await bridge.setFontSettings(
        settings: bridge.FontSettings(
          bundledDir: settings.bundledDir ?? bundledFontsDirectory(),
          fontDirs: settings.fontDirs,
          systemFonts: settings.systemFonts,
          askEachTime: settings.askEachTime,
          markMissing: settings.markMissing,
          keepLines: settings.keepLines,
        ),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<EditPreview> chooseFont(
    int transaction,
    FontOrigin origin,
    String postscriptName,
  ) async {
    try {
      final preview = await bridge.chooseFont(
        transaction: BigInt.from(transaction),
        origin: switch (origin) {
          FontOrigin.embedded => bridge.FontOrigin.embedded,
          FontOrigin.installed => bridge.FontOrigin.installed,
          FontOrigin.bundled => bridge.FontOrigin.bundled,
        },
        postscriptName: postscriptName,
      );
      return _preview(preview);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<EditPreview> keepAsIs(int transaction) async {
    try {
      final preview = await bridge.keepAsIs(
        transaction: BigInt.from(transaction),
      );
      return _preview(preview);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<List<InstalledFont>> installedFonts() async {
    try {
      final fonts = await bridge.installedFonts(
        bundledDir: bundledFontsDirectory(),
      );
      return [
        for (final font in fonts)
          InstalledFont(
            family: font.family,
            origin: _origin(font.origin),
            scripts: {
              for (final script in font.scripts)
                switch (script) {
                  bridge.FontScript.turkish => FontScript.turkish,
                  bridge.FontScript.latinExtended => FontScript.latinExtended,
                  bridge.FontScript.cyrillic => FontScript.cyrillic,
                  bridge.FontScript.greek => FontScript.greek,
                  bridge.FontScript.arabic => FontScript.arabic,
                  bridge.FontScript.hebrew => FontScript.hebrew,
                  bridge.FontScript.devanagari => FontScript.devanagari,
                  bridge.FontScript.cjk => FontScript.cjk,
                },
            },
          ),
      ];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  static FontOrigin _origin(bridge.FontOrigin origin) => switch (origin) {
    bridge.FontOrigin.embedded => FontOrigin.embedded,
    bridge.FontOrigin.installed => FontOrigin.installed,
    bridge.FontOrigin.bundled => FontOrigin.bundled,
  };

  static FontEmbedding _embedding(bridge.FontEmbedding embedding) =>
      switch (embedding) {
        bridge.FontEmbedding.installable => FontEmbedding.installable,
        bridge.FontEmbedding.editable => FontEmbedding.editable,
        bridge.FontEmbedding.previewAndPrint => FontEmbedding.previewAndPrint,
        bridge.FontEmbedding.restricted => FontEmbedding.restricted,
        bridge.FontEmbedding.noSubsetting => FontEmbedding.noSubsetting,
        bridge.FontEmbedding.bitmapOnly => FontEmbedding.bitmapOnly,
      };

  static FontSubstitution _substitution(bridge.FontSubstitution value) =>
      FontSubstitution(
        kind: switch (value.kind) {
          bridge.SubstitutionKind.sameFont => SubstitutionKind.sameFont,
          bridge.SubstitutionKind.similar => SubstitutionKind.similar,
          bridge.SubstitutionKind.marked => SubstitutionKind.marked,
        },
        chars: value.chars,
        fromFont: value.fromFont,
        toFont: value.toFont,
        origin: _origin(value.origin),
        announced: value.announced,
      );

  static MissingGlyphs _glyphs(bridge.MissingGlyphs glyphs) => MissingGlyphs(
    chars: [for (final c in glyphs.chars) MissingChar(text: c.text, at: c.at)],
    font: glyphs.font,
    reason: switch (glyphs.reason) {
      bridge.MissingReasonKind.notInstalled => MissingReason.notInstalled,
      bridge.MissingReasonKind.notEmbeddable => MissingReason.notEmbeddable,
      bridge.MissingReasonKind.restricted => MissingReason.restricted,
    },
    reasonFont: glyphs.reasonFont,
    reasonEmbedding: switch (glyphs.reasonEmbedding) {
      null => null,
      final embedding => _embedding(embedding),
    },
    bold: glyphs.bold,
    italic: glyphs.italic,
    candidates: [
      for (final candidate in glyphs.candidates) _candidate(candidate),
    ],
    drawn: glyphs.drawn,
  );

  static FontCandidate _candidate(bridge.FontCandidate candidate) =>
      FontCandidate(
        origin: _origin(candidate.origin),
        postscriptName: candidate.postscriptName,
        family: candidate.family,
        covered: candidate.covered,
        needed: candidate.needed,
        similarity: candidate.similarity,
        embedding: _embedding(candidate.embedding),
        usable: candidate.usable,
        preview: candidate.preview,
      );

  static EditPreview _preview(bridge.EditPreview preview) {
    final plan = preview.overflow;
    final blocked = plan?.extendBlocked;
    final glyphs = preview.glyphs;
    return EditPreview(
      page: _pageBlocks(preview.page),
      missing: preview.missing,
      glyphs: glyphs == null ? null : _glyphs(glyphs),
      substitutions: [
        for (final substitution in preview.substitutions)
          _substitution(substitution),
      ],
      overflowing: preview.overflowing,
      overflow: plan == null
          ? null
          : OverflowPlan(
              over: plan.over,
              extendLines: plan.extendLines,
              extendBlocked: blocked == null
                  ? null
                  : ExtendBlocked(
                      kind: switch (blocked.kind) {
                        bridge.ExtendBlockedKind.block =>
                          ExtendBlockedKind.block,
                        bridge.ExtendBlockedKind.pageEdge =>
                          ExtendBlockedKind.pageEdge,
                      },
                      block: blocked.block?.toSigned(64).toInt(),
                      text: blocked.text,
                    ),
              tightenPercent: plan.tightenPercent,
              tightenShort: plan.tightenShort,
              keepHidden: plan.keepHidden,
            ),
      chosen: switch (preview.chosen) {
        null => null,
        bridge.OverflowChoice.extend => OverflowChoice.extend,
        bridge.OverflowChoice.tighten => OverflowChoice.tighten,
        bridge.OverflowChoice.keep => OverflowChoice.keep,
      },
      dependents: [
        for (final cell in preview.dependents)
          DependentCell(
            id: cell.id.toSigned(64).toInt(),
            frame: _rect(cell.frame),
          ),
      ],
      language: preview.language,
    );
  }

  @override
  Future<RevisionInfo> commitEdit(int transaction, String name) => _revision(
    () => bridge.commitEdit(transaction: BigInt.from(transaction), name: name),
  );

  static bridge.FontOrigin _bridgeOrigin(FontOrigin origin) => switch (origin) {
    FontOrigin.embedded => bridge.FontOrigin.embedded,
    FontOrigin.installed => bridge.FontOrigin.installed,
    FontOrigin.bundled => bridge.FontOrigin.bundled,
  };

  static BlockAlignment _alignment(bridge.Alignment alignment) =>
      switch (alignment) {
        bridge.Alignment.left => BlockAlignment.left,
        bridge.Alignment.right => BlockAlignment.right,
        bridge.Alignment.center => BlockAlignment.center,
        bridge.Alignment.justified => BlockAlignment.justified,
      };

  static BlockFont? _blockFont(bridge.BlockFont? font) => font == null
      ? null
      : BlockFont(
          origin: _origin(font.origin),
          postscriptName: font.postscriptName,
        );

  @override
  Future<EditPreview> setBlockStyle(int transaction, BlockStyle style) async {
    try {
      return _preview(
        await bridge.setBlockStyle(
          transaction: BigInt.from(transaction),
          style: bridge.BlockStyle(
            font: switch (style.font) {
              final font? => bridge.BlockFont(
                origin: _bridgeOrigin(font.origin),
                postscriptName: font.postscriptName,
              ),
              null => null,
            },
            size: style.size,
            colour: style.colour,
            alignment: switch (style.alignment) {
              BlockAlignment.left => bridge.Alignment.left,
              BlockAlignment.right => bridge.Alignment.right,
              BlockAlignment.center => bridge.Alignment.center,
              BlockAlignment.justified => bridge.Alignment.justified,
              null => null,
            },
            charSpacing: style.charSpacing,
            lineSpacing: style.lineSpacing,
          ),
        ),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<EditPreview> moveBlock(int transaction, Offset by) async {
    try {
      return _preview(
        await bridge.moveBlock(
          transaction: BigInt.from(transaction),
          dx: by.dx,
          dy: by.dy,
        ),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<EditPreview> resizeBlock(int transaction, Rect frame) async {
    try {
      return _preview(
        await bridge.resizeBlock(
          transaction: BigInt.from(transaction),
          frame: bridge.PageRect(
            left: frame.left,
            top: frame.top,
            right: frame.right,
            bottom: frame.bottom,
          ),
        ),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<BlockStyleInfo?> blockStyle(int document, int page, int block) async {
    try {
      final info = await bridge.blockStyle(
        document: BigInt.from(document),
        page: page,
        block: BigInt.from(block),
      );
      if (info == null) return null;
      return BlockStyleInfo(
        font: info.font,
        family: info.family,
        bold: info.bold,
        italic: info.italic,
        boldToggle: _blockFont(info.boldToggle),
        italicToggle: _blockFont(info.italicToggle),
        size: info.size,
        colour: info.colour,
        documentColours: info.documentColours,
        alignment: _alignment(info.alignment),
        charSpacing: info.charSpacing,
        lineSpacing: info.lineSpacing,
        frame: Rect.fromLTRB(
          info.frame.left,
          info.frame.top,
          info.frame.right,
          info.frame.bottom,
        ),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<List<FontCandidate>> blockFonts(
    int document,
    int page,
    int block,
  ) async {
    try {
      final fonts = await bridge.blockFonts(
        document: BigInt.from(document),
        page: page,
        block: BigInt.from(block),
      );
      return [for (final font in fonts) _candidate(font)];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<RevisionInfo> rollbackEdit(int transaction) => _revision(
    () => bridge.rollbackEdit(transaction: BigInt.from(transaction)),
  );

  @override
  Future<FormInfo> formFields(int document) async {
    try {
      final form = await bridge.formFields(document: BigInt.from(document));
      return FormInfo(
        fields: [for (final field in form.fields) _field(field)],
        required: form.required_,
        requiredLeft: form.requiredLeft,
        problems: form.problems,
        hasXfa: form.hasXfa,
        truncated: form.truncated,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<FieldCommit> setFieldValue(
    int document,
    int handle,
    List<String> values, {
    required String name,
    MissingFont? missing,
  }) => _fieldCommit(
    () => bridge.setFieldValue(
      document: BigInt.from(document),
      handle: BigInt.from(handle),
      values: values,
      missing: _missing(missing),
      name: name,
    ),
  );

  static bridge.MissingFont? _missing(MissingFont? missing) =>
      switch (missing) {
        null => null,
        final missing => bridge.MissingFont.values.byName(missing.name),
      };

  Future<FieldCommit> _fieldCommit(
    Future<bridge.FieldCommit> Function() call,
  ) async {
    bridge.FieldCommit? commit;
    final revision = await _revision(() async {
      final made = await call();
      commit = made;
      return made.revision;
    });
    final made = commit!;
    return FieldCommit(
      revision: revision,
      problem: switch (made.problem) {
        null => null,
        final problem => _problem(problem),
      },
      fonts: made.fonts,
      marked: made.marked,
      xfaRemoved: made.xfaRemoved,
      asksFont: made.asksFont,
    );
  }

  @override
  Future<FieldCommit> clearForm(
    int document,
    String name, {
    MissingFont? missing,
  }) => _fieldCommit(
    () => bridge.clearForm(
      document: BigInt.from(document),
      missing: _missing(missing),
      name: name,
    ),
  );

  @override
  Future<FieldCommit> finishForm(
    int document,
    String name, {
    MissingFont? missing,
  }) => _fieldCommit(
    () => bridge.finishForm(
      document: BigInt.from(document),
      missing: _missing(missing),
      name: name,
    ),
  );

  @override
  Future<FillTargets> fillTargets(int document, int page) async {
    try {
      final found = await bridge.fillTargets(
        document: BigInt.from(document),
        page: BigInt.from(page),
      );
      return FillTargets(
        targets: [
          for (final target in found.targets)
            FillTarget(
              kind: FillTargetKind.values.byName(target.kind.name),
              rect: Rect.fromLTRB(
                target.rect.left,
                target.rect.top,
                target.rect.right,
                target.rect.bottom,
              ),
              cells: target.cells,
            ),
        ],
        truncated: found.truncated,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<List<HandwritingStyle>> handwritingStyles(String text) async {
    try {
      return [
        for (final style in await bridge.handwritingStyles(text: text))
          HandwritingStyle(family: style.family, covered: style.covered),
      ];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<AnnotationCommit> addSignature(
    int document,
    int page,
    NewSignature signature,
    String name,
  ) => _annotationCommit(
    () => bridge.addSignature(
      document: BigInt.from(document),
      page: BigInt.from(page),
      signature: bridge.NewSignature(
        rect: _bridgeRect(signature.rect),
        ink: switch (signature.ink) {
          TypedInk(:final text, :final family) => bridge.SignatureInk(
            kind: bridge.SignatureInkKind.typed,
            text: text,
            family: family,
            strokes: const [],
            width: 0,
            image: Uint8List(0),
          ),
          DrawnInk(:final strokes, :final width) => bridge.SignatureInk(
            kind: bridge.SignatureInkKind.drawn,
            text: '',
            family: '',
            strokes: _bridgePoints(strokes),
            width: width,
            image: Uint8List(0),
          ),
          ImageInk(:final bytes) => bridge.SignatureInk(
            kind: bridge.SignatureInkKind.image,
            text: '',
            family: '',
            strokes: const [],
            width: 0,
            image: bytes,
          ),
        },
        color: _bridgeColor(signature.color),
        tilt: signature.tilt,
        initials: signature.initials,
        field: signature.field,
        author: signature.author,
      ),
      name: name,
    ),
  );

  @override
  Future<List<SavedSignatureFile>> savedSignatures(String directory) async {
    try {
      return [
        for (final file in await bridge.savedSignatures(dir: directory))
          SavedSignatureFile(name: file.name, bytes: file.bytes),
      ];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> writeSavedSignature(
    String directory,
    String name,
    Uint8List bytes,
  ) async {
    try {
      await bridge.writeSavedSignature(
        dir: directory,
        name: name,
        bytes: bytes,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> deleteSavedSignature(String directory, String name) async {
    try {
      await bridge.deleteSavedSignature(dir: directory, name: name);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  static FieldProblem _problem(bridge.FieldProblem problem) => FieldProblem(
    kind: FieldProblemKind.values.byName(problem.kind.name),
    maxLen: problem.maxLen,
    pattern: problem.pattern,
    min: problem.min,
    max: problem.max,
  );

  static FieldInfo _field(bridge.FieldInfo field) => FieldInfo(
    handle: field.handle.toInt(),
    name: field.name,
    label: field.label,
    kind: FieldKind.values.byName(field.kind.name),
    readOnly: field.readOnly,
    required: field.required_,
    multiline: field.multiline,
    password: field.password,
    comb: field.comb,
    multiSelect: field.multiSelect,
    editable: field.editable,
    values: field.values,
    options: [
      for (final option in field.options)
        FieldOption(export: option.export_, display: option.display),
    ],
    maxLen: field.maxLen,
    widgets: [
      for (final widget in field.widgets)
        FieldWidget(
          page: widget.page.toInt(),
          rect: Rect.fromLTRB(
            widget.rect.left,
            widget.rect.top,
            widget.rect.right,
            widget.rect.bottom,
          ),
          onState: widget.onState,
        ),
    ],
    format: FieldFormatKind.values.byName(field.format.name),
    datePattern: field.datePattern,
    decimals: field.decimals,
    min: field.min,
    max: field.max,
    problem: switch (field.problem) {
      null => null,
      final problem => _problem(problem),
    },
    signed: field.signed,
    signature: field.signature?.toInt(),
    filled: field.filled,
  );

  @override
  Future<AnnotationList> annotations(int document) async {
    try {
      final list = await bridge.annotations(document: BigInt.from(document));
      return AnnotationList(
        annotations: [for (final item in list.annotations) _annotation(item)],
        people: list.people,
        truncated: list.truncated,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<AnnotationCommit> addAnnotation(
    int document,
    int page,
    NewAnnotation annotation,
    String name,
  ) => _annotationCommit(
    () => bridge.addAnnotation(
      document: BigInt.from(document),
      page: BigInt.from(page),
      annotation: bridge.NewAnnotation(
        kind: bridge.AnnotationKind.values.byName(annotation.kind.name),
        rect: _bridgeRect(annotation.rect),
        points: _bridgePoints(annotation.points),
        color: _bridgeColor(annotation.color),
        stroke: annotation.stroke,
        opacity: annotation.opacity,
        contents: annotation.contents,
        author: annotation.author,
        fontSize: annotation.fontSize,
        arrow: annotation.arrow,
        label: annotation.label,
        meta: annotation.meta,
        tilt: annotation.tilt,
        icon: annotation.icon,
        comb: annotation.comb,
      ),
      name: name,
    ),
  );

  @override
  Future<AnnotationCommit> updateAnnotation(
    int document,
    int handle,
    AnnotationChange change,
    String name,
  ) => _annotationCommit(
    () => bridge.updateAnnotation(
      document: BigInt.from(document),
      handle: BigInt.from(handle),
      change: bridge.AnnotationChange(
        contents: change.contents,
        rect: switch (change.rect) {
          null => null,
          final rect => _bridgeRect(rect),
        },
        points: switch (change.points) {
          null => null,
          final points => _bridgePoints(points),
        },
        color: switch (change.color) {
          null => null,
          final color => _bridgeColor(color),
        },
        stroke: change.stroke,
        opacity: change.opacity,
        fontSize: change.fontSize,
      ),
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> deleteAnnotation(
    int document,
    int handle,
    String name,
  ) => _revision(
    () => bridge.deleteAnnotation(
      document: BigInt.from(document),
      handle: BigInt.from(handle),
      name: name,
    ),
  );

  @override
  Future<int> showComments(int document, {required bool visible}) async {
    try {
      final key = await bridge.showComments(
        document: BigInt.from(document),
        visible: visible,
      );
      return key.toSigned(64).toInt();
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Stream<JobUpdate> flattenAnnotationsJob(
    int document,
    List<int> handles, {
    required String name,
    String? copy,
    String? staging,
  }) => _jobUpdates(
    bridge.startFlattenAnnotationsJob(
      document: BigInt.from(document),
      handles: Uint64List.fromList([for (final handle in handles) handle]),
      copy: copy,
      staging: staging,
      name: name,
    ),
  );

  @override
  Stream<JobUpdate> commentSummaryJob(
    int document,
    SummaryFormat format,
    SummaryOptions options, {
    required String output,
    String? staging,
  }) => _jobUpdates(
    bridge.startCommentSummaryJob(
      document: BigInt.from(document),
      format: bridge.SummaryFormat.values.byName(format.name),
      options: bridge.SummaryOptions(
        open: options.open,
        resolved: options.resolved,
        replies: options.replies,
        emptyPages: options.emptyPages,
        sort: bridge.SummarySort.values.byName(options.sort.name),
        pageLabel: options.pageLabel,
        columns: options.columns,
        kinds: [
          for (final MapEntry(:key, :value) in options.kinds.entries)
            bridge.SummaryKindName(
              kind: bridge.AnnotationKind.values.byName(key.name),
              name: value,
            ),
        ],
        openLabel: options.openLabel,
        resolvedLabel: options.resolvedLabel,
        noComments: options.noComments,
        datePattern: options.datePattern,
        paperWidth: options.paperWidth,
        paperHeight: options.paperHeight,
      ),
      output: output,
      staging: staging,
    ),
  );

  @override
  Future<LinkList> links(int document) async {
    try {
      final list = await bridge.links(document: BigInt.from(document));
      return LinkList(
        links: [for (final link in list.links) _link(link)],
        truncated: list.truncated,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<LinkInfo?> linkAt(int document, int page, Offset point) async {
    try {
      final link = await bridge.linkAt(
        document: BigInt.from(document),
        page: BigInt.from(page),
        x: point.dx,
        y: point.dy,
      );
      return link == null ? null : _link(link);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<AnnotationCommit> addLink(
    int document,
    int page,
    NewLink link,
    String name,
  ) => _annotationCommit(
    () => bridge.addLink(
      document: BigInt.from(document),
      page: BigInt.from(page),
      link: bridge.NewLink(
        rect: _bridgeRect(link.rect),
        quads: _bridgePoints(link.quads),
        destination: _bridgeDestination(link.destination),
        look: bridge.LinkLook.values.byName(link.look.name),
        color: _bridgeColor(link.color),
      ),
      name: name,
    ),
  );

  @override
  Future<AnnotationCommit> updateLink(
    int document,
    int handle,
    LinkChange change,
    String name,
  ) => _annotationCommit(
    () => bridge.updateLink(
      document: BigInt.from(document),
      handle: BigInt.from(handle),
      change: bridge.LinkChange(
        rect: switch (change.rect) {
          null => null,
          final rect => _bridgeRect(rect),
        },
        destination: switch (change.destination) {
          null => null,
          final destination => _bridgeDestination(destination),
        },
        look: switch (change.look) {
          null => null,
          final look => bridge.LinkLook.values.byName(look.name),
        },
        color: switch (change.color) {
          null => null,
          final color => _bridgeColor(color),
        },
      ),
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> deleteLink(int document, int handle, String name) =>
      _revision(
        () => bridge.deleteLink(
          document: BigInt.from(document),
          handle: BigInt.from(handle),
          name: name,
        ),
      );

  static bridge.LinkDestination _bridgeDestination(
    LinkDestination destination,
  ) => bridge.LinkDestination(
    address: destination.address,
    mail: destination.mail,
    page: switch (destination.page) {
      null => null,
      final page => BigInt.from(page),
    },
  );

  static LinkInfo _link(bridge.LinkInfo link) => LinkInfo(
    handle: link.handle.toSigned(64).toInt(),
    page: link.page.toSigned(64).toInt(),
    rect: _rect(link.rect),
    quads: [
      for (final part in link.quads)
        [for (final point in part.points) Offset(point.x, point.y)],
    ],
    kind: LinkKind.values.byName(link.kind.name),
    target: link.target,
    targetPage: link.targetPage?.toSigned(64).toInt(),
    wantedPage: link.wantedPage?.toSigned(64).toInt(),
    look: LinkLook.values.byName(link.look.name),
    color: switch (link.color) {
      null => null,
      final color => AnnotationColor(color.red, color.green, color.blue),
    },
  );

  @override
  Future<AnnotationCommit> replyToAnnotation(
    int document,
    int handle, {
    required String author,
    required String text,
    required String name,
  }) => _annotationCommit(
    () => bridge.replyToAnnotation(
      document: BigInt.from(document),
      handle: BigInt.from(handle),
      author: author,
      text: text,
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> setAnnotationResolved(
    int document,
    int handle, {
    required String author,
    required bool resolved,
    required String name,
  }) => _revision(
    () => bridge.setAnnotationResolved(
      document: BigInt.from(document),
      handle: BigInt.from(handle),
      author: author,
      resolved: resolved,
      name: name,
    ),
  );

  static Future<AnnotationCommit> _annotationCommit(
    Future<bridge.AnnotationCommit> Function() call,
  ) async {
    bridge.AnnotationCommit? commit;
    final revision = await _revision(() async {
      final made = await call();
      commit = made;
      return made.revision;
    });
    return AnnotationCommit(handle: commit!.handle.toInt(), revision: revision);
  }

  static bridge.PageRect _bridgeRect(Rect rect) => bridge.PageRect(
    left: rect.left,
    top: rect.top,
    right: rect.right,
    bottom: rect.bottom,
  );

  static List<bridge.AnnotationPoints> _bridgePoints(
    List<List<Offset>> points,
  ) => [
    for (final part in points)
      bridge.AnnotationPoints(
        points: [
          for (final point in part) bridge.PagePoint(x: point.dx, y: point.dy),
        ],
      ),
  ];

  static bridge.AnnotationColor _bridgeColor(AnnotationColor color) =>
      bridge.AnnotationColor(
        red: color.red,
        green: color.green,
        blue: color.blue,
      );

  static AnnotationInfo _annotation(bridge.AnnotationInfo item) =>
      AnnotationInfo(
        handle: item.handle.toInt(),
        page: item.page.toInt(),
        kind: AnnotationKind.values.byName(item.kind.name),
        subtype: item.subtype,
        rect: _rect(item.rect),
        points: [
          for (final part in item.points)
            [for (final point in part.points) Offset(point.x, point.y)],
        ],
        arrow: item.arrow,
        color: switch (item.color) {
          null => null,
          final color => AnnotationColor(color.red, color.green, color.blue),
        },
        opacity: item.opacity,
        stroke: item.stroke,
        fontSize: item.fontSize,
        author: item.author,
        contents: item.contents,
        quote: item.quote,
        rich: item.rich,
        created: _instant(item.created),
        modified: _instant(item.modified),
        icon: item.icon,
        repliesTo: item.repliesTo?.toInt(),
        thread: item.thread.toInt(),
        state: item.state,
        resolved: item.resolved,
        resolvedBy: item.resolvedBy,
        resolvedAt: _instant(item.resolvedAt),
        mentions: item.mentions,
      );

  /// A date with a zone as local time, one with none as written.
  static DateTime? _instant(bridge.PdfDate? date) {
    if (date == null) return null;
    final offset = date.offsetMinutes;
    if (offset == null) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second,
      );
    }
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute - offset,
      date.second,
    ).toLocal();
  }

  @override
  Future<RevisionInfo> rotatePages(
    int document,
    List<int> pages,
    int quarterTurns,
    String name,
  ) => _revision(
    () => bridge.rotatePages(
      document: BigInt.from(document),
      pages: _handles(pages),
      quarterTurns: quarterTurns,
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> deletePages(
    int document,
    List<int> pages,
    String name,
  ) => _revision(
    () => bridge.deletePages(
      document: BigInt.from(document),
      pages: _handles(pages),
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> movePages(
    int document,
    List<int> pages,
    int? before,
    String name,
  ) => _revision(
    () => bridge.movePages(
      document: BigInt.from(document),
      pages: _handles(pages),
      before: before == null ? null : BigInt.from(before),
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> duplicatePages(
    int document,
    List<int> pages,
    String name,
  ) => _revision(
    () => bridge.duplicatePages(
      document: BigInt.from(document),
      pages: _handles(pages),
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> insertBlankPages(
    int document, {
    required int? after,
    required int count,
    required double width,
    required double height,
    required String name,
  }) => _revision(
    () => bridge.insertBlankPages(
      document: BigInt.from(document),
      after: after == null ? null : BigInt.from(after),
      count: count,
      width: width,
      height: height,
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> setPageSize(
    int document,
    List<int> pages, {
    required double width,
    required double height,
    required PageFit fit,
    required String name,
  }) => _revision(
    () => bridge.setPageSize(
      document: BigInt.from(document),
      pages: _handles(pages),
      width: width,
      height: height,
      fit: switch (fit) {
        PageFit.centre => bridge.PageFit.centre,
        PageFit.scale => bridge.PageFit.scale,
      },
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> cropPages(
    int document,
    Map<int, PageMargins> crops,
    String name,
  ) => _revision(
    () => bridge.cropPages(
      document: BigInt.from(document),
      crops: [
        for (final MapEntry(key: page, value: margins) in crops.entries)
          bridge.PageCrop(
            page: BigInt.from(page),
            margins: bridge.PageMargins(
              top: margins.top,
              bottom: margins.bottom,
              left: margins.left,
              right: margins.right,
            ),
          ),
      ],
      name: name,
    ),
  );

  @override
  Future<List<PageMargins?>> whiteMargins(int document, List<int> pages) async {
    try {
      final margins = await bridge.whiteMargins(
        document: BigInt.from(document),
        pages: _handles(pages),
      );
      return [
        for (final page in margins)
          switch (page) {
            null => null,
            final page => PageMargins(
              top: page.top,
              bottom: page.bottom,
              left: page.left,
              right: page.right,
            ),
          },
      ];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<List<PageLabelRange>> pageLabelRanges(int document) async {
    try {
      final ranges = await bridge.pageLabelRanges(
        document: BigInt.from(document),
      );
      return [
        for (final range in ranges)
          PageLabelRange(
            start: range.start,
            style: switch (range.style) {
              bridge.LabelStyle.none => PageLabelStyle.none,
              bridge.LabelStyle.decimal => PageLabelStyle.decimal,
              bridge.LabelStyle.romanUpper => PageLabelStyle.romanUpper,
              bridge.LabelStyle.romanLower => PageLabelStyle.romanLower,
              bridge.LabelStyle.lettersUpper => PageLabelStyle.lettersUpper,
              bridge.LabelStyle.lettersLower => PageLabelStyle.lettersLower,
            },
            prefix: range.prefix,
            first: range.first,
          ),
      ];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<RevisionInfo> setPageLabels(
    int document,
    List<PageLabelRange> ranges,
    String name,
  ) => _revision(
    () => bridge.setPageLabels(
      document: BigInt.from(document),
      ranges: [
        for (final range in ranges)
          bridge.LabelRange(
            start: range.start,
            style: switch (range.style) {
              PageLabelStyle.none => bridge.LabelStyle.none,
              PageLabelStyle.decimal => bridge.LabelStyle.decimal,
              PageLabelStyle.romanUpper => bridge.LabelStyle.romanUpper,
              PageLabelStyle.romanLower => bridge.LabelStyle.romanLower,
              PageLabelStyle.lettersUpper => bridge.LabelStyle.lettersUpper,
              PageLabelStyle.lettersLower => bridge.LabelStyle.lettersLower,
            },
            prefix: range.prefix,
            first: range.first,
          ),
      ],
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> setOutline(
    int document,
    List<OutlineEdit> items,
    String name,
  ) => _revision(
    () => bridge.setOutline(
      document: BigInt.from(document),
      items: [
        for (final item in items)
          bridge.OutlineEdit(
            item: item.item,
            page: item.page,
            title: item.title,
            depth: item.depth,
            open: item.open,
          ),
      ],
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> setInfo(int document, InfoEdit info, String name) =>
      _revision(
        () => bridge.setInfo(
          document: BigInt.from(document),
          info: bridge.InfoEdit(
            title: info.title,
            author: info.author,
            subject: info.subject,
            keywords: info.keywords,
          ),
          name: name,
        ),
      );

  @override
  Future<RevisionInfo> attachFile(
    int document,
    String path,
    String fileName,
    String name,
  ) => _revision(
    () => bridge.attachFile(
      document: BigInt.from(document),
      path: path,
      fileName: fileName,
      name: name,
    ),
  );

  @override
  Future<RevisionInfo> removeAttachment(int document, int index, String name) =>
      _revision(
        () => bridge.removeAttachment(
          document: BigInt.from(document),
          index: index,
          name: name,
        ),
      );

  @override
  Future<int> showFormWidgets(int document, {required bool visible}) async {
    try {
      final key = await bridge.showFormWidgets(
        document: BigInt.from(document),
        visible: visible,
      );
      return key.toSigned(64).toInt();
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<RevisionInfo> undo(int document) =>
      _revision(() => bridge.undo(document: BigInt.from(document)));

  @override
  Future<RevisionInfo> redo(int document) =>
      _revision(() => bridge.redo(document: BigInt.from(document)));

  static Future<RevisionInfo> _revision(
    Future<bridge.RevisionInfo> Function() call,
  ) async {
    try {
      return _revisionOf(await call());
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  static RevisionInfo _revisionOf(bridge.RevisionInfo info) => RevisionInfo(
    current: info.current,
    // A render key is a 64-bit value: wrapped, not clamped.
    renderKey: info.renderKey?.toSigned(64).toInt(),
    changedPages: info.changedPages?.toList(),
    substitutions: [
      for (final substitution in info.substitutions)
        _substitution(substitution),
    ],
    structure: switch (info.structure) {
      null => null,
      final structure => DocumentStructure(
        pages: _pages(structure.pages),
        outline: _outline(structure.outline),
        attachments: _attachments(structure.attachments),
        info: _info(structure.info),
      ),
    },
  );

  @override
  Future<Reverted> revert(
    int document,
    int step,
    String name, {
    bool withDependents = false,
  }) async {
    final dependents = <int>[];
    var done = false;
    final revision = await _revision(() async {
      final result = await bridge.revert(
        document: BigInt.from(document),
        step: step,
        withDependents: withDependents,
        name: name,
      );
      dependents.addAll(result.dependents);
      done = result.reverted;
      return result.revision;
    });
    return Reverted(reverted: done, revision: revision, dependents: dependents);
  }

  @override
  Future<RevisionInfo> revertAll(int document, String name) => _revision(
    () => bridge.revertAll(document: BigInt.from(document), name: name),
  );

  @override
  Future<String?> saveText(String path, String text, {String? staging}) async {
    try {
      return await bridge.saveText(path: path, text: text, staging: staging);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<EditHistory> history(int document) async {
    try {
      final history = await bridge.history(document: BigInt.from(document));
      return EditHistory(
        steps: [
          for (final step in history.steps)
            HistoryStep(
              name: step.name,
              time: DateTime.fromMillisecondsSinceEpoch(step.time),
              hiddenLines: step.hiddenLines,
              substitutions: [
                for (final substitution in step.substitutions)
                  _substitution(substitution),
              ],
              pages: [for (final page in step.pages) page.toInt()],
              before: step.before,
              after: step.after,
              reverts: step.reverts.toList(),
              client: step.client,
            ),
        ],
        current: history.current,
        signatureInvalidated: history.signatureInvalidated,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<String?> save(
    int document, {
    bool overChange = false,
    String? staging,
  }) async {
    try {
      final id = BigInt.from(document);
      return await (overChange
          ? bridge.saveOverChange(document: id, staging: staging)
          : bridge.save(document: id, staging: staging));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<bool> finishSave(int document, {required bool swapped}) async {
    try {
      return await bridge.finishSave(
        document: BigInt.from(document),
        swapped: swapped,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<String?> saveAs(
    int document,
    String path, {
    SaveAsOptions options = const SaveAsOptions(),
    String? staging,
  }) async {
    try {
      return await bridge.saveAs(
        document: BigInt.from(document),
        path: path,
        options: _saveOptions(options),
        staging: staging,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<String?> saveCopy(
    int document,
    String path, {
    SaveAsOptions options = const SaveAsOptions(),
    String? staging,
  }) async {
    try {
      return await bridge.saveCopy(
        document: BigInt.from(document),
        path: path,
        options: _saveOptions(options),
        staging: staging,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  static bridge.SaveAsOptions _saveOptions(SaveAsOptions options) =>
      bridge.SaveAsOptions(
        includeComments: options.includeComments,
        removeHistory: options.removeHistory,
      );

  @override
  Future<String?> saveRepairedCopy(
    int document,
    String path, {
    bool replaceOriginal = false,
    String? staging,
  }) async {
    try {
      return await bridge.saveRepairedCopy(
        document: BigInt.from(document),
        path: path,
        replaceOriginal: replaceOriginal,
        staging: staging,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  /// Runs Optimize and clean's job to its end: the staged file, or null.
  @override
  Future<String?> optimizeAndClean(int document, {String? staging}) async {
    final last = await _jobUpdates(
      bridge.startOptimizeAndCleanJob(
        document: BigInt.from(document),
        staging: staging,
      ),
    ).last;
    switch (last.state) {
      case JobState.done:
        return last.outputs.isEmpty ? null : last.outputs.first.staged;
      case JobState.failed:
        throw last.error ?? const EngineException(messageKey: 'errorInternal');
      case JobState.cancelled || JobState.running || JobState.paused:
        throw const EngineException(messageKey: 'errorInternal');
    }
  }

  @override
  Future<CompressAnalysis> compressAnalysis(int document) async {
    try {
      final analysis = await bridge.compressAnalysis(
        document: BigInt.from(document),
      );
      return CompressAnalysis(
        before: analysis.before.toInt(),
        estimates: [
          for (final estimate in analysis.estimates)
            CompressEstimate(
              preset: switch (estimate.preset) {
                bridge.CompressPreset.highQuality => CompressPreset.highQuality,
                bridge.CompressPreset.balanced => CompressPreset.balanced,
                bridge.CompressPreset.smallest => CompressPreset.smallest,
              },
              after: estimate.after.toInt(),
              exact: estimate.exact,
              sampled: estimate.sampled,
            ),
        ],
        images: analysis.images,
        unreadable: analysis.unreadable,
        masks: analysis.masks,
        patterns: analysis.patterns,
        duplicateFonts: analysis.duplicateFonts,
        thumbnails: analysis.thumbnails,
        signed: analysis.signed,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Stream<JobUpdate> compressJob(
    int document, {
    required CompressPreset preset,
    required String output,
    bool unsign = false,
    String? staging,
  }) => _jobUpdates(
    bridge.startCompressJob(
      document: BigInt.from(document),
      preset: switch (preset) {
        CompressPreset.highQuality => bridge.CompressPreset.highQuality,
        CompressPreset.balanced => bridge.CompressPreset.balanced,
        CompressPreset.smallest => bridge.CompressPreset.smallest,
      },
      unsign: unsign,
      output: output,
      staging: staging,
    ),
  );

  @override
  Future<void> setVersionsEnabled({required bool enabled}) async {
    try {
      await bridge.setVersionsEnabled(enabled: enabled);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<List<VersionInfo>> versions(int document) async {
    try {
      final list = await bridge.versions(document: BigInt.from(document));
      return [
        for (final version in list)
          VersionInfo(
            id: version.id.toInt(),
            kind: switch (version.kind) {
              bridge.VersionKind.opened => VersionKind.opened,
              bridge.VersionKind.saved => VersionKind.saved,
              bridge.VersionKind.signed => VersionKind.signed,
              bridge.VersionKind.unsaved => VersionKind.unsaved,
              bridge.VersionKind.restored => VersionKind.restored,
            },
            time: version.time.toInt(),
            size: version.size.toInt(),
            edits: version.edits,
            names: version.names,
          ),
      ];
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<OpenedDocument> openVersion(
    int document,
    int version, {
    String? password,
  }) async {
    try {
      return _opened(
        await bridge.openVersion(
          document: BigInt.from(document),
          version: BigInt.from(version),
          password: password,
        ),
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<String?> restoreVersion(
    int document,
    int version, {
    String? staging,
  }) async {
    try {
      return await bridge.restoreVersion(
        document: BigInt.from(document),
        version: BigInt.from(version),
        staging: staging,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Stream<PrintPage> printPages(
    int document, {
    List<int> pages = const [],
    bool includeComments = true,
  }) => bridge
      .printPages(
        document: BigInt.from(document),
        pages: _handles(pages),
        includeComments: includeComments,
      )
      .handleError(
        (Object error) => throw _exception(error as bridge.ApiError),
        test: (error) => error is bridge.ApiError,
      )
      .map(
        (page) => PrintPage(
          index: page.index,
          widthPoints: page.widthPoints,
          heightPoints: page.heightPoints,
          dpi: page.dpi,
          width: page.width,
          height: page.height,
          pixels: page.pixels,
        ),
      );

  @override
  Future<bool> wouldBreakSignatures(int document) async {
    try {
      return await bridge.wouldBreakSignatures(document: BigInt.from(document));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<OpGate> opGate(
    int document,
    DocumentOp op, {
    List<String> fields = const [],
  }) async {
    try {
      final gate = await bridge.opGate(
        document: BigInt.from(document),
        op: switch (op) {
          DocumentOp.editText => bridge.DocumentOp.editText,
          DocumentOp.organize => bridge.DocumentOp.organize,
          DocumentOp.comment => bridge.DocumentOp.comment,
          DocumentOp.fill => bridge.DocumentOp.fill,
          DocumentOp.print => bridge.DocumentOp.print,
          DocumentOp.modify => bridge.DocumentOp.modify,
        },
        fields: fields,
      );
      return switch (gate) {
        bridge.OpGate.unaffected => OpGate.unaffected,
        bridge.OpGate.keepsSignatures => OpGate.keepsSignatures,
        bridge.OpGate.breaksSignatures => OpGate.breaksSignatures,
        bridge.OpGate.forbidden => OpGate.forbidden,
      };
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<int> confirmEditSigned(int document) async {
    try {
      final token = await bridge.confirmEditSigned(
        document: BigInt.from(document),
      );
      return token.toInt();
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<String?> saveUnsignedCopy(
    int document,
    String path, {
    String? staging,
  }) async {
    try {
      return await bridge.saveUnsignedCopy(
        document: BigInt.from(document),
        path: path,
        staging: staging,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<bool> checkExternalChange(int document) async {
    try {
      return await bridge.checkExternalChange(document: BigInt.from(document));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  static PageBlocks _pageBlocks(bridge.PageBlocks blocks) => PageBlocks(
    blocks: [
      for (final block in blocks.blocks)
        TextBlock(
          id: block.id.toSigned(64).toInt(),
          frame: _rect(block.frame),
          lines: [
            for (final line in block.lines)
              TextLine(
                text: line.text,
                bbox: _rect(line.bbox),
                baselineStart: Offset(
                  line.baselineStart.x,
                  line.baselineStart.y,
                ),
                baselineEnd: Offset(line.baselineEnd.x, line.baselineEnd.y),
              ),
          ],
          alignment: _alignment(block.alignment),
          direction: switch (block.direction) {
            bridge.TextDirection.leftToRight => BlockDirection.leftToRight,
            bridge.TextDirection.rightToLeft => BlockDirection.rightToLeft,
            bridge.TextDirection.vertical => BlockDirection.vertical,
          },
          notEditable: _reason(block.notEditable),
          language: block.language,
        ),
    ],
    empty: _reason(blocks.empty),
  );

  static Rect _rect(bridge.PageRect rect) =>
      Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom);

  static NotEditableReason? _reason(bridge.NotEditableReason? reason) =>
      switch (reason) {
        null => null,
        bridge.NotEditableReason.imageOnly => NotEditableReason.imageOnly,
        bridge.NotEditableReason.unknownText => NotEditableReason.unknownText,
        bridge.NotEditableReason.outlinedText => NotEditableReason.outlinedText,
        bridge.NotEditableReason.invisibleText =>
          NotEditableReason.invisibleText,
        bridge.NotEditableReason.restricted => NotEditableReason.restricted,
        bridge.NotEditableReason.readOnly => NotEditableReason.readOnly,
        bridge.NotEditableReason.damaged => NotEditableReason.damaged,
        bridge.NotEditableReason.signatureAppearance =>
          NotEditableReason.signatureAppearance,
        bridge.NotEditableReason.annotationOrField =>
          NotEditableReason.annotationOrField,
        bridge.NotEditableReason.tooComplexLimits =>
          NotEditableReason.tooComplexLimits,
        bridge.NotEditableReason.tooComplexSplitOperator =>
          NotEditableReason.tooComplexSplitOperator,
        bridge.NotEditableReason.tooComplexSkewed =>
          NotEditableReason.tooComplexSkewed,
      };

  @override
  Future<void> closeView(int view) async {
    try {
      await bridge.closeView(view: BigInt.from(view));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  /// Panics inside the engine's API guard (debug builds only) and returns
  /// the resulting error, for the test that a Rust panic reaches Dart as an
  /// error and the app keeps running.
  Future<EngineException?> debugPanic() async {
    try {
      await bridge.debugPanic();
      return null;
    } on bridge.ApiError catch (error) {
      return _exception(error);
    }
  }

  /// Returns [length] bytes from the engine, for the bridge benchmark.
  Future<int> debugBytesLength(int length) async =>
      (await bridge.debugBytes(len: length)).length;
}

/// A block id as the engine's `u64`. Block ids are hashes using all 64 bits, so
/// the app's `int` holds them with `toSigned(64)`; `toInt()` alone would clamp
/// half of them to the same value.
BigInt _wireBlockId(int block) => BigInt.from(block).toUnsigned(64);

EngineException _exception(bridge.ApiError error) => EngineException(
  kind: _kind(error.kind),
  messageKey: error.messageKey,
  details: error.details,
  offersSaveAs: error.offerSaveAs,
  noRecoveryCopy: error.noRecoveryCopy,
);

/// Every error kind of the bridge by name, with the app's kind it maps to,
/// for the test of the mapping (the tests cannot import the bridge).
@visibleForTesting
Map<String, EngineErrorKind> get bridgeErrorKinds => {
  for (final kind in bridge.ErrorKind.values) kind.name: _kind(kind),
};

EngineErrorKind _kind(bridge.ErrorKind kind) => switch (kind) {
  bridge.ErrorKind.invalidInput => EngineErrorKind.invalidInput,
  bridge.ErrorKind.notFound => EngineErrorKind.notFound,
  bridge.ErrorKind.permissionDenied => EngineErrorKind.permissionDenied,
  bridge.ErrorKind.passwordRequired => EngineErrorKind.passwordRequired,
  bridge.ErrorKind.wrongPassword => EngineErrorKind.wrongPassword,
  bridge.ErrorKind.damaged => EngineErrorKind.damaged,
  bridge.ErrorKind.unsupported => EngineErrorKind.unsupported,
  bridge.ErrorKind.resourceLimit => EngineErrorKind.resourceLimit,
  bridge.ErrorKind.io => EngineErrorKind.io,
  bridge.ErrorKind.notEditable => EngineErrorKind.notEditable,
  bridge.ErrorKind.diskFull => EngineErrorKind.diskFull,
  bridge.ErrorKind.fileLocked => EngineErrorKind.fileLocked,
  bridge.ErrorKind.renameFailed => EngineErrorKind.renameFailed,
  bridge.ErrorKind.volumeGone => EngineErrorKind.volumeGone,
  bridge.ErrorKind.hardLinked => EngineErrorKind.hardLinked,
  bridge.ErrorKind.notOwner => EngineErrorKind.notOwner,
  bridge.ErrorKind.fileChangedOnDisk => EngineErrorKind.fileChangedOnDisk,
  bridge.ErrorKind.confirmationRequired => EngineErrorKind.confirmationRequired,
  bridge.ErrorKind.internal => EngineErrorKind.internal,
};

bridge.ViewItem _item(RenderItem item) => switch (item) {
  TileItem() => bridge.ViewItem(
    kind: bridge.ItemKind.tile,
    page: item.page,
    zoomBucket: item.zoomBucket,
    devicePixelRatio: item.devicePixelRatio,
    column: item.column,
    row: item.row,
    size: 0,
  ),
  ThumbnailItem() => bridge.ViewItem(
    kind: bridge.ItemKind.thumbnail,
    page: item.page,
    zoomBucket: 0,
    devicePixelRatio: 0,
    column: 0,
    row: 0,
    size: item.size,
  ),
};

/// A rendered or failed item, or null for an event without one.
ViewUpdate? _update(bridge.ViewEvent event) {
  final item = switch (event.item) {
    null => null,
    final bridge.ViewItem item => switch (item.kind) {
      bridge.ItemKind.tile => TileItem(
        page: item.page,
        zoomBucket: item.zoomBucket,
        devicePixelRatio: item.devicePixelRatio,
        column: item.column,
        row: item.row,
      ),
      bridge.ItemKind.thumbnail => ThumbnailItem(
        page: item.page,
        size: item.size,
      ),
    },
  };
  if (item == null) return null;
  // A render key is a 64-bit hash: wrapped, not clamped, so keys stay apart.
  final generation = event.generation.toSigned(64).toInt();
  return switch (event.kind) {
    bridge.ViewEventKind.rendered => RenderedItem(
      item: item,
      generation: generation,
      renderKey: event.renderKey.toSigned(64).toInt(),
      x: event.x,
      y: event.y,
      width: event.width,
      height: event.height,
      stride: event.stride,
      pixels: event.pixels,
    ),
    bridge.ViewEventKind.failed => FailedItem(
      item: item,
      generation: generation,
      reason: switch (event.failReason) {
        bridge.FailReason.noSuchPage => RenderFailure.noSuchPage,
        bridge.FailReason.outOfRange => RenderFailure.outOfRange,
        bridge.FailReason.pageDamaged => RenderFailure.pageDamaged,
        bridge.FailReason.outOfMemory => RenderFailure.outOfMemory,
        bridge.FailReason.internal || null => RenderFailure.internal,
      },
    ),
    bridge.ViewEventKind.opened => null,
  };
}

/// The engine library the build bundles with the app, as an absolute path
/// next to the running executable (where the Rust engine also finds PDFium).
///
/// The bridge's default loader is not used: it first tries a folder relative
/// to the current directory, so a packaged app could load a library from
/// wherever it was started, and on macOS it looks for a framework named after
/// the crate, while cargokit links the engine into the `rust_lib_ferman`
/// plugin framework.
String bundledEngineLibraryPath({String? executable, String? operatingSystem}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  final separator = os == 'windows' ? r'\' : '/';
  final exe = executable ?? Platform.resolvedExecutable;
  final cut = exe.lastIndexOf(separator);
  final dir = cut < 0 ? '.' : exe.substring(0, cut);
  String join(List<String> parts) => [dir, ...parts].join(separator);
  return switch (os) {
    'linux' => join(['lib', 'libferman_api.so']),
    'windows' => join(['ferman_api.dll']),
    'macos' => join([
      '..',
      'Frameworks',
      'rust_lib_ferman.framework',
      'rust_lib_ferman',
    ]),
    _ => throw const EngineUnavailableException(
      EngineUnavailableReason.unsupportedPlatform,
    ),
  };
}

/// The folder of the fonts the build bundles (`app/assets/fonts`), as an absolute path next to the running executable: where
/// Flutter puts the app's assets on each desktop system; null elsewhere.
String? bundledFontsDirectory({String? executable, String? operatingSystem}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  final separator = os == 'windows' ? r'\' : '/';
  final exe = executable ?? Platform.resolvedExecutable;
  final cut = exe.lastIndexOf(separator);
  final dir = cut < 0 ? '.' : exe.substring(0, cut);
  String join(List<String> parts) => [dir, ...parts].join(separator);
  const assets = ['flutter_assets', 'assets', 'fonts'];
  return switch (os) {
    'linux' || 'windows' => join(['data', ...assets]),
    'macos' => join([
      '..',
      'Frameworks',
      'App.framework',
      'Resources',
      ...assets,
    ]),
    _ => null,
  };
}

/// Starts the engine for this platform.
Future<EngineService> startEngine() => FrbEngineService.start();

/// Page handles as the bridge takes them.
Uint64List _handles(List<int> pages) {
  final handles = Uint64List(pages.length);
  for (var i = 0; i < pages.length; i++) {
    handles[i] = BigInt.from(pages[i]);
  }
  return handles;
}

/// The engine's pages as the app's.
List<PageInfo> _pages(List<bridge.PageInfo> pages) => [
  for (final page in pages)
    PageInfo(
      width: page.width,
      height: page.height,
      rotation: page.rotation,
      label: page.label,
      handle: page.handle.toInt(),
    ),
];

/// The engine's outline as the app's.
List<OutlineEntry> _outline(List<bridge.OutlineEntry> outline) => [
  for (final item in outline)
    OutlineEntry(
      title: item.title,
      page: item.page,
      depth: item.depth,
      open: item.open,
    ),
];

/// The engine's attachments as the app's.
List<Attachment> _attachments(List<bridge.Attachment> attachments) => [
  for (final file in attachments)
    Attachment(
      name: file.name,
      size: file.size?.toInt(),
      modified: _date(file.modified),
    ),
];

/// The engine's document as the app's.
OpenedDocument _opened(bridge.OpenedDocument document) => OpenedDocument(
  id: document.id.toInt(),
  readOnly: switch (document.readOnly) {
    null => null,
    bridge.ReadOnlyReason.repaired => ReadOnlyReason.repaired,
    bridge.ReadOnlyReason.parsersDisagree => ReadOnlyReason.parsersDisagree,
    bridge.ReadOnlyReason.xfaOnly => ReadOnlyReason.xfaOnly,
  },
  repairs: [
    for (final fix in document.repairs)
      RepairFix(
        kind: switch (fix.kind) {
          bridge.RepairKind.crossReferenceRebuilt =>
            RepairKind.crossReferenceRebuilt,
          bridge.RepairKind.trailerRebuilt => RepairKind.trailerRebuilt,
          bridge.RepairKind.streamLengthsCorrected =>
            RepairKind.streamLengthsCorrected,
          bridge.RepairKind.objectsUnreadable => RepairKind.objectsUnreadable,
        },
        count: fix.count,
      ),
  ],
  rightToLeft: document.rightToLeft,
  pages: _pages(document.pages),
  outline: _outline(document.outline),
  attachments: _attachments(document.attachments),
  layers: [
    for (final layer in document.layers)
      Layer(name: layer.name, visible: layer.visible, locked: layer.locked),
  ],
  layersSwitchable: document.layersSwitchable,
  signed: document.signed,
  certification: document.certification,
  signatures: [
    for (final field in document.signatures)
      Signature(
        field: field.field,
        signed: field.signed,
        signer: field.signer,
        signedAt: _date(field.signedAt),
        page: field.page,
      ),
  ],
  version: document.version,
  fileSize: document.fileSize.toInt(),
  info: _info(document.info),
  language: document.language,
  tagged: document.tagged,
  linearized: document.linearized,
  fonts: [
    for (final font in document.fonts)
      FontEntry(
        name: font.name,
        kind: switch (font.kind) {
          bridge.FontType.type1 => FontType.type1,
          bridge.FontType.multipleMaster => FontType.multipleMaster,
          bridge.FontType.trueType => FontType.trueType,
          bridge.FontType.type0 => FontType.type0,
          bridge.FontType.type3 => FontType.type3,
          bridge.FontType.other => FontType.other,
        },
        embedded: font.embedded,
        subset: font.subset,
      ),
  ],
  security: _security(document.security),
  scripts: document.scripts,
  formFields: document.formFields,
  scanned: document.scanned,
);

Security? _security(bridge.Security? security) => switch (security) {
  null => null,
  final security => Security(
    method: switch (security.method) {
      bridge.EncryptionMethod.rc4 => EncryptionMethod.rc4,
      bridge.EncryptionMethod.aes128 => EncryptionMethod.aes128,
      bridge.EncryptionMethod.aes256 => EncryptionMethod.aes256,
      bridge.EncryptionMethod.identity => EncryptionMethod.identity,
    },
    keyBits: security.keyBits,
    userPasswordRequired: security.userPasswordRequired,
    permissions: DocumentPermissions(
      print: security.permissions.print,
      printHighQuality: security.permissions.printHighQuality,
      modify: security.permissions.modify,
      annotate: security.permissions.annotate,
      fillForms: security.permissions.fillForms,
      copy: security.permissions.copy,
      accessibility: security.permissions.accessibility,
      assemble: security.permissions.assemble,
    ),
    owner: security.owner,
    restricted: security.restricted,
  ),
};

/// The date as the file writes it, in no time zone, so it shows as written.
DocumentInfo _info(bridge.DocumentInfo info) => DocumentInfo(
  title: info.title,
  author: info.author,
  subject: info.subject,
  keywords: info.keywords,
  creator: info.creator,
  producer: info.producer,
  created: _date(info.created),
  modified: _date(info.modified),
  editable: info.editable,
);

DateTime? _date(bridge.PdfDate? date) => date == null
    ? null
    : DateTime(date.year, date.month, date.day, date.hour, date.minute);
