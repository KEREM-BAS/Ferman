import 'package:ferman/design/components/forms/color_picker.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;

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
                  child: SizedBox(width: 160, child: child),
                ),
              ),
            ),
          ),
          brightness: brightness,
        ),
      );

  Widget picker({
    Color? value = const Color(0xFF1F1D1A),
    ValueChanged<Color?>? onChanged,
    bool allowNone = false,
    List<Color> documentColors = const [],
    bool? open,
    bool initiallyOpen = false,
    ValueChanged<bool>? onOpenChanged,
    bool disabled = false,
    FocusNode? focusNode,
  }) => ColorPicker(
    label: 'Colour',
    value: value,
    onChanged: onChanged ?? (_) {},
    allowNone: allowNone,
    documentColors: documentColors,
    open: open,
    initiallyOpen: initiallyOpen,
    onOpenChanged: onOpenChanged,
    disabled: disabled,
    focusNode: focusNode,
    noneLabel: 'None',
    documentColorsLabel: 'In this document',
    standardColorsLabel: 'Standard',
    noColorLabel: 'No color',
    hexLabel: 'Hex',
    hexSemanticLabel: 'Hex color',
    dialogLabel: 'Choose color',
    eyedropper: const SizedBox(key: Key('eyedropper'), width: 26, height: 26),
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('ColorPicker', () {
    test('hex codes', () {
      expect(ColorPicker.hexOf(const Color(0xFF2a4daf)), '#2A4DAF');
      expect(ColorPicker.parseHex('2a4daf'), const Color(0xFF2A4DAF));
      expect(ColorPicker.parseHex('#FFE066'), const Color(0xFFFFE066));
      expect(ColorPicker.parseHex('#FFF'), isNull);
      expect(ColorPicker.standardSwatches, hasLength(16));
    });

    testWidgets('trigger: chip, upper-case hex, small box', (tester) async {
      await tester.pumpWidget(host(picker()));
      expect(find.text('#1F1D1A'), findsOneWidget);
      expect(find.text('Colour'), findsOneWidget);
      expect(tester.getSize(find.byKey(FieldBox.boxKey)).height, 26);
    });

    testWidgets('none: struck chip and the none label', (tester) async {
      await tester.pumpWidget(host(picker(value: null, allowNone: true)));
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('a click opens the popover with sections, swatches and the '
        'hex row', (tester) async {
      await tester.pumpWidget(
        host(picker(documentColors: const [Color(0xFF962C21)])),
      );
      await tester.tap(find.byKey(FieldBox.boxKey));
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      expect(
        tester.getSize(find.byType(PopoverSurface)).width,
        ColorPicker.popoverWidth,
      );
      expect(find.text('In this document'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Hex'), findsOneWidget);
      expect(find.byKey(const Key('eyedropper')), findsOneWidget);
      expect(find.bySemanticsLabel('#FFE066'), findsOneWidget);
    });

    testWidgets('picking a swatch reports it; the current one is ringed in '
        'the accent', (tester) async {
      final picked = <Color?>[];
      await tester.pumpWidget(
        host(picker(onChanged: picked.add, initiallyOpen: true)),
      );
      await tester.pumpAndSettle();
      final current = tester.widget<Container>(
        find
            .descendant(
              of: find.bySemanticsLabel('#1F1D1A').last,
              matching: find.byType(Container),
            )
            .first,
      );
      final shadows = (current.decoration! as BoxDecoration).boxShadow!;
      expect(shadows.first.color, light.accent);
      expect(shadows.first.spreadRadius, 4);
      await tester.tap(find.bySemanticsLabel('#FFE066'));
      expect(picked, [const Color(0xFFFFE066)]);
    });

    testWidgets('the none swatch reports null', (tester) async {
      final picked = <Color?>[];
      await tester.pumpWidget(
        host(
          picker(onChanged: picked.add, allowNone: true, initiallyOpen: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('No color'));
      expect(picked, [null]);
    });

    testWidgets('the hex field commits a valid code on Enter', (tester) async {
      final picked = <Color?>[];
      await tester.pumpWidget(
        host(picker(onChanged: picked.add, initiallyOpen: true)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'b42318');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'B42318',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(picked, [const Color(0xFFB42318)]);
      await tester.enterText(find.byType(EditableText), '12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(picked, hasLength(1));
    });

    testWidgets('Escape closes and returns focus to the trigger', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(host(picker(focusNode: node)));
      node.requestFocus();
      await tester.pumpAndSettle();
      final ring = tester
          .widget<FieldBox>(find.byType(FieldBox).first)
          .focusRingStyle;
      expect(ring, FocusRingStyle.outer);
      expect(
        tester.widget<FieldBox>(find.byType(FieldBox).first).focused,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('a click outside closes', (tester) async {
      await tester.pumpWidget(host(picker(initiallyOpen: true)));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 550));
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
    });

    testWidgets('controlled open reports requests', (tester) async {
      final requests = <bool>[];
      await tester.pumpWidget(
        host(picker(open: false, onOpenChanged: requests.add)),
      );
      await tester.tap(find.byKey(FieldBox.boxKey));
      await tester.pumpAndSettle();
      expect(requests, [true]);
      expect(find.byType(PopoverSurface), findsNothing);
    });

    testWidgets('disabled: no popover', (tester) async {
      await tester.pumpWidget(host(picker(disabled: true)));
      await tester.tap(find.byKey(FieldBox.boxKey), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      final box =
          tester
                  .widget<AnimatedContainer>(find.byKey(FieldBox.boxKey))
                  .decoration!
              as BoxDecoration;
      expect(box.color, light.surfaceSunken);
    });

    testWidgets('semantics: trigger button with value and expanded; dialog', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(picker()));
      expect(
        tester.getSemantics(find.byKey(FieldBox.boxKey)),
        isSemantics(
          label: 'Colour',
          value: '#1F1D1A',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
        ),
      );
      await tester.tap(find.byKey(FieldBox.boxKey));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Choose color'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('dark theme: lighter chip edge', (tester) async {
      await tester.pumpWidget(host(picker(), brightness: Brightness.dark));
      final edge = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null)
          .map((d) => (d.border! as Border).top.color);
      expect(edge, contains(ColorPicker.chipEdgeDark));
    });
  });
}
