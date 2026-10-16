import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/overlays/command_palette.dart';
import 'package:ferman/design/components/overlays/scrim.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;

  const groups = <CommandGroup>[
    (
      label: 'Commands',
      items: [
        CommandItem(
          id: 'rotate',
          label: 'Rotate page',
          icon: IconName.rotateCw,
          shortcut: ['Ctrl', 'R'],
        ),
        CommandItem(id: 'ocr', label: 'Recognise text', keywords: 'scan'),
        CommandItem(
          id: 'ai',
          label: 'Ask the assistant',
          disabledReason: 'Available in a future version',
        ),
      ],
    ),
    (
      label: 'Pages',
      items: [CommandItem(id: 'p4', label: 'Contract', hint: 'Page 4')],
    ),
  ];

  Widget palette({
    bool open = true,
    bool inline = false,
    String? query,
    ValueChanged<String>? onQueryChanged,
    ValueChanged<CommandItem>? onSelected,
    VoidCallback? onClose,
  }) => CommandPalette(
    open: open,
    inline: inline,
    groups: groups,
    query: query,
    onQueryChanged: onQueryChanged,
    onSelected: onSelected,
    onClose: onClose,
    placeholder: 'Search commands, pages and text',
    emptyText: 'No commands match.',
    semanticLabel: 'Command palette',
    escapeKeys: const ['Esc'],
    footerHints: const [
      (keys: ['↑', '↓'], label: 'Move'),
      (keys: ['↵'], label: 'Run'),
      (keys: ['Esc'], label: 'Close'),
    ],
  );

  Color? rowColor(WidgetTester tester, String label) {
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.textContaining(label, findRichText: true),
            matching: find.byType(Container),
          )
          .first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  group('CommandPalette', () {
    testWidgets('inline: 600 px, input row, groups, rows, footer', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(palette(inline: true)));
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsNothing);
      final box = find
          .descendant(
            of: find.byType(CommandPalette),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(box).width, 600);
      expect(find.text('Search commands, pages and text'), findsOneWidget);
      expect(find.text('Commands'), findsOneWidget);
      expect(find.text('Pages'), findsOneWidget);
      expect(find.text('Page 4'), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);
      final search = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.name == IconName.search),
      );
      expect(search.size, 18);
      final row = find
          .ancestor(
            of: find.textContaining('Contract', findRichText: true),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(row).height, CommandPalette.itemHeight);
      expect(rowColor(tester, 'Rotate page'), light.surfaceSelectedStrong);
      expect(
        tester
            .widgetList<Kbd>(find.byType(Kbd))
            .where((kbd) => kbd.tone == KbdTone.plain),
        hasLength(1),
      );
    });

    testWidgets('typing filters with keywords and bolds the match', (
      tester,
    ) async {
      final queries = <String>[];
      await tester.pumpWidget(
        componentHost(palette(inline: true, onQueryChanged: queries.add)),
      );
      await tester.enterText(find.byType(EditableText), 'scan');
      await tester.pump();
      expect(queries, ['scan']);
      expect(
        find.textContaining('Recognise', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Rotate', findRichText: true), findsNothing);
      await tester.enterText(find.byType(EditableText), 'rot');
      await tester.pump();
      final rich = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'Rotate page',
        ),
      );
      // Text.rich wraps the label's span in one carrying the default style.
      final label = (rich.text as TextSpan).children!.single as TextSpan;
      final spans = label.children!.cast<TextSpan>();
      final bold = spans.firstWhere((span) => span.style?.fontWeight != null);
      expect(bold.text, 'Rot');
      expect(bold.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('no match shows the empty text', (tester) async {
      await tester.pumpWidget(componentHost(palette(inline: true)));
      await tester.enterText(find.byType(EditableText), 'zzz');
      await tester.pump();
      expect(find.text('No commands match.'), findsOneWidget);
    });

    testWidgets('Turkish casing: “İ” matches “i” in a Turkish UI', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const CommandPalette(
            inline: true,
            groups: [
              (
                label: 'Komutlar',
                items: [CommandItem(id: 'sign', label: 'İmzala')],
              ),
            ],
          ),
          locale: const Locale('tr'),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'imz');
      await tester.pump();
      expect(find.textContaining('mzala', findRichText: true), findsOneWidget);
    });

    testWidgets('keyboard: arrows move (stopping at the ends), Enter runs, a '
        'reason blocks, Escape closes', (tester) async {
      final ran = <String>[];
      var closes = 0;
      await tester.pumpWidget(
        componentHost(
          palette(
            onSelected: (item) => ran.add(item.id),
            onClose: () => closes++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsOneWidget);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(rowColor(tester, 'Rotate page'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rowColor(tester, 'Recognise text'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(ran, ['ocr']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(ran, ['ocr']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rowColor(tester, 'Contract'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closes, 1);
    });

    testWidgets('pointer: moving over a row activates it, a click runs it, a '
        'scrim click closes', (tester) async {
      final ran = <String>[];
      var closes = 0;
      await tester.pumpWidget(
        componentHost(
          palette(
            onSelected: (item) => ran.add(item.id),
            onClose: () => closes++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.textContaining('Contract', findRichText: true)),
      );
      await tester.pump();
      expect(rowColor(tester, 'Contract'), light.surfaceSelectedStrong);
      await tester.tap(find.textContaining('Contract', findRichText: true));
      expect(ran, ['p4']);
      await tester.tapAt(const Offset(10, 590));
      expect(closes, 1);
    });

    testWidgets('modal placement: 14 % from the top on the light scrim', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(palette()));
      await tester.pumpAndSettle();
      final scrim = tester.widget<Scrim>(find.byType(Scrim));
      expect(scrim.top, isTrue);
      final box = find
          .descendant(of: find.byType(Scrim), matching: find.byType(Container))
          .first;
      // The test surface is 800 × 600.
      expect(tester.getTopLeft(box).dy, closeTo(600 * 0.14, 0.5));
    });

    testWidgets('semantics: a dialog named Command palette, the active row '
        'selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(palette(inline: true)));
      await tester.pumpAndSettle();
      final row = tester.getSemantics(
        find.textContaining('Rotate page', findRichText: true),
      );
      expect(
        row,
        isSemantics(
          label: 'Rotate page',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      final ai = tester.getSemantics(
        find.textContaining('Ask the assistant', findRichText: true),
      );
      expect(
        ai,
        isSemantics(
          hint: 'Available in a future version',
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      var node = row.parent;
      while (node != null &&
          node.getSemanticsData().role != SemanticsRole.dialog) {
        node = node.parent;
      }
      expect(node?.label, 'Command palette');
      handle.dispose();
    });

    testWidgets('closed: nothing shown', (tester) async {
      await tester.pumpWidget(componentHost(palette(open: false)));
      await tester.pumpAndSettle();
      expect(find.byType(Scrim), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('dark theme: the dark top scrim', (tester) async {
      await tester.pumpWidget(
        componentHost(palette(), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      final tint = tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(Scrim),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      expect(tint, Scrim.topDark);
    });
  });
}
