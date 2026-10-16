import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/number_stepper.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;
  final saudi = Region.forCode('SA');
  final germany = Region.forCode('DE');
  final france = Region.forCode('FR');

  group('NumberStepper.parse', () {
    test('either decimal separator', () {
      for (final region in [Region.turkiye, Region.unitedStates, germany]) {
        expect(NumberStepper.parse('10,5', region), 10.5);
        expect(NumberStepper.parse('10.5', region), 10.5);
      }
    });

    test('grouping as the region writes it', () {
      expect(NumberStepper.parse('1.234,5', Region.turkiye), 1234.5);
      expect(NumberStepper.parse('1,234.5', Region.unitedStates), 1234.5);
      expect(NumberStepper.parse('1.234', Region.turkiye), 1234);
      expect(NumberStepper.parse('1,234', Region.unitedStates), 1234);
      expect(NumberStepper.parse('1.234', Region.unitedStates), 1.234);
      expect(NumberStepper.parse('1.234.567', Region.turkiye), 1234567);
      expect(NumberStepper.parse('1 234,5', france), 1234.5);
    });

    test('region and Arabic digits, the Arabic separators, a unit', () {
      expect(NumberStepper.parse('١٠٫٥', saudi), 10.5);
      expect(NumberStepper.parse('١٬٢٣٤٫٥', saudi), 1234.5);
      expect(NumberStepper.parse('۱۰٫۵', saudi), 10.5);
      expect(NumberStepper.parse('10,5 pt', Region.turkiye, unit: 'pt'), 10.5);
      expect(NumberStepper.parse('10,5 pt', Region.turkiye, unit: 'pt'), 10.5);
      expect(NumberStepper.parse('10,5pt', Region.turkiye, unit: 'pt'), 10.5);
      expect(NumberStepper.parse('10,5 pt', Region.turkiye), isNull);
      expect(
        NumberStepper.parse('10,5 px', Region.turkiye, unit: 'pt'),
        isNull,
      );
    });

    test('grouping must be well formed; a typo is not a number', () {
      final india = Region.forCode('IN');
      expect(NumberStepper.parse('10..5', Region.unitedStates), isNull);
      expect(NumberStepper.parse('1.2.3', Region.turkiye), isNull);
      expect(NumberStepper.parse('10 5', Region.unitedStates), isNull);
      expect(NumberStepper.parse('10 5', france), isNull);
      expect(NumberStepper.parse('1,2,34', Region.unitedStates), isNull);
      expect(NumberStepper.parse('1.234.56', germany), isNull);
      expect(NumberStepper.parse('0.500.000', Region.turkiye), isNull);
      // With no decimal separator the last group may be a fraction
      // ("1,234,56" may mean 1234.56), so it is not read.
      expect(NumberStepper.parse('1,234,56', Region.unitedStates), isNull);
      expect(NumberStepper.parse('12,34,56', india), isNull);
      expect(NumberStepper.parse('1 2,5', Region.unitedStates), isNull);
    });

    test('around a certain decimal separator, groups of any length read', () {
      // One digit added to or taken from the integer part of a grouped
      // value the field shows: the decimal is certain (both kinds, the
      // Arabic decimal sign, or a lone mark that is not the region's
      // group separator), so the integer part means one number.
      expect(NumberStepper.parse('1.34,5', germany), 134.5);
      expect(NumberStepper.parse('1.1907,6', Region.turkiye), 11907.6);
      expect(NumberStepper.parse('12.34,5', Region.turkiye), 1234.5);
      expect(NumberStepper.parse('١٬٢٣٫٥', saudi), 123.5);
      expect(NumberStepper.parse('1\u202F34,5', france), 134.5);
      expect(NumberStepper.parse("1'2347.5", Region.forCode('CH')), 12347.5);
      // Still no empty group (a doubled mark) and no leading 0.
      expect(NumberStepper.parse('1..234,5', germany), isNull);
      expect(NumberStepper.parse('1.,5', Region.unitedStates), isNull);
      expect(NumberStepper.parse('0.234,5', germany), isNull);
    });

    test('a lone group separator that groups nothing is the decimal', () {
      expect(NumberStepper.parse('0.500', Region.turkiye), 0.5);
      expect(NumberStepper.parse('0,500', Region.unitedStates), 0.5);
      expect(NumberStepper.parse('12,5', Region.unitedStates), 12.5);
      expect(NumberStepper.parse('1234,5', Region.unitedStates), 1234.5);
      expect(NumberStepper.parse(',567', Region.unitedStates), 0.567);
    });

    test('a lone region group separator after four digits and before three '
        'is not a number', () {
      // "1,234,567" with a separator deleted, or a decimal: 1000 times
      // apart, so neither is guessed.
      expect(NumberStepper.parse('1234,567', Region.unitedStates), isNull);
      expect(NumberStepper.parse('1234,567', Region.forCode('IN')), isNull);
      expect(NumberStepper.parse('1234.567', Region.turkiye), isNull);
      // Not the region's group separator: the decimal.
      expect(NumberStepper.parse('1234.567', Region.unitedStates), 1234.567);
      expect(NumberStepper.parse('1234,567', Region.turkiye), 1234.567);
    });

    test('a group separator before the first digit is ignored', () {
      // What deleting the leading digit of a grouped value leaves.
      expect(NumberStepper.parse('.234,5', germany), 234.5);
      expect(NumberStepper.parse(',234.5', Region.unitedStates), 234.5);
      expect(NumberStepper.parse(',234,567', Region.unitedStates), 234567);
      expect(NumberStepper.parse('.234,567', Region.unitedStates), 234.567);
      expect(NumberStepper.parse('٬٢٣٤٫٥', saudi), 234.5);
      expect(NumberStepper.parse('٬٢٣٤', saudi), 234);
      // Only one.
      expect(NumberStepper.parse(',,234', Region.unitedStates), isNull);
      expect(NumberStepper.parse('.234.', Region.unitedStates), isNull);
    });

    test('a space beside a separator is spacing; a run of spaces is one '
        'group separator', () {
      expect(NumberStepper.parse('10 ,5', Region.turkiye), 10.5);
      expect(NumberStepper.parse('10, 5', Region.unitedStates), 10.5);
      expect(NumberStepper.parse('10 .5', Region.unitedStates), 10.5);
      expect(NumberStepper.parse('١٠ ٫٥', saudi), 10.5);
      expect(NumberStepper.parse('10 ٫ 5', saudi), 10.5);
      expect(NumberStepper.parse('1  234', france), 1234);
      expect(NumberStepper.parse('1 \u00A0234', france), 1234);
      expect(NumberStepper.parse('1 234 ,5', france), 1234.5);
      expect(NumberStepper.parse('1 ,234', Region.unitedStates), 1234);
      expect(NumberStepper.parse('1 ,234', Region.turkiye), 1.234);
      expect(NumberStepper.parse('10 ,5 pt', Region.turkiye, unit: 'pt'), 10.5);
      // Two plain groups are still not a number, nor a doubled mark.
      expect(NumberStepper.parse('12 34', france), isNull);
      expect(NumberStepper.parse('10 ,, 5', Region.unitedStates), isNull);
      expect(NumberStepper.parse('1 . 2 . 3', Region.turkiye), isNull);
    });

    test('well-formed grouping still reads', () {
      final india = Region.forCode('IN');
      expect(NumberStepper.parse('12,34,567', india), 1234567);
      expect(NumberStepper.parse('1,234,567', india), 1234567);
      expect(NumberStepper.parse('1 234,5', france), 1234.5);
      expect(NumberStepper.parse('1\u202F234,5', france), 1234.5);
      expect(NumberStepper.parse("1'234.5", Region.forCode('CH')), 1234.5);
      expect(NumberStepper.parse('− 2,5', Region.turkiye), -2.5);
      expect(NumberStepper.parse('1.234.567,25', germany), 1234567.25);
    });

    test('a digit string too long for a double is not a number', () {
      expect(NumberStepper.parse('9' * 400, Region.unitedStates), isNull);
    });

    test('a leading minus, with direction marks', () {
      expect(NumberStepper.parse('-2', Region.turkiye), -2);
      expect(NumberStepper.parse('− 2,5', Region.turkiye), -2.5);
      expect(NumberStepper.parse('؜-٢', saudi), -2);
    });

    test('not a number', () {
      for (final text in ['', 'abc', '1-2', '1,2,3.4.5', '1e5', 'NaN', '--1']) {
        expect(NumberStepper.parse(text, Region.unitedStates), isNull);
      }
    });
  });

  group('NumberStepper.commitValue', () {
    test('rounds to the step, clamps and fixes the precision', () {
      expect(
        NumberStepper.commitValue(
          10.26,
          step: 0.5,
          min: 1,
          max: 96,
          precision: 1,
        ),
        10.5,
      );
      expect(
        NumberStepper.commitValue(200, step: 1, min: 1, max: 96, precision: 0),
        96,
      );
      expect(
        NumberStepper.commitValue(
          0.1 + 0.2,
          step: 0.1,
          min: double.negativeInfinity,
          max: double.infinity,
          precision: 1,
        ),
        0.3,
      );
    });
  });

  group('NumberStepper', () {
    Widget stepper({
      double value = 10.5,
      Region? region,
      ValueChanged<double>? onChanged,
      double min = 1,
      double max = 96,
      double step = 0.5,
      String? unit = 'pt',
      int precision = 1,
      FieldSize size = FieldSize.sm,
      bool disabled = false,
      String? label = 'Size',
      FocusNode? focusNode,
    }) => NumberStepper(
      value: value,
      region: region ?? Region.turkiye,
      onChanged: onChanged ?? (_) {},
      min: min,
      max: max,
      step: step,
      unit: unit,
      precision: precision,
      size: size,
      disabled: disabled,
      label: label,
      focusNode: focusNode,
    );

    String shown(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText)).controller.text;

    setUp(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    });

    tearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    testWidgets('shows the value in the region format with the precision', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(stepper()));
      expect(shown(tester), '10,5');
      await tester.pumpWidget(
        componentHost(stepper(region: Region.unitedStates, precision: 2)),
      );
      expect(shown(tester), '10.50');
      await tester.pumpWidget(componentHost(stepper(region: saudi)));
      expect(shown(tester), '١٠٫٥');
    });

    testWidgets('84 px wide, small box, unit and arrows', (tester) async {
      await tester.pumpWidget(componentHost(stepper()));
      expect(tester.getSize(find.byType(NumberStepper)).width, 84);
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 26);
      final unit = tester.widget<Text>(find.text('pt'));
      expect(unit.style!.color, light.textTertiary);
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.map((i) => i.name), [
        IconName.chevronUp,
        IconName.chevronDown,
      ]);
      expect(icons.first.size, 11);
      expect(icons.first.strokeWidth, 2);
      expect(icons.first.color, light.iconSecondary);
      final arrow = find.ancestor(
        of: find.byWidget(icons.first),
        matching: find.byType(Container),
      );
      expect(tester.getSize(arrow.first).width, NumberStepper.arrowWidth);
    });

    testWidgets('the arrows step and commit', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(componentHost(stepper(onChanged: values.add)));
      await tester.tap(find.byType(Icon).first);
      await tester.tap(find.byType(Icon).last);
      expect(values, [11, 10]);
    });

    testWidgets('an arrow is disabled at its limit', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(
        componentHost(stepper(value: 96, onChanged: values.add)),
      );
      final up = tester.widgetList<Icon>(find.byType(Icon)).first;
      expect(up.color, light.iconDisabled);
      await tester.tap(find.byType(Icon).first);
      expect(values, isEmpty);
    });

    testWidgets('arrow hover and press tints', (tester) async {
      await tester.pumpWidget(componentHost(stepper()));
      final arrow = find
          .ancestor(
            of: find.byType(Icon).first,
            matching: find.byType(Container),
          )
          .first;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(arrow));
      await tester.pump();
      Color? background() =>
          (tester.widget<Container>(arrow).decoration as BoxDecoration?)
              ?.color ??
          tester.widget<Container>(arrow).color;
      expect(background(), light.surfaceHover);
      await mouse.down(tester.getCenter(arrow));
      await tester.pump();
      expect(background(), light.surfacePressed);
      await mouse.up();
    });

    testWidgets('ArrowUp and ArrowDown step; Shift takes ten steps', (
      tester,
    ) async {
      final values = <double>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(stepper(onChanged: values.add, focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(
        ((tester
                            .widget<AnimatedContainer>(
                              find.byKey(FieldBox.boxKey),
                            )
                            .decoration!
                        as BoxDecoration)
                    .border!
                as Border)
            .top
            .color,
        light.borderFocus,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(values, [11, 10, 15.5]);
    });

    testWidgets('a typed draft commits on Enter, rounded and clamped', (
      tester,
    ) async {
      final values = <double>[];
      var value = 10.5;
      // An owner that keeps the committed value.
      await tester.pumpWidget(
        componentHost(
          StatefulBuilder(
            builder: (context, setState) => stepper(
              value: value,
              onChanged: (next) {
                values.add(next);
                setState(() => value = next);
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '12.3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(values, [12.5]);
      expect(shown(tester), '12,5');
      await tester.enterText(find.byType(EditableText), '500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(values, [12.5, 96]);
      expect(shown(tester), '96,0');
    });

    testWidgets('controlled: an owner that keeps its value is shown as it '
        'is', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(componentHost(stepper(onChanged: values.add)));
      await tester.enterText(find.byType(EditableText), '12.3');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(values, [12.5]);
      expect(shown(tester), '10,5');
      await tester.tap(find.byType(Icon).first);
      await tester.pump();
      expect(values, [12.5, 11]);
      expect(shown(tester), '10,5');
    });

    testWidgets('a digit taken from a grouped value it shows commits the '
        'edited number', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(
        componentHost(
          stepper(
            value: 1234.5,
            region: germany,
            max: double.infinity,
            step: 0.1,
            onChanged: values.add,
          ),
        ),
      );
      expect(shown(tester), '1.234,5');
      // The 2 deleted.
      await tester.enterText(find.byType(EditableText), '1.34,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(values, [134.5]);
    });

    testWidgets('an overlong draft is dropped without an error', (
      tester,
    ) async {
      final values = <double>[];
      await tester.pumpWidget(componentHost(stepper(onChanged: values.add)));
      await tester.enterText(find.byType(EditableText), '9' * 400);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(values, isEmpty);
      expect(shown(tester), '10,5');
    });

    testWidgets('semantics: the draft is the value while typing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(stepper()));
      await tester.enterText(find.byType(EditableText), '12');
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'Size', value: '12\u00a0pt', isTextField: true),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(label: 'Size', value: '10,5\u00a0pt', isTextField: true),
      );
      handle.dispose();
    });

    testWidgets('the arrows: a 1 px subtle line between them, behind a 1 px '
        'border outside their 18 px', (tester) async {
      await tester.pumpWidget(componentHost(stepper()));
      final line = find.descendant(
        of: find.byType(NumberStepper),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == light.borderSubtle,
        ),
      );
      expect(tester.getSize(line), const Size(18, 1));
      final column = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border is BorderDirectional,
      );
      final arrows = tester.getRect(column);
      expect(arrows.width, NumberStepper.arrowWidth + 1);
      final up = tester.getRect(
        find
            .ancestor(
              of: find.byType(Icon).first,
              matching: find.byType(Container),
            )
            .first,
      );
      // The hover fill starts after the border.
      expect(up.left, arrows.left + 1);
      expect(up.width, NumberStepper.arrowWidth);
    });

    testWidgets('a click on the label focuses the field', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        TapRegionSurface(child: componentHost(stepper(focusNode: node))),
      );
      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('a draft commits when focus leaves; a bad draft is dropped', (
      tester,
    ) async {
      final values = <double>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(stepper(onChanged: values.add, focusNode: node)),
      );
      await tester.enterText(find.byType(EditableText), '8,5');
      node.unfocus();
      await tester.pump();
      expect(values, [8.5]);
      await tester.enterText(find.byType(EditableText), 'abc');
      node.unfocus();
      await tester.pump();
      expect(values, [8.5]);
      expect(shown(tester), '10,5');
    });

    testWidgets('a new value from the owner updates the text', (tester) async {
      await tester.pumpWidget(componentHost(stepper()));
      await tester.pumpWidget(componentHost(stepper(value: 14)));
      expect(shown(tester), '14,0');
    });

    testWidgets('medium size', (tester) async {
      await tester.pumpWidget(componentHost(stepper(size: FieldSize.md)));
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 30);
    });

    testWidgets('disabled: no steps, disabled arrows and text', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(
        componentHost(stepper(onChanged: values.add, disabled: true)),
      );
      await tester.tap(find.byType(Icon).first, warnIfMissed: false);
      expect(values, isEmpty);
      final icons = tester.widgetList<Icon>(find.byType(Icon));
      expect(icons.every((i) => i.color == light.iconDisabled), isTrue);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.style.color, light.textDisabled);
    });

    testWidgets('semantics: label, formatted value with unit, increase and '
        'decrease', (tester) async {
      final handle = tester.ensureSemantics();
      final values = <double>[];
      await tester.pumpWidget(componentHost(stepper(onChanged: values.add)));
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Size',
          value: '10,5 pt',
          increasedValue: '11,0 pt',
          decreasedValue: '10,0 pt',
          isTextField: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.increase(find.semantics.byLabel('Size'));
      expect(values, [11]);
      handle.dispose();
    });

    testWidgets('right to left: arrows on the left', (tester) async {
      await tester.pumpWidget(
        componentHost(stepper(), textDirection: TextDirection.rtl),
      );
      final box = tester.getRect(find.byKey(FieldBox.boxKey));
      expect(
        tester.getRect(find.byType(Icon).first).center.dx,
        lessThan(box.left + NumberStepper.arrowWidth + 1),
      );
    });
  });
}
