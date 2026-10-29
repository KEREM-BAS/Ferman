import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pages of the open document on the canvas (a2-1a to a2-1d, a2-13,
/// a2-15), drawn from the engine's tiles through one engine view.
///
/// Each frame whose wanted set changes sends it with a new generation:
/// the tiles in view at the zoom's bucket, nearest the centre first, the
/// tiles half a window beyond, and each page's preview thumbnail. A page
/// shows its thumbnail and any tiles of other buckets, scaled, until its
/// sharp tiles arrive, so it sharpens in place without moving (G30). A
/// page that fails to render shows a2-13's placeholder with Try again; the
/// other pages keep working. When layers show or hide, every bitmap goes
/// stale and is asked for again; each stays until its new one arrives.
///
/// The wheel scrolls, and zooms with ⌘ or Ctrl; a trackpad scrolls and
/// pinches. With [tools] the View row's pointer tools apply: Hand drags
/// the pages, Marquee zoom drags a rectangle to zoom into (a2-2).
///
/// It sits inside the canvas's left-to-right [Directionality]: pages never
/// mirror (ADR 0014).
class DocumentView extends ConsumerStatefulWidget {
  /// The pages of `viewerProvider`'s document.
  const new({required this.uiDirection, super.key, this.tools = true});

  /// The UI's direction, for the copy on a failed page.
  final TextDirection uiDirection;

  /// Whether the View row's pointer tools apply (View mode).
  final bool tools;

  /// The decoded bitmaps kept, in bytes.
  static const int cacheBytes = 256 << 20;

  @override
  ConsumerState<DocumentView> createState() => _DocumentViewState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty('uiDirection', uiDirection))
      ..add(FlagProperty('tools', value: tools, ifFalse: 'no tools'));
  }
}

class _DocumentViewState extends ConsumerState<DocumentView> {
  late final EngineService _engine = ref.read(engineServiceProvider);
  EngineView? _view;
  StreamSubscription<ViewUpdate>? _updates;

  /// Decoded bitmaps, oldest first.
  final Map<RenderItem, ui.Image> _images = {};
  int _bytes = 0;

  /// Bitmaps drawn before the layers last changed, and the render key of
  /// that change.
  final Set<RenderItem> _stale = {};
  int _renderKey = 0;

  /// Pages that failed to render, until Try again.
  final Set<int> _failed = {};

  /// Whether the view itself could not open: every page shows the
  /// placeholder.
  bool _viewFailed = false;

  int _generation = 0;
  List<WantedItem> _wanted = const [];
  bool _requestScheduled = false;

  /// The trackpad pinch's scale so far.
  double _pinch = 1;

  /// A marquee's corners on the canvas while it is drawn.
  Offset? _marqueeStart;
  Offset? _marqueeEnd;

  /// Whether the Hand tool is dragging.
  bool _grabbing = false;

  @override
  void initState() {
    super.initState();
    _renderKey = ref.read(layerVisibilityProvider)?.renderKey ?? 0;
    ref.listenManual(layerVisibilityProvider.select((s) => s?.renderKey ?? 0), (
      _,
      key,
    ) {
      _renderKey = key;
      _stale.addAll(_images.keys);
      _request(force: true);
    });
    unawaited(_open());
  }

