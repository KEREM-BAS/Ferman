import 'dart:math' as math;
import 'dart:ui';

import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'viewer_state.g.dart';

/// The pointer tool of the View row (a2-1a, a2-2).
enum ViewerTool {
  /// The default pointer; selecting text comes with B106.
  select,

  /// Drags the pages.
  hand,

  /// Drags a rectangle to zoom into.
  marquee,
}

/// The document the canvas shows, as `openDocumentProvider`, or null.
///
/// Set by whatever opens a document: the tests in W2, the open picker,
/// drag and drop and the OS from W3 (ROADMAP §6 step 6).
@Riverpod(keepAlive: true)
class OpenDocument extends _$OpenDocument {
  @override
  OpenedDocument? build() => null;

  /// Shows [document] on the canvas, or nothing.
  void show(OpenedDocument? document) {
    if (document == state) return;
    state = document;
  }
}

/// Which layers of the open document show, and the render key showing them
/// gave every page, as `layerVisibilityProvider`.
@immutable
final class LayerState {
  /// The document's own defaults, before anything changed.
  const new({required this.visible, this.renderKey = 0});

  /// Whether each of the document's layers shows, in its order.
  final List<bool> visible;

  /// The render key the engine gave every page when these layers were set:
  /// a bitmap with an older one shows the layers as they were.
  final int renderKey;
}

/// Shows and hides the open document's layers (a2-3c) in every view, as
/// `layerVisibilityProvider`; null without a document.
@Riverpod(keepAlive: true)
class LayerVisibility extends _$LayerVisibility {
  /// The calls to the engine, one after another, so each starts from the
  /// state the last one left.
  Future<void> _queue = Future.value();

  @override
  LayerState? build() {
    final document = ref.watch(openDocumentProvider);
    if (document == null) return null;
    return LayerState(
      visible: [for (final layer in document.layers) layer.visible],
    );
  }

  /// Shows layer [index] if [visible], hides it otherwise. Completes when
  /// the views can ask for the new pixels; throws an [EngineException] if
  /// the engine refuses, and the layer stays as it was.
  Future<void> show(int index, {required bool visible}) {
    final next = _queue.then((_) async {
      final current = state;
      final document = ref.read(openDocumentProvider);
      if (current == null || document == null) return;
      final wanted = [...current.visible]..[index] = visible;
      final key = await ref
          .read(engineServiceProvider)
          .showLayers(document.id, wanted);
      // The document may have closed meanwhile.
      if (ref.read(openDocumentProvider)?.id != document.id) return;
      state = LayerState(visible: wanted, renderKey: key);
    });
    _queue = next.catchError((Object _) {});
    return next;
  }
}

/// Asks the status bar's page field for focus (⌘G or Ctrl+G, a2-13): the
/// count of requests, as `pageFieldRequestProvider`.
@riverpod
class PageFieldRequest extends _$PageFieldRequest {
  @override
  int build() => 0;

  /// Focuses the page field.
  void request() => state++;
}

/// How the canvas shows its document: layout, zoom, tool and scroll
/// position, in logical pixels.
@immutable
final class ViewerState {
  /// The view of [document].
  new({
    required this.document,
    this.layout = PageLayout.continuous,
    this.zoom = 1,
    this.fit = ZoomFit.width,
    this.tool = ViewerTool.select,
    this.viewport = Size.zero,
    this.offset = Offset.zero,
    this.row = 0,
  });

  /// The document shown.
  final OpenedDocument document;

  /// The page layout.
  final PageLayout layout;

  /// The zoom: 1 is 100 % ([pixelsPerPoint]).
  final double zoom;

  /// The fit the zoom follows when the window changes, or null for a zoom
  /// of its own.
  final ZoomFit? fit;

  /// The pointer tool.
  final ViewerTool tool;

  /// The size of the canvas.
  final Size viewport;

  /// The point of the laid-out pages at the canvas's top left; negative
  /// where they are narrower (or, paged, shorter) than the canvas and
  /// centred in it.
  final Offset offset;

  /// The row a paged layout shows.
  final int row;

  /// Each page's size in points.
  late final List<Size> pageSizes = [
    for (final page in document.pages) Size(page.width, page.height),
  ];

  /// Logical pixels per point.
  double get scale => zoom * pixelsPerPoint;

  /// Where the pages sit.
  late final PagePlacement placement = PagePlacement.of(
    pageSizes,
    layout,
    rightToLeft: document.rightToLeft,
    scale: scale,
    row: row,
  );

  /// The part of the laid-out pages on the canvas.
  Rect get visible => offset & viewport;

  /// The page the reader is on.
  late final int currentPage = placement.currentPage(visible);

