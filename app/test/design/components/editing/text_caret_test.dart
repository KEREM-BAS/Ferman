import 'package:ferman/design/components/editing/text_caret.dart';
import 'package:ferman/design/theme.dart';
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

  testWidgets('page-tuned: the same ink in the dark theme', (tester) async {
    await tester.pumpWidget(
      componentHost(caret(), brightness: Brightness.dark),
    );
    expect(bar(tester), paints..rect(color: page.editCaret));
  });

  testWidgets('sits on the baseline inside text', (tester) async {
    await tester.pumpWidget(
      componentHost(
        const Text.rich(
          TextSpan(
            text: 'kira',
            style: TextStyle(fontSize: 20),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: TextCaret(),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(TextCaret), findsOneWidget);
  });

  testWidgets('decorative: no semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(componentHost(caret()));
    expect(tester.getSemantics(find.byType(TextCaret)), isSemantics(label: ''));
    handle.dispose();
  });
}
