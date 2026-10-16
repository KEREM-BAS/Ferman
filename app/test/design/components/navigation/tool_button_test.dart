import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/navigation/tool_button.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import 'navigation_test_helpers.dart';

final Finder _box = find.descendant(
  of: find.byType(ToolButton),
  matching: find.byType(AnimatedContainer),
);

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(_box).decoration! as BoxDecoration;

Icon _icon(WidgetTester tester, IconName name) => tester.widget<Icon>(
  find.byWidgetPredicate((widget) => widget is Icon && widget.name == name),
);

Future<void> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('ToolButton', () {
    testWidgets('inline: 30 px, 8 px padding, 16 px icon, body text', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          ToolButton(icon: IconName.hand, label: 'Hand', onPressed: () {}),
        ),
      );
      final theme = FermanTheme.light;
      expect(tester.getSize(_box).height, 30);
      final decoration = _decoration(tester);
      expect(decoration.color, transparent);
      expect(decoration.borderRadius, BorderRadius.circular(4));
      expect(decoration.border, Border.all(color: transparent));
      expect(_icon(tester, IconName.hand).size, 16);
      expect(_icon(tester, IconName.hand).color, theme.colors.iconPrimary);
      expect(textColor(tester, 'Hand'), theme.colors.textPrimary);
      expect(textStyle(tester, 'Hand').fontSize, 13);
      expect(textStyle(tester, 'Hand').fontWeight, FontWeight.w400);
      // 1 px border + 8 px padding + 16 px icon + 6 px gap.
      final box = tester.getRect(_box);
      final icon = tester.getRect(find.byType(Icon));
      expect(icon.left - box.left, 9);
      expect(tester.getRect(find.text('Hand')).left - icon.right, 6);
    });

    testWidgets('icon only: 30 × 30, label as tooltip with the shortcut and '
        'as the accessible name', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Hand',
            showLabel: false,
            shortcut: const ['H'],
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(_box), const Size(30, 30));
      expect(find.text('Hand'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Hand')),
        isSemantics(
          label: 'Hand',
          tooltip: 'Hand',
          isButton: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      await _hover(tester, _box);
      expect(find.text('Hand'), findsOneWidget);
      expect(find.byType(Kbd), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a labelled tool without a shortcut shows no tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          ToolButton(icon: IconName.hand, label: 'Split', onPressed: () {}),
        ),
      );
      await _hover(tester, _box);
      expect(find.text('Split'), findsOneWidget);
    });

    testWidgets('a labelled tool with a shortcut shows the label and key '
        'caps (G22)', (tester) async {
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Select',
            shortcut: const ['V'],
            onPressed: () {},
          ),
        ),
      );
      await _hover(tester, _box);
      expect(find.text('Select'), findsNWidgets(2));
      expect(find.text('V'), findsOneWidget);
    });

    testWidgets('stacked: 48 px tall, at least 56 wide, 20 px icon, small '
        'text', (tester) async {
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Hand',
            layout: ToolButtonLayout.stacked,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(_box).height, 48);
      expect(tester.getSize(_box).width, greaterThanOrEqualTo(56));
      expect(_icon(tester, IconName.hand).size, 20);
      final style = textStyle(tester, 'Hand');
      expect(style.fontSize, 11);
      expect(style.height, 14 / 11);
      expect(
        tester.getTopLeft(find.text('Hand')).dy,
        greaterThan(tester.getBottomLeft(find.byType(Icon)).dy),
      );
    });

    testWidgets('hover and pressed tint the surface', (tester) async {
      await tester.pumpWidget(
        componentHost(
          ToolButton(icon: IconName.hand, label: 'Hand', onPressed: () {}),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      final theme = FermanTheme.light;
      expect(_decoration(tester).color, theme.colors.surfaceHover);
      await tester.pumpWidget(
        componentHost(
          ToolButton(icon: IconName.hand, label: 'Hand', onPressed: () {}),
          forcedStates: const {WidgetState.hovered, WidgetState.pressed},
        ),
      );
      expect(_decoration(tester).color, theme.colors.surfacePressed);
    });

    testWidgets('toggled on: accent fill and text, toggled semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Hand',
            active: true,
            onPressed: () {},
          ),
        ),
      );
      final theme = FermanTheme.light;
      expect(_decoration(tester).color, theme.colors.accentSubtle);
      expect(textColor(tester, 'Hand'), theme.colors.textAccent);
      expect(_icon(tester, IconName.hand).color, theme.colors.textAccent);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Hand')),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Hand',
            active: true,
            onPressed: () {},
          ),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(_decoration(tester).color, theme.colors.accentSubtleHover);
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Hand',
            active: false,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Hand')),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      handle.dispose();
    });

    testWidgets('dark: the toggled fill follows the dark accent', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Hand',
            active: true,
            onPressed: () {},
          ),
          brightness: Brightness.dark,
        ),
      );
      final theme = FermanTheme.dark;
      expect(_decoration(tester).color, theme.colors.accentSubtle);
      expect(textColor(tester, 'Hand'), theme.colors.textAccent);
    });

    testWidgets('keyboard focus shows the outer ring; Enter and Space press', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Hand',
            onPressed: () => taps++,
          ),
        ),
      );
      await focusFirstTabStop(tester);
      final ring = tester.widget<FocusRing>(
        find.descendant(
          of: find.byType(ToolButton),
          matching: find.byType(FocusRing),
        ),
      );
      expect(ring.visible, isTrue);
      expect(ring.style, FocusRingStyle.outer);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.tap(_box);
      expect(taps, 3);
    });

    testWidgets('disabled: disabled colours, no tooltip, no Tab stop', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.hand,
            label: 'Hand',
            shortcut: const ['H'],
            disabled: true,
            onPressed: () => taps++,
          ),
        ),
      );
      final theme = FermanTheme.light;
      expect(textColor(tester, 'Hand'), theme.colors.textDisabled);
      expect(_icon(tester, IconName.hand).color, theme.colors.iconDisabled);
      expect(_decoration(tester).color, transparent);
      expect(tabStops, isEmpty);
      await tester.tap(_box, warnIfMissed: false);
      expect(taps, 0);
      await _hover(tester, _box);
      expect(find.text('Hand'), findsOneWidget);
    });

    testWidgets('disabled with a reason: focusable, the reason as tooltip '
        'and hint, activation does nothing', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => ToolButton(
              icon: IconName.link,
              label: 'Link',
              disabled: true,
              disabledReason: futureVersionReason(context),
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(tabStops, hasLength(1));
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 0);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Link')),
        isSemantics(
          label: 'Link',
          hint: 'Available in a future version',
          isEnabled: false,
          isFocusable: true,
          isFocused: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('menu: a 12 px caret at 70 % opacity; ArrowDown asks for '
        'the menu', (tester) async {
      var presses = 0;
      var menus = 0;
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.shapes,
            label: 'Shapes',
            hasMenu: true,
            onPressed: () => presses++,
            onMenuRequested: () => menus++,
          ),
        ),
      );
      final caret = _icon(tester, IconName.chevronDown);
      expect(caret.size, 12);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byWidget(caret), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 0.7);
      // 6 px gap, minus the caret's 2 px negative margin.
      expect(
        tester.getRect(find.byWidget(caret)).left -
            tester.getRect(find.text('Shapes')).right,
        4,
      );
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(menus, 1);
      expect(presses, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 1);
    });

    testWidgets('menu without onMenuRequested: ArrowDown presses', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.stamp,
            label: 'Stamp',
            hasMenu: true,
            onPressed: () => presses++,
          ),
        ),
      );
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(presses, 1);
    });

    testWidgets('swatch: a 14 × 3 bar 4 px above the bottom, centred', (
      tester,
    ) async {
      const yellow = Color(0xFFFFD400);
      await tester.pumpWidget(
        componentHost(
          ToolButton(
            icon: IconName.highlighter,
            label: 'Highlight',
            swatch: yellow,
            onPressed: () {},
          ),
        ),
      );
      final bar = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).color == yellow,
      );
      expect(tester.getSize(bar), const Size(14, 3));
      final box = tester.getRect(_box);
      final rect = tester.getRect(bar);
      // 1 px border + 4 px.
      expect(box.bottom - rect.bottom, 5);
      expect(rect.center.dx, closeTo(box.center.dx, 0.01));
    });

    testWidgets('right to left: the icon comes after the label visually', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          ToolButton(icon: IconName.hand, label: 'Hand', onPressed: () {}),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.byType(Icon)).dx,
        greaterThan(tester.getCenter(find.text('Hand')).dx),
      );
    });
  });
}
