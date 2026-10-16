import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/foundation/modal_scope.dart';
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

  // Fifteen commands: more than the 344 px list shows.
  final many = <CommandGroup>[
    (
      label: 'Commands',
      items: [
        for (var i = 0; i < 15; i++)
          CommandItem(id: 'c$i', label: 'Command $i'),
      ],
    ),
  ];

  Widget palette({
    bool open = true,
    bool inline = false,
    String? query,
    ValueChanged<String>? onQueryChanged,
    ValueChanged<CommandItem>? onSelected,
    VoidCallback? onClose,
    List<CommandGroup>? commands,
  }) => CommandPalette(
    open: open,
    inline: inline,
    groups: commands ?? groups,
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

  final listFinder = find
      .descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      )
      .first;

  Rect rowRect(WidgetTester tester, String label) => tester.getRect(
    find
        .ancestor(
          of: find.textContaining(label, findRichText: true),
          matching: find.byType(Container),
        )
        .first,
  );

  /// Announcements reach the test only where the platform supports them.
  Widget announcing(Widget child) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(supportsAnnounce: true),
      child: child,
    ),
  );

  tearDown(ModalScope.debugReset);

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

    testWidgets('no match shows the empty text; the arrows and Enter do '
        'nothing', (tester) async {
      final ran = <String>[];
      await tester.pumpWidget(
        componentHost(palette(onSelected: (item) => ran.add(item.id))),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'zzz');
      await tester.pump();
      expect(find.text('No commands match.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(ran, isEmpty);
      expect(find.text('No commands match.'), findsOneWidget);
    });

    testWidgets('a long list scrolls only as far as the active row needs, '
        '6 px clear of the edge; hover never scrolls', (tester) async {
      await tester.pumpWidget(componentHost(palette(commands: many)));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(listFinder).position;
      expect(position.maxScrollExtent, greaterThan(0));
      final viewport = tester.getRect(listFinder);
      // Hover over a row in view: it becomes active, nothing scrolls.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.textContaining('Command 4', findRichText: true)),
      );
      await tester.pumpAndSettle();
      expect(rowColor(tester, 'Command 4'), light.surfaceSelectedStrong);
      expect(position.pixels, 0);
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump();
      // ArrowDown to the first row that is not fully in view.
      var index = 4;
      while (rowRect(tester, 'Command ${index + 1}').bottom <=
          viewport.bottom) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        index++;
        expect(position.pixels, 0, reason: 'Command $index is in view');
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      index++;
      expect(position.pixels, greaterThan(0));
      expect(
        viewport.bottom - rowRect(tester, 'Command $index').bottom,
        CommandPalette.revealMargin,
      );
      // Back up to a row in view: no jump.
      final scrolled = position.pixels;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(position.pixels, scrolled);
    });

    testWidgets('a command in two groups is fine', (tester) async {
      const twice = <CommandGroup>[
        (label: 'Recent', items: [CommandItem(id: 'rotate', label: 'Rotate')]),
        (
          label: 'Commands',
          items: [
            CommandItem(id: 'rotate', label: 'Rotate'),
            CommandItem(id: 'ocr', label: 'Recognise text'),
          ],
        ),
      ];
      final ran = <String>[];
      await tester.pumpWidget(
        componentHost(
          palette(commands: twice, onSelected: (item) => ran.add(item.id)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(ran, ['ocr']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a command disabled with a reason shows it while it is the '
        'active row (G10)', (tester) async {
      await tester.pumpWidget(componentHost(palette()));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      // The row rebuilds active, the tooltip starts its delay after that
      // frame, and the bubble shows a frame after the delay.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Available in a future version'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.text('Available in a future version'), findsNothing);
    });

    testWidgets('the arrow keys announce the active command; hover does not', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(announcing(palette())));
      await tester.pumpAndSettle();
      tester.takeAnnouncements();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.takeAnnouncements().map((a) => a.message), [
        'Recognise text',
        'Ask the assistant, Available in a future version',
      ]);
      // At the end of the list nothing moves, so nothing is said.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(tester.takeAnnouncements().map((a) => a.message), [
        'Contract, Page 4',
      ]);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(
          find.textContaining('Rotate page', findRichText: true),
        ),
      );
      await tester.pump();
      expect(tester.takeAnnouncements(), isEmpty);
    });

    testWidgets('modal: in the root overlay over a top bar, counted by '
        'ModalScope while it shows', (tester) async {
      const bar = Key('bar');
      Widget page({required bool open}) => componentHost(
        SizedBox.expand(
          child: Column(
            children: [
              const SizedBox(key: bar, height: 40, width: double.infinity),
              Expanded(
                child: Navigator(
                  onGenerateRoute: (settings) => PageRouteBuilder<void>(
                    pageBuilder: (context, animation, secondary) =>
                        palette(open: open),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(page(open: true));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(Scrim)),
        Offset.zero & const Size(800, 600),
      );
      expect(ModalScope.openCount.value, 1);
      await tester.pumpWidget(componentHost(const SizedBox()));
      await tester.pumpAndSettle();
      expect(ModalScope.openCount.value, 0);
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
      // The field is named by its placeholder, as the bundle's input is.
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Search commands, pages and text',
          isTextField: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('row glyphs stay 16 px at touch density', (tester) async {
      await tester.pumpWidget(
        componentHost(
          FermanThemeScope(touch: true, child: palette(inline: true)),
        ),
      );
      await tester.pumpAndSettle();
      final glyph = tester.widget<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.name == IconName.rotateCw),
      );
      expect(glyph.size, 16);
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
