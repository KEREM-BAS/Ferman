import 'package:ferman/design/components/additions/fm_number.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;

  String shown(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  group('FmNumber', () {
    testWidgets('the board defaults: 10,5 pt, small, 84 px', (tester) async {
      await tester.pumpWidget(
        componentHost(const FmNumber(region: Region.turkiye)),
      );
      expect(shown(tester), '10,5');
      expect(find.text('pt'), findsOneWidget);
      expect(tester.getSize(find.byType(FmNumber)).width, 84);
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 26);
    });

    testWidgets('formats for the region, never the UI language (G34)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const FmNumber(region: Region.unitedStates),
          locale: const Locale('tr'),
        ),
      );
      expect(shown(tester), '10.5');
      await tester.pumpWidget(
        componentHost(
          FmNumber(region: Region.forCode('DE'), value: 1234.5, unit: 'mm'),
        ),
      );
      expect(shown(tester), '1.234,5');
    });

    testWidgets('Arabic, right to left: native digits, arrows on the left', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          FmNumber(region: Region.forCode('SA'), label: 'العربية'),
          locale: const Locale('ar'),
        ),
      );
      expect(shown(tester), '١٠٫٥');
      final box = tester.getRect(find.byKey(FieldBox.boxKey));
      expect(
        tester.getRect(find.byType(Icon).first).center.dx,
        lessThan(box.center.dx),
      );
      expect(
        tester.getTopRight(find.text('العربية')).dx,
        moreOrLessEquals(box.right),
      );
    });

    testWidgets('error: danger border and message', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const FmNumber(
            region: Region.turkiye,
            value: 0,
            error: 'Enter 4–96 pt.',
          ),
        ),
      );
      final border =
          ((tester
                              .widget<AnimatedContainer>(
                                find.byKey(FieldBox.boxKey),
                              )
                              .decoration!
                          as BoxDecoration)
                      .border!
                  as Border)
              .top
              .color;
      expect(border, light.danger);
      expect(find.text('Enter 4–96 pt.'), findsOneWidget);
      // FmNumber.dc.html draws the error as text only.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.circleAlert,
        ),
        findsNothing,
      );
    });

    testWidgets('the value in the body role (13 px), over the 12 px of a '
        'small field; the unit stays 12 px', (tester) async {
      await tester.pumpWidget(
        componentHost(const FmNumber(region: Region.turkiye)),
      );
      final style = tester
          .widget<EditableText>(find.byType(EditableText))
          .style;
      expect(style.fontSize, FermanTheme.light.typeScale.sizeMd);
      expect(style.fontSize, 13);
      expect(style.color, light.textPrimary);
      expect(
        style.fontFeatures,
        containsAll(FermanTheme.light.typeScale.numericTabular),
      );
      expect(tester.widget<Text>(find.text('pt')).style!.fontSize, 12);
      // Disabled keeps the size with the disabled colour.
      await tester.pumpWidget(
        componentHost(const FmNumber(region: Region.turkiye, disabled: true)),
      );
      final disabled = tester
          .widget<EditableText>(find.byType(EditableText))
          .style;
      expect(disabled.fontSize, 13);
      expect(disabled.color, light.textDisabled);
    });

    testWidgets('typing either separator commits (B003)', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(
        componentHost(
          FmNumber(region: Region.turkiye, onChanged: values.add, step: 0.1),
        ),
      );
      await tester.enterText(find.byType(EditableText), '12.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(find.byType(EditableText), '9,5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(values, [12.5, 9.5]);
    });

    testWidgets('ArrowUp steps; a commit rounds to the step, as the bundle '
        'does (10.5 + 1 rounds to 12)', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final values = <double>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          FmNumber(
            region: Region.turkiye,
            onChanged: values.add,
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(values, [12]);
    });

    testWidgets('semantics: label or semanticLabel, formatted value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          FmNumber(
            region: Region.turkiye,
            semanticLabel: 'Font size',
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Font size',
          value: '10,5 pt',
          isTextField: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
