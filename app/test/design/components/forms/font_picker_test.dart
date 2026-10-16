import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/font_picker.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
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

  const fonts = [
    FontOption(name: 'IBM Plex Serif', group: FontGroup.document),
    FontOption(
      name: 'Minion Pro',
      available: false,
      substitute: 'IBM Plex Serif',
      group: FontGroup.document,
    ),
    FontOption(name: 'IBM Plex Sans'),
    FontOption(name: 'IBM Plex Mono'),
  ];

  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      TapRegionSurface(
        child: componentHost(
          ColoredBox(
            color: const Color(0x00000000),
            child: SizedBox.expand(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(24),
                  child: SizedBox(width: 200, child: child),
                ),
              ),
            ),
          ),
          brightness: brightness,
        ),
      );

  Color? rowColor(WidgetTester tester, String name) => tester
      .widget<Container>(
        find
            .ancestor(
              of: find.text(name).last,
              matching: find.byType(Container),
            )
            .first,
      )
      .color;

  Widget picker({
    String value = 'IBM Plex Serif',
    ValueChanged<String>? onChanged,
    bool initiallyOpen = false,
    bool glyphWarning = false,
    String? warning,
    FocusNode? focusNode,
    bool disabled = false,
    String? disabledReason,
  }) => FontPicker(
    label: 'Font',
    value: value,
    fonts: fonts,
    onChanged: onChanged ?? (_) {},
    initiallyOpen: initiallyOpen,
    glyphWarning: glyphWarning,
    warning: warning,
    focusNode: focusNode,
    disabled: disabled,
    disabledReason: disabledReason,
    missingNote:
        'Minion Pro isn’t installed. Ferman is showing IBM Plex '
        'Serif instead.',
    missingBadge: const Text('Not installed'),
    documentGroupLabel: 'In this document',
    systemGroupLabel: 'On this device',
    searchPlaceholder: 'Search fonts',
    searchSemanticLabel: 'Search fonts',
    listSemanticLabel: 'Fonts',
    noMatchesText: (query) => 'No fonts match “$query”.',
  );

  Color borderOf(WidgetTester tester) =>
      ((tester
                          .widget<AnimatedContainer>(
                            find.byKey(FieldBox.boxKey).first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border)
          .top
          .color;

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('FontPicker', () {
    testWidgets('trigger: the font name in its family at 13 px', (
      tester,
    ) async {
      await tester.pumpWidget(host(picker()));
      final name = tester.widget<Text>(find.text('IBM Plex Serif'));
      expect(name.style!.fontFamily, 'IBM Plex Serif');
      expect(name.style!.fontSize, 13);
      expect(name.style!.color, light.textPrimary);
      expect(borderOf(tester), light.borderDefault);
    });

    testWidgets('missing font: italic secondary name, triangle, warning '
        'border and note', (tester) async {
      await tester.pumpWidget(host(picker(value: 'Minion Pro')));
      final name = tester.widget<Text>(find.text('Minion Pro'));
      expect(name.style!.fontStyle, FontStyle.italic);
      expect(name.style!.color, light.textSecondary);
      expect(borderOf(tester), light.warningSolid);
      expect(
        tester
            .widgetList<Icon>(find.byType(Icon))
            .where((icon) => icon.name == IconName.triangleAlert),
        hasLength(2),
      );
      final note = tester.widget<Text>(find.textContaining('isn’t installed'));
      expect(note.style!.color, light.warning);
    });

    testWidgets('warning overrides the missing note', (tester) async {
      await tester.pumpWidget(
        host(picker(value: 'Minion Pro', warning: 'Custom note')),
      );
      expect(find.text('Custom note'), findsOneWidget);
      expect(find.textContaining('isn’t installed'), findsNothing);
    });

    testWidgets('glyph warning: amber border and a triangle, no note', (
      tester,
    ) async {
      await tester.pumpWidget(host(picker(glyphWarning: true)));
      expect(borderOf(tester), light.warningSolid);
      final triangle = tester
          .widgetList<Icon>(find.byType(Icon))
          .firstWhere((icon) => icon.name == IconName.triangleAlert);
      expect(triangle.strokeWidth, FontPicker.glyphWarningStroke);
      expect(find.textContaining('isn’t installed'), findsNothing);
    });

    testWidgets('the popover: search, sections, check, badge', (tester) async {
      await tester.pumpWidget(host(picker()));
      await tester.tap(find.byKey(FieldBox.boxKey));
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      expect(
        tester.getSize(find.byType(PopoverSurface)).width,
        FontPicker.popoverWidth,
      );
      expect(find.text('In this document'), findsOneWidget);
      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('Not installed'), findsOneWidget);
      expect(find.text('Search fonts'), findsOneWidget);
      final rows = find.ancestor(
        of: find.text('IBM Plex Mono'),
        matching: find.byType(Container),
      );
      expect(tester.getSize(rows.first).height, FontPicker.rowHeight);
      final rowName = tester.widget<Text>(find.text('IBM Plex Mono'));
      expect(rowName.style!.fontSize, 14);
      expect(rowName.style!.fontFamily, 'IBM Plex Mono');
    });

    testWidgets('searching filters; no match shows the empty text', (
      tester,
    ) async {
      await tester.pumpWidget(host(picker(initiallyOpen: true)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'mono');
      await tester.pump();
      expect(find.text('IBM Plex Mono'), findsOneWidget);
      expect(find.text('IBM Plex Sans'), findsNothing);
      expect(find.text('In this document'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'xyz');
      await tester.pump();
      expect(find.text('No fonts match “xyz”.'), findsOneWidget);
    });

    testWidgets('choosing a font reports it and closes', (tester) async {
      final chosen = <String>[];
      await tester.pumpWidget(
        host(picker(onChanged: chosen.add, initiallyOpen: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('IBM Plex Sans'));
      await tester.pumpAndSettle();
      expect(chosen, ['IBM Plex Sans']);
      expect(find.byType(PopoverSurface), findsNothing);
    });

    testWidgets('keyboard: Enter opens with the search focused, ArrowDown '
        'reaches the rows, Enter chooses, Escape closes', (tester) async {
      final chosen = <String>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(picker(onChanged: chosen.add, focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final search = tester.widget<EditableText>(find.byType(EditableText));
      expect(search.focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['Minion Pro']);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('keyboard: the arrows stay in the list, whatever lies under '
        'the popover', (tester) async {
      final chosen = <String>[];
      final trigger = FocusNode(debugLabel: 'trigger');
      final outside = [
        for (final name in ['above', 'size', 'colour', 'bold', 'align'])
          FocusNode(debugLabel: name),
      ];
      for (final node in [trigger, ...outside]) {
        addTearDown(node.dispose);
      }
      Widget focusable(FocusNode node) =>
          Focus(focusNode: node, child: const SizedBox(width: 60, height: 26));
      // The FmEditPanel layout: the picker, then the size and colour row
      // and the B/I/U and alignment row 10 px apart, under the popover.
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              focusable(outside[0]),
              picker(onChanged: chosen.add, focusNode: trigger),
              Row(children: [focusable(outside[1]), focusable(outside[2])]),
              Row(children: [focusable(outside[3]), focusable(outside[4])]),
            ],
          ),
        ),
      );
      trigger.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final search = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(search.hasFocus, isTrue);
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        final focus = FocusManager.instance.primaryFocus;
        expect(outside.contains(focus) || focus == trigger, isFalse);
      }

      // ArrowUp on the search field stays there.
      await press(LogicalKeyboardKey.arrowUp);
      expect(search.hasFocus, isTrue);
      // ArrowDown to the first row, ArrowUp back to the search field.
      await press(LogicalKeyboardKey.arrowDown);
      expect(search.hasFocus, isFalse);
      await press(LogicalKeyboardKey.arrowUp);
      expect(search.hasFocus, isTrue);
      // Past the last row the focus stays on it.
      for (var i = 0; i < fonts.length + 2; i++) {
        await press(LogicalKeyboardKey.arrowDown);
      }
      expect(find.byType(PopoverSurface), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['IBM Plex Mono']);
      // With no match ArrowDown keeps the search field.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'xyz');
      await tester.pump();
      await press(LogicalKeyboardKey.arrowDown);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('trigger focus: the outer ring and the focus border', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(host(picker(focusNode: node)));
      node.requestFocus();
      await tester.pumpAndSettle();
      final box = tester.widget<FieldBox>(find.byType(FieldBox).first);
      expect(box.focusRingStyle, FocusRingStyle.outer);
      expect(box.focused, isTrue);
      expect(borderOf(tester), light.borderFocus);
    });

    testWidgets('hover: the trigger border; rows tint under the pointer and '
        'keyboard focus', (tester) async {
      await tester.pumpWidget(host(picker()));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(FieldBox.boxKey).first));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderStrong);
      await tester.tap(find.byKey(FieldBox.boxKey).first);
      await tester.pumpAndSettle();
      expect(rowColor(tester, 'IBM Plex Sans'), isNull);
      await mouse.moveTo(tester.getCenter(find.text('IBM Plex Sans')));
      await tester.pumpAndSettle();
      expect(rowColor(tester, 'IBM Plex Sans'), light.surfaceHover);
      await mouse.moveTo(const Offset(700, 10));
      await tester.pumpAndSettle();
      // Keyboard focus on the first row tints it too.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(rowColor(tester, 'IBM Plex Serif'), light.surfaceHover);
      expect(rowColor(tester, 'IBM Plex Sans'), isNull);
    });

    testWidgets('disabled: no popover, disabled name, sunken box', (
      tester,
    ) async {
      await tester.pumpWidget(host(picker(disabled: true)));
      await tester.tap(find.byKey(FieldBox.boxKey), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      final name = tester.widget<Text>(find.text('IBM Plex Serif'));
      expect(name.style!.color, light.textDisabled);
      final box =
          tester
                  .widget<AnimatedContainer>(find.byKey(FieldBox.boxKey))
                  .decoration!
              as BoxDecoration;
      expect(box.color, light.surfaceSunken);
      // `.fm-input > svg { color: var(--icon-secondary) }` in every state.
      final chevron = tester
          .widgetList<Icon>(find.byType(Icon))
          .firstWhere((icon) => icon.name == IconName.chevronDown);
      expect(chevron.color, light.iconSecondary);
    });

    testWidgets('disabled with a reason: focusable, reason as tooltip and '
        'hint', (tester) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(
          picker(
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
          label: 'Font',
          hint: 'Available in a future version',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('glyph warning keeps the amber border with focus and when '
        'disabled; a missing font yields to focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(picker(glyphWarning: true, focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.warningSolid);
      final ring = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.boxShadow)
          .whereType<List<BoxShadow>>()
          .where((shadows) => shadows.isNotEmpty);
      expect(ring, contains(FocusRing.outerShadows(FermanTheme.light)));
      await tester.pumpWidget(host(picker(glyphWarning: true, disabled: true)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.warningSolid);
      final missing = FocusNode();
      addTearDown(missing.dispose);
      await tester.pumpWidget(
        host(picker(value: 'Minion Pro', focusNode: missing)),
      );
      missing.requestFocus();
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderFocus);
    });

    testWidgets('the missing-font note is a live region of its own', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(picker(value: 'Minion Pro')));
      expect(
        tester.getSemantics(find.textContaining('isn’t installed')),
        isSemantics(
          isLiveRegion: true,
          label:
              'Minion Pro isn’t installed. Ferman is showing IBM Plex '
              'Serif instead.',
        ),
      );
      handle.dispose();
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(host(picker(), brightness: Brightness.dark));
      expect(borderOf(tester), dark.borderDefault);
      final name = tester.widget<Text>(find.text('IBM Plex Serif'));
      expect(name.style!.color, dark.textPrimary);
    });

    testWidgets('semantics: trigger value, selected row', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(picker(initiallyOpen: true)));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(FieldBox.boxKey).first),
        isSemantics(
          label: 'Font',
          value: 'IBM Plex Serif',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('IBM Plex Serif').last),
        isSemantics(
          label: 'IBM Plex Serif',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      handle.dispose();
    });
  });
}
