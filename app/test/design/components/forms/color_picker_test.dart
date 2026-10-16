import 'package:ferman/design/components/forms/color_picker.dart';
import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import '../keyboard_reach.dart';

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;

  // The app's own shortcuts and actions (Tab moves focus), which
  // componentHost leaves out.
  Widget appKeys(Widget child) => Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(actions: WidgetsApp.defaultActions, child: child),
  );

  Widget host(
    Widget child, {
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    Set<WidgetState>? forcedStates,
  }) => TapRegionSurface(
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
      locale: locale,
      forcedStates: forcedStates,
    ),
  );

  Color borderOf(WidgetTester tester) {
    final box = tester.widget<AnimatedContainer>(find.byKey(FieldBox.boxKey));
    return ((box.decoration! as BoxDecoration).border! as Border).top.color;
  }

  Container swatchOf(WidgetTester tester, String label) =>
      tester.widget<Container>(
        find
            .descendant(
              of: find.bySemanticsLabel(label).last,
              matching: find.byType(Container),
            )
            .first,
      );

  Color? edgeOf(Container swatch) {
    final decoration = swatch.foregroundDecoration as BoxDecoration?;
    return (decoration?.border as Border?)?.top.color;
  }

  final second = ColorPicker.hexOf(ColorPicker.standardSwatches[1]);

  Widget picker({
    Color? value = const Color(0xFF1F1D1A),
    ValueChanged<Color?>? onChanged,
    bool allowNone = false,
    List<Color> documentColors = const [],
    bool? open,
    bool initiallyOpen = false,
    ValueChanged<bool>? onOpenChanged,
    bool disabled = false,
    String? disabledReason,
    FocusNode? focusNode,
    String noneLabel = 'None',
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
    disabledReason: disabledReason,
    focusNode: focusNode,
    noneLabel: noneLabel,
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

    testWidgets('none: struck chip and the upper-cased none label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(picker(value: null, allowNone: true)));
      // `.fm-colortrigger__value { text-transform: uppercase }`.
      expect(find.text('NONE'), findsOneWidget);
      expect(find.text('None'), findsNothing);
      // Screen readers hear the word, not spelled capitals.
      expect(
        tester.getSemantics(find.byKey(FieldBox.boxKey)),
        isSemantics(label: 'Colour', value: 'None', isButton: true),
      );
      // `.fm-chip--none`: the raised surface with a 2 px danger stripe.
      final chip = find
          .descendant(
            of: find.byKey(FieldBox.boxKey),
            matching: find.byType(CustomPaint),
          )
          .first;
      expect(
        chip,
        paints
          ..rect(color: light.surfaceRaised)
          ..line(color: light.danger, strokeWidth: 2),
      );
      await tester.tap(find.byKey(FieldBox.boxKey));
      await tester.pumpAndSettle();
      final noneSwatch = find
          .descendant(
            of: find.bySemanticsLabel('No color').last,
            matching: find.byType(CustomPaint),
          )
          .first;
      expect(
        noneSwatch,
        paints
          ..rect(color: light.surfaceRaised)
          ..line(color: light.danger, strokeWidth: 2),
      );
      handle.dispose();
    });

    testWidgets('the none label follows the casing of the UI language', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          picker(value: null, allowNone: true, noneLabel: 'yeni'),
          locale: const Locale('tr'),
        ),
      );
      expect(find.text('YENİ'), findsOneWidget);
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
      // No focus highlight, so the focused current swatch shows its ring.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
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

    testWidgets('a click opens with focus on the popover itself: no swatch '
        'and not the trigger shows the focus ring (G22)', (tester) async {
      final node = FocusNode(debugLabel: 'trigger');
      addTearDown(node.dispose);
      var value = const Color(0xFF1F1D1A);
      await tester.pumpWidget(
        appKeys(
          host(
            StatefulBuilder(
              builder: (context, setState) => picker(
                value: value,
                focusNode: node,
                onChanged: (next) => setState(() => value = next!),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(FieldBox.boxKey),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      expect(node.hasFocus, isFalse);
      expect(
        tester.widget<FieldBox>(find.byType(FieldBox).first).focused,
        isFalse,
      );
      final dialog = find.bySemanticsLabel('Choose color');
      final focus = FocusManager.instance.primaryFocus!;
      expect(focus, isA<FocusScopeNode>());
      expect(
        find
            .descendant(
              of: dialog,
              matching: find.byElementPredicate(
                (element) => identical(element, focus.context),
              ),
            )
            .evaluate(),
        isNotEmpty,
      );
      final current = swatchOf(tester, '#1F1D1A');
      expect(
        (current.decoration! as BoxDecoration).boxShadow!.first.color,
        light.accent,
      );
      // A mouse pick: only the picked swatch is ringed, in the accent.
      await tester.tap(
        find.bySemanticsLabel('#FFE066'),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(
        (swatchOf(tester, '#1F1D1A').decoration! as BoxDecoration).boxShadow,
        isEmpty,
      );
      expect(
        (swatchOf(tester, '#FFE066').decoration! as BoxDecoration)
            .boxShadow!
            .first
            .color,
        light.accent,
      );
      // Tab moves into the swatches.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        (swatchOf(tester, '#1F1D1A').decoration! as BoxDecoration).boxShadow,
        FocusRing.outerShadows(FermanTheme.light),
      );
    });

    testWidgets('after a click opened it, a click outside leaves the trigger '
        'without focus; Escape gives it focus', (tester) async {
      final node = FocusNode(debugLabel: 'trigger');
      addTearDown(node.dispose);
      await tester.pumpWidget(host(picker(focusNode: node)));
      await tester.tap(
        find.byKey(FieldBox.boxKey),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 550), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(node.hasFocus, isFalse);
      expect(
        tester.widget<FieldBox>(find.byType(FieldBox).first).focused,
        isFalse,
      );
      await tester.tap(
        find.byKey(FieldBox.boxKey),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(node.hasFocus, isTrue);
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
      // `.fm-input > svg { color: var(--icon-secondary) }` in every state.
      final chevron = tester.widget<Icon>(find.byType(Icon));
      expect(chevron.color, light.iconSecondary);
    });

    testWidgets('disabled with a reason: focusable, reason as tooltip and '
        'hint, no popover', (tester) async {
      final handle = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(
          picker(
            disabled: true,
            disabledReason: 'Available in a future version',
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(FieldBox.boxKey)),
        isSemantics(
          label: 'Colour',
          hint: 'Available in a future version',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('trigger hover: the strong border, by pointer or forced', (
      tester,
    ) async {
      await tester.pumpWidget(host(picker()));
      expect(borderOf(tester), light.borderDefault);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(FieldBox.boxKey)));
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderStrong);
      await tester.pumpWidget(
        host(picker(), forcedStates: {WidgetState.hovered}),
      );
      await tester.pumpAndSettle();
      expect(borderOf(tester), light.borderStrong);
    });

    testWidgets('swatch hover: a 2 px strong ring', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pumpWidget(host(picker(initiallyOpen: true)));
      await tester.pumpAndSettle();
      expect(swatchOf(tester, '#FFE066').decoration, isA<BoxDecoration>());
      expect(
        (swatchOf(tester, '#FFE066').decoration! as BoxDecoration).boxShadow,
        isEmpty,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.bySemanticsLabel('#FFE066').last),
      );
      await tester.pumpAndSettle();
      final shadows =
          (swatchOf(tester, '#FFE066').decoration! as BoxDecoration).boxShadow!;
      expect(shadows, hasLength(1));
      expect(shadows.single.color, light.borderStrong);
      expect(shadows.single.spreadRadius, 2);
    });

    testWidgets('opening moves focus to the selected swatch; keyboard focus '
        'shows the focus ring without the inset edge', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(appKeys(host(picker(focusNode: node))));
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      final current = swatchOf(tester, '#1F1D1A');
      expect(
        (current.decoration! as BoxDecoration).boxShadow,
        FocusRing.outerShadows(FermanTheme.light),
      );
      expect(current.foregroundDecoration, isNull);
      // Tab moves to the next swatch, which takes the ring in turn.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final next = swatchOf(tester, second);
      expect(
        (next.decoration! as BoxDecoration).boxShadow,
        FocusRing.outerShadows(FermanTheme.light),
      );
      expect(next.foregroundDecoration, isNull);
      // The current one is back to its accent ring and inset edge.
      final back = swatchOf(tester, '#1F1D1A');
      expect(
        (back.decoration! as BoxDecoration).boxShadow!.first.color,
        light.accent,
      );
      expect(edgeOf(back), ColorPicker.chipEdgeLight);
    });

    testWidgets('Tab reaches the trigger; Space opens the popover on the '
        'selected swatch and Space on a swatch picks it', (tester) async {
      final picked = <Color?>[];
      await tester.pumpWidget(
        TapRegionSurface(
          child: componentHost(
            afterLeadingTabStop(
              SizedBox(width: 160, child: picker(onChanged: picked.add)),
            ),
          ),
        ),
      );
      await expectTabReaches(tester, find.byType(ColorPicker));
      expect(borderOf(tester), light.borderFocus);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
      expect(
        (swatchOf(tester, '#1F1D1A').decoration! as BoxDecoration).boxShadow,
        FocusRing.outerShadows(FermanTheme.light),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(picked, [ColorPicker.standardSwatches[1]]);
      // A pick keeps the popover open; Escape closes it onto the trigger,
      // where Space opens it again.
      expect(find.byType(PopoverSurface), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(focusIsWithin(find.byType(ColorPicker)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsOneWidget);
    });

    testWidgets('with no colour chosen the first swatch takes focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(picker(value: const Color(0xFF123456), initiallyOpen: true)),
      );
      await tester.pumpAndSettle();
      expect(
        (swatchOf(tester, '#1F1D1A').decoration! as BoxDecoration).boxShadow,
        FocusRing.outerShadows(FermanTheme.light),
      );
    });

    testWidgets('Tab and Shift+Tab stay inside the popover', (tester) async {
      final above = FocusNode(debugLabel: 'above');
      final below = FocusNode(debugLabel: 'below');
      final beside = FocusNode(debugLabel: 'beside');
      final trigger = FocusNode(debugLabel: 'trigger');
      for (final node in [above, below, beside, trigger]) {
        addTearDown(node.dispose);
      }
      Widget focusable(FocusNode node) =>
          Focus(focusNode: node, child: const SizedBox(width: 40, height: 26));
      await tester.pumpWidget(
        TapRegionSurface(
          child: componentHost(
            appKeys(
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  focusable(above),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      SizedBox(width: 160, child: picker(focusNode: trigger)),
                      focusable(beside),
                    ],
                  ),
                  // Under the popover, in the band of its swatches.
                  focusable(below),
                ],
              ),
            ),
          ),
        ),
      );
      trigger.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final outside = {above, below, beside, trigger};
      final hexNode = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      // Tab from the trigger's row would reach `beside` when the popover is
      // not a scope of its own.
      var reachedHex = false;
      for (var i = 0; i < 24; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        expect(outside.contains(focus), isFalse, reason: 'Tab $i: $focus');
        if (focus == hexNode) reachedHex = true;
      }
      expect(reachedHex, isTrue);
      for (var i = 0; i < 24; i++) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        expect(outside.contains(focus), isFalse, reason: 'Shift+Tab $i');
      }
      expect(find.byType(PopoverSurface), findsOneWidget);
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

    testWidgets('dark theme: a swatch at rest has the light edge; hovered and '
        'selected swatches the dark one', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await tester.pumpWidget(
        host(picker(initiallyOpen: true), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      expect(edgeOf(swatchOf(tester, '#FFE066')), ColorPicker.chipEdgeDark);
      // forms.css:121 `[aria-pressed="true"]` restates the dark edge.
      final selected = swatchOf(tester, '#1F1D1A');
      expect(edgeOf(selected), ColorPicker.chipEdgeLight);
      expect(
        (selected.decoration! as BoxDecoration).boxShadow!.first.color,
        dark.accent,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(
        tester.getCenter(find.bySemanticsLabel('#FFE066').last),
      );
      await tester.pumpAndSettle();
      // forms.css:119 `.fm-swatch:hover` comes after :112.
      expect(edgeOf(swatchOf(tester, '#FFE066')), ColorPicker.chipEdgeLight);
    });
  });
}