  /// A copy with the given values.
  ViewerState copyWith({
    PageLayout? layout,
    double? zoom,
    ZoomFit? Function()? fit,
    ViewerTool? tool,
    Size? viewport,
    Offset? offset,
    int? row,
  }) => ViewerState(
    document: document,
    layout: layout ?? this.layout,
    zoom: zoom ?? this.zoom,
    fit: fit == null ? this.fit : fit(),
    tool: tool ?? this.tool,
    viewport: viewport ?? this.viewport,
    offset: offset ?? this.offset,
    row: row ?? this.row,
  );

  /// The zoom a marquee drawn over [area] of the canvas zooms to.
  double marqueeZoom(Rect area) =>
      (zoom *
              math.min(
                viewport.width / area.width,
                viewport.height / area.height,
              ))
          .clamp(minZoom, maxZoom);
}

/// The canvas's view of the open document, as `viewerProvider`: null when
/// no document is open. The View row, the status bar and the canvas read
/// and change it.
@Riverpod(keepAlive: true)
class Viewer extends _$Viewer {
  /// How far a wheel scrolls past the end of a paged row before the page
  /// turns.
  static const double turnDistance = 160;

  /// A marquee smaller than this zooms in one step instead.
  static const double marqueeMinimum = 8;

  double _overscroll = 0;

  @override
  ViewerState? build() {
    final document = ref.watch(openDocumentProvider);
    if (document == null) return null;
    return ViewerState(document: document);
  }

  /// The canvas is [viewport] large; a fitted zoom follows it.
  void resize(Size viewport) {
    final view = state;
    if (view == null || view.viewport == viewport) return;
    final fit = view.fit;
    final focal = Offset(viewport.width / 2, 0);
    final sized = view.copyWith(viewport: viewport);
    if (fit == null || view.pageSizes.isEmpty) {
      state = _clamped(sized);
      return;
    }
    final zoom = fitZoom(fit, view.pageSizes, view.layout, viewport);
    state = _rescaled(sized, zoom, fit, focal);
  }

  /// Scrolls by [delta] logical pixels. In a paged layout, a scroll that
  /// keeps pushing past the row's end turns the page.
  void scrollBy(Offset delta) {
    final view = state;
    if (view == null) return;
    final next = _clamped(view.copyWith(offset: view.offset + delta));
    if (view.layout.paged &&
        delta.dy != 0 &&
        next.offset.dy == view.offset.dy) {
      if (_overscroll.sign != delta.dy.sign) _overscroll = 0;
      _overscroll += delta.dy;
      if (_overscroll.abs() < turnDistance) return;
      _overscroll = 0;
      final forward = delta.dy > 0;
      final row = view.row + (forward ? 1 : -1);
      if (row < 0 || row >= view.placement.rows.length) return;
      state = _clamped(
        view.copyWith(
          row: row,
          offset: Offset(
            view.offset.dx,
            forward ? double.negativeInfinity : double.infinity,
          ),
        ),
      );
      return;
    }
    _overscroll = 0;
    state = next;
  }

  /// Zooms to [zoom], keeping the page point under [focal] (on the canvas;
  /// its centre by default) where it is.
  void zoomTo(double zoom, {Offset? focal}) {
    final view = state;
    if (view == null) return;
    state = _rescaled(
      view,
      zoom.clamp(minZoom, maxZoom),
      null,
      focal ?? view.viewport.center(Offset.zero),
    );
  }

  /// Zooms by [factor] around [focal]: the wheel with ⌘ or Ctrl, a pinch.
  void zoomBy(double factor, Offset focal) {
    final view = state;
    if (view != null) zoomTo(view.zoom * factor, focal: focal);
  }

  /// Zooms in one step.
  void zoomIn() {
    final view = state;
    if (view != null) zoomTo(zoomStepAfter(view.zoom));
  }

  /// Zooms out one step.
  void zoomOut() {
    final view = state;
    if (view != null) zoomTo(zoomStepBefore(view.zoom));
  }

  /// Fits the pages to the canvas; Fit page shows the current page whole.
  void fit(ZoomFit fit) {
    final view = state;
    if (view == null || view.pageSizes.isEmpty) return;
    final zoom = fitZoom(fit, view.pageSizes, view.layout, view.viewport);
    final page = view.currentPage;
    final fitted = _rescaled(
      view,
      zoom,
      fit,
      Offset(view.viewport.width / 2, 0),
    );
    state = fit == ZoomFit.page ? _showing(fitted, page) : fitted;
  }

  /// Zooms so [area] of the canvas fills it (Marquee zoom, a2-2); a click
  /// or a tiny drag zooms in one step there.
  void zoomToRect(Rect area) {
    final view = state;
    if (view == null) return;
    if (area.longestSide < marqueeMinimum) {
      zoomTo(zoomStepAfter(view.zoom), focal: area.center);
      return;
    }
    // Keep the area's centre, then bring it to the canvas's centre.
    final zoomed = _rescaled(view, view.marqueeZoom(area), null, area.center);
    final centre = view.viewport.center(Offset.zero);
    state = _clamped(
      zoomed.copyWith(offset: zoomed.offset + area.center - centre),
    );
  }

