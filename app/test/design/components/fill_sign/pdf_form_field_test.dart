import 'dart:ui' show SemanticsValidationResult;

import 'package:ferman/design/components/fill_sign/pdf_form_field.dart';
import 'package:ferman/design/components/overlays/menu.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const page = FermanPageColors();
  const ramps = FermanRamps();
  final box = find.byKey(const ValueKey<String>('PdfFormField.box'));
  final asterisk = find.byKey(const ValueKey<String>('PdfFormField.required'));
  final error = find.byKey(const ValueKey<String>('PdfFormField.error'));

  BoxDecoration boxOf(WidgetTester tester) =>
      tester.widget<Container>(box).decoration! as BoxDecoration;

  Color borderOf(WidgetTester tester) =>
      (boxOf(tester).border! as Border).top.color;

  /// The foreground painter around the box: the read-only dotted line or
  /// the signature's dashes.
  RenderObject linePainterOf(WidgetTester tester) => tester.renderObject(
    find.ancestor(of: box, matching: find.byType(CustomPaint)).first,
  );

  /// Expects the read-only dotted bottom line: 1 px squares 2 px apart.
  void expectDottedLine(WidgetTester tester) {
    final height = tester.getSize(box).height;
    final dots = <Rect>[];
    expect(
      linePainterOf(tester),
      paints..everything((method, arguments) {
        if (method == #drawRect &&
            (arguments[1] as Paint).color.toARGB32() ==
                ramps.paper400.toARGB32()) {
          dots.add(arguments.first as Rect);
        }
        return true;
      }),
    );
    expect(dots.length, greaterThan(3));
    expect(dots.first, Rect.fromLTWH(0, height - 1, 1, 1));
    expect(dots[1].left - dots[0].left, 2);
  }

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('PdfFormField looks', () {
    testWidgets('empty text field: the form-field tint, 22 px, 160 wide', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const PdfFormField(label: 'Adı', required: true)),
      );
      expect(boxOf(tester).color, page.formFieldBg);
      expect(borderOf(tester), page.formFieldBorder);
      expect(tester.getSize(box), const Size(160, PdfFormField.boxHeight));
      final label = tester.widget<Text>(find.text('Adı'));
      expect(label.style!.fontSize, PdfFormField.labelFontSize);
      expect(label.style!.color, ramps.paper600);
      expect(asterisk, findsOneWidget);
      final star = tester.getRect(asterisk);
      final field = tester.getRect(box);
      // From the padding edge, inside the 1 px border.
      expect(star.top, field.top - (PdfFormField.asteriskTop - 1));
      expect(star.right, field.right + (PdfFormField.asteriskEnd - 1));
    });

    testWidgets('hover strengthens an empty border only', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(label: 'Adı'),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(borderOf(tester), ramps.ink400);
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(label: 'Adı', value: 'AYŞE'),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(borderOf(tester), PdfFormField.filledBorder);
    });

    testWidgets('focus: white, the focus border and the ink ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(state: PdfFormFieldState.focus, value: 'AYŞ'),
        ),
      );
      expect(boxOf(tester).color, PdfFormField.focusFill);
      expect(borderOf(tester), page.formFieldFocus);
      expect(boxOf(tester).boxShadow, const [
        BoxShadow(
          color: PdfFormField.focusRing,
          spreadRadius: PdfFormField.ringWidth,
        ),
      ]);
    });

    testWidgets('filled: the fainter tint', (tester) async {
      await tester.pumpWidget(
        componentHost(const PdfFormField(value: '13.10.2026')),
      );
      expect(boxOf(tester).color, PdfFormField.filledFill);
      expect(borderOf(tester), PdfFormField.filledBorder);
    });

    testWidgets('error: red border and ring, the message with its glyph', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            label: 'T.C. Kimlik No',
            value: '4123987651',
            error: 'Enter all 11 digits.',
          ),
        ),
      );
      expect(borderOf(tester), ramps.red600);
      expect(boxOf(tester).color, PdfFormField.errorFill);
      expect(boxOf(tester).boxShadow!.single.color, PdfFormField.errorRing);
      expect(error, findsOneWidget);
      expect(find.text('Enter all 11 digits.'), findsOneWidget);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: error, matching: find.byType(Icon)),
            )
            .name,
        IconName.circleAlert,
      );
    });

    testWidgets('read-only: a dotted line under the value', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            state: PdfFormFieldState.readonly,
            value: '2026-0047812',
          ),
        ),
      );
      // A transparent 1 px border all round (the content stays put), the
      // dotted line drawn over the bottom one.
      expect(boxOf(tester).border, Border.all(color: const Color(0x00000000)));
      expect(boxOf(tester).borderRadius, isNull);
      expect(boxOf(tester).color, isNull);
      expectDottedLine(tester);
      expect(find.text('2026-0047812'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('read-only dropdown and checkbox: the dotted line too', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            type: PdfFormFieldType.dropdown,
            state: PdfFormFieldState.readonly,
            value: 'İSTANBUL',
          ),
        ),
      );
      expectDottedLine(tester);
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            type: PdfFormFieldType.checkbox,
            state: PdfFormFieldState.readonly,
            checked: true,
          ),
        ),
      );
      expect(boxOf(tester).border, Border.all(color: const Color(0x00000000)));
      expectDottedLine(tester);
      // Not in the other looks.
      await tester.pumpWidget(componentHost(const PdfFormField()));
      expect(linePainterOf(tester), isNot(paints..rect()));
    });

    testWidgets('page-tuned: the same colours in the dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const PdfFormField(), brightness: Brightness.dark),
      );
      expect(boxOf(tester).color, page.formFieldBg);
    });

    testWidgets('right to left: the asterisk at the top-start corner', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(required: true),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getRect(asterisk).left,
        tester.getRect(box).left - (PdfFormField.asteriskEnd - 1),
      );
    });
  });

  group('PdfFormField text and date', () {
    testWidgets('editable: typing reports the text; focus shows the look', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            label: 'Adı',
            value: 'AYŞE',
            placeholder: 'Adınız',
            onChanged: changes.add,
          ),
        ),
      );
      expect(borderOf(tester), PdfFormField.filledBorder);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(borderOf(tester), page.formFieldFocus);
      await tester.enterText(find.byType(EditableText), 'AYŞEGÜL');
      expect(changes, ['AYŞEGÜL']);
      final value = tester.widget<EditableText>(find.byType(EditableText));
      expect(value.style.fontFamily, FermanTypeTokens.fontDocSample.family);
      expect(value.style.fontSize, PdfFormField.valueFontSize);
    });

    testWidgets('placeholder in the UI face at 11 px', (tester) async {
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.date,
            placeholder: 'GG.AA.YYYY',
            onChanged: (_) {},
          ),
        ),
      );
      final placeholder = tester.widget<Text>(find.text('GG.AA.YYYY'));
      expect(placeholder.style!.fontSize, PdfFormField.placeholderFontSize);
      expect(placeholder.style!.color, ramps.paper500);
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.calendar);
    });

    testWidgets('multiline: three 16 px rows, 60 px in every look', (
      tester,
    ) async {
      const lines =
          'Birinci satır\nİkinci satır\nÜçüncü satır\nDördüncü\nBeşinci';
      await tester.pumpWidget(
        componentHost(
          PdfFormField(type: PdfFormFieldType.multiline, onChanged: (_) {}),
        ),
      );
      expect(tester.getSize(box).height, 60);
      final editor = tester.widget<EditableText>(find.byType(EditableText));
      expect(editor.maxLines, PdfFormField.multilineRows);
      expect(editor.minLines, PdfFormField.multilineRows);
      expect(
        editor.style.height! * editor.style.fontSize!,
        closeTo(PdfFormField.multilineLineHeight, 1e-9),
      );
      // More lines scroll inside; the box stays.
      await tester.enterText(find.byType(EditableText), lines);
      await tester.pump();
      expect(tester.getSize(box).height, 60);
      // Read-only and not editable: the same box and line height.
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            type: PdfFormFieldType.multiline,
            state: PdfFormFieldState.readonly,
            value: lines,
          ),
        ),
      );
      expect(tester.getSize(box).height, 60);
      final text = tester.widget<Text>(find.text(lines));
      expect(text.maxLines, PdfFormField.multilineRows);
      expect(
        text.style!.height! * text.style!.fontSize!,
        closeTo(PdfFormField.multilineLineHeight, 1e-9),
      );
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(type: PdfFormFieldType.multiline, value: 'Kısa'),
        ),
      );
      expect(tester.getSize(box).height, 60);
    });

    testWidgets('semantics: label, required, error as hint, invalid', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            label: 'Tarih',
            required: true,
            value: '31.02.2026',
            error: 'February has 28 days in 2026.',
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(EditableText)),
        isSemantics(
          label: 'Tarih',
          hint: 'February has 28 days in 2026.',
          isTextField: true,
          isRequired: true,
          validationResult: SemanticsValidationResult.invalid,
        ),
      );
      handle.dispose();
    });
  });

  group('PdfFormField dropdown', () {
    testWidgets('shows the placeholder, opens the options, reports a choice', (
      tester,
    ) async {
      final chosen = <String>[];
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.dropdown,
            label: 'İl',
            placeholder: 'Seçiniz',
            options: const ['ANKARA', 'İSTANBUL', 'İZMİR'],
            onChanged: chosen.add,
          ),
        ),
      );
      expect(find.text('Seçiniz'), findsOneWidget);
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.chevronDown);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(find.byType(Menu), findsOneWidget);
      await tester.tap(find.text('İZMİR'));
      await tester.pumpAndSettle();
      expect(chosen, ['İZMİR']);
      expect(find.byType(Menu), findsNothing);
    });

    testWidgets('Enter opens it from the keyboard; read-only never opens', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.dropdown,
            options: const ['A', 'B'],
            focusNode: node,
            onChanged: (_) {},
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(Menu), findsOneWidget);
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.dropdown,
            state: PdfFormFieldState.readonly,
            value: 'A',
            options: const ['A', 'B'],
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(find.byType(Menu), findsNothing);
    });

    testWidgets('semantics: focusable and focused while it can open', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.dropdown,
            label: 'İl',
            options: const ['A', 'B'],
            focusNode: node,
            onChanged: (_) {},
          ),
        ),
      );
      expect(
        tester.getSemantics(box),
        isSemantics(label: 'İl', isFocusable: true, isFocused: false),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(box),
        isSemantics(isFocusable: true, isFocused: true),
      );
      // Without a handler it cannot open, nor take focus.
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            type: PdfFormFieldType.dropdown,
            label: 'İl',
            options: ['A', 'B'],
          ),
        ),
      );
      expect(tester.getSemantics(box), isSemantics(isFocusable: false));
      handle.dispose();
    });
  });

  group('PdfFormField checkbox and radio', () {
    testWidgets('checkbox: 16 px box with a check; Space toggles, not Enter', (
      tester,
    ) async {
      var presses = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.checkbox,
            label: 'Beyan',
            checked: true,
            focusNode: node,
            onPressed: () => presses++,
          ),
        ),
      );
      expect(tester.getSize(box), const Size.square(PdfFormField.checkSize));
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.check);
      expect(boxOf(tester).color, PdfFormField.filledFill);
      await tester.tap(box);
      expect(presses, 1);
      expect(
        tester.getSemantics(box),
        isSemantics(label: 'Beyan', hasCheckedState: true, isChecked: true),
      );
      handle.dispose();
    });

    testWidgets('Space toggles; Enter does not, even with the app shortcuts', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final type in [PdfFormFieldType.checkbox, PdfFormFieldType.radio]) {
        var presses = 0;
        final node = FocusNode();
        addTearDown(node.dispose);
        // The app's shortcuts map Enter and NumpadEnter to ActivateIntent.
        await tester.pumpWidget(
          componentHost(
            Shortcuts(
              shortcuts: WidgetsApp.defaultShortcuts,
              child: Actions(
                actions: WidgetsApp.defaultActions,
                child: PdfFormField(
                  type: type,
                  label: 'Beyan',
                  focusNode: node,
                  onPressed: () => presses++,
                ),
              ),
            ),
          ),
        );
        node.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
        expect(presses, 0, reason: '$type');
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(presses, 1, reason: '$type');
        expect(
          tester.getSemantics(box),
          isSemantics(isFocusable: true, isFocused: true),
        );
      }
      handle.dispose();
    });

    testWidgets('radio: a circle with a dot, in a group', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.radio,
            label: 'Kadın',
            checked: true,
            onPressed: () {},
          ),
        ),
      );
      expect(boxOf(tester).shape, BoxShape.circle);
      expect(
        tester.getSemantics(box),
        isSemantics(
          label: 'Kadın',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('error: the message without a glyph', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            type: PdfFormFieldType.checkbox,
            required: true,
            error: 'Required to submit.',
          ),
        ),
      );
      expect(find.text('Required to submit.'), findsOneWidget);
      expect(
        find.descendant(of: error, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(borderOf(tester), ramps.red600);
      // 4 px under the box (`a5-2b`: `display:grid;gap:4px`), where text
      // fields keep the `.fm-pff` 3 px gap.
      expect(
        tester.getTopLeft(error).dy - tester.getBottomLeft(box).dy,
        FermanSpaceTokens.space1,
      );
      await tester.pumpWidget(
        componentHost(const PdfFormField(error: 'Enter all 11 digits.')),
      );
      expect(
        tester.getTopLeft(error).dy - tester.getBottomLeft(box).dy,
        PdfFormField.gap,
      );
    });
  });

  group('PdfFormField signature', () {
    testWidgets('unsigned: a dashed box with the call to action', (
      tester,
    ) async {
      var presses = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.signature,
            label: 'İmza',
            width: 150,
            signHereLabel: 'Sign here',
            focusNode: node,
            onPressed: () => presses++,
          ),
        ),
      );
      expect(
        tester.getSize(box),
        const Size(150, PdfFormField.signatureHeight),
      );
      expect(find.text('Sign here'), findsOneWidget);
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.signature);
      expect(
        tester.renderObject(
          find.ancestor(of: box, matching: find.byType(CustomPaint)).first,
        ),
        paints..something((method, arguments) {
          if (method != #drawPath) return false;
          final paint = arguments[1] as Paint;
          return paint.strokeWidth == PdfFormField.signatureBorder &&
              paint.color.toARGB32() == page.formFieldBorder.toARGB32();
        }),
      );
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 2);
    });

    testWidgets('unsigned: the asterisk and the content inside the dashes', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.signature,
            required: true,
            width: 150,
            signHereLabel: 'Sign here',
            onPressed: () {},
          ),
        ),
      );
      const border = PdfFormField.signatureBorder;
      final field = tester.getRect(box);
      final star = tester.getRect(asterisk);
      expect(star.top, field.top - (PdfFormField.asteriskTop - border));
      expect(star.right, field.right + (PdfFormField.asteriskEnd - border));
      expect(
        tester.getTopLeft(find.byType(Icon)).dx - field.left,
        PdfFormField.signaturePaddingX + border,
      );
      // Signed: a 1 px solid border, which takes its own room.
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.signature,
            required: true,
            signedAs: 'Ayşe Yılmaz',
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getRect(asterisk).top,
        tester.getRect(box).top - (PdfFormField.asteriskTop - 1),
      );
      expect(
        tester.getTopLeft(find.text('Ayşe Yılmaz')).dx -
            tester.getRect(box).left,
        PdfFormField.signaturePaddingX + 1,
      );
    });

    testWidgets('read-only: the dotted line; solid once signed', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            type: PdfFormFieldType.signature,
            state: PdfFormFieldState.readonly,
            signHereLabel: 'Sign here',
          ),
        ),
      );
      final unsigned = boxOf(tester).border! as BorderDirectional;
      expect(unsigned.top.color, const Color(0x00000000));
      expect(unsigned.top.width, PdfFormField.signatureBorder);
      expect(unsigned.start.width, PdfFormField.signatureBorder);
      expect(unsigned.bottom.width, 1);
      expectDottedLine(tester);
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            type: PdfFormFieldType.signature,
            state: PdfFormFieldState.readonly,
            signedAs: 'M. Kaya',
          ),
        ),
      );
      final signed = boxOf(tester).border! as BorderDirectional;
      expect(signed.top, const BorderSide(color: Color(0x00000000)));
      expect(signed.bottom, BorderSide(color: ramps.paper400));
      expect(linePainterOf(tester), isNot(paints..rect()));
    });

    testWidgets('semantics: focusable and focused while it can sign', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.signature,
            signHereLabel: 'Sign here',
            focusNode: node,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(box),
        isSemantics(isFocusable: true, isFocused: false, hasFocusAction: true),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(box),
        isSemantics(isFocusable: true, isFocused: true),
      );
      await tester.pumpWidget(
        componentHost(
          const PdfFormField(
            type: PdfFormFieldType.signature,
            state: PdfFormFieldState.readonly,
            signHereLabel: 'Sign here',
          ),
        ),
      );
      expect(tester.getSemantics(box), isSemantics(isFocusable: false));
      handle.dispose();
    });

    testWidgets('signed: the name in the italic signature face', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          PdfFormField(
            type: PdfFormFieldType.signature,
            signedAs: 'Ayşe Yılmaz',
            semanticLabel: 'Signed by Ayşe Yılmaz',
            onPressed: () {},
          ),
        ),
      );
      final name = tester.widget<Text>(find.text('Ayşe Yılmaz'));
      expect(name.style!.fontStyle, FontStyle.italic);
      expect(name.style!.fontFamily, FermanTypeTokens.fontBrand.family);
      expect(name.style!.color, ramps.ink800);
      expect(borderOf(tester), PdfFormField.filledBorder);
      expect(
        tester.getSemantics(box),
        isSemantics(label: 'Signed by Ayşe Yılmaz', isButton: true),
      );
      handle.dispose();
    });
  });
}
