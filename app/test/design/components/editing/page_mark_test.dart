import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/editing/page_mark.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const page = FermanPageColors();

  RenderObject markOf(WidgetTester tester) =>
      tester.renderObject(find.byType(MarkedText));

  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      componentHost(SizedBox(width: 300, child: child), brightness: brightness);

  /// Every canvas call the mark makes, in order.
  List<(Symbol, List<dynamic>)> callsOf(WidgetTester tester) {
    final calls = <(Symbol, List<dynamic>)>[];
    expect(
      markOf(tester),
      paints..everything((method, arguments) {
        calls.add((method, arguments));
        return true;
      }),
    );
    return calls;
  }

  List<RRect> rrectsOf(WidgetTester tester) => [
    for (final (method, arguments) in callsOf(tester))
      if (method == #drawRRect) arguments.first as RRect,
  ];

  /// The baseline of a one-line run laid out at its own size (the host
  /// centres it, so its one fragment spans its whole width).
  double baselineOf(WidgetTester tester) {
    final box = tester.renderObject<RenderBox>(find.byType(MarkedText));
    return box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;
  }

  /// The vertical extent of the curve [path] draws (not its control
  /// points).
  (double, double) curveExtent(Path path) {
    var top = double.infinity;
    var bottom = double.negativeInfinity;
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at <= metric.length; at += 0.1) {
        final y = metric.getTangentForOffset(at)!.position.dy;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    return (top, bottom);
  }

  group('PageMark kinds', () {
    testWidgets('selection is the default: the edit-selection tint', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const PageMark(child: TextSpan(text: 'kira'))),
      );
      expect(
        markOf(tester),
        paints
          ..rrect(color: page.editSelection)
          ..paragraph(),
      );
    });

    testWidgets('edited: a dotted ink underline and no fill (fix 3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.edited,
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      // Under the text, as CSS paints an underline.
      expect(
        markOf(tester),
        paints
          ..rect(color: page.editMark)
          ..paragraph(),
      );
      expect(markOf(tester), isNot(paints..rrect()));
    });

    testWidgets('edited geometry: square dots one dot apart, 3 px down', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const PageMark(
            kind: PageMarkKind.edited,
            child: TextSpan(text: 'değiştirilemez'),
          ),
        ),
      );
      final width = tester.getSize(find.byType(MarkedText)).width;
      final top = (baselineOf(tester) + PageMark.underlineOffset)
          .roundToDouble();
      final dots = [
        for (final (method, arguments) in callsOf(tester))
          if (method == #drawRect) arguments,
      ];
      expect(dots.length, greaterThan(3));
      // 1.5 px snapped to whole pixels at 1x: 2 px squares, a 4 px pitch,
      // drawn crisp.
      Rect rect(int i) => dots[i].first as Rect;
      for (var i = 0; i < dots.length; i++) {
        expect(rect(i).top, top);
        expect(rect(i).size, const Size.square(2));
        expect((dots[i][1] as Paint).isAntiAlias, isFalse);
        if (i > 0) expect(rect(i).left - rect(i - 1).left, 4);
      }
      expect(rect(0).left, 0);
      expect(rect(dots.length - 1).right, lessThanOrEqualTo(width + 0.01));
      expect(width - rect(dots.length - 1).right, lessThan(4));
    });

    testWidgets('edited at 2x: 1.5 px dots, a 3 px pitch', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const MediaQuery(
            data: MediaQueryData(devicePixelRatio: 2),
            child: PageMark(
              kind: PageMarkKind.edited,
              child: TextSpan(text: 'kira bedeli'),
            ),
          ),
        ),
      );
      final rects = [
        for (final (method, arguments) in callsOf(tester))
          if (method == #drawRect) arguments.first as Rect,
      ];
      expect(rects.first.size, const Size.square(1.5));
      expect(rects[1].left - rects[0].left, 3);
    });

    testWidgets('missing glyph: amber tint and a wavy amber underline', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.missingGlyph,
            char: 'ğ',
            child: TextSpan(text: 'ğ'),
          ),
        ),
      );
      expect(
        markOf(tester),
        paints
          ..rrect(color: page.glyphMissingBg)
          ..path(
            color: page.glyphMissing,
            style: PaintingStyle.stroke,
            strokeWidth: PageMark.missingGlyphThickness,
          )
          ..paragraph(),
      );
    });

    testWidgets('missing glyph geometry: a 1 px wave from 3 px down', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const PageMark(
            kind: PageMarkKind.missingGlyph,
            child: TextSpan(text: 'ğğğ'),
          ),
        ),
      );
      final baseline = baselineOf(tester);
      final path =
          callsOf(tester).firstWhere((call) => call.$1 == #drawPath).$2.first
              as Path;
      final (top, bottom) = curveExtent(path);
      // The wave swings one thickness either side of its middle line.
      expect(top, closeTo(baseline + PageMark.underlineOffset, 0.05));
      expect(
        bottom,
        closeTo(
          baseline +
              PageMark.underlineOffset +
              2 * PageMark.missingGlyphThickness,
          0.05,
        ),
      );
    });

    testWidgets('search and current search hit', (tester) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.search,
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(markOf(tester), paints..rrect(color: page.searchMatch));
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.searchCurrent,
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(
        markOf(tester),
        paints
          ..rrect(color: page.searchCurrent)
          ..rrect(
            color: page.searchCurrentBorder,
            style: PaintingStyle.stroke,
            strokeWidth: PageMark.ringWidth,
          )
          ..paragraph(),
      );
    });

    testWidgets('the rings sit 1 px outside the fill, corners grown', (
      tester,
    ) async {
      for (final kind in [
        PageMarkKind.searchCurrent,
        PageMarkKind.redactPending,
      ]) {
        await tester.pumpWidget(
          componentHost(
            PageMark(
              kind: kind,
              child: const TextSpan(text: 'kira'),
            ),
          ),
        );
        final rrects = rrectsOf(tester);
        expect(rrects, hasLength(2));
        final fill = rrects.first;
        expect(fill.tlRadius, const Radius.circular(PageMark.radius));
        // `box-shadow: 0 0 0 1px` on `border-radius: 1px`: a 1 px band out
        // to radius 2, stroked along its middle.
        expect(
          rrects.last,
          RRect.fromRectAndRadius(
            fill.outerRect.inflate(PageMark.ringWidth / 2),
            const Radius.circular(PageMark.radius + PageMark.ringWidth / 2),
          ),
        );
      }
    });

    testWidgets('pending redaction stripes: -45°, 4 px tint then 2 px red', (
      tester,
    ) async {
      const key = ValueKey<String>('mark');
      await tester.pumpWidget(
        componentHost(
          RepaintBoundary(
            key: key,
            child: PageMark(
              kind: PageMarkKind.redactPending,
              // No-break spaces: a wide run with no ink over the stripes.
              child: TextSpan(text: '\u00A0' * 16),
            ),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image = (await tester.runAsync(boundary.toImage))!;
      final data = (await tester.runAsync(image.toByteData))!;
      addTearDown(image.dispose);
      // The tint is 12 % (alpha 31), the red stripe 22 % (alpha 56).
      bool red(int x, int y) =>
          data.getUint8((y * image.width + x) * 4 + 3) >= 44;
      final y = image.height ~/ 2;
      var reds = 0;
      var count = 0;
      for (var x = 3; x < image.width - 3; x++) {
        count++;
        if (red(x, y)) reds++;
        // -45°: the stripes run up to the right (x + y constant).
        expect(red(x, y), red(x + 1, y - 1), reason: 'at ($x, $y)');
      }
      // 2 px of every 6 px period along the diagonal.
      expect(reds / count, closeTo(1 / 3, 0.08));
      expect(data.lengthInBytes, image.width * image.height * 4);
    });

    testWidgets('pending redaction: red stripes and a red ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.redactPending,
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(
        markOf(tester),
        paints
          ..something((method, arguments) {
            if (method != #drawRRect) return false;
            return (arguments[1] as Paint).shader != null;
          })
          ..rrect(color: page.redactPending, style: PaintingStyle.stroke)
          ..paragraph(),
      );
    });

    testWidgets('applied redaction: black, the text no longer drawn', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.redactApplied,
            tooltip: 'Redacted',
            child: TextSpan(text: 'secret'),
          ),
        ),
      );
      expect(markOf(tester), paints..rrect(color: page.redactApplied));
      expect(markOf(tester), isNot(paints..paragraph()));
      expect(find.bySemanticsLabel('secret'), findsNothing);
      expect(
        tester.getSemantics(find.byType(MarkedText)),
        isSemantics(tooltip: 'Redacted'),
      );
      handle.dispose();
    });
  });

  group('PageMark layout and semantics', () {
    testWidgets('the mark is painted once per line fragment', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const SizedBox(
            width: 60,
            child: PageMark(child: TextSpan(text: 'kira bedeli her yıl artar')),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(MarkedText));
      expect(box.size.height, greaterThan(20));
      expect(
        markOf(tester),
        paints
          ..rrect(color: page.editSelection)
          ..rrect(color: page.editSelection),
      );
    });

    testWidgets('the tooltip shows and is given to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.edited,
            tooltip: 'Edited',
            child: TextSpan(text: 'kira'),
          ),
        ),
      );
      expect(find.byType(Tooltip), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(MarkedText)),
        isSemantics(label: 'kira', tooltip: 'Edited'),
      );
      handle.dispose();
    });

    testWidgets('page-tuned: the same colours in the dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const PageMark(
            kind: PageMarkKind.search,
            child: TextSpan(text: 'kira'),
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(markOf(tester), paints..rrect(color: page.searchMatch));
    });

    testWidgets('right-to-left text is marked where it is drawn: the start', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const SizedBox(
            width: 300,
            child: PageMark(child: TextSpan(text: 'عقد الإيجار')),
          ),
          locale: const Locale('ar'),
        ),
      );
      expect(markOf(tester), paints..rrect(color: page.editSelection));
      final fill = rrectsOf(tester).single.outerRect;
      expect(fill.right, closeTo(300, 0.5));
      expect(fill.left, greaterThan(0));
    });

    testWidgets('a tight width aligns the text and its mark', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const SizedBox(
            width: 300,
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
              child: PageMark(child: TextSpan(text: 'kira')),
            ),
          ),
        ),
      );
      final fill = rrectsOf(tester).single.outerRect;
      expect(fill.center.dx, closeTo(150, 0.5));
      expect(fill.left, greaterThan(0));
      expect(tester.getSize(find.byType(MarkedText)), const Size(300, 14));
    });

    testWidgets('MarkedText inherits the ambient text style', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const DefaultTextStyle(
            style: TextStyle(fontSize: 30),
            child: MarkedText(text: TextSpan(text: 'A')),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byType(MarkedText));
      expect(box.size.height, 30);
    });
  });
}