  /// Lays the pages out in [layout], staying on the current page.
  void setLayout(PageLayout layout) {
    final view = state;
    if (view == null || view.layout == layout) return;
    final page = view.currentPage;
    final fit = view.fit;
    var next = view.copyWith(layout: layout, row: 0);
    if (fit != null) {
      next = next.copyWith(
        zoom: fitZoom(fit, view.pageSizes, layout, view.viewport),
      );
    }
    state = _showing(next, page);
  }

  /// Picks the pointer [tool].
  void setTool(ViewerTool tool) {
    final view = state;
    if (view != null && view.tool != tool) state = view.copyWith(tool: tool);
  }

  /// Shows [page] from its top.
  void goToPage(int page) {
    final view = state;
    if (view == null || view.pageSizes.isEmpty) return;
    state = _showing(view, page.clamp(0, view.pageSizes.length - 1));
  }

  /// Moves to the next row of pages.
  void nextPage() => _turn(1);

  /// Moves to the previous row of pages.
  void previousPage() => _turn(-1);

  void _turn(int rows) {
    final view = state;
    if (view == null || view.pageSizes.isEmpty) return;
    final placement = view.placement;
    final row = placement.rowOf(view.currentPage) + rows;
    if (row < 0 || row >= placement.rows.length) return;
    state = _showing(view, placement.firstPageOf(row));
  }

  /// [view] scrolled to the top of [page].
  static ViewerState _showing(ViewerState view, int page) {
    if (view.layout.paged) {
      return _clamped(
        view.copyWith(
          row: view.placement.rowOf(page),
          offset: Offset(view.offset.dx, double.negativeInfinity),
        ),
      );
    }
    final top = view.placement.rects[page]?.top ?? 0;
    return _clamped(
      view.copyWith(offset: Offset(view.offset.dx, top - view.layout.padding)),
    );
  }

  /// [view] at [zoom], with the page point under [focal] kept there.
  static ViewerState _rescaled(
    ViewerState view,
    double zoom,
    ZoomFit? fit,
    Offset focal,
  ) {
    final point = view.offset + focal;
    int? anchor;
    var distance = double.infinity;
    for (final (page, rect) in view.placement.rects.indexed) {
      if (rect == null) continue;
      final dx = math.max(
        0,
        math.max(rect.left - point.dx, point.dx - rect.right),
      );
      final dy = math.max(
        0,
        math.max(rect.top - point.dy, point.dy - rect.bottom),
      );
      final d = (dx * dx + dy * dy).toDouble();
      if (d < distance) {
        distance = d;
        anchor = page;
      }
    }
    final next = view.copyWith(zoom: zoom, fit: () => fit);
    final before = anchor == null ? null : view.placement.rects[anchor];
    final after = anchor == null ? null : next.placement.rects[anchor];
    if (before == null || after == null) return _clamped(next);
    final local = (point - before.topLeft) / view.scale;
    return _clamped(
      next.copyWith(offset: after.topLeft + local * next.scale - focal),
    );
  }

  /// [view] with its offset inside the pages, centred where they are
  /// smaller than the canvas (across always, down in a paged layout).
  static ViewerState _clamped(ViewerState view) {
    final content = view.placement.size;
    double axis(
      double value,
      double pages,
      double window, {
      required bool centre,
    }) => pages <= window
        ? (centre ? (pages - window) / 2 : 0)
        : value.clamp(0, pages - window);
    return view.copyWith(
      offset: Offset(
        axis(view.offset.dx, content.width, view.viewport.width, centre: true),
        axis(
          view.offset.dy,
          content.height,
          view.viewport.height,
          centre: view.layout.paged,
        ),
      ),
    );
  }
}

/// The page a typed [input] names (the status bar's page field, a2-13):
/// a page label as the document writes it ("iv", "A-3"), or else a page
/// number from 1, in Western, Arabic-Indic or Persian digits; null for
/// neither.
int? pageForInput(String input, List<PageInfo> pages) {
  final text = input.trim();
  if (text.isEmpty) return null;
  // A label wins: a thesis whose page 9 is labelled "1" opens there.
  final labelled = pages.indexWhere((page) => page.label == text);
  if (labelled >= 0) return labelled;
  final western = String.fromCharCodes([
    for (final unit in text.codeUnits)
      switch (unit) {
        >= 0x0660 && <= 0x0669 => unit - 0x0660 + 0x30,
        >= 0x06F0 && <= 0x06F9 => unit - 0x06F0 + 0x30,
        _ => unit,
      },
  ]);
  final number = int.tryParse(western);
  if (number == null || number < 1 || number > pages.length) return null;
  return number - 1;
}
