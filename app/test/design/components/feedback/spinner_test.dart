import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  SpinnerPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(Spinner),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as SpinnerPainter;

  double turns(WidgetTester tester) => tester
      .widget<RotationTransition>(find.byType(RotationTransition))
      .turns
      .value;

  group('Spinner', () {
    testWidgets('16 px by default; border and accent colours', (tester) async {
      await tester.pumpWidget(componentHost(const Spinner()));
      expect(tester.getSize(find.byType(Spinner)), const Size.square(16));
      final ring = painter(tester);
      expect(ring.trackColor, FermanColorTokens.light.borderDefault);
      expect(ring.arcColor, FermanColorTokens.light.accent);
      expect(ring.strokeWidth, 2);
    });

    testWidgets('the stroke follows the size', (tester) async {
      expect(Spinner.strokeWidthFor(12), 1.5);
      expect(Spinner.strokeWidthFor(16), 2);
      expect(Spinner.strokeWidthFor(31), 2);
      expect(Spinner.strokeWidthFor(32), 3);
      await tester.pumpWidget(componentHost(const Spinner(size: 12)));
      expect(painter(tester).strokeWidth, 1.5);
      expect(tester.getSize(find.byType(Spinner)), const Size.square(12));
    });

    testWidgets('on accent: translucent white ring, white quarter', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const Spinner(onAccent: true)));
      expect(painter(tester).trackColor, Spinner.onAccentTrackColor);
      expect(painter(tester).arcColor, Spinner.onAccentArcColor);
    });

    testWidgets('dark theme takes the dark tokens', (tester) async {
      await tester.pumpWidget(
        componentHost(const Spinner(), brightness: Brightness.dark),
      );
      expect(painter(tester).trackColor, FermanColorTokens.dark.borderDefault);
      expect(painter(tester).arcColor, FermanColorTokens.dark.accent);
    });

    testWidgets('turns once every 0.8 s', (tester) async {
      await tester.pumpWidget(componentHost(const Spinner()));
      expect(turns(tester), 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(turns(tester), closeTo(0.25, 0.001));
      await tester.pump(const Duration(milliseconds: 600));
      expect(turns(tester), closeTo(0, 0.001));
    });

    testWidgets('keeps turning under reduced motion (decision 12)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const Spinner(), disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(turns(tester), closeTo(0.5, 0.001));
    });

    testWidgets('a labelled loading indicator in a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(const Spinner(semanticLabel: 'Opening')),
      );
      final node = tester.getSemantics(find.byType(CustomPaint).last);
      expect(node, isSemantics(label: 'Opening', isLiveRegion: true));
      expect(node.getSemanticsData().role, SemanticsRole.loadingSpinner);
      handle.dispose();
    });

    testWidgets('without a label it is decorative', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(const Spinner()));
      expect(
        find.descendant(
          of: find.byType(Spinner),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Spinner),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
      handle.dispose();
    });
  });
}
