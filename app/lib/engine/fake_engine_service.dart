import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

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
  });

  /// The status [status] returns.
  final EngineStatus fakeStatus;

  /// The documents [open] opens, by path; any other path is not found.
  final Map<String, OpenedDocument> documents;

  /// Pages whose items fail as damaged.
  final Set<int> failingPages;

  /// The wanted sets of every [requestView], oldest first.
  final List<List<WantedItem>> requests = [];

  final Map<int, (int, StreamController<ViewUpdate>)> _views = {};
  int _nextView = 1;

  @override
  EngineApiVersion apiVersion() => fakeStatus.apiVersion;

  @override
  Future<EngineStatus> status() async => fakeStatus;

  @override
  Future<OpenedDocument> open(String path, {String? password}) async =>
      documents[path] ??
      (throw const EngineException(
        kind: EngineErrorKind.notFound,
        messageKey: 'errorFileNotFound',
      ));

  /// Ends the document's views.
  @override
  Future<void> close(int document) async {
    for (final (owner, updates) in [..._views.values]) {
      if (owner == document) await updates.close();
    }
    _views.removeWhere((_, view) => view.$1 == document);
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
          renderKey: 0,
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
