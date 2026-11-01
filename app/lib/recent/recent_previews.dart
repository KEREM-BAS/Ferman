import 'dart:async';
import 'dart:ui' as ui;

import 'package:ferman/engine/engine_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recent_previews.g.dart';

/// Keeps the recent files' first-page previews, PNGs by file path (a1-4,
/// ADR 0021). The desktop store (`FileRecentPreviewStore`) keeps them in
/// the app cache directory; none is ever kept for a file that needs a
/// password (G109). Tests and the web build use [MemoryRecentPreviewStore].
abstract interface class RecentPreviewStore {
  /// The preview of the file at [path]; null when there is none.
  Future<Uint8List?> load(String path);

  /// Keeps [png] as the preview of the file at [path].
  Future<void> save(String path, Uint8List png);

  /// Deletes the preview of the file at [path], if there is one.
  Future<void> remove(String path);
}

/// A [RecentPreviewStore] in memory.
final class MemoryRecentPreviewStore implements RecentPreviewStore {
  /// The previews, by path.
  final Map<String, Uint8List> previews = {};

  @override
  Future<Uint8List?> load(String path) async => previews[path];

  @override
  Future<void> save(String path, Uint8List png) async => previews[path] = png;

  @override
  Future<void> remove(String path) async => previews.remove(path);
}

/// Where the previews are kept. `bootstrap()` overrides it with the
/// platform's store.
@Riverpod(keepAlive: true)
RecentPreviewStore recentPreviewStore(Ref ref) => MemoryRecentPreviewStore();

/// The preview of the recent file at [path]; null when there is none.
@riverpod
Future<Uint8List?> recentPreview(Ref ref, String path) =>
    ref.watch(recentPreviewStoreProvider).load(path);

/// The side, in pixels, of the square a preview fits in: the start
/// screen's card page (93 × 132) at a device pixel ratio of 2.
const int recentPreviewSize = 264;

/// Renders [document]'s first page at background priority and encodes it
/// as a PNG; null when the page does not render or the document closes
/// first.
Future<Uint8List?> renderRecentPreview(
  EngineService engine,
  int document,
) async {
  final view = await engine.openView(document);
  final ViewUpdate? update;
  try {
    final first = view.updates.cast<ViewUpdate?>().firstWhere(
      (_) => true,
      // The view's updates ended: the document closed.
      orElse: () => null,
    );
    await engine.requestView(view.id, 1, const [
      WantedItem(
        ThumbnailItem(page: 0, size: recentPreviewSize),
        RenderPriority.background,
      ),
    ]);
    update = await first;
  } finally {
    // Closed before encoding, so closing the document never waits on it.
    unawaited(engine.closeView(view.id).catchError((Object _) {}));
  }
  return update is RenderedItem ? await _png(update) : null;
}

Future<Uint8List?> _png(RenderedItem item) async {
  final decoded = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    item.pixels,
    item.width,
    item.height,
    ui.PixelFormat.bgra8888,
    decoded.complete,
    rowBytes: item.stride,
  );
  final image = await decoded.future;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
