import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const box = SizedBox(width: 40, height: 20, key: Key('box'));
  const radius = BorderRadius.all(Radius.circular(4));
  final ringPaint = find
      .ancestor(of: find.byKey(box.key!), matching: find.byType(CustomPaint))
      .first;

  FocusRingPainter painterOf(WidgetTester tester) =>
      tester.widget<CustomPaint>(ringPaint).painter! as FocusRingPainter;

  DecoratedBox insetBoxOf(WidgetTester tester) => tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.byKey(box.key!), matching: find.byType(DecoratedBox))
        .first,
  );

  group('FocusRing', () {
    testWidgets('draws nothing while hidden, with the same widget tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const FocusRing(visible: false, child: box)),
      );
      expect(painterOf(tester).progress, 0);
      expect(ringPaint, isNot(paints..drrect()));
      final element = tester.element(find.byKey(box.key!));

      await tester.pumpWidget(
        componentHost(const FocusRing(visible: true, child: box)),
      );
      // The child keeps its element: showing the ring rebuilds nothing.
      expect(tester.element(find.byKey(box.key!)), same(element));
      expect(painterOf(tester).progress, 1);
    });

    testWidgets('outer: the --focus-ring layers as bands outside the '
        'control, the inside left unpainted', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const FocusRing(visible: true, borderRadius: radius, child: box),
        ),
      );
      final painter = painterOf(tester);
      expect(painter.layers, FermanFocusTokens.light.focusRing);
      expect(painter.borderRadius, radius);
      final inner = radius.toRRect(const Rect.fromLTWH(0, 0, 40, 20));
      // Each band runs from the control's edge out to its spread, the
      // corners growing with it: the 4 px focus colour first, the 2 px gap
      // in the raised surface colour on top. Nothing fills the inside.
      expect(
        ringPaint,
        paints
          ..drrect(
            outer: RRect.fromLTRBR(-4, -4, 44, 24, const Radius.circular(8)),
            inner: inner,
            color: FermanColorTokens.light.borderFocus,
          )
          ..drrect(
            outer: RRect.fromLTRBR(-2, -2, 42, 22, const Radius.circular(6)),
            inner: inner,
            color: FermanColorTokens.light.surfaceRaised,
          ),
      );
      expect(ringPaint, isNot(paints..rrect(rrect: inner)));
      expect(ringPaint, isNot(paints..rect()));
    });

    testWidgets('outer follows the dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const FocusRing(visible: true, child: box),
          brightness: Brightness.dark,
        ),
      );
      expect(painterOf(tester).layers, FermanFocusTokens.dark.focusRing);
      expect(
        ringPaint,
        paints
          ..drrect(color: FermanColorTokens.dark.borderFocus)
          ..drrect(color: FermanColorTokens.dark.surfaceRaised),
      );
    });

    testWidgets('square corners stay square, small radii grow less than the '
        'spread (CSS spread shadows)', (tester) async {
      expect(FocusRingPainter.spreadRadius(0, 4), 0);
      expect(FocusRingPainter.spreadRadius(4, 4), 8);
      expect(FocusRingPainter.spreadRadius(4, 2), 6);
      // r / spread = 0.5: 2 + 4 × (1 − 0.125).
      expect(FocusRingPainter.spreadRadius(2, 4), 5.5);
      expect(FocusRingPainter.spreadRadius(3, 0), 3);
      await tester.pumpWidget(
        componentHost(const FocusRing(visible: true, child: box)),
      );
      expect(
        ringPaint,
        paints..drrect(
          outer: RRect.fromLTRBR(-4, -4, 44, 24, Radius.zero),
          inner: RRect.fromLTRBR(0, 0, 40, 20, Radius.zero),
        ),
      );
    });

    testWidgets('right to left resolves directional radii', (tester) async {
      const directional = BorderRadiusDirectional.only(
        topStart: Radius.circular(4),
      );
      await tester.pumpWidget(
        componentHost(
          const FocusRing(visible: true, borderRadius: directional, child: box),
          textDirection: TextDirection.rtl,
        ),
      );
      final resolved = painterOf(tester).borderRadius;
      expect(resolved.topRight, const Radius.circular(4));
      expect(resolved.topLeft, Radius.zero);
    });

    testWidgets('with a duration the ring fades and grows in and out', (
      tester,
    ) async {
      const duration = Duration(milliseconds: 120);
      await tester.pumpWidget(
        componentHost(
          const FocusRing(visible: false, duration: duration, child: box),
        ),
      );
      await tester.pumpWidget(
        componentHost(
          const FocusRing(visible: true, duration: duration, child: box),
        ),
      );
      expect(painterOf(tester).progress, 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(painterOf(tester).progress, closeTo(0.5, 0.01));
      final focus = FermanColorTokens.light.borderFocus;
      expect(
        ringPaint,
        paints..drrect(
          outer: RRect.fromLTRBR(-2, -2, 42, 22, Radius.zero),
          color: focus.withValues(alpha: focus.a * painterOf(tester).progress),
        ),
      );
      await tester.pumpAndSettle();
      expect(painterOf(tester).progress, 1);
      await tester.pumpWidget(
        componentHost(
          const FocusRing(visible: false, duration: duration, child: box),
        ),
      );
      await tester.pumpAndSettle();
      expect(painterOf(tester).progress, 0);
    });

    testWidgets('without a duration the ring switches at once', (tester) async {
      await tester.pumpWidget(
        componentHost(const FocusRing(visible: false, child: box)),
      );
      await tester.pumpWidget(
        componentHost(const FocusRing(visible: true, child: box)),
      );
      expect(painterOf(tester).progress, 1);
    });

    testWidgets('inset: a 2 px focus border painted over the control', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const FocusRing(
            visible: true,
            style: FocusRingStyle.inset,
            child: box,
          ),
        ),
      );
      final decorated = insetBoxOf(tester);
      expect(decorated.position, DecorationPosition.foreground);
      final border = (decorated.decoration as BoxDecoration).border! as Border;
      expect(border.top, FermanFocusTokens.light.focusRingInset);

      await tester.pumpWidget(
        componentHost(
          const FocusRing(
            visible: false,
            style: FocusRingStyle.inset,
            child: box,
          ),
        ),
      );
      expect((insetBoxOf(tester).decoration as BoxDecoration).border, isNull);
    });

    testWidgets('field: a 1 px band of the focus colour', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const FocusRing(
            visible: true,
            style: FocusRingStyle.field,
            borderRadius: radius,
            child: box,
          ),
        ),
      );
      final layers = painterOf(tester).layers;
      expect(layers, hasLength(1));
      expect(layers.single.spreadRadius, 1);
      expect(layers.single.color, FermanColorTokens.light.borderFocus);
      expect(
        ringPaint,
        paints..drrect(
          outer: RRect.fromLTRBR(-1, -1, 41, 21, const Radius.circular(5)),
          inner: radius.toRRect(const Rect.fromLTWH(0, 0, 40, 20)),
          color: FermanColorTokens.light.borderFocus,
        ),
      );
    });

    testWidgets('never changes the control size', (tester) async {
      await tester.pumpWidget(
        componentHost(const FocusRing(visible: true, child: box)),
      );
      expect(tester.getSize(find.byType(FocusRing)), const Size(40, 20));
    });

    test('the painter repaints only when what it draws changes', () {
      final layers = FermanFocusTokens.light.focusRing;
      final a = FocusRingPainter(layers: layers, borderRadius: radius);
      expect(
        a.shouldRepaint(
          FocusRingPainter(layers: [...layers], borderRadius: radius),
        ),
        isFalse,
      );
      expect(
        a.shouldRepaint(
          FocusRingPainter(layers: layers, borderRadius: radius, progress: 0.5),
        ),
        isTrue,
      );
      expect(
        a.shouldRepaint(
          FocusRingPainter(
            layers: FermanFocusTokens.dark.focusRing,
            borderRadius: radius,
          ),
        ),
        isTrue,
      );
    });
  });

  group('FermanForcedStates', () {
    testWidgets('is empty without a provider and gives the forced states', (
      tester,
    ) async {
      late Set<WidgetState> outside;
      late Set<WidgetState> inside;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  outside = FermanForcedStates.of(context);
                  return const SizedBox();
                },
              ),
              FermanForcedStates(
                states: const {WidgetState.hovered},
                child: Builder(
                  builder: (context) {
                    inside = FermanForcedStates.of(context);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(outside, isEmpty);
      expect(inside, {WidgetState.hovered});
    });

    test('notifies only when the states change', () {
      const a = FermanForcedStates(
        states: {WidgetState.hovered},
        child: SizedBox(),
      );
      expect(
        a.updateShouldNotify(
          const FermanForcedStates(
            states: {WidgetState.hovered},
            child: SizedBox(),
          ),
        ),
        isFalse,
      );
      expect(
        a.updateShouldNotify(
          const FermanForcedStates(
            states: {WidgetState.focused},
            child: SizedBox(),
          ),
        ),
        isTrue,
      );
    });
  });
}
