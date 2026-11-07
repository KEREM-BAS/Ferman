import 'dart:ui';

import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Five A4 pages, labelled i, ii, 1, 2, 3.
const OpenedDocument document = OpenedDocument(
  id: 7,
  pages: [
    PageInfo(width: 595, height: 842, label: 'i'),
    PageInfo(width: 595, height: 842, label: 'ii'),
    PageInfo(width: 595, height: 842, label: '1'),
    PageInfo(width: 595, height: 842, label: '2'),
    PageInfo(width: 595, height: 842, label: '3'),
  ],
);

void main() {
  test('a render key counts for the pages that got it', () {
    final keys = CurrentKeys()..raise(3);
    expect(keys.isCurrent(0, 2), isFalse);
    expect(keys.isCurrent(0, 3), isTrue);
    keys.raise(5, pages: [1]);
    expect(keys.isCurrent(0, 3), isTrue, reason: 'it kept its key');
    expect(keys.isCurrent(1, 3), isFalse);
    expect(keys.isCurrent(1, 5), isTrue);
    keys.raise(7);
    expect(keys.isCurrent(1, 5), isFalse);
    expect(keys.isCurrent(0, 7), isTrue);
  });

  late ProviderContainer container;
  ViewerState view() => container.read(viewerProvider)!;
  Viewer viewer() => container.read(viewerProvider.notifier);

  setUp(() {
    container = ProviderContainer.test()
      ..read(openDocumentProvider.notifier).show(document);
    viewer().resize(const Size(1000, 700));
  });

  group('after a revision', () {
    PageInfo a4(int handle) =>
        PageInfo(width: 595, height: 842, handle: handle);
    OpenedDocument pages(List<PageInfo> pages) =>
        OpenedDocument(id: 7, pages: pages);
    void show(OpenedDocument next) =>
        container.read(openDocumentProvider.notifier).show(next);
    double intoPage() =>
        view().offset.dy - view().placement.rects[view().currentPage]!.top;

    setUp(() => show(pages([for (var i = 0; i < 12; i++) a4(100 + i)])));

    test('an edit leaves the offset as it was', () {
      viewer().scrollBy(const Offset(0, 3000.5));
      final offset = view().offset;
      show(pages([for (var i = 0; i < 12; i++) a4(100 + i)]));
      expect(view().offset, offset);
    });

    test('removing an earlier page keeps the same page and place', () {
      viewer().goToPage(9);
      viewer().scrollBy(const Offset(0, 120));
      final into = intoPage();
      show(pages([for (var i = 1; i < 12; i++) a4(100 + i)]));
      expect(view().document.pageHandle(view().currentPage), 109);
      expect(view().currentPage, 8);
      expect(intoPage(), closeTo(into, 1e-6));
    });

    test('a page moved to the front takes the reader with it', () {
      viewer().goToPage(5);
      show(
        pages([
          a4(105),
          for (var i = 0; i < 12; i++)
            if (i != 5) a4(100 + i),
        ]),
      );
      expect(view().currentPage, 0);
    });

    test('removing the widest page keeps the place through the new fit', () {
      show(
        pages([
          const PageInfo(width: 1190, height: 842, handle: 99),
          for (var i = 0; i < 12; i++) a4(100 + i),
        ]),
      );
      viewer().goToPage(6);
      viewer().scrollBy(const Offset(0, 90));
      final zoom = view().zoom;
      final into = intoPage();
      show(pages([for (var i = 0; i < 12; i++) a4(100 + i)]));
      expect(view().zoom, closeTo(zoom * 2, 1e-9));
      expect(view().document.pageHandle(view().currentPage), 105);
      expect(intoPage(), closeTo(into * 2, 1e-6));
    });

    test('with its page gone the reader goes to the nearest page left', () {
      viewer().goToPage(4);
      show(
        pages([
          for (var i = 0; i < 12; i++)
            if (i != 4 && i != 5) a4(100 + i),
        ]),
      );
      expect(view().document.pageHandle(view().currentPage), 103);
    });

    test('a paged layout follows the page to its new row', () {
      viewer().setLayout(PageLayout.single);
      viewer().goToPage(6);
      show(pages([for (var i = 1; i < 12; i++) a4(100 + i)]));
      expect(view().document.pageHandle(view().currentPage), 106);
    });
  });

  test('no document, no view', () {
    container.read(openDocumentProvider.notifier).show(null);
    expect(container.read(viewerProvider), isNull);
  });

  test('a new view is continuous at Fit width, from the top', () {
    expect(view().layout, PageLayout.continuous);
    expect(view().fit, ZoomFit.width);
    expect(view().zoom, closeTo((1000 - 48) / (595 * pixelsPerPoint), 1e-9));
    expect(view().offset.dy, 0);
    expect(view().currentPage, 0);
  });

  test('a new view takes the layout and zoom of Settings › General', () {
    final opened = ProviderContainer.test(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          const AppSettings(
            pageLayout: NewDocumentLayout.spread,
            zoom: NewDocumentZoom.actual,
          ),
        ),
      ],
    )..read(openDocumentProvider.notifier).show(document);
    final fresh = opened.read(viewerProvider)!;
    expect(fresh.layout, PageLayout.twoPage);
    expect(fresh.fit, isNull);
    expect(fresh.zoom, 1);
  });

  test('scrolling stops at the ends', () {
    viewer().scrollBy(const Offset(0, -50));
    expect(view().offset.dy, 0);
    viewer().scrollBy(const Offset(0, 100000));
    expect(
      view().offset.dy,
      view().placement.size.height - view().viewport.height,
    );
    expect(view().currentPage, 4);
  });

  test('zooming keeps the page point under the pointer', () {
    viewer().zoomTo(1);
    viewer().scrollBy(const Offset(0, 500));
    const focal = Offset(400, 300);
    final before = view();
    final rect = before.placement.rects[0]!;
    final point = (before.offset + focal - rect.topLeft) / before.scale;
    viewer().zoomBy(2, focal);
    final after = view();
    expect(after.zoom, 2);
    expect(after.fit, isNull);
    final moved = after.placement.rects[0]!.topLeft + point * after.scale;
    expect(moved - after.offset, within(distance: 1e-6, from: focal));
  });

  test('zoom is held between 10 % and 1,600 %', () {
    viewer().zoomTo(100);
    expect(view().zoom, maxZoom);
    viewer().zoomOut();
    expect(view().zoom, 8);
    viewer().zoomTo(0);
    expect(view().zoom, minZoom);
  });

  test('page turns and Go to page move by rows', () {
    viewer().goToPage(3);
    expect(view().currentPage, 3);
    viewer().previousPage();
    expect(view().currentPage, 2);
    viewer().setLayout(PageLayout.book);
    // Book: [cover], [1, 2], [3, 4]; page 3 is in the second spread.
    expect(view().currentPage, 1);
    viewer().nextPage();
    expect(view().currentPage, 3);
    viewer().nextPage();
    expect(view().currentPage, 3);
  });

  test('a paged layout centres its row and turns at the end of a scroll', () {
    viewer()
      ..setLayout(PageLayout.single)
      ..fit(ZoomFit.page);
    expect(view().placement.rects.whereType<Rect>(), hasLength(1));
    expect(view().offset.dy, lessThanOrEqualTo(0));
    viewer().scrollBy(const Offset(0, Viewer.turnDistance / 2));
    expect(view().currentPage, 0);
    viewer().scrollBy(const Offset(0, Viewer.turnDistance));
    expect(view().currentPage, 1);
    viewer().scrollBy(const Offset(0, -2 * Viewer.turnDistance));
    expect(view().currentPage, 0);
  });

  test('a marquee zooms its area to fill the window, centred', () {
    viewer().zoomTo(1);
    const area = Rect.fromLTWH(100, 100, 250, 175);
    expect(view().marqueeZoom(area), 4);
    viewer().zoomToRect(area);
    expect(view().zoom, 4);
    viewer().zoomToRect(const Rect.fromLTWH(500, 300, 2, 2));
    expect(view().zoom, zoomStepAfter(4));
  });

  test('reveal scrolls the least that shows a box low and right on its page, '
      'in either layout', () {
    for (final layout in [PageLayout.continuous, PageLayout.single]) {
      viewer()
        ..setLayout(layout)
        ..zoomTo(2)
        ..goToPage(2);
      const box = Rect.fromLTWH(480, 700, 100, 20);
      viewer().reveal(2, box);
      final rect = view().placement.rects[2]!;
      final shown = Rect.fromLTRB(
        rect.left + box.left * view().scale,
        rect.top + box.top * view().scale,
        rect.left + box.right * view().scale,
        rect.top + box.bottom * view().scale,
      );
      expect(view().visible.contains(shown.topLeft), isTrue, reason: '$layout');
      expect(
        view().visible.contains(shown.bottomRight),
        isTrue,
        reason: '$layout',
      );
      // Already in view: nothing moves.
      final offset = view().offset;
      viewer().reveal(2, box);
      expect(view().offset, offset);
    }
  });

  test('the page field takes labels first, then numbers in any digits', () {
    expect(pageForInput(' ii ', document.pages), 1);
    expect(pageForInput('1', document.pages), 2);
    expect(pageForInput('4', document.pages), 3);
    expect(pageForInput('٥', document.pages), 4);
    expect(pageForInput('۴', document.pages), 3);
    expect(pageForInput('6', document.pages), isNull);
    expect(pageForInput('0', document.pages), isNull);
    expect(pageForInput('x', document.pages), isNull);
  });
}
