import 'package:ferman/design/components/overlays/scrim.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const childKey = Key('child');
  const box = SizedBox(key: childKey, width: 200, height: 100);

  Color colorOf(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find.descendant(
          of: find.byType(Scrim),
          matching: find.byType(ColoredBox),
        ),
      )
      .color;

  group('Scrim', () {
    testWidgets('fills the space with --surface-scrim and centres the child', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const Scrim(child: box)));
      await tester.pumpAndSettle();
      expect(colorOf(tester), FermanTheme.light.colors.surfaceScrim);
      expect(tester.getSize(find.byType(Scrim)), const Size(800, 600));
      expect(tester.getCenter(find.byKey(childKey)), const Offset(400, 300));
    });

    testWidgets('top: lighter tint, the child 14 % from the top', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const Scrim(top: true, child: box)),
      );
      await tester.pumpAndSettle();
      expect(colorOf(tester), Scrim.topLight);
      expect(tester.getTopLeft(find.byKey(childKey)).dy, 600 * 0.14);
      expect(tester.getCenter(find.byKey(childKey)).dx, 400);
    });

    testWidgets('dark: the dark scrim and the dark top tint', (tester) async {
      await tester.pumpWidget(
        componentHost(const Scrim(child: box), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      expect(colorOf(tester), FermanTheme.dark.colors.surfaceScrim);
      await tester.pumpWidget(
        componentHost(
          const Scrim(top: true, child: box),
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(colorOf(tester), Scrim.topDark);
    });

    testWidgets('fades in over --dur-base, the child with it', (tester) async {
      await tester.pumpWidget(componentHost(const Scrim(child: box)));
      final fade = find.descendant(
        of: find.byType(Scrim),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(fade).opacity, 0);
      // The tint itself is the full scrim colour; the fade is on the whole
      // layer, child included (CSS opacity fades the subtree).
      expect(colorOf(tester), FermanTheme.light.colors.surfaceScrim);
      expect(
        find.descendant(of: fade, matching: find.byKey(childKey)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fade, matching: find.byType(ColoredBox)),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 90));
      final halfway = tester.widget<Opacity>(fade).opacity;
      expect(halfway, greaterThan(0));
      expect(halfway, lessThan(1));
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.widget<Opacity>(fade).opacity, 1);
    });

    testWidgets('reduced motion: shown at once', (tester) async {
      await tester.pumpWidget(
        componentHost(const Scrim(child: box), disableAnimations: true),
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(
                of: find.byType(Scrim),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        1,
      );
    });

    testWidgets('a pointer down on the scrim dismisses; on the child not', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        componentHost(
          Scrim(
            onDismiss: () => dismissed++,
            child: const ColoredBox(color: Color(0xFFFFFFFF), child: box),
          ),
        ),
      );
      await tester.tap(find.byKey(childKey));
      expect(dismissed, 0);
      await tester.tapAt(const Offset(20, 20));
      expect(dismissed, 1);
    });

    testWidgets('semantics: a dismiss target only with a label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          Scrim(onDismiss: () {}, dismissLabel: 'Close', child: box),
        ),
      );
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      // On the first, transparent frame too.
      await tester.pumpWidget(componentHost(const SizedBox()));
      await tester.pumpWidget(
        componentHost(
          Scrim(onDismiss: () {}, dismissLabel: 'Close', child: box),
        ),
      );
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      await tester.pumpWidget(
        componentHost(Scrim(onDismiss: () {}, child: box)),
      );
      expect(find.bySemanticsLabel('Close'), findsNothing);
      handle.dispose();
    });

    testWidgets('right to left keeps the child centred', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const Scrim(child: box),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(tester.getCenter(find.byKey(childKey)), const Offset(400, 300));
    });
  });
}
