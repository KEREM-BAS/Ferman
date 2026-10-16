import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/annotations/highlight.dart';
import 'package:ferman/design/components/editing/page_mark.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const ramps = FermanRamps();

  RenderObject markOf(WidgetTester tester) =>
      tester.renderObject(find.byType(MarkedText));

  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      componentHost(SizedBox(width: 300, child: child), brightness: brightness);

  /// The first canvas call named [method] and its arguments.
  List<dynamic> firstCall(WidgetTester tester, Symbol method) {
    List<dynamic>? found;
    expect(
      markOf(tester),
      paints..everything((name, arguments) {
        if (name == method) found ??= arguments;
        return true;
      }),
    );
    return found!;
  }

  /// The baseline of a one-line run laid out at its own size.
  double baselineOf(WidgetTester tester) {
    final box = tester.renderObject<RenderBox>(find.byType(MarkedText));
    return box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;
  }

  testWidgets('highlight is the default: yellow, multiplied, under the text', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const Highlight(child: TextSpan(text: 'her ayın beşinci'))),
    );
    expect(
      markOf(tester),
      paints
        ..something((method, arguments) {
          if (method != #drawRRect) return false;
          final paint = arguments[1] as Paint;
          return paint.color.toARGB32() == ramps.annotYellow.toARGB32() &&
              paint.blendMode == BlendMode.multiply;
        })
        ..paragraph(),
    );
  });

  testWidgets('the fill bleeds 1 px past the text on each side', (
    tester,
  ) async {
    await tester.pumpWidget(
      componentHost(const Highlight(child: TextSpan(text: 'A'))),
    );
    final box = tester.renderObject<RenderBox>(find.byType(MarkedText));
    expect(
      markOf(tester),
      paints..something((method, arguments) {
        if (method != #drawRRect) return false;
        final rrect = arguments.first as RRect;
        return rrect.left == -Highlight.bleed &&
            (rrect.width - box.size.width - 2 * Highlight.bleed).abs() < 1e-6;
      }),
    );
  });

  testWidgets('underline: a 2 px line under the baseline', (tester) async {
    await tester.pumpWidget(
      host(
        const Highlight(
          variant: HighlightVariant.underline,
          color: AnnotationColor.green,
          child: TextSpan(text: 'IBAN'),
        ),
      ),
    );
    expect(
      markOf(tester),
      paints
        ..something((method, arguments) {
          if (method != #drawRect) return false;
          final rect = arguments.first as Rect;
          return (arguments[1] as Paint).color.toARGB32() ==
                  ramps.annotGreen.toARGB32() &&
              (rect.height - Highlight.lineThickness).abs() < 1e-6;
        })
        ..paragraph(),
    );
  });

  testWidgets('underline geometry: its top 2 px under the baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      componentHost(
        const Highlight(
          variant: HighlightVariant.underline,
          child: TextSpan(text: 'IBAN'),
        ),
      ),
    );
    final rect = firstCall(tester, #drawRect).first as Rect;
    expect(
      rect.top,
      closeTo(baselineOf(tester) + Highlight.underlineOffset, 1e-9),
    );
    expect(rect.left, 0);
    expect(rect.height, Highlight.lineThickness);
    expect(rect.width, tester.getSize(find.byType(MarkedText)).width);
  });

  testWidgets('squiggly geometry: a 1.5 px wave from 3 px down', (
    tester,
  ) async {
    await tester.pumpWidget(
      componentHost(
        const Highlight(
          variant: HighlightVariant.squiggly,
          child: TextSpan(text: 'kira'),
        ),
      ),
    );
    final path = firstCall(tester, #drawPath).first as Path;
    var top = double.infinity;
    var bottom = double.negativeInfinity;
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at <= metric.length; at += 0.1) {
        final y = metric.getTangentForOffset(at)!.position.dy;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    final baseline = baselineOf(tester);
    expect(top, closeTo(baseline + Highlight.squigglyOffset, 0.05));
    // One thickness either side of the wave's middle line.
    expect(
      bottom,
      closeTo(
        baseline + Highlight.squigglyOffset + 2 * Highlight.squigglyThickness,
        0.05,
      ),
    );
  });

  testWidgets('strikethrough geometry: through the lowercase letters', (
    tester,
  ) async {
    const text = TextSpan(text: 'kullandırılamaz');
    // The run's box, from the highlight fill of the same text.
    await tester.pumpWidget(componentHost(const Highlight(child: text)));
    final top = (firstCall(tester, #drawRRect).first as RRect).top;
    await tester.pumpWidget(
      componentHost(
        const Highlight(variant: HighlightVariant.strikethrough, child: text),
      ),
    );
    final baseline = baselineOf(tester);
    final rect = firstCall(tester, #drawRect).first as Rect;
    expect(
      rect.center.dy,
      closeTo(baseline - (baseline - top) * MarkPaint.strikeRatio, 1e-9),
    );
    expect(rect.height, Highlight.lineThickness);
  });

  testWidgets('strikethrough: a 2 px line over the text', (tester) async {
    await tester.pumpWidget(
      host(
        const Highlight(
          variant: HighlightVariant.strikethrough,
          color: AnnotationColor.red,
          child: TextSpan(text: 've kullandırılamaz'),
        ),
      ),
    );
    expect(
      markOf(tester),
      paints
        ..paragraph()
        ..rect(color: ramps.annotRed),
    );
  });

  testWidgets('squiggly: a 1.5 px wave', (tester) async {
    await tester.pumpWidget(
      host(
        const Highlight(
          variant: HighlightVariant.squiggly,
          color: AnnotationColor.blue,
          child: TextSpan(text: 'kira'),
        ),
      ),
    );
    expect(
      markOf(tester),
      paints..path(
        color: ramps.annotBlue,
        strokeWidth: Highlight.squigglyThickness,
        style: PaintingStyle.stroke,
      ),
    );
  });

  testWidgets('ink maps to the blue ink, as the bundle does', (tester) async {
    await tester.pumpWidget(
      host(
        const Highlight(
          variant: HighlightVariant.underline,
          color: AnnotationColor.ink,
          child: TextSpan(text: 'kira'),
        ),
      ),
    );
    expect(markOf(tester), paints..rect(color: ramps.annotBlueInk));
  });

  testWidgets('customColor overrides the palette', (tester) async {
    const custom = Color(0xFF00FF00);
    await tester.pumpWidget(
      host(
        const Highlight(
          variant: HighlightVariant.underline,
          customColor: custom,
          child: TextSpan(text: 'kira'),
        ),
      ),
    );
    expect(markOf(tester), paints..rect(color: custom));
  });

  testWidgets('document colours: the same in the dark theme', (tester) async {
    await tester.pumpWidget(
      host(
        const Highlight(
          variant: HighlightVariant.underline,
          color: AnnotationColor.pink,
          child: TextSpan(text: 'kira'),
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(markOf(tester), paints..rect(color: ramps.annotPink));
  });

  testWidgets('screen readers hear the text', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const Highlight(child: TextSpan(text: 'kira'))),
    );
    expect(find.bySemanticsLabel('kira'), findsOneWidget);
    handle.dispose();
  });
}
