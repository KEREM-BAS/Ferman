import 'dart:async';
import 'dart:ui' as ui;

import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The thumbnails of a list of `viewerProvider`'s pages, the sidebar's and the
/// page grid's: they come through an engine view of their own, only for the
/// thumbnails built ([thumbnailBuilt], through [ThumbnailReporter]), so a long
/// document never holds every bitmap.
///
/// A bitmap belongs to a page by its handle, so it moves with the page; one
/// drawn before a change stays until its new one arrives.
mixin PageThumbnails<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final EngineService _engine = ref.read(engineServiceProvider);
  EngineView? _view;
  StreamSubscription<ViewUpdate>? _updates;
  int _generation = 0;
  bool _requestScheduled = false;

  /// The pages whose thumbnails are built, and their bitmaps once decoded.
  final Set<int> _shown = {};
  final Map<int, ui.Image> _images = {};

  /// The pages whose bitmap was drawn before the layers last changed, and
  /// the render key of that change; each stays until its new one arrives.
  final Set<int> _stale = {};
  final CurrentKeys _keys = CurrentKeys();

  /// The bitmap of the page [handle], once decoded.
  ui.Image? thumbnailOf(int handle) => _images[handle];

  OpenedDocument? get _document => ref.read(viewerProvider)?.document;

  /// Call from `initState`.
  void startThumbnails() {
    _keys.raise(ref.read(layerVisibilityProvider)?.renderKey ?? 0);
    ref.listenManual(layerVisibilityProvider.select((s) => s?.renderKey ?? 0), (
      _,
      key,
    ) {
      _keys.raise(key);
      _stale.addAll(_images.keys);
      _scheduleRequest();
    });
    // A commit, undo or redo changed the pages too.
    ref.listenManual(documentEditorProvider.select((s) => s.renderKey), (
      _,
      key,
    ) {
      if (key == null) return;
      final pages = ref.read(documentEditorProvider).changedPages;
      _keys.raise(key, pages: pages);
      final document = _document;
      _stale.addAll(
        _images.keys.where(
          (handle) =>
              pages == null ||
              document == null ||
              pages.any((page) => document.pageHandle(page) == handle),
        ),
      );
      _scheduleRequest();
    });
    unawaited(_open());
  }

  /// Call from `dispose`.
  void stopThumbnails() {
    unawaited(_updates?.cancel());
    final view = _view;
    if (view != null) {
      // The document may be closed already, which closed the view.
      unawaited(_engine.closeView(view.id).catchError((Object _) {}));
    }
    for (final image in _images.values) {
      image.dispose();
    }
  }

  Future<void> _open() async {
    final document = _document;
    if (document == null) return;
    try {
      final view = await _engine.openView(document.id);
      if (!mounted) {
        unawaited(_engine.closeView(view.id).catchError((Object _) {}));
        return;
      }
      _view = view;
      _updates = view.updates.listen(_receive);
      _scheduleRequest();
    } on Object {
      // shortcut: the thumbnails stay blank when the view cannot open; the
      // canvas shows the failure. Add a2-13's placeholder here if it ever
      // fails alone.
    }
  }

  void _receive(ViewUpdate update) {
    if (!mounted) return;
    if (update case RenderedItem(
      item: ThumbnailItem(:final page),
      :final renderKey,
    )) {
      final handle = _document?.pageHandle(page);
      if (handle == null ||
          !_shown.contains(handle) ||
          !_keys.isCurrent(page, renderKey)) {
        return;
      }
      ui.decodeImageFromPixels(
        update.pixels,
        update.width,
        update.height,
        ui.PixelFormat.bgra8888,
        (image) {
          if (!mounted || !_shown.contains(handle)) {
            image.dispose();
            return;
          }
          setState(() {
            _images[handle]?.dispose();
            _images[handle] = image;
            if (!_keys.isCurrent(page, renderKey)) {
              _stale.add(handle);
            } else {
              _stale.remove(handle);
            }
          });
        },
        rowBytes: update.stride,
      );
    }
    // A failed thumbnail stays blank; the canvas shows a2-13's placeholder.
  }

  /// The thumbnail of the page [handle] was built.
  void thumbnailBuilt(int handle) {
    _shown.add(handle);
    _scheduleRequest();
  }

  /// The thumbnail of the page [handle] is gone.
  void thumbnailGone(int handle) {
    _shown.remove(handle);
    _stale.remove(handle);
    _images.remove(handle)?.dispose();
    _scheduleRequest();
  }

  /// Sends the built thumbnails after this frame.
  void _scheduleRequest() {
    if (_requestScheduled) return;
    _requestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestScheduled = false;
      if (!mounted) return;
      final view = _view;
      final document = _document;
      if (view == null || document == null) return;
      final pages = <int>[
        for (var page = 0; page < document.pages.length; page++)
          if (switch (document.pageHandle(page)) {
            final handle =>
              _shown.contains(handle) &&
                  (!_images.containsKey(handle) || _stale.contains(handle)),
          })
            page,
      ];
      unawaited(
        _engine
            .requestView(view.id, ++_generation, [
              for (final page in pages)
                WantedItem(
                  ThumbnailItem(page: page, size: previewSize),
                  RenderPriority.visibleThumbnail,
                ),
            ])
            .catchError((Object _) {}),
      );
    });
  }
}

/// Tells its list when the thumbnail of a page is built and when it goes.
class ThumbnailReporter extends StatefulWidget {
  /// Reports the page [handle] around [child]; give it a key by [handle], so
  /// it moves with the page.
  const new({
    required this.handle,
    required this.onBuilt,
    required this.onGone,
    required this.child,
    super.key,
  });

  /// The page.
  final int handle;

  /// Called once the thumbnail is built.
  final ValueChanged<int> onBuilt;

  /// Called when the thumbnail goes.
  final ValueChanged<int> onGone;

  /// The thumbnail.
  final Widget child;

  @override
  State<ThumbnailReporter> createState() => _ThumbnailReporterState();
}

class _ThumbnailReporterState extends State<ThumbnailReporter> {
  @override
  void initState() {
    super.initState();
    widget.onBuilt(widget.handle);
  }

  @override
  void dispose() {
    widget.onGone(widget.handle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
