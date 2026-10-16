import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/fill_sign/signature_pad.dart';
import 'package:ferman/design/components/forms/checkbox.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/navigation/segmented_control.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const page = FermanPageColors();
  const ramps = FermanRamps();

  const labels = SignaturePadLabels(
    method: 'Signature method',
    draw: 'Draw',
    type: 'Type',
    image: 'Image',
    drawingArea: 'Signature drawing area.',
    typeName: 'Type your name',
    namePlaceholder: 'Your name',
    drawHint: 'Sign above the line',
    typeHint: 'Type your name above the line',
    imageHint: 'Drop a photo or scan of your signature.',
    chooseImage: 'Choose image…',
    inkColor: 'Ink color',
    black: 'Black',
    blue: 'Blue',
    clear: 'Clear',
    saveOnDevice: 'Save on this device',
  );

  final area = find.byKey(const ValueKey<String>('SignaturePad.area'));
  final hint = find.byKey(const ValueKey<String>('SignaturePad.hint'));
  final strokes = find.byKey(const ValueKey<String>('SignaturePad.strokes'));

  Finder swatch(String name) => find.byWidgetPredicate(
    (w) => w is FermanInteractive && w.semanticLabel == name,
  );

  Button clearButton(WidgetTester tester) => tester.widget<Button>(
    find.ancestor(of: find.text('Clear'), matching: find.byType(Button)),
  );

  Widget pad({
    SignatureMode mode = SignatureMode.draw,
    ValueChanged<SignatureMode>? onModeChanged,
    String initialName = '',
    Color ink = SignaturePad.blackInk,
    ValueChanged<Color>? onInkChanged,
    bool saveForLater = true,
    ValueChanged<bool>? onSaveForLaterChanged,
    ValueChanged<SignatureValue>? onChanged,
    List<List<Offset>> initialStrokes = const [],
  }) => SizedBox(
    width: 520,
    child: SignaturePad(
      labels: labels,
      mode: mode,
      onModeChanged: onModeChanged,
      initialName: initialName,
      ink: ink,
      onInkChanged: onInkChanged,
      saveForLater: saveForLater,
      onSaveForLaterChanged: onSaveForLaterChanged,
      onChanged: onChanged,
      initialStrokes: initialStrokes,
    ),
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('SignaturePad draw', () {
    testWidgets('empty: the page-coloured area, the hint, Clear disabled', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(pad()));
      expect(tester.getSize(area).height, SignaturePad.areaHeight);
      final box = tester.widget<Container>(area).decoration! as BoxDecoration;
      expect(box.color, page.pageBg);
      expect(tester.widget<Text>(hint).data, 'Sign above the line');
      expect(clearButton(tester).disabled, isTrue);
      expect(
        tester
            .widget<SegmentedControl<SignatureMode>>(
              find.byType(SegmentedControl<SignatureMode>),
            )
            .value,
        SignatureMode.draw,
      );
      expect(find.text(SignaturePad.cross), findsOneWidget);
    });

    testWidgets('a stroke is reported as data; Clear empties it', (
      tester,
    ) async {
      final values = <SignatureValue>[];
      await tester.pumpWidget(componentHost(pad(onChanged: values.add)));
      final start = tester.getTopLeft(area) + const Offset(40, 60);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(20, 5));
      await gesture.moveBy(const Offset(20, -5));
      await gesture.up();
      await tester.pump();
      expect(values, hasLength(1));
      final value = values.single;
      expect(value.mode, SignatureMode.draw);
      expect(value.isEmpty, isFalse);
      expect(value.ink, SignaturePad.blackInk);
      expect(value.strokes.single.first, const Offset(40, 60));
      expect(value.strokes.single, hasLength(3));
      expect(hint, findsNothing);
      expect(clearButton(tester).disabled, isFalse);
      expect(
        tester.renderObject(strokes),
        paints..something((method, arguments) {
          if (method != #drawPath) return false;
          final paint = arguments[1] as Paint;
          return paint.style == PaintingStyle.stroke &&
              (paint.strokeWidth - SignaturePad.strokeWidth).abs() < 1e-6 &&
              paint.strokeCap == StrokeCap.round &&
              paint.color.toARGB32() == SignaturePad.blackInk.toARGB32();
        }),
      );
      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(values.last.isEmpty, isTrue);
      expect(values.last.strokes, isEmpty);
      expect(hint, findsOneWidget);
    });

    testWidgets('initial strokes; Ctrl+Z removes the last stroke', (
      tester,
    ) async {
      final values = <SignatureValue>[];
      await tester.pumpWidget(
        componentHost(
          pad(
            ink: SignaturePad.blueInk,
            onChanged: values.add,
            initialStrokes: const [
              [Offset(10, 10), Offset(20, 20), Offset(30, 10)],
              [Offset(40, 10), Offset(50, 20)],
            ],
          ),
        ),
      );
      expect(
        tester.renderObject(strokes),
        paints..path(color: SignaturePad.blueInk),
      );
      Focus.of(tester.element(area)).requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FocusRing>(
              find.ancestor(of: area, matching: find.byType(FocusRing)),
            )
            .visible,
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(values.single.strokes, hasLength(1));
      expect(values.single.ink, SignaturePad.blueInk);
    });

    testWidgets('the stroke path smooths through midpoints', (tester) async {
      final path = SignatureStrokesPainter.pathOf(const [
        Offset.zero,
        Offset(10, 0),
        Offset(20, 10),
      ]);
      expect(path.getBounds().left, 0);
      expect(path.getBounds().right, closeTo(15, 1e-6));
    });

    testWidgets('page-tuned: the area stays white in the dark theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(pad(), brightness: Brightness.dark),
      );
      final box = tester.widget<Container>(area).decoration! as BoxDecoration;
      expect(box.color, page.pageBg);
      expect(
        (box.border! as Border).top.color,
        FermanColorTokens.dark.borderDefault,
      );
    });

    testWidgets('right to left: the × sits at the right', (tester) async {
      await tester.pumpWidget(
        componentHost(pad(), textDirection: TextDirection.rtl),
      );
      final right = tester.getTopRight(area).dx;
      final cross = tester.getTopRight(find.text(SignaturePad.cross)).dx;
      // 1 px border plus the 28 px inset.
      expect(right - cross, closeTo(SignaturePad.lineInset + 1, 0.5));
    });
  });

  group('SignaturePad type and image', () {
    testWidgets('type: the name in the italic signature face, reported', (
      tester,
    ) async {
      final values = <SignatureValue>[];
      await tester.pumpWidget(
        componentHost(
          pad(
            mode: SignatureMode.type,
            ink: SignaturePad.blueInk,
            onChanged: values.add,
          ),
        ),
      );
      expect(find.text('Your name'), findsOneWidget);
      expect(tester.widget<Text>(hint).data, 'Type your name above the line');
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.style.fontStyle, FontStyle.italic);
      expect(field.style.fontFamily, FermanTypeTokens.fontBrand.family);
      expect(field.style.fontSize, SignaturePad.typedFontSize);
      expect(field.style.color, SignaturePad.blueInk);
      await tester.enterText(find.byType(EditableText), 'Ayşe Yılmaz');
      await tester.pump();
      expect(values.last.text, 'Ayşe Yılmaz');
      expect(values.last.mode, SignatureMode.type);
      expect(values.last.isEmpty, isFalse);
      expect(hint, findsNothing);
    });

    testWidgets('image: choosing a file waits for a future version', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(pad(mode: SignatureMode.image)));
      expect(
        find.text('Drop a photo or scan of your signature.'),
        findsOneWidget,
      );
      final choose = tester.widget<Button>(
        find.ancestor(
          of: find.text('Choose image…'),
          matching: find.byType(Button),
        ),
      );
      expect(choose.disabled, isTrue);
      expect(
        choose.disabledReason,
        futureVersionReason(tester.element(find.byType(SignaturePad))),
      );
      expect(hint, findsNothing);
      expect(
        tester.renderObject(
          find.byKey(const ValueKey<String>('SignaturePad.image')),
        ),
        paints
          ..path(color: ramps.paper300, strokeWidth: SignaturePad.imageBorder),
      );
    });

    testWidgets('picking a mode asks the owner', (tester) async {
      final modes = <SignatureMode>[];
      await tester.pumpWidget(componentHost(pad(onModeChanged: modes.add)));
      await tester.tap(find.text('Type'));
      expect(modes, [SignatureMode.type]);
    });
  });

  group('SignaturePad bar', () {
    testWidgets('inks: a radio group; picking blue asks the owner', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final inks = <Color>[];
      await tester.pumpWidget(componentHost(pad(onInkChanged: inks.add)));
      await tester.tap(swatch('Blue'));
      expect(inks, [SignaturePad.blueInk]);
      final group = find.bySemanticsLabel('Ink color');
      expect(
        tester.getSemantics(group).getSemanticsData().role,
        SemanticsRole.radioGroup,
      );
      handle.dispose();
    });

    testWidgets('checked ink: the double ring; arrow keys move and check', (
      tester,
    ) async {
      final inks = <Color>[];
      await tester.pumpWidget(componentHost(pad(onInkChanged: inks.add)));
      Container circle(String name) => tester.widget<Container>(
        find.descendant(of: swatch(name), matching: find.byType(Container)),
      );
      const colors = FermanColorTokens.light;
      expect((circle('Black').decoration! as BoxDecoration).boxShadow, [
        BoxShadow(color: colors.textPrimary, spreadRadius: 4),
        BoxShadow(color: colors.surfacePanel, spreadRadius: 2),
      ]);
      expect((circle('Blue').decoration! as BoxDecoration).boxShadow, isEmpty);
      Focus.of(
        tester.element(
          find.descendant(
            of: swatch('Black'),
            matching: find.byType(Container),
          ),
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(inks, [SignaturePad.blueInk]);
    });

    testWidgets('"Save on this device" asks the owner', (tester) async {
      final saves = <bool>[];
      await tester.pumpWidget(
        componentHost(pad(onSaveForLaterChanged: saves.add)),
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).checked, isTrue);
      await tester.tap(find.text('Save on this device'));
      expect(saves, [false]);
    });

    testWidgets('the drawing area is named for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(pad()));
      expect(find.bySemanticsLabel('Signature drawing area.'), findsOneWidget);
      expect(find.bySemanticsLabel('Signature method'), findsOneWidget);
      handle.dispose();
    });
  });

  test('SignatureValue equality compares the strokes', () {
    const a = SignatureValue(
      mode: SignatureMode.draw,
      ink: SignaturePad.blackInk,
      strokes: [
        [Offset(1, 2)],
      ],
      isEmpty: false,
    );
    const b = SignatureValue(
      mode: SignatureMode.draw,
      ink: SignaturePad.blackInk,
      strokes: [
        [Offset(1, 2)],
      ],
      isEmpty: false,
    );
    const c = SignatureValue(
      mode: SignatureMode.draw,
      ink: SignaturePad.blackInk,
      strokes: [
        [Offset(1, 3)],
      ],
      isEmpty: false,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