  @override
  void dispose() {
    unawaited(_updates?.cancel());
    final view = _view;
    if (view != null) {
      // The document may be closed already, which closed the view.
      unawaited(_engine.closeView(view.id).catchError((Object _) {}));
    }
    for (final image in _images.values) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _open() async {
    final document = ref.read(viewerProvider)?.document;
    if (document == null) return;
    try {
      final view = await _engine.openView(document.id);
      if (!mounted) {
        unawaited(_engine.closeView(view.id).catchError((Object _) {}));
        return;
      }
      _view = view;
      _updates = view.updates.listen(_receive);
      setState(() => _viewFailed = false);
      _request(force: true);
    } on Object {
      if (mounted) setState(() => _viewFailed = true);
    }
  }

  void _receive(ViewUpdate update) {
    switch (update) {
      case FailedItem(:final item):
        setState(() => _failed.add(item.page));
      // A bitmap from before the layers last changed is not shown again.
      case RenderedItem(:final item, :final renderKey)
          when renderKey >= _renderKey:
        ui.decodeImageFromPixels(
          update.pixels,
          update.width,
          update.height,
          ui.PixelFormat.bgra8888,
          (image) {
            if (!mounted) {
              image.dispose();
              return;
            }
            setState(() {
              final old = _images.remove(item);
              if (old != null) {
                _bytes -= _sizeOf(old);
                old.dispose();
              }
              _images[item] = image;
              _bytes += _sizeOf(image);
              // The layers may have changed while it decoded.
              if (renderKey < _renderKey) {
                _stale.add(item);
              } else {
                _stale.remove(item);
              }
              _evict();
            });
          },
          rowBytes: update.stride,
        );
      case RenderedItem():
      // From before the layers last changed: asked for again already.
    }
  }

  static int _sizeOf(ui.Image image) => image.width * image.height * 4;

  /// Drops the oldest bitmaps nobody wants while the cache is over budget.
  void _evict() {
    if (_bytes <= DocumentView.cacheBytes) return;
    final wanted = {for (final entry in _wanted) entry.item};
    for (final item in _images.keys.toList()) {
      if (_bytes <= DocumentView.cacheBytes) break;
      if (wanted.contains(item)) continue;
      final image = _images.remove(item);
      if (image == null) continue;
      _stale.remove(item);
      _bytes -= _sizeOf(image);
      image.dispose();
    }
  }

  /// Sends the wanted set after this frame when it changed.
  void _scheduleRequest() {
    if (_requestScheduled) return;
    _requestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestScheduled = false;
      if (mounted) _request();
    });
  }

  void _request({bool force = false}) {
    final view = _view;
    final state = ref.read(viewerProvider);
    if (view == null || state == null || state.viewport.isEmpty) return;
    final visible = state.visible;
    final wanted = wantedItems(
      placement: state.placement,
      pages: state.pageSizes,
      scale: state.scale,
      ratio: engineRatio(MediaQuery.devicePixelRatioOf(context)),
      visible: visible,
      prefetch: visible.inflate(state.viewport.shortestSide / 2),
    )..removeWhere((entry) => _failed.contains(entry.item.page));
    if (!force && _same(wanted, _wanted)) return;
    _wanted = wanted;
    // Bitmaps already here are not asked for again, unless stale.
    final missing = [
      for (final entry in wanted)
        if (!_images.containsKey(entry.item) || _stale.contains(entry.item))
          entry,
    ];
    unawaited(
      _engine
          .requestView(view.id, ++_generation, missing)
          .catchError((Object _) {}),
    );
  }

  static bool _same(List<WantedItem> a, List<WantedItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].item != b[i].item || a[i].priority != b[i].priority) {
        return false;
      }
    }
    return true;
  }

  void _retry(int page) {
    if (_viewFailed) {
      setState(() => _viewFailed = false);
      unawaited(_open());
      return;
    }
    setState(() => _failed.remove(page));
    _request(force: true);
  }

  // Pointer input.

  Viewer get _viewer => ref.read(viewerProvider.notifier);

  ViewerTool get _tool => widget.tools
      ? (ref.read(viewerProvider)?.tool ?? ViewerTool.select)
      : ViewerTool.select;

  static bool get _zoomKey =>
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isControlPressed;

  void _signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      if (_zoomKey) {
        _viewer.zoomBy(
          math.pow(2, -scroll.scrollDelta.dy / 240).toDouble(),
          scroll.localPosition,
        );
      } else {
        _viewer.scrollBy(scroll.scrollDelta);
      }
    });
  }

  void _panZoom(PointerPanZoomUpdateEvent event) {
    if (_zoomKey) {
      _viewer.zoomBy(
        math.pow(2, event.panDelta.dy / 240).toDouble(),
        event.localPosition,
      );
      return;
    }
    _viewer.scrollBy(-event.panDelta);
    final factor = event.scale / _pinch;
    _pinch = event.scale;
    if (factor != 1) _viewer.zoomBy(factor, event.localPosition);
  }

  void _down(PointerDownEvent event) {
    Focus.maybeOf(context)?.requestFocus();
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    switch (_tool) {
      case ViewerTool.hand:
        setState(() => _grabbing = true);
      case ViewerTool.marquee:
        setState(() => _marqueeStart = _marqueeEnd = event.localPosition);
      case ViewerTool.select:
        break;
    }
  }

  void _move(PointerMoveEvent event) {
    if (_grabbing) {
      _viewer.scrollBy(-event.delta);
    } else if (_marqueeStart != null) {
      setState(() => _marqueeEnd = event.localPosition);
    }
  }

  void _up(PointerEvent event) {
    final start = _marqueeStart;
    final end = _marqueeEnd;
    if (start != null && end != null && event is PointerUpEvent) {
      _viewer.zoomToRect(Rect.fromPoints(start, end));
    }
    setState(() {
      _grabbing = false;
      _marqueeStart = _marqueeEnd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final state = ref.watch(viewerProvider);
    if (state == null) return const SizedBox.shrink();
    _scheduleRequest();
    final cursor = switch (_tool) {
      ViewerTool.hand =>
        _grabbing ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      ViewerTool.marquee => SystemMouseCursors.precise,
      ViewerTool.select => MouseCursor.defer,
    };
    final start = _marqueeStart;
    final end = _marqueeEnd;
    final marquee = start == null || end == null
        ? null
        : Rect.fromPoints(start, end);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        if (viewport != state.viewport) {
          // Resizing changes a fitted zoom: after this build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _viewer.resize(viewport);
          });
        }
        return Listener(
          onPointerSignal: _signal,
          onPointerPanZoomStart: (_) => _pinch = 1,
          onPointerPanZoomUpdate: _panZoom,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: MouseRegion(
            cursor: cursor,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PagesPainter(
                        state: state,
                        images: _images,
                        failed: _viewFailed ? null : _failed,
                        page: BoxDecoration(
                          color: theme.pageColors.pageBg,
                          boxShadow: theme.elevation.shadowPage,
                        ),
                        filter: theme.pageColorFilter,
                        marquee: marquee,
                        marqueeColor: theme.colors.borderFocus,
                        marqueeFill: theme.colors.accentSubtle,
                      ),
                    ),
                  ),
                  for (final (page, rect) in state.placement.rects.indexed)
                    if (rect != null &&
                        rect.overlaps(state.visible) &&
                        (_viewFailed || _failed.contains(page)))
                      PositionedDirectional(
                        start: rect.left - state.offset.dx,
                        top: rect.top - state.offset.dy,
                        width: rect.width,
                        height: rect.height,
                        child: Directionality(
                          textDirection: widget.uiDirection,
                          child: _FailedPage(
                            page: page,
                            onRetry: () => _retry(page),
                          ),
                        ),
                      ),
                  if (marquee != null &&
                      marquee.longestSide >= Viewer.marqueeMinimum)
                    PositionedDirectional(
                      start: marquee.right + theme.space.space2,
                      top: marquee.bottom + theme.space.space2,
                      child: _MarqueeLabel(zoom: state.marqueeZoom(marquee)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints the visible pages: the page and its shadow, the preview, then
/// the tiles from the bucket farthest from the zoom's to its own, so the
/// sharpest lands on top.
class _PagesPainter extends CustomPainter {
  new({
    required this.state,
    required this.images,
    required this.failed,
    required this.page,
    required this.filter,
    required this.marquee,
    required this.marqueeColor,
    required this.marqueeFill,
  });

  final ViewerState state;
  final Map<RenderItem, ui.Image> images;

  /// The failed pages, painted blank; null when every page is.
  final Set<int>? failed;
  final BoxDecoration page;
  final ColorFilter? filter;
  final Rect? marquee;
  final Color marqueeColor;
  final Color marqueeFill;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = state.visible;
    final bucket = zoomBucket(state.scale);
    final decoration = page.createBoxPainter();
    final byPage = <int, List<MapEntry<RenderItem, ui.Image>>>{};
    for (final entry in images.entries) {
      (byPage[entry.key.page] ??= []).add(entry);
    }
    final pixels = Paint()
      ..filterQuality = FilterQuality.medium
      // Tiles meet edge to edge; antialiased edges would show seams.
      ..isAntiAlias = false;
    canvas
      ..save()
      ..translate(-visible.left, -visible.top);
    for (final (index, rect) in state.placement.rects.indexed) {
      if (rect == null || !rect.overlaps(visible)) continue;
      decoration.paint(
        canvas,
        rect.topLeft,
        ImageConfiguration(size: rect.size),
      );
      final failed = this.failed;
      if (failed == null || failed.contains(index)) continue;
      final entries = byPage[index] ?? [];
      int rank(RenderItem item) => switch (item) {
        ThumbnailItem() => 1 << 20,
        TileItem(:final zoomBucket) => (zoomBucket - bucket).abs(),
      };
      entries.sort((a, b) => rank(b.key).compareTo(rank(a.key)));
      if (filter != null) {
        canvas.saveLayer(rect, Paint()..colorFilter = filter);
      }
      canvas
        ..save()
        ..clipRect(rect);
      for (final MapEntry(key: item, value: image) in entries) {
        final source =
            Offset.zero & Size(image.width.toDouble(), image.height.toDouble());
        final target = switch (item) {
          ThumbnailItem() => rect,
          TileItem(
            :final zoomBucket,
            :final devicePixelRatio,
            :final column,
            :final row,
          ) =>
            () {
              final toCanvas =
                  state.scale / (bucketScale(zoomBucket) * devicePixelRatio);
              return Rect.fromLTWH(
                rect.left + column * tileSize * toCanvas,
                rect.top + row * tileSize * toCanvas,
                image.width * toCanvas,
                image.height * toCanvas,
              );
            }(),
        };
        canvas.drawImageRect(image, source, target, pixels);
      }
      canvas.restore();
      if (filter != null) canvas.restore();
    }
    canvas.restore();
    final marquee = this.marquee;
    if (marquee != null && marquee.longestSide >= Viewer.marqueeMinimum) {
      canvas.drawRect(marquee, Paint()..color = marqueeFill);
      _dashed(canvas, marquee, Paint()..color = marqueeColor);
    }
  }

  /// a2-2's dashed marquee outline: 4 px dashes, 1 px wide.
  static void _dashed(Canvas canvas, Rect rect, Paint paint) {
    const dash = 4.0;
    void line(Offset from, Offset to) {
      final length = (to - from).distance;
      final step = (to - from) / length;
      for (var at = 0.0; at < length; at += 2 * dash) {
        final end = math.min(at + dash, length);
        canvas.drawRect(
          Rect.fromPoints(
            from + step * at,
            from + step * end + const Offset(1, 1),
          ),
          paint,
        );
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.bottomLeft, rect.bottomRight);
    line(rect.topLeft, rect.bottomLeft);
    line(rect.topRight, rect.bottomRight);
  }

  @override
  bool shouldRepaint(_PagesPainter old) => true;
}

/// a2-13's placeholder for a page that failed to render: the `file-x`
/// glyph on a sunken square, "Ferman couldn't draw page N.", a plain
/// reason and Try again.
class _FailedPage extends ConsumerWidget {
  const new({required this.page, required this.onRetry});

  final int page;
  final VoidCallback onRetry;

  /// a2-13: the glyph's square, the glyph and the reason's width.
  static const double markBox = 44;
  static const double markSize = 22;
  static const double bodyWidth = 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space2_5,
        children: [
          Container(
            width: markBox,
            height: markBox,
            decoration: BoxDecoration(
              color: theme.colors.surfaceSunken,
              borderRadius: BorderRadius.all(
                Radius.circular(theme.radius.radiusMd),
              ),
            ),
            child: Icon(
              IconName.fileX,
              size: markSize,
              color: theme.colors.iconSecondary,
            ),
          ),
          Text(
            l10n.viewerPageFailed(format.integer(page + 1)),
            textAlign: TextAlign.center,
            style: theme.typography.bodyStrong.copyWith(
              color: theme.ramps.paper900,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: bodyWidth),
            child: Text(
              l10n.viewerPageFailedReason,
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(
                color: theme.ramps.paper700,
              ),
            ),
          ),
          Button(
            size: ButtonSize.sm,
            icon: IconName.refreshCw,
            onPressed: onRetry,
            child: Text(l10n.viewerTryAgain),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('page', page))
      ..add(ObjectFlagProperty<VoidCallback>.has('onRetry', onRetry));
  }
}

/// a2-2's label beside a marquee: "Release to zoom to 180%" on the
/// tooltip's inverse surface.
class _MarqueeLabel extends ConsumerWidget {
  const new({required this.zoom});

  final double zoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space2,
        vertical: theme.space.space1,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfaceInverse,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusSm)),
        boxShadow: theme.elevation.shadowSm,
      ),
      child: Text(
        l10n.viewerMarqueeZoom(
          bidiIsolate(format.percent((zoom * 100).round())),
        ),
        softWrap: false,
        style: theme.typography.caption.copyWith(
          color: theme.colors.textInverse,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('zoom', zoom));
  }
}
