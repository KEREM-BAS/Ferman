import 'dart:async';
import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:ferman/bridge/frb.dart' as bridge;
import 'package:ferman/bridge/frb_generated.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

/// The [EngineService] backed by the Rust engine through flutter_rust_bridge.
/// This file and the generated `app/lib/bridge/` are the only Dart code that
/// touches the bridge (tools/checks imports rule).
class FrbEngineService implements EngineService {
  new _();

  /// Loads the engine library, checks its API version and returns the
  /// service. Throws an [EngineUnavailableException] when the library cannot
  /// be loaded or speaks an API version this app does not accept.
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
    return service;
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
      final document = await bridge.open(path: path, password: password);
      return OpenedDocument(
        id: document.id.toInt(),
        readOnly: switch (document.readOnly) {
          null => null,
          bridge.ReadOnlyReason.repaired => ReadOnlyReason.repaired,
          bridge.ReadOnlyReason.parsersDisagree =>
            ReadOnlyReason.parsersDisagree,
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
                bridge.RepairKind.objectsUnreadable =>
                  RepairKind.objectsUnreadable,
              },
              count: fix.count,
            ),
        ],
        rightToLeft: document.rightToLeft,
        pages: [
          for (final page in document.pages)
            PageInfo(width: page.width, height: page.height, label: page.label),
        ],
        outline: [
          for (final item in document.outline)
            OutlineEntry(
              title: item.title,
              page: item.page,
              depth: item.depth,
              open: item.open,
            ),
        ],
        attachments: [
          for (final file in document.attachments)
            Attachment(
              name: file.name,
              size: file.size?.toInt(),
              modified: _date(file.modified),
            ),
        ],
        layers: [
          for (final layer in document.layers)
            Layer(
              name: layer.name,
              visible: layer.visible,
              locked: layer.locked,
            ),
        ],
        layersSwitchable: document.layersSwitchable,
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
        info: DocumentInfo(
          title: document.info.title,
          author: document.info.author,
          subject: document.info.subject,
          keywords: document.info.keywords,
          creator: document.info.creator,
          producer: document.info.producer,
          created: _date(document.info.created),
          modified: _date(document.info.modified),
        ),
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
  Future<void> close(int document) async {
    try {
      await bridge.close(document: BigInt.from(document));
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
        block: BigInt.from(block),
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
        bridge.TextPosition(block: BigInt.from(at.block), index: at.index);
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
        block: BigInt.from(block),
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
      return EditPreview(
        page: _pageBlocks(preview.page),
        missing: preview.missing,
        overflowing: preview.overflowing,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<RevisionInfo> commitEdit(int transaction, String name) => _revision(
    () => bridge.commitEdit(transaction: BigInt.from(transaction), name: name),
  );

  @override
  Future<RevisionInfo> rollbackEdit(int transaction) => _revision(
    () => bridge.rollbackEdit(transaction: BigInt.from(transaction)),
  );

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
      final info = await call();
      return RevisionInfo(
        current: info.current,
        // A render key is a 64-bit value: wrapped, not clamped.
        renderKey: info.renderKey?.toSigned(64).toInt(),
      );
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
            ),
        ],
        current: history.current,
      );
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> save(int document) async {
    try {
      await bridge.save(document: BigInt.from(document));
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  @override
  Future<void> saveAs(int document, String path) async {
    try {
      await bridge.saveAs(document: BigInt.from(document), path: path);
    } on bridge.ApiError catch (error) {
      throw _exception(error);
    }
  }

  static PageBlocks _pageBlocks(bridge.PageBlocks blocks) => PageBlocks(
    blocks: [
      for (final block in blocks.blocks)
        TextBlock(
          id: block.id.toInt(),
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
          alignment: switch (block.alignment) {
            bridge.Alignment.left => BlockAlignment.left,
            bridge.Alignment.right => BlockAlignment.right,
            bridge.Alignment.center => BlockAlignment.center,
            bridge.Alignment.justified => BlockAlignment.justified,
          },
          direction: switch (block.direction) {
            bridge.TextDirection.leftToRight => BlockDirection.leftToRight,
            bridge.TextDirection.rightToLeft => BlockDirection.rightToLeft,
            bridge.TextDirection.vertical => BlockDirection.vertical,
          },
          notEditable: _reason(block.notEditable),
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

EngineException _exception(bridge.ApiError error) => EngineException(
  kind: _kind(error.kind),
  messageKey: error.messageKey,
  details: error.details,
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

/// Starts the engine for this platform.
Future<EngineService> startEngine() => FrbEngineService.start();

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
DateTime? _date(bridge.PdfDate? date) => date == null
    ? null
    : DateTime(date.year, date.month, date.day, date.hour, date.minute);
