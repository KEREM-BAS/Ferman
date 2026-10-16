import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/forms/select.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;

  const options = [
    SelectOption(value: 'scroll', label: 'Continuous scroll'),
    SelectOption(value: 'single', label: 'Single page'),
    SelectOption(value: 'two', label: 'Two pages', disabled: true),
    SelectOption(
      value: 'book',
      label: 'Book',
      disabled: true,
      disabledReason: 'Available in a future version',
    ),
    SelectOption(value: 'grid', label: 'Grid'),
  ];

  final long = [
    for (var i = 0; i < 20; i++) SelectOption(value: 'o$i', label: 'Option $i'),
  ];

  ScrollPosition listPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(PopoverSurface),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  Rect listViewport(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(PopoverSurface),
      matching: find.byType(Scrollable),
    ),
  );

  Rect rowRect(WidgetTester tester, String label) => tester.getRect(
    find
        .ancestor(of: find.text(label).last, matching: find.byType(Container))
        .first,
  );

  Color borderOf(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(find.byKey(FieldBox.boxKey));
    return ((box.decoration! as BoxDecoration).border! as Border).top.color;
  }

  Widget host(
    Widget child, {
    Brightness brightness = Brightness.light,
    TextDirection? textDirection,
    Set<WidgetState>? forcedStates,
  }) => TapRegionSurface(
    child: componentHost(
      // A hit-testable page behind the select, as the app has, so a click
      // outside reaches the tap-region surface.
      ColoredBox(
        color: const Color(0x00000000),
        child: SizedBox.expand(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(40),
              child: SizedBox(width: 220, child: child),
            ),
          ),
        ),
      ),
      brightness: brightness,
      textDirection: textDirection,
      forcedStates: forcedStates,
    ),
  );

  Widget select({
    String? value = 'scroll',
    ValueChanged<String>? onChanged,
    String? label = 'Page layout',
    FieldSize size = FieldSize.md,
    IconName? icon,
    bool disabled = false,
    String? disabledReason,
    String? semanticLabel,
    FocusNode? focusNode,
  }) => Select<String>(
    options: options,
    value: value,
    onChanged: onChanged ?? (_) {},
    label: label,
    size: size,
    icon: icon,
    disabled: disabled,
    disabledReason: disabledReason,
    semanticLabel: semanticLabel,
    focusNode: focusNode,
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(FieldBox.boxKey));
    await tester.pumpAndSettle();
  }

  Color? rowColor(WidgetTester tester, String label) {
    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text(label).last, matching: find.byType(Container))
          .first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('Select', () {
    testWidgets('shows the chosen label, the label above and a chevron', (
      tester,
    ) async {
      await tester.pumpWidget(host(select()));
      expect(find.text('Continuous scroll'), findsOneWidget);
      expect(find.text('Page layout'), findsOneWidget);
      final chevron = tester.widget<Icon>(find.byType(Icon));
      expect(chevron.name, IconName.chevronDown);
      expect(chevron.size, 14);
      expect(chevron.color, light.iconSecondary);
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 30);
      expect(borderOf(tester), light.borderDefault);
    });

    testWidgets('small with a 14 px leading icon', (tester) async {
      await tester.pumpWidget(
        host(select(size: FieldSize.sm, icon: IconName.languages)),
      );
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 26);
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.first.name, IconName.languages);
      expect(icons.first.size, 14);
      final text = tester.widget<Text>(find.text('Continuous scroll'));
      final style = DefaultTextStyle.of(
        tester.element(find.text('Continuous scroll')),
      ).style.merge(text.style);
      expect(style.fontSize, 12);
    });

    testWidgets('a click opens the list under the box, as wide as it', (
      tester,
    ) async {
      await tester.pumpWidget(host(select()));
      await open(tester);
      expect(find.byType(PopoverSurface), findsOneWidget);
      final box = tester.getRect(find.byKey(FieldBox.boxKey));
      final list = tester.getRect(find.byType(PopoverSurface));
      expect(list.top, box.bottom + Popover.gap);
      expect(list.left, box.left);
      expect(list.width, greaterThanOrEqualTo(box.width));
      expect(tester.getSize(find.text('Single page')).height, lessThan(28));
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Single page'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        Select.rowHeight,
      );
      expect(
        rowColor(tester, 'Continuous scroll'),
        light.surfaceSelectedStrong,
      );
      final check = tester
          .widgetList<Icon>(find.byType(Icon))
          .firstWhere((icon) => icon.name == IconName.check);
      // The Menu check colour: `.fm-menu__item svg` wins over the accent.
      expect(check.color, light.iconSecondary);
    });

    testWidgets('choosing an option reports it and closes the list', (
      tester,
    ) async {
      final chosen = <String>[];
      await tester.pumpWidget(host(select(onChanged: chosen.add)));
      await open(tester);
      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();
      expect(chosen, ['grid']);
      expect(find.byType(PopoverSurface), findsNothing);
    });

    testWidgets('disabled options cannot be chosen', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(host(select(onChanged: chosen.add)));
      await open(tester);
      await tester.tap(find.text('Two pages'));
      await tester.tap(find.text('Book'));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty);
      final text = tester.widget<Text>(find.text('Two pages'));
      expect(text.style!.color, light.textDisabled);
    });

    testWidgets('a click outside closes without a change', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(host(select(onChanged: chosen.add)));
      await open(tester);
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(chosen, isEmpty);
    });

    testWidgets('a second click on the box closes the list without a '
        'change', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(host(select(onChanged: chosen.add)));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await mouse.down(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      // The highlight follows the pointer onto Grid…
      await mouse.moveTo(tester.getCenter(find.text('Grid')));
      await tester.pump();
      expect(rowColor(tester, 'Grid'), light.surfaceSelectedStrong);
      // …but a click back on the box only closes the list.
      await mouse.moveTo(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await mouse.down(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(chosen, isEmpty);
      // The same after hovering an option disabled with a reason.
      await open(tester);
      await mouse.moveTo(tester.getCenter(find.text('Book')));
      await tester.pump();
      await tester.tap(find.byKey(FieldBox.boxKey));
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(chosen, isEmpty);
    });

    testWidgets('a click opens the list with focus on the box, so the keys '
        'work', (tester) async {
      final chosen = <String>[];
      final node = FocusNode();
      final other = FocusNode(debugLabel: 'other');
      addTearDown(node.dispose);
      addTearDown(other.dispose);
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Focus(focusNode: other, child: const SizedBox(height: 20)),
              select(onChanged: chosen.add, focusNode: node),
            ],
          ),
        ),
      );
      other.requestFocus();
      await tester.pump();
      await open(tester);
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['single']);
      expect(node.hasFocus, isTrue);
      // Escape after a click closes without a change, focus on the box.
      await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(chosen, ['single']);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('a long list opens scrolled to the chosen option', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Select<String>(
            options: long,
            value: 'o17',
            onChanged: (_) {},
            label: 'Language',
          ),
        ),
      );
      await open(tester);
      final viewport = listViewport(tester);
      final row = rowRect(tester, 'Option 17');
      expect(listPosition(tester).pixels, greaterThan(0));
      expect(row.top, greaterThanOrEqualTo(viewport.top));
      expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
    });

    testWidgets('the highlight scrolls the list only as far as it needs', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(
          Select<String>(
            options: long,
            value: 'o0',
            onChanged: (_) {},
            label: 'Language',
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // A row in view: no scroll.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(listPosition(tester).pixels, 0);
      // Twelve rows fit in the 340 px list (4 px padding, 28 px rows); the
      // thirteenth scrolls in just far enough to show at the bottom.
      for (var i = 1; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(rowColor(tester, 'Option 12'), light.surfaceSelectedStrong);
      expect(listPosition(tester).pixels, Select.rowHeight);
      expect(rowRect(tester, 'Option 12').bottom, listViewport(tester).bottom);
      // Back up to a row in view: no jump.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(listPosition(tester).pixels, Select.rowHeight);
    });

    testWidgets('keyboard: Enter opens, arrows move (skipping disabled, '
        'stopping on a reason), Enter chooses', (tester) async {
      final chosen = <String>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(select(onChanged: chosen.add, focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderFocus);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      expect(
        rowColor(tester, 'Continuous scroll'),
        light.surfaceSelectedStrong,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rowColor(tester, 'Single page'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      // The forced-open tooltip shows two frames after the highlight moves.
      await tester.pump();
      await tester.pump();
      // "Two pages" is skipped; "Book" has a reason, so the highlight stops
      // there and the reason shows.
      expect(rowColor(tester, 'Book'), light.surfaceSelectedStrong);
      expect(find.text('Available in a future version'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(chosen, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rowColor(tester, 'Grid'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['grid']);
      expect(find.byType(PopoverSurface), findsNothing);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('keyboard: Space and Alt+ArrowDown open; Escape closes '
        'without a change and keeps focus', (tester) async {
      final chosen = <String>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(select(onChanged: chosen.add, focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(chosen, isEmpty);
      expect(node.hasFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
    });

    testWidgets('keyboard: Home and End', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(host(select(value: 'single', focusNode: node)));
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(rowColor(tester, 'Grid'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(
        rowColor(tester, 'Continuous scroll'),
        light.surfaceSelectedStrong,
      );
    });

    testWidgets('hover highlights a row and the box border', (tester) async {
      await tester.pumpWidget(host(select()));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderStrong);
      await open(tester);
      await mouse.moveTo(tester.getCenter(find.text('Grid')));
      await tester.pump();
      expect(rowColor(tester, 'Grid'), light.surfaceSelectedStrong);
      expect(rowColor(tester, 'Continuous scroll'), isNull);
    });

    testWidgets('hover does not tint an option disabled with a reason, but '
        'its reason shows', (tester) async {
      await tester.pumpWidget(host(select()));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await open(tester);
      await mouse.moveTo(tester.getCenter(find.text('Book')));
      await tester.pump();
      expect(rowColor(tester, 'Book'), isNull);
      // The highlight stays where it was.
      expect(
        rowColor(tester, 'Continuous scroll'),
        light.surfaceSelectedStrong,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Available in a future version'), findsOneWidget);
    });

    testWidgets('forced hover and focus', (tester) async {
      await tester.pumpWidget(
        host(select(), forcedStates: {WidgetState.hovered}),
      );
      expect(borderOf(tester), light.borderStrong);
      await tester.pumpWidget(
        host(select(), forcedStates: {WidgetState.focused}),
      );
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderFocus);
    });

    testWidgets('disabled: no list, disabled look', (tester) async {
      await tester.pumpWidget(host(select(disabled: true)));
      expect(borderOf(tester), light.borderSubtle);
      await tester.tap(find.byKey(FieldBox.boxKey), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      // `.fm-input > svg { color: var(--icon-secondary) }` sets the colour
      // on the svg, which `.fm-input--disabled` does not reach.
      final chevron = tester.widget<Icon>(find.byType(Icon));
      expect(chevron.color, light.iconSecondary);
    });

    testWidgets('disabled with a reason: focusable, reason as tooltip and '
        'hint', (tester) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(
          select(
            disabled: true,
            disabledReason: 'Available in a future version',
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(FieldBox.boxKey)),
        isSemantics(
          label: 'Page layout',
          hint: 'Available in a future version',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('semantics: a button named by the label with the chosen '
        'value, expanded while open', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(select()));
      expect(
        tester.getSemantics(find.byKey(FieldBox.boxKey)),
        isSemantics(
          label: 'Page layout',
          value: 'Continuous scroll',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await open(tester);
      expect(
        tester.getSemantics(find.byKey(FieldBox.boxKey)),
        isSemantics(
          label: 'Page layout',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Single page')),
        isSemantics(
          label: 'Single page',
          role: SemanticsRole.menuItemRadio,
          isButton: true,
          hasCheckedState: true,
          isChecked: false,
          hasSelectedState: true,
          isSelected: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Continuous scroll').last),
        isSemantics(
          label: 'Continuous scroll',
          role: SemanticsRole.menuItemRadio,
          hasCheckedState: true,
          isChecked: true,
        ),
      );
      // The open list: a menu named by the label, scoping its route (the
      // listbox the native select's list would be).
      expect(
        tester.getSemantics(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.role == SemanticsRole.menu,
          ),
        ),
        isSemantics(
          label: 'Page layout',
          role: SemanticsRole.menu,
          scopesRoute: true,
          namesRoute: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('semantics: semanticLabel without a visible label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(select(label: null, semanticLabel: 'Zoom')));
      expect(
        tester.getSemantics(find.byKey(FieldBox.boxKey)),
        isSemantics(label: 'Zoom', value: 'Continuous scroll', isButton: true),
      );
      handle.dispose();
    });

    testWidgets('right to left: chevron on the left, list lined up on the '
        'right', (tester) async {
      await tester.pumpWidget(host(select(), textDirection: TextDirection.rtl));
      final box = tester.getRect(find.byKey(FieldBox.boxKey));
      expect(tester.getRect(find.byType(Icon)).left, box.left + 1 + 4);
      await open(tester);
      final list = tester.getRect(find.byType(PopoverSurface));
      expect(list.right, box.right);
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(host(select(), brightness: Brightness.dark));
      expect(borderOf(tester), dark.borderDefault);
      await open(tester);
      expect(rowColor(tester, 'Continuous scroll'), dark.surfaceSelectedStrong);
    });

    testWidgets('an empty box when no option has the value', (tester) async {
      await tester.pumpWidget(host(select(value: null)));
      expect(find.text('Continuous scroll'), findsNothing);
    });
  });
}
