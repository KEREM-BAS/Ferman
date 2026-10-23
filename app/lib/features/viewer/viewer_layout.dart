import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:ferman/engine/engine_models.dart';

/// How the canvas lays pages out: the View row's Page layout control
/// (a2-1a to a2-1d).
enum PageLayout {
  /// One page at a time (a2-1a).
  single,

  /// Every page in one scrolling column (a2-1b).
  continuous,

  /// Two pages side by side, one spread at a time (a2-1c).
  twoPage,

  /// The cover alone, then spreads, in one scrolling column (a2-1d).
  book;

  /// Whether the canvas shows one row at a time, centred in the window.
  bool get paged => this == single || this == twoPage;

  /// Whether pages stand side by side.
  bool get spreads => this == twoPage || this == book;

  /// The space around the pages: a2-1a's 8 px around a fitted page, the
  /// 24 px above a continuous column, the 40 px above the spreads of a2-1c
  /// and a2-1d.
  double get padding => switch (this) {
    single => 8,
    continuous => 24,
    twoPage || book => 40,
  };
}

/// A zoom that follows the window: Fit width or Fit page (a2-2).
enum ZoomFit {
  /// The widest page fills the window's width.
  width,

  /// The largest page fits in the window.
  page,
}

/// Logical pixels per point at 100 %: the design draws an A4 page 794 px
/// wide at 100 %, the CSS 96 dpi (`DocKira`), and so does the canvas.
const double pixelsPerPoint = 96 / 72;

/// The space between rows of pages (a2-1b, a2-1d `row-gap`).
const double rowGap = 24;

/// The space between the two pages of a spread (a2-1c, a2-1d `column-gap`).
const double spreadGap = 12;

/// The smallest zoom.
const double minZoom = 0.1;

/// The largest zoom.
const double maxZoom = 16;

/// The zoom steps of ⌘+ and ⌘−; the menu shows 50 % to 400 % (a2-2).
const List<double> zoomSteps = [
  0.1,
  0.25,
  0.5,
  0.75,
  1,
  1.25,
  1.5,
  2,
  3,
  4,
  8,
  16,
];

/// The step after [zoom], or [maxZoom].
double zoomStepAfter(double zoom) =>
    zoomSteps.firstWhere((step) => step > zoom * 1.001, orElse: () => maxZoom);

/// The step before [zoom], or [minZoom].
double zoomStepBefore(double zoom) =>
    zoomSteps.lastWhere((step) => step < zoom / 1.001, orElse: () => minZoom);

/// The rows of [count] pages in [layout]: one page per row, or a left and
/// a right slot, null where a spread has no page. Spreads follow the
/// document's direction, never the UI's (G32): with [rightToLeft] page 1
/// sits on the right, and a book's cover stands alone on the left (a2-15).
List<List<int?>> pageRows(
  int count,
  PageLayout layout, {
  required bool rightToLeft,
}) {
  if (!layout.spreads) {
    return [
      for (var page = 0; page < count; page++) [page],
    ];
  }
  final rows = <List<int?>>[];
  var page = 0;
  if (layout == PageLayout.book && count > 0) {
    // The cover is a recto: the end slot of the reading direction.
    rows.add(rightToLeft ? [0, null] : [null, 0]);
    page = 1;
  }
  for (; page < count; page += 2) {
    final first = page;
    final second = page + 1 < count ? page + 1 : null;
    rows.add(rightToLeft ? [second, first] : [first, second]);
  }
  return rows;
}

/// Where pages sit on the canvas at one scale, in logical pixels from the
/// top left of the laid-out pages.
final class PagePlacement {
  /// Lays out [pages] (their sizes in points) in [layout] at [scale]
  /// logical pixels per point. Paged layouts place only [row].
  factory of(
    List<Size> pages,
    PageLayout layout, {
    required bool rightToLeft,
    required double scale,
    int row = 0,
  }) {
    final rows = pageRows(pages.length, layout, rightToLeft: rightToLeft);
    final widest = pages.fold<double>(0, (w, page) => math.max(w, page.width));
    final column = widest * scale;
    final padding = layout.padding;
    final rects = List<Rect?>.filled(pages.length, null);
    final shown = layout.paged
        ? [rows[row.clamp(0, math.max(0, rows.length - 1))]]
        : rows;
    var top = padding;
    for (final (index, slots) in shown.indexed) {
      if (index > 0) top += rowGap;
      var height = 0.0;
      for (final (slot, page) in slots.indexed) {
        if (page == null) continue;
        final size = pages[page] * scale;
        // One page is centred in the column; a spread's pages meet at the
        // gutter.
        final left = switch ((slots.length, slot)) {
          (1, _) => padding + (column - size.width) / 2,
          (_, 0) => padding + column - size.width,
          _ => padding + column + spreadGap,
        };
        rects[page] = Offset(left, top) & size;
        height = math.max(height, size.height);
      }
      top += height;
    }
    final width = layout.spreads ? 2 * column + spreadGap : column;
    return PagePlacement._(
      rects: rects,
      rows: rows,
      size: Size(width + 2 * padding, shown.isEmpty ? 0 : top + padding),
    );
  }

  const new _({required this.rects, required this.rows, required this.size});

  /// Each page's rectangle, or null for a page not placed (another row of a
  /// paged layout).
  final List<Rect?> rects;

  /// Every row of the layout, placed or not ([pageRows]).
  final List<List<int?>> rows;

  /// The size of the laid-out pages with their padding.
  final Size size;

  /// The row that holds [page].
  int rowOf(int page) =>
      math.max(0, rows.indexWhere((slots) => slots.contains(page)));

