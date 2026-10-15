import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  group('Kbd', () {
    testWidgets('shows one cap per key', (tester) async {
      await tester.pumpWidget(componentHost(const Kbd(['⌘', 'K'])));
      expect(find.text('⌘'), findsOneWidget);
      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('standard caps: raised, 18 px tall, thicker bottom edge', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const Kbd(['K'])));
      final cap = tester.widget<Container>(
        find.ancestor(of: find.text('K'), matching: find.byType(Container)),
      );
      final decoration = cap.decoration! as BoxDecoration;
      expect(decoration.color, FermanColorTokens.light.surfaceRaised);
      final border = decoration.border! as BorderDirectional;
      expect(border.top.width, 1);
      expect(border.bottom.width, 2);
      expect(tester.getSize(find.byType(Container)).height, Kbd.capExtent);
      final text = tester.widget<Text>(find.text('K'));
      expect(text.style!.color, FermanColorTokens.light.textSecondary);
    });

    testWidgets('plain caps are bare text in the tertiary colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const Kbd(['K'], tone: KbdTone.plain)),
      );
      expect(find.byType(Container), findsNothing);
      final text = tester.widget<Text>(find.text('K'));
      expect(text.style!.color, FermanColorTokens.light.textTertiary);
    });

    testWidgets('inverse caps are bare inverse text at 68 % opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const Kbd(['K'], tone: KbdTone.inverse)),
      );
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, Kbd.inverseOpacity);
      final text = tester.widget<Text>(find.text('K'));
      expect(text.style!.color, FermanColorTokens.light.textInverse);
    });

    testWidgets('is read as one label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(const Kbd(['Ctrl', 'K'])));
      expect(find.bySemanticsLabel('Ctrl K'), findsOneWidget);
      await tester.pumpWidget(
        componentHost(const Kbd(['⌘', 'K'], semanticLabel: 'Command K')),
      );
      expect(find.bySemanticsLabel('Command K'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('mirrors the cap order in right to left', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const Kbd(['Ctrl', 'K']),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.text('Ctrl')).dx,
        greaterThan(tester.getCenter(find.text('K')).dx),
      );
    });
  });
}
