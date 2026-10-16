import 'package:ferman/design/components/editing/text_caret.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const page = FermanPageColors();

  RenderCaretBar bar(WidgetTester tester) =>
      tester.renderObject<RenderCaretBar>(
        find.descendant(
          of: find.byType(TextCaret),
          matching: find.byWidgetPredicate(
            (widget) => widget is LeafRenderObjectWidget,
          ),
        ),
      );

  Widget caret({double fontSize = 20}) => DefaultTextStyle(
    style: TextStyle(fontSize: fontSize),
    child: const TextCaret(),
  );

  testWidgets('1.15 em tall, no width, 0.2 em below the baseline', (
    tester,
  ) async {
    await tester.pumpWidget(componentHost(caret()));
    final box = bar(tester);
    expect(box.size, const Size(0, 20 * TextCaret.heightEm));
    expect(
      box.getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic),
      closeTo(20 * (TextCaret.heightEm - TextCaret.descentEm), 1e-9),
    );
  });

  testWidgets('paints a 1.5 px edit-caret bar centred on its position', (
    tester,
  ) async {
    await tester.pumpWidget(componentHost(caret()));
    expect(
      bar(tester),
      paints..rect(
        rect: const Rect.fromLTWH(
          -TextCaret.width / 2,
          0,
          TextCaret.width,
          20 * TextCaret.heightEm,
        ),
        color: page.editCaret,
      ),
    );
  });

  testWidgets('blinks in hard steps every 1.05 s', (tester) async {
    await tester.pumpWidget(componentHost(caret()));
    expect(bar(tester).visible, isTrue);
    await tester.pump(TextCaret.blinkPeriod ~/ 2);
    expect(bar(tester).visible, isFalse);
    expect(bar(tester), isNot(paints..rect()));
    await tester.pump(TextCaret.blinkPeriod ~/ 2);
    expect(bar(tester).visible, isTrue);
    // Unmounting cancels the timer (a pending timer would fail the test).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stays solid under reduced motion', (tester) async {
    await tester.pumpWidget(componentHost(caret(), disableAnimations: true));
    for (var i = 0; i < 4; i++) {
      await tester.pump(TextCaret.blinkPeriod ~/ 2);
      expect(bar(tester).visible, isTrue);
    }
  });

  testWidgets('stays solid, with no timer, while its tickers are muted', (
    tester,
  ) async {
    Widget muted({required bool enabled}) =>
        componentHost(TickerMode(enabled: enabled, child: caret()));
    await tester.pumpWidget(muted(enabled: false));
    for (var i = 0; i < 4; i++) {
      await tester.pump(TextCaret.blinkPeriod ~/ 2);
      expect(bar(tester).visible, isTrue);
    }
    // Unmuted, it blinks again; muted, it shows at once and stops.
    await tester.pumpWidget(muted(enabled: true));
    await tester.pump(TextCaret.blinkPeriod ~/ 2);
    expect(bar(tester).visible, isFalse);
    await tester.pumpWidget(muted(enabled: false));
    expect(bar(tester).visible, isTrue);
    await tester.pump(TextCaret.blinkPeriod);
    expect(bar(tester).visible, isTrue);
    // No timer is left (a pending one would fail the test).
  });

  testWidgets('stays solid on a hidden IndexedStack page', (tester) async {
    // The hidden page is offstage, so find it with skipOffstage off.
    RenderCaretBar hiddenBar() => tester.renderObject<RenderCaretBar>(
      find.descendant(
        of: find.byType(TextCaret, skipOffstage: false),
        matching: find.byWidgetPredicate(
          (widget) => widget is LeafRenderObjectWidget,
          skipOffstage: false,
        ),
        skipOffstage: false,
      ),
    );
    Widget stack(int index) => componentHost(
      IndexedStack(
        index: index,
        children: [caret(), const SizedBox.square(dimension: 10)],
      ),
    );
    await tester.pumpWidget(stack(1));
    for (var i = 0; i < 3; i++) {
      await tester.pump(TextCaret.blinkPeriod ~/ 2);
      expect(hiddenBar().visible, isTrue);
    }
    await tester.pumpWidget(stack(0));
    await tester.pump(TextCaret.blinkPeriod ~/ 2);
    expect(hiddenBar().visible, isFalse);
    await tester.pumpWidget(stack(1));
    expect(hiddenBar().visible, isTrue);
  });

  testWidgets('page-tuned: the same ink in the dark theme', (tester) async {
    await tester.pumpWidget(
      componentHost(caret(), brightness: Brightness.dark),
    );
    expect(bar(tester), paints..rect(color: page.editCaret));
  });

  Widget inText({TextScaler textScaler = TextScaler.noScaling}) =>
      componentHost(
        Text.rich(
          textScaler: textScaler,
          TextSpan(
            text: 'kira',
            style: const TextStyle(fontSize: 20),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                // A widget span's child does not inherit the span's style.
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 20),
                  child: const TextCaret(),
                ),
              ),
            ],
          ),
        ),
      );

  double baselineOf(WidgetTester tester) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    return tester.getTopLeft(find.byType(RichText)).dy +
        paragraph.getDryBaseline(
          paragraph.constraints,
          TextBaseline.alphabetic,
        )!;
  }

  testWidgets('sits on the baseline inside text, 1.15 em of the span', (
    tester,
  ) async {
    await tester.pumpWidget(inText());
    final rect = tester.getRect(find.byType(TextCaret));
    expect(rect.height, closeTo(20 * TextCaret.heightEm, 1e-6));
    expect(
      rect.bottom,
      // Within the paragraph's sub-pixel rounding of the placeholder.
      closeTo(baselineOf(tester) + 20 * TextCaret.descentEm, 0.5),
    );
  });

  testWidgets('scaled once by a larger text size, as the text is', (
    tester,
  ) async {
    await tester.pumpWidget(inText(textScaler: const TextScaler.linear(2)));
    final rect = tester.getRect(find.byType(TextCaret));
    // 2 × 20 px × 1.15 = 46 px, not 92.
    expect(rect.height, closeTo(2 * 20 * TextCaret.heightEm, 1e-6));
    expect(
      rect.bottom,
      closeTo(baselineOf(tester) + 2 * 20 * TextCaret.descentEm, 0.5),
    );
    // Outside text, the caret is not scaled.
    await tester.pumpWidget(
      componentHost(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: caret(),
        ),
      ),
    );
    expect(bar(tester).size, const Size(0, 20 * TextCaret.heightEm));
  });

  testWidgets('decorative: no semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(componentHost(caret()));
    expect(tester.getSemantics(find.byType(TextCaret)), isSemantics(label: ''));
    handle.dispose();
  });
}