  /// The first page of [row] in reading order.
  int firstPageOf(int row) => rows[row].whereType<int>().reduce(math.min);

  /// The page the reader is on in [visible]: the placed page with the most
  /// of its area in view, the earlier one on a tie; 0 when none is.
  int currentPage(Rect visible) {
    var best = -1.0;
    var current = 0;
    for (final (page, rect) in rects.indexed) {
      if (rect == null || !rect.overlaps(visible)) continue;
      final shown = rect.intersect(visible);
      final area = shown.width * shown.height;
      if (area > best) {
        best = area;
        current = page;
      }
    }
    return current;
  }
}

/// The zoom at which [fit] holds for [pages] in [layout] in a window of
/// [viewport].
double fitZoom(
  ZoomFit fit,
  List<Size> pages,
  PageLayout layout,
  Size viewport,
) {
  if (pages.isEmpty || viewport.isEmpty) return 1;
  final widest = pages.fold<double>(0, (w, page) => math.max(w, page.width));
  final tallest = pages.fold<double>(0, (h, page) => math.max(h, page.height));
  final padding = 2 * layout.padding;
  final columns = layout.spreads ? 2 : 1;
  final gaps = layout.spreads ? spreadGap : 0;
  final byWidth =
      (viewport.width - padding - gaps) / (columns * widest * pixelsPerPoint);
  final byHeight = (viewport.height - padding) / (tallest * pixelsPerPoint);
  final zoom = switch (fit) {
    ZoomFit.width => byWidth,
    ZoomFit.page => math.min(byWidth, byHeight),
  };
  return zoom.clamp(minZoom, maxZoom);
}

/// The side of a full tile in device pixels (`ferman_render::TILE_SIZE`).
const int tileSize = 512;

/// The longer side of the thumbnail shown while a page's tiles load.
const int previewSize = 256;

/// `2^(k/4)` for `k` in `0..4`, the constants of
/// `ferman_render::ZoomBucket::zoom`, so both sides compute the same raster.
const List<double> _quarterOctaves = [
  1,
  1.189207115002721,
  math.sqrt2,
  1.681792830507429,
];

/// The quarter-octave bucket whose rasters show a page at [scale] logical
/// pixels per point with the least scaling, -16 to 28.
int zoomBucket(double scale) =>
    (4 * math.log(scale) / math.ln2).round().clamp(-16, 28);

/// The scale of [bucket] in pixels per point, exactly as the engine
/// computes it.
double bucketScale(int bucket) =>
    // Dart's `%` is Euclidean, like Rust's `rem_euclid`.
    math.pow(2, (bucket - bucket % 4) ~/ 4) * _quarterOctaves[bucket % 4];

/// [ratio] rounded to the engine's `f32`, so both sides compute the same
/// raster.
double engineRatio(double ratio) =>
    Float32List.fromList([ratio.clamp(0.5, 4)]).first;

/// What a view of [placement] wants rendered: for every page in
/// [prefetch], its preview thumbnail and the tiles at [scale] that cover
/// the part of it in [prefetch], at [ratio] device pixels per logical
/// pixel. Items in [visible] come first, nearest its centre first.
List<WantedItem> wantedItems({
  required PagePlacement placement,
  required List<Size> pages,
  required double scale,
  required double ratio,
  required Rect visible,
  required Rect prefetch,
}) {
  final bucket = zoomBucket(scale);
  final raster = bucketScale(bucket) * ratio;
  final centre = visible.center;
  final near = <(double, WantedItem)>[];
  final far = <WantedItem>[];
  for (final (page, rect) in placement.rects.indexed) {
    if (rect == null || !rect.overlaps(prefetch)) continue;
    final onScreen = rect.overlaps(visible);
    far.add(
      WantedItem(
        ThumbnailItem(page: page, size: previewSize),
        onScreen ? RenderPriority.visibleThumbnail : RenderPriority.thumbnail,
      ),
    );
    // Device pixels of the raster per logical pixel on the canvas.
    final toRaster = raster / scale;
    final columns = (pages[page].width * raster).round();
    final rows = (pages[page].height * raster).round();
    final wanted = rect.intersect(prefetch).shift(-rect.topLeft);
    final first = (wanted.left * toRaster ~/ tileSize).clamp(0, columns);
    final last = ((wanted.right * toRaster).ceil() - 1) ~/ tileSize;
    final top = (wanted.top * toRaster ~/ tileSize).clamp(0, rows);
    final bottom = ((wanted.bottom * toRaster).ceil() - 1) ~/ tileSize;
    final lastColumn = math.min(last, (columns - 1) ~/ tileSize);
    final lastRow = math.min(bottom, (rows - 1) ~/ tileSize);
    for (var row = top; row <= lastRow; row++) {
      for (var column = first; column <= lastColumn; column++) {
        final tile = Rect.fromLTWH(
          column * tileSize / toRaster,
          row * tileSize / toRaster,
          tileSize / toRaster,
          tileSize / toRaster,
        ).shift(rect.topLeft).intersect(rect);
        final item = TileItem(
          page: page,
          zoomBucket: bucket,
          devicePixelRatio: ratio,
          column: column,
          row: row,
        );
        if (tile.overlaps(visible)) {
          final distance = (tile.center - centre).distanceSquared;
          near.add((distance, WantedItem(item, RenderPriority.visible)));
        } else {
          far.add(WantedItem(item, RenderPriority.prefetch));
        }
      }
    }
  }
  near.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, item) in near) item, ...far];
}
