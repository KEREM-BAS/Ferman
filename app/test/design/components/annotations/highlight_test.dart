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
