import 'dart:ui';

import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a4 = Size(595, 842);

  group('pageRows', () {
    test('spreads read left to right, or right to left by the document', () {
      expect(pageRows(5, PageLayout.twoPage, rightToLeft: false), [
        [0, 1],
        [2, 3],
        [4, null],
      ]);
      // a2-15: page 1 on the right, page 2 on its left (G32).
      expect(pageRows(5, PageLayout.twoPage, rightToLeft: true), [
        [1, 0],
        [3, 2],
        [null, 4],
      ]);
    });

    test('a book’s cover stands alone on the right, or on the left in '
        'right to left (a2-1d, a2-15)', () {
      expect(pageRows(4, PageLayout.book, rightToLeft: false), [
        [null, 0],
        [1, 2],
        [3, null],
      ]);
      expect(pageRows(4, PageLayout.book, rightToLeft: true), [
        [0, null],
        [2, 1],
        [null, 3],
      ]);
    });

    test('single and continuous put one page in each row', () {
      expect(pageRows(2, PageLayout.continuous, rightToLeft: true), [
        [0],
        [1],
      ]);
    });
  });

  group('PagePlacement', () {
    test('a continuous column centres each page below the padding', () {
      final placement = PagePlacement.of(
        [a4, const Size(842, 595)],
        PageLayout.continuous,
        rightToLeft: false,
        scale: 1,
      );
      expect(placement.rects[0], const Rect.fromLTWH(24 + 123.5, 24, 595, 842));
      expect(
        placement.rects[1],
        const Rect.fromLTWH(24, 24 + 842 + rowGap, 842, 595),
      );
      expect(placement.size, const Size(842 + 48, 24 + 842 + 24 + 595 + 24));
    });

    test('a spread meets at the gutter; a paged layout places one row', () {
      final placement = PagePlacement.of(
        [a4, a4, a4],
        PageLayout.twoPage,
        rightToLeft: true,
        scale: 1,
        row: 1,
      );
      // Row 1 of a right-to-left spread holds page 3 alone on the right.
      expect(placement.rects[0], isNull);
      expect(placement.rects[1], isNull);
      expect(
        placement.rects[2],
        const Rect.fromLTWH(40 + 595 + spreadGap, 40, 595, 842),
      );
      expect(placement.rowOf(2), 1);
      expect(placement.firstPageOf(0), 0);
    });

    test('the current page is the one most in view', () {
      final placement = PagePlacement.of(
        [a4, a4, a4],
        PageLayout.continuous,
        rightToLeft: false,
        scale: 1,
      );
      expect(placement.currentPage(const Rect.fromLTWH(0, 0, 700, 600)), 0);
      expect(placement.currentPage(const Rect.fromLTWH(0, 700, 700, 600)), 1);
    });
  });

  test('Fit width and Fit page fill the window at 96 dpi', () {
    // A 595 pt page is 793.3 px wide at 100 %.
    final width = fitZoom(
      ZoomFit.width,
      [a4],
      PageLayout.continuous,
      const Size(793.33 + 48, 400),
    );
    expect(width, closeTo(1, 0.001));
    final page = fitZoom(
      ZoomFit.page,
      [a4],
      PageLayout.single,
      const Size(2000, 842 * pixelsPerPoint / 2 + 16),
    );
    expect(page, closeTo(0.5, 0.001));
  });

  test('zoom steps go up and down from any zoom', () {
    expect(zoomStepAfter(1), 1.25);
    expect(zoomStepAfter(1.1), 1.25);
    expect(zoomStepBefore(1.1), 1);
    expect(zoomStepBefore(minZoom), minZoom);
    expect(zoomStepAfter(maxZoom), maxZoom);
  });

  test('buckets are the engine’s quarter octaves', () {
    expect(bucketScale(0), 1);
    expect(bucketScale(4), 2);
    expect(bucketScale(-1), 0.5 * 1.681792830507429);
    expect(bucketScale(-16), 1 / 16);
    expect(zoomBucket(1), 0);
    expect(zoomBucket(pixelsPerPoint), 2);
    expect(zoomBucket(1e-9), -16);
    expect(engineRatio(1.1), isNot(1.1));
    expect(engineRatio(9), 4);
  });

  test('a view wants the tiles in view nearest the centre first, then the '
      'previews and the tiles around', () {
    final placement = PagePlacement.of(
      [a4, a4],
      PageLayout.continuous,
      rightToLeft: false,
      scale: 1,
    );
    final wanted = wantedItems(
      placement: placement,
      pages: [a4, a4],
      scale: 1,
      ratio: 1,
      visible: const Rect.fromLTWH(0, 0, 643, 600),
      prefetch: const Rect.fromLTWH(0, 0, 643, 1200),
    );
    final visible = wanted
        .where((entry) => entry.priority == RenderPriority.visible)
        .map((entry) => entry.item)
        .toList();
    // Bucket 0 at ratio 1: page 1's raster is 595 × 842, two by two tiles.
    expect(visible, hasLength(4));
    expect(
      visible.first,
      const TileItem(
        page: 0,
        zoomBucket: 0,
        devicePixelRatio: 1,
        column: 0,
        row: 0,
      ),
    );
    expect(
      wanted.map((entry) => entry.item),
      containsAll(const [
        ThumbnailItem(page: 0, size: previewSize),
        ThumbnailItem(page: 1, size: previewSize),
      ]),
    );
    expect(
      wanted.where((entry) => entry.priority == RenderPriority.prefetch),
      everyElement(
        isA<WantedItem>().having((entry) => entry.item.page, 'page', 1),
      ),
    );
  });
}
