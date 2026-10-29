import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:ferman/bridge/frb.dart' as bridge;
import 'package:ferman/bridge/frb_generated.dart';
import 'package:ferman/engine/engine_service.dart';
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
              ),
          ]),
          bridge.SearchEventKind.progress => SearchProgress(
            searched: event.searched,
            pages: event.pages,
          ),
          bridge.SearchEventKind.done => SearchDone(cancelled: event.cancelled),
        },
      )
      .where((update) => update != null)
      .cast<SearchUpdate>();

  /// The UTF-16 offset of the character at [chars] in [text].
  static int _units(String text, int chars) => text.runes
      .take(chars)
      .fold(0, (units, rune) => units + (rune > 0xFFFF ? 2 : 1));

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
  kind: switch (error.kind) {
    bridge.ErrorKind.invalidInput => EngineErrorKind.invalidInput,
    bridge.ErrorKind.notFound => EngineErrorKind.notFound,
    bridge.ErrorKind.permissionDenied => EngineErrorKind.permissionDenied,
    bridge.ErrorKind.passwordRequired => EngineErrorKind.passwordRequired,
    bridge.ErrorKind.wrongPassword => EngineErrorKind.wrongPassword,
    bridge.ErrorKind.damaged => EngineErrorKind.damaged,
    bridge.ErrorKind.unsupported => EngineErrorKind.unsupported,
    bridge.ErrorKind.resourceLimit => EngineErrorKind.resourceLimit,
    bridge.ErrorKind.io => EngineErrorKind.io,
    bridge.ErrorKind.internal => EngineErrorKind.internal,
  },
  messageKey: error.messageKey,
  details: error.details,
);

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

/// The date as the file writes it, in no time zone, so it shows as written.
DateTime? _date(bridge.PdfDate? date) => date == null
    ? null
    : DateTime(date.year, date.month, date.day, date.hour, date.minute);
