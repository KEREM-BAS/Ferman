import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/font_picker.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;

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

  Widget host(Widget child) => TapRegionSurface(
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
    ),
  );

  Widget picker({
    String value = 'IBM Plex Serif',
    ValueChanged<String>? onChanged,
    bool initiallyOpen = false,
    bool glyphWarning = false,
    String? warning,
    FocusNode? focusNode,
  }) => FontPicker(
    label: 'Font',
    value: value,
    fonts: fonts,
    onChanged: onChanged ?? (_) {},
    initiallyOpen: initiallyOpen,
    glyphWarning: glyphWarning,
    warning: warning,
    focusNode: focusNode,
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
