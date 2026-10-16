import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/editing/search_replace_bar.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;

  final labels = SearchReplaceBarLabels(
    region: 'Find and replace',
    find: 'Find',
    replaceWith: 'Replace with',
    matchCase: 'Match case',
    wholeWord: 'Whole word',
    regex: 'Regular expression',
    showReplace: 'Show replace',
    hideReplace: 'Hide replace',
    previous: 'Previous match',
    next: 'Next match',
    close: 'Close',
    replace: 'Replace',
    replaceAll: 'Replace all',
    noResults: 'No results',
    count: (current, total) => '$current of $total',
    previousShortcut: const ['⇧', '↵'],
    nextShortcut: const ['↵'],
    closeShortcut: const ['Esc'],
  );

  final count = find.byKey(const ValueKey<String>('SearchReplaceBar.count'));
  final replaceRow = find.byKey(
    const ValueKey<String>('SearchReplaceBar.replaceRow'),
  );
  final notice = find.byKey(const ValueKey<String>('SearchReplaceBar.notice'));

  IconButton iconButton(WidgetTester tester, String label) =>
      tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.label == label),
      );

  Finder toggle(String label) => find.byWidgetPredicate(
    (w) => w is FermanInteractive && w.semanticLabel == label,
  );

  Widget bar({
    String query = '',
    String replaceWith = '',
    bool showReplace = false,
    int current = 0,
    int total = 0,
    bool matchCase = false,
    String? notice,
    ValueChanged<String>? onQueryChanged,
    // The component's own parameter type (the spec's).
    // ignore: avoid_positional_boolean_parameters
    void Function(SearchOption option, bool value)? onToggleOption,
    VoidCallback? onToggleReplace,
    VoidCallback? onPrevious,
    VoidCallback? onNext,
    VoidCallback? onReplace,
    VoidCallback? onReplaceAll,
    VoidCallback? onClose,
  }) => SearchReplaceBar(
    labels: labels,
    query: query,
    replaceWith: replaceWith,
    showReplace: showReplace,
    current: current,
    total: total,
    matchCase: matchCase,
    notice: notice,
    onQueryChanged: onQueryChanged,
    onToggleOption: onToggleOption,
    onToggleReplace: onToggleReplace,
    onPrevious: onPrevious,
    onNext: onNext,
    onReplace: onReplace,
    onReplaceAll: onReplaceAll,
    onClose: onClose,
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('SearchReplaceBar look', () {
    testWidgets('find only: 440 px, raised, no replace row, empty count', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(bar()));
      expect(tester.getSize(find.byType(SearchReplaceBar)).width, 440);
      final surface = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(SearchReplaceBar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.color, light.surfaceRaised);
      expect(decoration.boxShadow, FermanElevationTokens.light.shadowPopover);
      expect(replaceRow, findsNothing);
      expect(tester.widget<Text>(count).data, '');
      expect(find.text('Find'), findsOneWidget);
    });

    testWidgets('count: N of M; previous and next enabled', (tester) async {
      await tester.pumpWidget(
        componentHost(bar(query: 'kira', current: 1, total: 7)),
      );
      expect(tester.widget<Text>(count).data, '1 of 7');
      expect(tester.widget<Text>(count).style!.color, light.textSecondary);
      expect(iconButton(tester, 'Previous match').disabled, isFalse);
      expect(iconButton(tester, 'Next match').disabled, isFalse);
      expect(iconButton(tester, 'Previous match').shortcut, ['⇧', '↵']);
    });

    testWidgets('no results: danger count, previous and next disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(bar(query: 'xyz', showReplace: true)),
      );
      expect(tester.widget<Text>(count).data, 'No results');
      expect(tester.widget<Text>(count).style!.color, light.danger);
      expect(iconButton(tester, 'Previous match').disabled, isTrue);
      expect(iconButton(tester, 'Next match').disabled, isTrue);
      for (final button in tester.widgetList<Button>(find.byType(Button))) {
        expect(button.disabled, isTrue);
      }
    });

    testWidgets('replace shown: the row, its buttons and the indent', (
      tester,
    ) async {
      var replaced = 0;
      var all = 0;
      await tester.pumpWidget(
        componentHost(
          bar(
            query: 'kiraya veren',
            replaceWith: 'mal sahibi',
            showReplace: true,
            current: 2,
            total: 5,
            onReplace: () => replaced++,
            onReplaceAll: () => all++,
          ),
        ),
      );
      expect(replaceRow, findsOneWidget);
      expect(find.text('mal sahibi'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byType(Icon).first).name,
        IconName.chevronDown,
      );
      final rowLeft = tester.getTopLeft(replaceRow).dx;
      final fieldLeft = tester
          .getTopLeft(
            find.descendant(of: replaceRow, matching: find.byType(Row)).first,
          )
          .dx;
      expect(fieldLeft - rowLeft, SearchReplaceBar.replaceIndent);
      await tester.tap(find.text('Replace'));
      await tester.tap(find.text('Replace all'));
      expect((replaced, all), (1, 1));
    });

    testWidgets('notice: a warning callout', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(bar(notice: '2 matches are part of a longer word.')),
      );
      final box = tester.widget<Container>(notice);
      expect((box.decoration! as BoxDecoration).color, light.warningBg);
      expect(
        tester.getSemantics(find.text('2 matches are part of a longer word.')),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('dark theme takes the dark tokens', (tester) async {
      await tester.pumpWidget(
        componentHost(bar(query: 'x'), brightness: Brightness.dark),
      );
      expect(
        tester.widget<Text>(count).style!.color,
        FermanColorTokens.dark.danger,
      );
    });

    testWidgets('right to left: the replace row is indented at the start', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          bar(showReplace: true, query: 'a', total: 1, current: 1),
          textDirection: TextDirection.rtl,
        ),
      );
      final rowRight = tester.getTopRight(replaceRow).dx;
      final fieldRight = tester
          .getTopRight(
            find.descendant(of: replaceRow, matching: find.byType(Row)).first,
          )
          .dx;
      expect(rowRight - fieldRight, SearchReplaceBar.replaceIndent);
    });
  });

  group('SearchReplaceBar options', () {
    testWidgets('toggles report the option and its new value', (tester) async {
      final toggled = <(SearchOption, bool)>[];
      await tester.pumpWidget(
        componentHost(
          bar(
            matchCase: true,
            onToggleOption: (option, value) => toggled.add((option, value)),
          ),
        ),
      );
      await tester.tap(toggle('Match case'));
      await tester.tap(toggle('Whole word'));
      await tester.tap(toggle('Regular expression'));
      expect(toggled, [
        (SearchOption.matchCase, false),
        (SearchOption.wholeWord, true),
        (SearchOption.regex, true),
      ]);
    });

    testWidgets('on: accent-subtle fill; hover: the hover tint; toggled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(bar(matchCase: true, onToggleOption: (_, _) {})),
      );
      Container square(String label) => tester.widget<Container>(
        find.descendant(of: toggle(label), matching: find.byType(Container)),
      );
      expect(
        (square('Match case').decoration! as BoxDecoration).color,
        light.accentSubtle,
      );
      expect((square('Whole word').decoration! as BoxDecoration).color, isNull);
      expect(
        tester.getSemantics(
          find.descendant(
            of: toggle('Match case'),
            matching: find.byType(Icon),
          ),
        ),
        isSemantics(
          label: 'Match case',
          hasToggledState: true,
          isToggled: true,
        ),
      );
      await tester.pumpWidget(
        componentHost(
          bar(onToggleOption: (_, _) {}),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(
        (square('Whole word').decoration! as BoxDecoration).color,
        light.surfaceHover,
      );
      handle.dispose();
    });

    testWidgets('keyboard focus shows the inset ring', (tester) async {
      await tester.pumpWidget(
        componentHost(
          bar(onToggleOption: (_, _) {}),
          forcedStates: const {WidgetState.focused},
        ),
      );
      final ring = tester.widget<FocusRing>(
        find.descendant(
          of: toggle('Regular expression'),
          matching: find.byType(FocusRing),
        ),
      );
      expect(ring.visible, isTrue);
      expect(ring.style, FocusRingStyle.inset);
    });
  });

  group('SearchReplaceBar keyboard and editing', () {
    testWidgets('Enter in the find field: next; Shift+Enter: previous', (
      tester,
    ) async {
      var next = 0;
      var previous = 0;
      await tester.pumpWidget(
        componentHost(
          bar(
            query: 'kira',
            current: 1,
            total: 3,
            onNext: () => next++,
            onPrevious: () => previous++,
          ),
        ),
      );
      await tester.tap(find.text('kira'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect((next, previous), (1, 0));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect((next, previous), (1, 1));
    });

    testWidgets('Escape anywhere in the bar closes it', (tester) async {
      var closed = 0;
      await tester.pumpWidget(
        componentHost(bar(onClose: () => closed++, onToggleOption: (_, _) {})),
      );
      await tester.tap(find.text('Find'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closed, 1);
      await tester.tap(
        find.byWidgetPredicate((w) => w is IconButton && w.label == 'Close'),
      );
      expect(closed, 2);
    });

    testWidgets('typing reports the query; a new query updates the field', (
      tester,
    ) async {
      final queries = <String>[];
      await tester.pumpWidget(componentHost(bar(onQueryChanged: queries.add)));
      await tester.enterText(find.byType(EditableText).first, 'kira');
      expect(queries, ['kira']);
      await tester.pumpWidget(
        componentHost(bar(query: 'depozito', onQueryChanged: queries.add)),
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        'depozito',
      );
    });

    testWidgets('the disclosure button toggles the replace row', (
      tester,
    ) async {
      var toggles = 0;
      await tester.pumpWidget(
        componentHost(bar(onToggleReplace: () => toggles++)),
      );
      expect(iconButton(tester, 'Show replace').icon, IconName.chevronRight);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.label == 'Show replace',
        ),
      );
      expect(toggles, 1);
    });

    testWidgets('semantics: a named group with a live count', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(bar(query: 'kira', current: 1, total: 7)),
      );
      expect(find.bySemanticsLabel('Find and replace'), findsOneWidget);
      expect(
        tester.getSemantics(count),
        isSemantics(label: '1 of 7', isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
