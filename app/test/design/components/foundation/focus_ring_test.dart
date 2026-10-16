import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const box = SizedBox(width: 40, height: 20, key: Key('box'));

  BoxDecoration decorationOf(WidgetTester tester) {
    final decorated = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(box.key!),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return decorated.decoration as BoxDecoration;
  }

  group('FocusRing', () {
    testWidgets('draws nothing while hidden, with the same widget tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const FocusRing(visible: false, child: box)),
      );
      final hidden = decorationOf(tester);
      expect(hidden.boxShadow, isNull);
      expect(hidden.border, isNull);
      final element = tester.element(find.byKey(box.key!));

      await tester.pumpWidget(
        componentHost(const FocusRing(visible: true, child: box)),
      );
      // The child keeps its element: showing the ring rebuilds nothing.
      expect(tester.element(find.byKey(box.key!)), same(element));
    });

    testWidgets('outer: the --focus-ring shadows behind the control', (
      tester,
    ) async {
      const radius = BorderRadius.all(Radius.circular(4));
      await tester.pumpWidget(
        componentHost(
          const FocusRing(visible: true, borderRadius: radius, child: box),
        ),
      );
      final decoration = decorationOf(tester);
      expect(decoration.boxShadow, FermanFocusTokens.light.focusRing);
      expect(decoration.borderRadius, radius);
      final decorated = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byKey(box.key!),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(decorated.position, DecorationPosition.background);
    });

    testWidgets('outer follows the dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const FocusRing(visible: true, child: box),
          brightness: Brightness.dark,
        ),
      );
      expect(decorationOf(tester).boxShadow, FermanFocusTokens.dark.focusRing);
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
      final decorated = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byKey(box.key!),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(decorated.position, DecorationPosition.foreground);
      final border = (decorated.decoration as BoxDecoration).border! as Border;
      expect(border.top, FermanFocusTokens.light.focusRingInset);
    });

    testWidgets('field: 1 px of the focus colour', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const FocusRing(
            visible: true,
            style: FocusRingStyle.field,
            child: box,
          ),
        ),
      );
      final shadows = decorationOf(tester).boxShadow!;
      expect(shadows, hasLength(1));
      expect(shadows.single.spreadRadius, 1);
      expect(shadows.single.color, FermanColorTokens.light.borderFocus);
    });

    testWidgets('never changes the control size', (tester) async {
      await tester.pumpWidget(
        componentHost(const FocusRing(visible: true, child: box)),
      );
      expect(tester.getSize(find.byType(FocusRing)), const Size(40, 20));
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
