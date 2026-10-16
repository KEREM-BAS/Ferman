import 'package:ferman/design/components/additions/date_picker.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;
  final november = DateTime(2026, 11);

  Widget picker({
    DateTime? value,
    DateTime? month,
    int firstDayOfWeek = DateTime.monday,
    Region region = Region.turkiye,
    ValueChanged<DateTime>? onChanged,
    ValueChanged<DateTime>? onMonthChanged,
    VoidCallback? onDismiss,
    bool autofocus = false,
  }) => DatePicker(
    value: value,
    month: month ?? november,
    firstDayOfWeek: firstDayOfWeek,
    region: region,
    onChanged: onChanged,
    onMonthChanged: onMonthChanged,
    onDismiss: onDismiss,
    autofocus: autofocus,
    semanticLabel: 'Choose a date',
    formatNote: 'Format DD.MM.YYYY · from the form',
    weekdayLabels: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
    previousMonthButton: const SizedBox(
      key: Key('prev'),
      width: 26,
      height: 26,
    ),
    nextMonthButton: const SizedBox(key: Key('next'), width: 26, height: 26),
    todayButton: const SizedBox(key: Key('today'), width: 60, height: 26),
  );

  BoxDecoration? cellOf(WidgetTester tester, String day, {int which = 0}) {
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text(day).at(which),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration as BoxDecoration?;
  }

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('DatePicker', () {
    test('six weeks from the first day of the week', () {
      final days = DatePicker.daysOf(november, DateTime.monday);
      expect(days, hasLength(42));
      expect(days.first, DateTime(2026, 10, 26));
      expect(days[6], DateTime(2026, 11));
      expect(days.last, DateTime(2026, 12, 6));
      expect(
        DatePicker.daysOf(november, DateTime.sunday).first,
        DateTime(2026, 11),
      );
    });

    testWidgets('the drawing: 260 px surface, month, weekdays, grid, note', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(picker(value: DateTime(2026, 11))));
      final surface = find
          .descendant(
            of: find.byType(DatePicker),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(surface).width, DatePicker.width);
      final decoration =
          tester.widget<Container>(surface).decoration! as BoxDecoration;
      expect(decoration.boxShadow, FermanTheme.light.elevation.shadowPopover);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(8)),
      );
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Mo'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Mo')).style!.color,
        light.textTertiary,
      );
      expect(find.text('Format DD.MM.YYYY · from the form'), findsOneWidget);
      expect(find.byKey(const Key('today')), findsOneWidget);
      // The first cell is 26 October, outside the month.
      expect(
        tester.widget<Text>(find.text('26').first).style!.color,
        light.textDisabled,
      );
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('26').first,
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        DatePicker.dayHeight,
      );
    });

    testWidgets('the selected day: accent, on-accent semibold', (tester) async {
      await tester.pumpWidget(componentHost(picker(value: DateTime(2026, 11))));
      // "1" appears for 1 November and 1 December; the first is November.
      expect(cellOf(tester, '1')?.color, light.accent);
      final text = tester.widget<Text>(find.text('1').first);
      expect(text.style!.color, light.textOnAccent);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(cellOf(tester, '2')?.color, isNull);
    });

    testWidgets('a click chooses a day', (tester) async {
      final chosen = <DateTime>[];
      await tester.pumpWidget(componentHost(picker(onChanged: chosen.add)));
      await tester.tap(find.text('15'));
      expect(chosen, [DateTime(2026, 11, 15)]);
    });

    testWidgets('keyboard: arrows, Home, End, PageDown, Enter, Escape', (
      tester,
    ) async {
      final chosen = <DateTime>[];
      final months = <DateTime>[];
      var dismissed = 0;
      await tester.pumpWidget(
        componentHost(
          picker(
            value: DateTime(2026, 11, 4),
            onChanged: chosen.add,
            onMonthChanged: months.add,
            onDismiss: () => dismissed++,
            autofocus: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Color? ringOn(String day) {
        final container = tester.widget<Container>(
          find
              .ancestor(
                of: find.text(day).first,
                matching: find.byType(Container),
              )
              .first,
        );
        final foreground = container.foregroundDecoration as BoxDecoration?;
        return (foreground?.border as Border?)?.top.color;
      }

      expect(ringOn('4'), FermanTheme.light.focus.focusRingInset.color);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(ringOn('5'), isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(ringOn('12'), isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(ringOn('9'), isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(ringOn('15'), isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(ringOn('8'), isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(ringOn('7'), isNotNull);
      expect(ringOn('8'), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(ringOn('15'), isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(chosen, [DateTime(2026, 11, 15)]);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(months, [DateTime(2026, 12)]);
      // Back to November (the shown month), then to October.
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(months, [DateTime(2026, 12), DateTime(2026, 10)]);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissed, 1);
    });

    testWidgets('right to left: ArrowLeft moves to the next day', (
      tester,
    ) async {
      final chosen = <DateTime>[];
      await tester.pumpWidget(
        componentHost(
          picker(
            value: DateTime(2026, 11, 4),
            onChanged: chosen.add,
            autofocus: true,
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(chosen, [DateTime(2026, 11, 5)]);
      // Monday sits on the right.
      expect(
        tester.getCenter(find.text('Mo')).dx,
        greaterThan(tester.getCenter(find.text('Su')).dx),
      );
    });

    testWidgets('a month step keeps the day within the month: 31 January '
        'to 28 February', (tester) async {
      final chosen = <DateTime>[];
      final months = <DateTime>[];
      await tester.pumpWidget(
        componentHost(
          picker(
            month: DateTime(2026),
            value: DateTime(2026, 1, 31),
            onChanged: chosen.add,
            onMonthChanged: months.add,
            autofocus: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(months, [DateTime(2026, 2)]);
      expect(chosen, [DateTime(2026, 2, 28)]);
    });

    testWidgets('semantics: the day with keyboard focus is focused, and moves '
        'with the arrows', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(picker(value: DateTime(2026, 11, 4), autofocus: true)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('4').first),
        isSemantics(isFocusable: true, isFocused: true, isButton: true),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        tester.getSemantics(find.text('5').first),
        isSemantics(isFocusable: true, isFocused: true),
      );
      expect(
        tester.getSemantics(find.text('4').first),
        isSemantics(isFocusable: true, isFocused: false),
      );
      handle.dispose();
    });

    testWidgets('moving out of the month asks for the next month', (
      tester,
    ) async {
      final months = <DateTime>[];
      await tester.pumpWidget(
        componentHost(
          picker(
            value: DateTime(2026, 11, 30),
            onMonthChanged: months.add,
            autofocus: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(months, [DateTime(2026, 12)]);
    });

    testWidgets('the region’s digits; first day of the week Sunday', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          picker(region: Region.forCode('SA'), firstDayOfWeek: DateTime.sunday),
        ),
      );
      expect(find.text('١٥'), findsOneWidget);
      expect(find.text('٢٠٢٦', findRichText: true), findsNothing);
      expect(find.textContaining('٢٠٢٦'), findsOneWidget);
      final names = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ExcludeSemantics),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .take(7)
          .toList();
      expect(names.first, 'Su');
    });

    testWidgets('default names come from the UI language', (tester) async {
      await tester.pumpWidget(
        componentHost(
          DatePicker(month: november, region: Region.turkiye),
          locale: const Locale('tr'),
        ),
      );
      expect(find.text('Kasım 2026'), findsOneWidget);
    });

    testWidgets('semantics: a dialog; days named by the full date', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(picker(value: DateTime(2026, 11))));
      expect(find.bySemanticsLabel('Choose a date'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Choose a date')),
        isSemantics(
          label: 'Choose a date',
          scopesRoute: true,
          namesRoute: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('1').first),
        isSemantics(
          label: 'Sunday, November 1, 2026',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          picker(value: DateTime(2026, 11)),
          brightness: Brightness.dark,
        ),
      );
      expect(cellOf(tester, '1')?.color, FermanTheme.dark.colors.accent);
    });
  });
}
