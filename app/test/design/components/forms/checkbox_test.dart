import 'dart:ui' show CheckedState;

import 'package:ferman/design/components/forms/check_row.dart';
import 'package:ferman/design/components/forms/checkbox.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import '../keyboard_reach.dart';

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;

  BoxDecoration boxOf(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(Checkbox),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;

  Color borderOf(WidgetTester tester) =>
      (boxOf(tester).border! as Border).top.color;

  // The app's own shortcuts and actions (Enter → ActivateIntent), which
  // componentHost leaves out.
  Widget appKeys(Widget child) => Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(actions: WidgetsApp.defaultActions, child: child),
  );

  Widget checkbox({
    bool checked = false,
    bool indeterminate = false,
    ValueChanged<bool>? onChanged,
    bool disabled = false,
    String? disabledReason,
    String? description,
    FocusNode? focusNode,
    String? label = 'Include annotations',
  }) => Checkbox(
    checked: checked,
    indeterminate: indeterminate,
    onChanged: onChanged,
    label: label,
    description: description,
    disabled: disabled,
    disabledReason: disabledReason,
    focusNode: focusNode,
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('Checkbox', () {
    testWidgets('unchecked: 16 px, 3 px corners, strong border, raised', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(checkbox(onChanged: (_) {})));
      final box = boxOf(tester);
      expect(box.color, light.surfaceRaised);
      expect(box.borderRadius, const BorderRadius.all(Radius.circular(3)));
      expect(borderOf(tester), light.borderStrong);
      expect(find.byType(Icon), findsNothing);
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(Checkbox),
            matching: find.byType(AnimatedContainer),
          ),
        ),
        const Size.square(16),
      );
    });

    testWidgets('checked: accent with a white 12 px check', (tester) async {
      await tester.pumpWidget(
        componentHost(checkbox(checked: true, onChanged: (_) {})),
      );
      expect(boxOf(tester).color, light.accent);
      final mark = tester.widget<Icon>(find.byType(Icon));
      expect(mark.name, IconName.check);
      expect(mark.size, 12);
      expect(mark.strokeWidth, 2.75);
      expect(mark.color, light.textOnAccent);
    });

    testWidgets('indeterminate: accent with a minus', (tester) async {
      await tester.pumpWidget(
        componentHost(checkbox(indeterminate: true, onChanged: (_) {})),
      );
      expect(boxOf(tester).color, light.accent);
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.minus);
    });

    testWidgets('a tap toggles; indeterminate reports true', (tester) async {
      final values = <bool>[];
      await tester.pumpWidget(componentHost(checkbox(onChanged: values.add)));
      await tester.tap(find.text('Include annotations'));
      await tester.pumpWidget(
        componentHost(checkbox(checked: true, onChanged: values.add)),
      );
      await tester.tap(find.text('Include annotations'));
      await tester.pumpWidget(
        componentHost(checkbox(indeterminate: true, onChanged: values.add)),
      );
      await tester.tap(find.byType(Checkbox));
      expect(values, [true, false, true]);
    });

    testWidgets('Space toggles; keyboard focus shows the outer ring', (
      tester,
    ) async {
      final values = <bool>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(checkbox(onChanged: values.add, focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, [true]);
    });

    testWidgets('Tab reaches the checkbox, and Space then toggles; a plain '
        'disabled checkbox is skipped', (tester) async {
      final values = <bool>[];
      await tester.pumpWidget(
        componentHost(afterLeadingTabStop(checkbox(onChanged: values.add))),
      );
      await expectTabReaches(tester, find.byType(Checkbox));
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, [true]);
      await tester.pumpWidget(
        componentHost(
          KeyedSubtree(
            key: const ValueKey('disabled'),
            child: afterLeadingTabStop(
              checkbox(onChanged: values.add, disabled: true),
            ),
          ),
        ),
      );
      await expectTabSkips(tester, find.byType(Checkbox));
    });

    testWidgets('Enter does not toggle (Space only)', (tester) async {
      final values = <bool>[];
      var outer = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        appKeys(
          componentHost(
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () => outer++,
              },
              child: checkbox(onChanged: values.add, focusNode: node),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      expect(values, isEmpty);
      expect(outer, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, [true]);
    });

    testWidgets('the row: box 1 px down, 8 px before the text, the '
        'description 2 px under the label', (tester) async {
      await tester.pumpWidget(
        componentHost(
          checkbox(onChanged: (_) {}, description: 'Comments and highlights'),
        ),
      );
      final row = tester.getRect(find.byType(CheckRow));
      final box = tester.getRect(
        find.descendant(
          of: find.byType(Checkbox),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final label = tester.getRect(find.text('Include annotations'));
      final description = tester.getRect(find.text('Comments and highlights'));
      expect(box.top - row.top, CheckRow.boxTopMargin);
      expect(label.left - box.right, 8);
      expect(description.top - label.bottom, CheckRow.textGap);
      // Description only: 8 px after the box, which stays 1 px down.
      await tester.pumpWidget(
        componentHost(
          checkbox(
            onChanged: (_) {},
            label: null,
            description: 'Comments and highlights',
          ),
        ),
      );
      final onlyRow = tester.getRect(find.byType(CheckRow));
      final onlyBox = tester.getRect(
        find.descendant(
          of: find.byType(Checkbox),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final onlyDescription = tester.getRect(
        find.text('Comments and highlights'),
      );
      expect(onlyBox.top - onlyRow.top, CheckRow.boxTopMargin);
      expect(onlyDescription.left - onlyBox.right, 8);
      expect(onlyDescription.top, onlyRow.top);
    });

    testWidgets('hover turns the border paper-500, even when checked', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(checkbox(checked: true, onChanged: (_) {})),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(Checkbox)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), FermanTheme.light.ramps.paper500);
    });

    testWidgets('disabled: sunken, subtle border, disabled label, no '
        'hover (G75), no focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          checkbox(disabled: true, onChanged: (_) {}, focusNode: node),
        ),
      );
      expect(boxOf(tester).color, light.surfaceSunken);
      expect(borderOf(tester), light.borderSubtle);
      expect(
        tester.widget<Text>(find.text('Include annotations')).style!.color,
        light.textDisabled,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(Checkbox)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderSubtle);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
    });

    testWidgets('disabled and indeterminate: the strong grey of checked', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          checkbox(indeterminate: true, disabled: true, onChanged: (_) {}),
        ),
      );
      expect(boxOf(tester).color, light.borderStrong);
      expect(borderOf(tester), light.borderStrong);
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.minus);
    });

    testWidgets('disabled and checked: strong grey', (tester) async {
      await tester.pumpWidget(
        componentHost(
          checkbox(checked: true, disabled: true, onChanged: (_) {}),
        ),
      );
      expect(boxOf(tester).color, light.borderStrong);
      expect(borderOf(tester), light.borderStrong);
    });

    testWidgets('disabled with a reason: focusable, no toggle, reason as '
        'hint', (tester) async {
      final handle = tester.ensureSemantics();
      final values = <bool>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          checkbox(
            onChanged: values.add,
            disabled: true,
            disabledReason: 'Available in a future version',
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Include annotations')),
        isSemantics(
          label: 'Include annotations',
          hint: 'Available in a future version',
          hasCheckedState: true,
          isChecked: false,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('semantics: checked, mixed, description as hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          checkbox(
            checked: true,
            onChanged: (_) {},
            description: 'Comments and highlights',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(Checkbox)),
        isSemantics(
          label: 'Include annotations',
          hint: 'Comments and highlights',
          hasCheckedState: true,
          isChecked: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.pumpWidget(
        componentHost(checkbox(indeterminate: true, onChanged: (_) {})),
      );
      final data = tester
          .getSemantics(find.byType(Checkbox))
          .getSemanticsData();
      expect(data.flagsCollection.isChecked, CheckedState.mixed);
      handle.dispose();
    });

    testWidgets('right to left: the box on the right', (tester) async {
      await tester.pumpWidget(
        componentHost(
          checkbox(onChanged: (_) {}),
          textDirection: TextDirection.rtl,
        ),
      );
      final box = tester.getRect(
        find.descendant(
          of: find.byType(Checkbox),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(
        tester.getTopRight(find.text('Include annotations')).dx,
        box.left - 8,
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          checkbox(checked: true, onChanged: (_) {}),
          brightness: Brightness.dark,
        ),
      );
      expect(boxOf(tester).color, dark.accent);
    });
  });
}
