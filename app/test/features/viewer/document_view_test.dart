import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/shell_canvas.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';

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

/// A view that answers only the tiles of [buckets], and no thumbnails, as
/// an engine whose sharp tiles are still on their way; [release] answers
/// the last request in full.
class _SlowTiles extends FakeEngineService {
  new() : super(documents: {'/kira.pdf': document});

  /// The zoom buckets whose tiles arrive; null lets every tile arrive.
  Set<int>? buckets;

  /// The last request as the canvas sent it.
  (int, int, List<WantedItem>)? last;

  @override
  Future<void> requestView(int view, int generation, List<WantedItem> wanted) {
    last = (view, generation, wanted);
    return super.requestView(view, generation, [
      for (final entry in wanted)
        if (entry.item case TileItem(:final zoomBucket)
            when buckets?.contains(zoomBucket) ?? true)
          entry,
    ]);
  }

  /// The sharp tiles arrive.
  Future<void> release() async {
    if (last case (final view, final generation, final wanted)) {
      await super.requestView(view, generation, [
        for (final entry in wanted)
          if (entry.item is TileItem) entry,
      ]);
    }
  }
}

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  /// The shell with [document] open on [engine].
  Future<FakeEngineService> pumpDocument(
    WidgetTester tester, {
    Set<int> failingPages = const {},
    FakeEngineService? fake,
  }) async {
    final engine =
        fake ??
        FakeEngineService(
          documents: {'/kira.pdf': document},
          failingPages: failingPages,
        );
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        overrides: [engineServiceProvider.overrideWithValue(engine)],
      ),
    );
    containerOf(tester).read(openDocumentProvider.notifier).show(document);
    await settle(tester);
    return engine;
  }

  ViewerState view(WidgetTester tester) =>
      containerOf(tester).read(viewerProvider)!;

  // Region values are bidi-isolated, so the text contains them.
  Finder statusText(String text) => find.descendant(
    of: find.byType(ShellStatusBar),
    matching: find.textContaining(text),
  );

  Finder iconButton(String label) => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.label == label,
  );

  testWidgets('the canvas shows the document and asks for its tiles', (
    tester,
  ) async {
    final engine = await pumpDocument(tester);
    expect(find.byType(DocumentView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ShellCanvas),
        matching: find.text(futureVersion),
      ),
      findsNothing,
    );
    // The canvas's set: the sidebar's thumbnails come through a view of their
    // own.
    final wanted = engine.requests.lastWhere(
      (wanted) => wanted.any((entry) => entry.item is TileItem),
    );
    expect(wanted.first.priority, RenderPriority.visible);
    expect(wanted.first.item, isA<TileItem>().having((t) => t.page, 'page', 0));
    expect(
      wanted.map((entry) => entry.item),
      contains(const ThumbnailItem(page: 0, size: previewSize)),
    );
    expect(statusText('Page 1 of 5'), findsOneWidget);
    // The fake's pixels decode outside the test's fake clock; then the
    // page shows them.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(
      tester.renderObject(
        find
            .descendant(
              of: find.byType(DocumentView),
              matching: find.byType(CustomPaint),
            )
            .first,
      ),
      paints..drawImageRect(),
    );
    // Fit width by default (a11-1): the zoom field names it.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Select<String> && widget.value == 'fit-width',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the zoom field opens a2-2’s menu: the fits with their keys, '
      'the steps and Marquee zoom', (tester) async {
    await pumpDocument(tester);
    final field = find.byWidgetPredicate(
      (widget) => widget is Select<String> && widget.value == 'fit-width',
    );
    await tester.tap(field);
    await settle(tester);
    final menu = tester.widget<Menu>(find.byType(Menu));
    expect(
      [
        for (final item in menu.items)
          if (item.separator) '-' else item.label,
      ],
      [
        'Fit width',
        'Fit page',
        'Actual size',
        '-',
        ...[
          '50',
          '75',
          '100',
          '125',
          '150',
          '200',
          '400',
        ].map((step) => menu.items.firstWhere((item) => item.id == step).label),
        '-',
        'Marquee zoom',
      ],
    );
    expect(menu.items.first.shortcut, ['Ctrl', '2']);
    expect(menu.items.first.checked, isTrue);
    expect(menu.items.last.shortcut, ['Z']);
    await tester.tap(find.text('Fit page').last);
    await settle(tester);
    expect(find.byType(Menu), findsNothing);
    expect(view(tester).fit, ZoomFit.page);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Select<String> && widget.value == 'fit-page',
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Marquee zoom').last);
    await settle(tester);
    expect(view(tester).tool, ViewerTool.marquee);
  });

  testWidgets('a page that fails shows a2-13’s placeholder, and Try again '
      'asks for it again', (tester) async {
    final engine = await pumpDocument(tester, failingPages: {0});
    expect(find.text('Ferman couldn’t draw page 1.'), findsOneWidget);
    expect(
      find.text(
        'Something on this page can’t be read. The rest of the document '
        'works as usual.',
      ),
      findsOneWidget,
    );
    final asked = engine.requests.length;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(engine.requests.length, greaterThan(asked));
    expect(engine.requests[asked].map((entry) => entry.item.page), contains(0));
  });

  testWidgets('Ctrl+G opens the page field, which takes numbers and labels', (
    tester,
  ) async {
    await pumpDocument(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.byType(EditableText), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(view(tester).currentPage, 3);
    expect(statusText('Page 4 of 5'), findsOneWidget);
    // A click opens it too; "1" is the label of page 3.
    await tester.tap(statusText('Page 4 of 5'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText), '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(statusText('Page 3 of 5'), findsOneWidget);
  });

  testWidgets('the status bar zooms and shows the zoom a fit gives', (
    tester,
  ) async {
    await pumpDocument(tester);
    final fitted = (view(tester).zoom * 100).round();
    expect(statusText('$fitted%'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(ShellStatusBar),
        matching: iconButton('Zoom in'),
      ),
    );
    await settle(tester);
    expect(view(tester).fit, isNull);
    expect(view(tester).zoom, zoomStepAfter(fitted / 100));
    expect(
      statusText('${(zoomStepAfter(fitted / 100) * 100).round()}%'),
      findsOneWidget,
    );
  });

  testWidgets('Ctrl with the wheel zooms around the pointer, the wheel '
      'scrolls', (tester) async {
    await pumpDocument(tester);
    final canvas = tester.getCenter(find.byType(DocumentView));
    final before = view(tester).zoom;
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(canvas));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 300)));
    await settle(tester);
    expect(view(tester).offset.dy, 300);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -240)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(view(tester).zoom, closeTo(before * 2, 1e-9));
  });

  testWidgets('the trackpad pinch zooms around the pointer, its pan '
      'scrolls', (tester) async {
    await pumpDocument(tester);
    final origin = tester.getTopLeft(find.byType(DocumentView));
    final focal =
        tester.getCenter(find.byType(DocumentView)) + const Offset(80, 60);
    // The point of page 1 under the pointer, in points.
    Offset underPointer() {
      final state = view(tester);
      final page = state.placement.rects.first!;
      return (state.visible.topLeft + focal - origin - page.topLeft) /
          state.scale;
    }

    final before = view(tester).zoom;
    final point = underPointer();
    final trackpad = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(trackpad.panZoomStart(focal));
    await tester.sendEventToBinding(trackpad.panZoomUpdate(focal, scale: 1.5));
    await tester.sendEventToBinding(trackpad.panZoomUpdate(focal, scale: 2));
    await tester.sendEventToBinding(trackpad.panZoomEnd());
    await settle(tester);
    expect(view(tester).zoom, closeTo(before * 2, 1e-9));
    expect(underPointer().dx, closeTo(point.dx, 1e-6));
    expect(underPointer().dy, closeTo(point.dy, 1e-6));

    // Two fingers moving up scroll down; a new pinch starts from 1 again.
    final offset = view(tester).offset;
    await tester.sendEventToBinding(trackpad.panZoomStart(focal));
    await tester.sendEventToBinding(
      trackpad.panZoomUpdate(focal, pan: const Offset(0, -120)),
    );
    await tester.sendEventToBinding(trackpad.panZoomEnd());
    await settle(tester);
    expect(view(tester).zoom, closeTo(before * 2, 1e-9));
    expect(view(tester).offset.dy, closeTo(offset.dy + 120, 1e-6));
  });

  testWidgets('a page shows another bucket’s tiles, scaled, until its sharp '
      'tiles arrive (G30)', (tester) async {
    final engine = _SlowTiles();
    await pumpDocument(tester, fake: engine);
    final bucket = zoomBucket(view(tester).scale);
    // Every bitmap drawn on the canvas, in order: its source and target.
    List<(Rect, Rect)> drawn() {
      final calls = <(Rect, Rect)>[];
      expect(
        tester.renderObject(
          find
              .descendant(
                of: find.byType(DocumentView),
                matching: find.byType(CustomPaint),
              )
              .first,
        ),
        paints..everything((method, arguments) {
          if (method == #drawImageRect) {
            calls.add((arguments[1]! as Rect, arguments[2]! as Rect));
          }
          return true;
        }),
      );
      return calls;
    }

    double ratio((Rect, Rect) draw) => draw.$2.width / draw.$1.width;

    // The fake's pixels decode outside the test's fake clock.
    Future<void> decode() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }

    await decode();
    final sharp = drawn();
    expect(sharp, isNotEmpty);
    final size = ratio(sharp.first);

    engine.buckets = {bucket};
    containerOf(tester)
        .read(viewerProvider.notifier)
        .zoomTo(view(tester).zoom * 2);
    await settle(tester);
    await decode();
    expect(zoomBucket(view(tester).scale), bucket + 4);
    // The sharp tiles were asked for and have not come: the old ones show,
    // twice as large, where the page now is.
    expect(
      engine.last!.$3.map((entry) => entry.item),
      contains(
        isA<TileItem>().having((t) => t.zoomBucket, 'zoomBucket', bucket + 4),
      ),
    );
    final scaled = drawn();
    expect(scaled, isNotEmpty);
    for (final draw in scaled) {
      expect(ratio(draw), closeTo(size * 2, 1e-6));
    }

    // They sharpen in place: the new tiles are drawn last, on top, at their
    // own size.
    await engine.release();
    await decode();
    final after = drawn();
    expect(after.length, greaterThan(scaled.length));
    expect(ratio(after.last), closeTo(size, 1e-6));
    expect(ratio(after.first), closeTo(size * 2, 1e-6));
  });

  testWidgets('the Hand tool drags the pages; Marquee zoom zooms into a '
      'rectangle and says how far', (tester) async {
    await pumpDocument(tester);
    final canvas = tester.getCenter(find.byType(DocumentView));
    await tester.tap(find.text('Hand'));
    await settle(tester);
    expect(view(tester).tool, ViewerTool.hand);
    final hand = await tester.startGesture(
      canvas,
      kind: PointerDeviceKind.mouse,
    );
    await hand.moveBy(const Offset(0, -200));
    await hand.up();
    await settle(tester);
    expect(view(tester).offset.dy, 200);

    await tester.tap(find.text('Marquee zoom'));
    await settle(tester);
    final zoom = view(tester).zoom;
    final marquee = await tester.startGesture(
      canvas,
      kind: PointerDeviceKind.mouse,
    );
    await marquee.moveBy(const Offset(120, 80));
    await tester.pump();
    final target = view(tester).marqueeZoom(
      Rect.fromPoints(
        canvas - tester.getTopLeft(find.byType(DocumentView)),
        canvas -
            tester.getTopLeft(find.byType(DocumentView)) +
            const Offset(120, 80),
      ),
    );
    expect(find.textContaining('${(target * 100).round()}%'), findsOneWidget);
    await marquee.up();
    await settle(tester);
    expect(view(tester).zoom, greaterThan(zoom));
    expect(view(tester).zoom, closeTo(target, 1e-9));
  });

  testWidgets('the View row lays pages out and fits them', (tester) async {
    await pumpDocument(tester);
    // Icon-only segments: the one named by its tooltip.
    await tester.tap(find.bySemanticsLabel('Book (cover page alone)').last);
    await settle(tester);
    expect(view(tester).layout, PageLayout.book);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(view(tester).fit, ZoomFit.page);
  });
}
