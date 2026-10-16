import 'package:ferman/design/components/forms/radio.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

enum _Page { paper, dim, invert }

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;
  final ramps = FermanTheme.light.ramps;

  BoxDecoration circleOf(WidgetTester tester, String label) {
    final row = find.ancestor(
      of: find.text(label),
      matching: find.byType(Radio<_Page>),
    );
    final container = tester.widget<AnimatedContainer>(
      find.descendant(of: row, matching: find.byType(AnimatedContainer)),
    );
    return container.decoration! as BoxDecoration;
  }

  Color borderOf(WidgetTester tester, String label) =>
      (circleOf(tester, label).border! as Border).top.color;

  Widget radio(
    _Page value, {
    _Page? groupValue,
    ValueChanged<_Page>? onChanged,
    bool disabled = false,
    String? disabledReason,
    String? description,
    FocusNode? focusNode,
  }) => Radio<_Page>(
    value: value,
    groupValue: groupValue,
    onChanged: onChanged ?? (_) {},
    label: value.name,
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

  group('Radio', () {
    testWidgets('unchecked: 16 px circle, strong border, raised fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(radio(_Page.dim, groupValue: _Page.paper)),
      );
      final circle = circleOf(tester, 'dim');
      expect(circle.shape, BoxShape.circle);
      expect(circle.color, light.surfaceRaised);
      expect(borderOf(tester, 'dim'), light.borderStrong);
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(Radio<_Page>),
            matching: find.byType(AnimatedContainer),
          ),
        ),
        const Size.square(16),
      );
    });

    testWidgets('checked: accent with a 6 px raised centre', (tester) async {
      await tester.pumpWidget(
        componentHost(radio(_Page.paper, groupValue: _Page.paper)),
      );
      final circle = circleOf(tester, 'paper');
      expect(circle.color, light.accent);
      expect(borderOf(tester, 'paper'), light.accent);
      // AnimatedContainer builds a Container of its own; the dot is inside.
      final dot = find
          .descendant(
            of: find.byType(AnimatedContainer),
            matching: find.byType(Container),
          )
          .last;
      expect(tester.getSize(dot), const Size.square(Radio.dotSize));
      expect(
        (tester.widget<Container>(dot).decoration! as BoxDecoration).color,
        light.surfaceRaised,
      );
    });

    testWidgets('label in body text, description in tertiary caption, '
        '8 px after the circle', (tester) async {
      await tester.pumpWidget(
        componentHost(
          radio(
            _Page.paper,
            groupValue: _Page.paper,
            description: 'Pages look exactly as printed.',
          ),
        ),
      );
      final label = tester.widget<Text>(find.text('paper'));
      expect(label.style!.color, light.textPrimary);
      expect(label.style!.fontSize, 13);
      final desc = tester.widget<Text>(
        find.text('Pages look exactly as printed.'),
      );
      expect(desc.style!.color, light.textTertiary);
      expect(desc.style!.fontSize, 12);
      final circle = tester.getRect(
        find.descendant(
          of: find.byType(Radio<_Page>),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(tester.getTopLeft(find.text('paper')).dx, circle.right + 8);
    });

    testWidgets('a tap on the row selects it', (tester) async {
      final selected = <_Page>[];
      await tester.pumpWidget(
        componentHost(
          radio(_Page.dim, groupValue: _Page.paper, onChanged: selected.add),
        ),
      );
      await tester.tap(find.text('dim'));
      expect(selected, [_Page.dim]);
    });

    testWidgets('a checked radio does not report again', (tester) async {
      final selected = <_Page>[];
      await tester.pumpWidget(
        componentHost(
          radio(_Page.dim, groupValue: _Page.dim, onChanged: selected.add),
        ),
      );
      await tester.tap(find.text('dim'));
      expect(selected, isEmpty);
    });

    testWidgets('hover turns an unchecked border paper-500', (tester) async {
      await tester.pumpWidget(
        componentHost(
          radio(_Page.dim, groupValue: _Page.paper, onChanged: (_) {}),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('dim')));
      await tester.pumpAndSettle();
      expect(borderOf(tester, 'dim'), ramps.paper500);
    });

    testWidgets('forced hover in dark: soot-500', (tester) async {
      await tester.pumpWidget(
        componentHost(
          radio(_Page.dim, groupValue: _Page.paper, onChanged: (_) {}),
          brightness: Brightness.dark,
          forcedStates: {WidgetState.hovered},
        ),
      );
      await tester.pumpAndSettle();
      expect(borderOf(tester, 'dim'), FermanTheme.dark.ramps.soot500);
    });

    testWidgets('Space selects; keyboard focus shows the outer ring', (
      tester,
    ) async {
      final selected = <_Page>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          radio(
            _Page.dim,
            groupValue: _Page.paper,
            onChanged: selected.add,
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(selected, [_Page.dim]);
    });

    testWidgets('in a RadioGroup: arrow keys move and select, wrapping', (
      tester,
    ) async {
      var value = _Page.paper;
      final nodes = [for (final _ in _Page.values) FocusNode()];
      for (final node in nodes) {
        addTearDown(node.dispose);
      }
      await tester.pumpWidget(
        componentHost(
          // The app's WidgetsApp maps VoidCallbackIntent, which the group's
          // shortcuts use.
          Actions(
            actions: {VoidCallbackIntent: VoidCallbackAction()},
            child: StatefulBuilder(
              builder: (context, setState) => RadioGroup<_Page>(
                groupValue: value,
                onChanged: (next) => setState(() => value = next ?? value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final page in _Page.values)
                      Radio<_Page>(
                        value: page,
                        label: page.name,
                        focusNode: nodes[page.index],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(circleOf(tester, 'paper').color, light.accent);
      nodes[0].requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(value, _Page.dim);
      expect(nodes[1].hasFocus, isTrue);
      expect(circleOf(tester, 'dim').color, light.accent);
      expect(circleOf(tester, 'paper').color, light.surfaceRaised);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(value, _Page.invert);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(value, _Page.paper);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(value, _Page.invert);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(value, _Page.dim);
    });

    testWidgets('in a RadioGroup: arrows skip a radio disabled with a '
        'reason, which stays focusable', (tester) async {
      var value = _Page.paper;
      final nodes = [for (final _ in _Page.values) FocusNode()];
      for (final node in nodes) {
        addTearDown(node.dispose);
      }
      await tester.pumpWidget(
        componentHost(
          // The app's WidgetsApp maps VoidCallbackIntent, which the group's
          // shortcuts use.
          Actions(
            actions: {VoidCallbackIntent: VoidCallbackAction()},
            child: StatefulBuilder(
              builder: (context, setState) => RadioGroup<_Page>(
                groupValue: value,
                onChanged: (next) => setState(() => value = next ?? value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final page in _Page.values)
                      Radio<_Page>(
                        value: page,
                        label: page.name,
                        disabled: page == _Page.dim,
                        disabledReason: page == _Page.dim
                            ? 'Available in a future version'
                            : null,
                        focusNode: nodes[page.index],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      nodes[0].requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(value, _Page.invert);
      nodes[1].requestFocus();
      await tester.pumpAndSettle();
      expect(nodes[1].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(value, _Page.invert);
    });

    testWidgets('disabled: sunken circle, subtle border, disabled label, '
        'not focusable', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          radio(
            _Page.dim,
            groupValue: _Page.paper,
            onChanged: (_) {},
            disabled: true,
            focusNode: node,
          ),
        ),
      );
      expect(circleOf(tester, 'dim').color, light.surfaceSunken);
      expect(borderOf(tester, 'dim'), light.borderSubtle);
      expect(
        tester.widget<Text>(find.text('dim')).style!.color,
        light.textDisabled,
      );
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
    });

    testWidgets('disabled and checked: the strong grey fill', (tester) async {
      await tester.pumpWidget(
        componentHost(
          radio(
            _Page.dim,
            groupValue: _Page.dim,
            onChanged: (_) {},
            disabled: true,
          ),
        ),
      );
      expect(circleOf(tester, 'dim').color, light.borderStrong);
    });

    testWidgets('disabled with a reason: focusable, reason as tooltip and '
        'hint, cannot be selected', (tester) async {
      final handle = tester.ensureSemantics();
      final selected = <_Page>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          radio(
            _Page.dim,
            groupValue: _Page.paper,
            onChanged: selected.add,
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
      await tester.tap(find.text('dim'));
      expect(selected, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('dim')),
        isSemantics(
          label: 'dim',
          hint: 'Available in a future version',
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('semantics: checked radio in a group, description as hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          radio(
            _Page.paper,
            groupValue: _Page.paper,
            onChanged: (_) {},
            description: 'Pages look exactly as printed.',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(Radio<_Page>)),
        isSemantics(
          label: 'paper',
          hint: 'Pages look exactly as printed.',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('right to left: the circle on the right', (tester) async {
      await tester.pumpWidget(
        componentHost(
          radio(_Page.paper, groupValue: _Page.paper, onChanged: (_) {}),
          textDirection: TextDirection.rtl,
        ),
      );
      final circle = tester.getRect(
        find.descendant(
          of: find.byType(Radio<_Page>),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(tester.getTopRight(find.text('paper')).dx, circle.left - 8);
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          radio(_Page.paper, groupValue: _Page.paper, onChanged: (_) {}),
          brightness: Brightness.dark,
        ),
      );
      expect(circleOf(tester, 'paper').color, dark.accent);
    });
  });
}
