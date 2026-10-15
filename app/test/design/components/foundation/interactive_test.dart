import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  late Set<WidgetState> states;

  Widget control({
    VoidCallback? onPressed,
    bool disabled = false,
    String? disabledReason,
    String? tooltip,
    bool selected = false,
    bool? toggled,
    FocusNode? focusNode,
  }) => FermanInteractive(
    onPressed: onPressed,
    disabled: disabled,
    disabledReason: disabledReason,
    tooltip: tooltip,
    selected: selected,
    toggled: toggled,
    focusNode: focusNode,
    semanticLabel: 'Rotate',
    builder: (context, value, child) {
      states = value;
      return const SizedBox(width: 40, height: 24, key: Key('control'));
    },
  );

  final controlFinder = find.byKey(const Key('control'));

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('FermanInteractive', () {
    testWidgets('a tap activates an enabled control', (tester) async {
      var taps = 0;
      await tester.pumpWidget(componentHost(control(onPressed: () => taps++)));
      await tester.tap(controlFinder);
      expect(taps, 1);
    });

    testWidgets('pressed while held, hovered while the pointer is over', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(control(onPressed: () {})));
      expect(states, isEmpty);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(controlFinder));
      await tester.pump();
      expect(states, {WidgetState.hovered});
      final press = await tester.startGesture(tester.getCenter(controlFinder));
      await tester.pump();
      expect(states, contains(WidgetState.pressed));
      await press.up();
      await tester.pump();
      expect(states, isNot(contains(WidgetState.pressed)));
    });

    testWidgets('Enter and Space activate the focused control', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(control(onPressed: () => taps++, focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(states, contains(WidgetState.focused));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 2);
    });

    testWidgets('focus-visible only with the keyboard highlight', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(control(onPressed: () {}, focusNode: node)),
      );
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(states, isNot(contains(WidgetState.focused)));
    });

    testWidgets('disabled: no activation, no hover, not focusable', (
      tester,
    ) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          control(onPressed: () => taps++, disabled: true, focusNode: node),
        ),
      );
      expect(states, {WidgetState.disabled});
      await tester.tap(controlFinder, warnIfMissed: false);
      expect(taps, 0);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
    });

    testWidgets('a null onPressed disables the control', (tester) async {
      await tester.pumpWidget(componentHost(control()));
      expect(states, {WidgetState.disabled});
    });

    testWidgets('disabled with a reason: focusable, reason as tooltip and '
        'hint, activation does nothing', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => control(
              onPressed: () => taps++,
              disabled: true,
              disabledReason: futureVersionReason(context),
              tooltip: 'Rotate page',
              focusNode: node,
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(states, containsAll({WidgetState.disabled, WidgetState.focused}));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 0);

      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(find.text('Rotate page'), findsNothing);
      expect(
        tester.getSemantics(controlFinder),
        matchesSemantics(
          label: 'Rotate',
          hint: 'Available in a future version',
          tooltip: 'Available in a future version',
          isButton: true,
          hasEnabledState: true,
          isFocusable: true,
          isFocused: true,
          // Still focusable, so screen readers can move to it and read why.
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('the reason is localized', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => control(
              disabled: true,
              disabledReason: futureVersionReason(context),
            ),
          ),
          locale: const Locale('tr'),
        ),
      );
      final interactive = tester.widget<FermanInteractive>(
        find.byType(FermanInteractive),
      );
      expect(interactive.disabledReason, 'Gelecek bir sürümde sunulacak');
    });

    testWidgets('an enabled control shows its tooltip on hover', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(control(onPressed: () {}, tooltip: 'Rotate page')),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(controlFinder));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsOneWidget);
    });

    testWidgets('selected and toggled reach the states and semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(control(onPressed: () {}, selected: true, toggled: true)),
      );
      expect(states, {WidgetState.selected});
      expect(
        tester.getSemantics(controlFinder),
        matchesSemantics(
          label: 'Rotate',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasSelectedState: true,
          isSelected: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('adds the forced states', (tester) async {
      await tester.pumpWidget(
        componentHost(
          control(onPressed: () {}),
          forcedStates: const {WidgetState.hovered, WidgetState.focused},
        ),
      );
      expect(states, {WidgetState.hovered, WidgetState.focused});
    });
  });
}
