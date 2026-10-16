import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;
  const desktop = FermanDensityTokens.desktop;

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: find.byType(Button),
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;

  Color? textColor(WidgetTester tester, String text) =>
      DefaultTextStyle.of(tester.element(find.text(text))).style.color;

  Size buttonSize(WidgetTester tester) => tester.getSize(
    find.descendant(
      of: find.byType(Button),
      matching: find.byType(AnimatedContainer),
    ),
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('Button variants', () {
    testWidgets('secondary is the default: raised, bordered, small shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(Button(onPressed: () {}, child: const Text('Cancel'))),
      );
      final box = decoration(tester);
      expect(box.color, light.surfaceRaised);
      expect((box.border! as Border).top.color, light.borderDefault);
      expect(box.boxShadow, FermanElevationTokens.light.shadowSm);
      expect(
        box.borderRadius,
        const BorderRadius.all(Radius.circular(FermanRadiusTokens.radiusSm)),
      );
      expect(textColor(tester, 'Cancel'), light.textPrimary);
    });

    testWidgets('primary: accent fill, on-accent text', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.primary,
            onPressed: () {},
            child: const Text('Save'),
          ),
        ),
      );
      expect(decoration(tester).color, light.accent);
      expect(textColor(tester, 'Save'), light.textOnAccent);
    });

    testWidgets('ghost: no fill, no border', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.ghost,
            onPressed: () {},
            child: const Text('More'),
          ),
        ),
      );
      final box = decoration(tester);
      expect(box.color!.a, 0);
      expect((box.border! as Border).top.color.a, 0);
      expect(box.boxShadow, isEmpty);
    });

    testWidgets('danger: solid danger fill, white text', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.danger,
            onPressed: () {},
            child: const Text('Apply'),
          ),
        ),
      );
      expect(decoration(tester).color, light.dangerSolid);
      expect(textColor(tester, 'Apply'), Button.dangerForeground);
    });

    testWidgets('dark theme takes the dark tokens', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.primary,
            onPressed: () {},
            child: const Text('Save'),
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(decoration(tester).color, FermanColorTokens.dark.accent);
    });
  });

  group('Button sizes', () {
    testWidgets('heights, padding, type and icon size per size', (
      tester,
    ) async {
      for (final (size, height, padding, glyph) in [
        (ButtonSize.sm, desktop.controlHSm, 8.0, 14.0),
        (ButtonSize.md, desktop.controlHMd, 12.0, 16.0),
        (ButtonSize.lg, desktop.controlHLg, 16.0, 16.0),
      ]) {
        await tester.pumpWidget(
          componentHost(
            Button(
              key: ValueKey(size),
              size: size,
              icon: IconName.save,
              onPressed: () {},
              child: const Text('Save'),
            ),
          ),
        );
        expect(buttonSize(tester).height, height, reason: '$size');
        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(Button),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(
          container.padding,
          EdgeInsetsDirectional.symmetric(horizontal: padding),
          reason: '$size',
        );
        expect(tester.widget<Icon>(find.byType(Icon)).size, glyph);
        final fontSize = DefaultTextStyle.of(tester.element(find.text('Save')))
            .style
            .fontSize;
        expect(fontSize, size == ButtonSize.sm ? 12 : 13, reason: '$size');
      }
    });

    testWidgets('at least --hit-min wide', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            onPressed: () {},
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(buttonSize(tester).width, desktop.hitMin);
    });

    testWidgets('fullWidth fills its parent', (tester) async {
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 300,
            child: Button(
              fullWidth: true,
              onPressed: () {},
              child: const Text('Continue'),
            ),
          ),
        ),
      );
      expect(buttonSize(tester).width, 300);
    });
  });

  group('Button states', () {
    testWidgets('hover per variant', (tester) async {
      for (final (variant, expected) in [
        (ButtonVariant.primary, light.accentHover),
        (
          ButtonVariant.secondary,
          Color.alphaBlend(light.surfaceHover, light.surfaceRaised),
        ),
        (ButtonVariant.ghost, light.surfaceHover),
        (ButtonVariant.danger, light.dangerHover),
      ]) {
        await tester.pumpWidget(
          componentHost(
            Button(variant: variant, onPressed: () {}, child: const Text('Go')),
            forcedStates: const {WidgetState.hovered},
          ),
        );
        await tester.pumpAndSettle();
        expect(decoration(tester).color, expected, reason: '$variant');
      }
      // Secondary hover also strengthens the border.
      await tester.pumpWidget(
        componentHost(
          Button(onPressed: () {}, child: const Text('Go')),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (decoration(tester).border! as Border).top.color,
        light.borderStrong,
      );
    });

    testWidgets('pressed per variant', (tester) async {
      for (final (variant, expected) in [
        (ButtonVariant.primary, light.accentPressed),
        (
          ButtonVariant.secondary,
          Color.alphaBlend(light.surfacePressed, light.surfaceRaised),
        ),
        (ButtonVariant.ghost, light.surfacePressed),
        (ButtonVariant.danger, light.dangerHover),
      ]) {
        await tester.pumpWidget(
          componentHost(
            Button(variant: variant, onPressed: () {}, child: const Text('Go')),
            forcedStates: const {WidgetState.pressed},
          ),
        );
        await tester.pumpAndSettle();
        expect(decoration(tester).color, expected, reason: '$variant');
      }
    });

    testWidgets('secondary pressed drops the shadow', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(onPressed: () {}, child: const Text('Go')),
          forcedStates: const {WidgetState.pressed},
        ),
      );
      await tester.pumpAndSettle();
      expect(decoration(tester).boxShadow, isEmpty);
    });

    testWidgets('danger pressed adds the inner shadow', (tester) async {
      Iterable<CustomPaint> insetPaints() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(Button),
              matching: find.byType(CustomPaint),
            ),
          )
          .where((paint) => paint.foregroundPainter is InsetShadowPainter);

      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.danger,
            onPressed: () {},
            child: const Text('Apply'),
          ),
        ),
      );
      expect(insetPaints(), isEmpty);
      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.danger,
            onPressed: () {},
            child: const Text('Apply'),
          ),
          forcedStates: const {WidgetState.pressed},
        ),
      );
      final painter =
          insetPaints().single.foregroundPainter! as InsetShadowPainter;
      expect(painter.shadow, Button.dangerPressedShadow);
      expect(painter.shadow.color, const Color(0x33000000));
    });

    testWidgets('a real pointer hovers and presses', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.primary,
            onPressed: () {},
            child: const Text('Save'),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(Button)));
      await tester.pumpAndSettle();
      expect(decoration(tester).color, light.accentHover);
      await mouse.down(tester.getCenter(find.byType(Button)));
      await tester.pumpAndSettle();
      expect(decoration(tester).color, light.accentPressed);
      await mouse.up();
      await tester.pumpAndSettle();
    });

    testWidgets('keyboard focus shows the outer focus ring', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: FocusScope(
                autofocus: true,
                child: Button(onPressed: () {}, child: const Text('Save')),
              ),
            ),
          ),
        ),
      );
      FocusRing ring() => tester.widget<FocusRing>(
        find.descendant(
          of: find.byType(Button),
          matching: find.byType(FocusRing),
        ),
      );
      expect(ring().visible, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ring().visible, isTrue);
      expect(ring().style, FocusRingStyle.outer);
      expect(
        ring().borderRadius,
        const BorderRadius.all(Radius.circular(FermanRadiusTokens.radiusSm)),
      );
    });

    testWidgets('disabled: sunken fill, disabled text, inert, skipped', (
      tester,
    ) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.primary,
            disabled: true,
            focusNode: node,
            onPressed: () => taps++,
            child: const Text('Save'),
          ),
        ),
      );
      final box = decoration(tester);
      expect(box.color, light.surfaceSunken);
      expect(box.boxShadow, isEmpty);
      expect(textColor(tester, 'Save'), light.textDisabled);
      await tester.tap(find.text('Save'), warnIfMissed: false);
      expect(taps, 0);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
    });

    testWidgets('disabled ghost stays unfilled; a null onPressed disables', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const Button(variant: ButtonVariant.ghost, child: Text('More')),
        ),
      );
      expect(decoration(tester).color!.a, 0);
      expect(textColor(tester, 'More'), light.textDisabled);
    });

    testWidgets('disabled with a reason: focusable, reason as tooltip and '
        'hint, activation does nothing', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => Button(
              disabled: true,
              disabledReason: futureVersionReason(context),
              focusNode: node,
              onPressed: () => taps++,
              child: const Text('Export'),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 0);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Export')),
        isSemantics(
          label: 'Export',
          hint: 'Available in a future version',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
        ),
      );
      expect(decoration(tester).color, light.surfaceSunken);
      handle.dispose();
    });
  });

  group('Button keyboard and semantics', () {
    testWidgets('tap, Enter and Space activate', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          Button(
            focusNode: node,
            onPressed: () => taps++,
            child: const Text('Save'),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 3);
    });

    testWidgets('a button named by its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          Button(
            icon: IconName.save,
            onPressed: () {},
            child: const Text('Save'),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Save')),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('Button icons and loading', () {
    testWidgets('icon before and iconEnd after the label', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            icon: IconName.save,
            iconEnd: IconName.chevronDown,
            onPressed: () {},
            child: const Text('Save'),
          ),
        ),
      );
      final save = tester.getCenter(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.save,
        ),
      );
      final chevron = tester.getCenter(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.chevronDown,
        ),
      );
      final label = tester.getCenter(find.text('Save'));
      expect(save.dx, lessThan(label.dx));
      expect(chevron.dx, greaterThan(label.dx));
      // 6 px between the parts.
      final iconRight = tester
          .getTopRight(
            find.byWidgetPredicate(
              (widget) => widget is Icon && widget.name == IconName.save,
            ),
          )
          .dx;
      expect(tester.getTopLeft(find.text('Save')).dx - iconRight, 6);
    });

    testWidgets('right to left puts the icon after the label', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            icon: IconName.save,
            onPressed: () {},
            child: const Text('Save'),
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.byType(Icon)).dx,
        greaterThan(tester.getCenter(find.text('Save')).dx),
      );
    });

    testWidgets('loading: a turning loader-circle replaces the icon, '
        'iconEnd hides, the cursor shows progress', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        componentHost(
          Button(
            loading: true,
            icon: IconName.save,
            iconEnd: IconName.chevronDown,
            onPressed: () => taps++,
            child: const Text('Exporting'),
          ),
        ),
      );
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.map((icon) => icon.name), [IconName.loaderCircle]);
      final spin = tester.widget<SpinRotation>(find.byType(SpinRotation));
      expect(spin.period, Button.spinPeriod);
      expect(
        tester.widgetList<MouseRegion>(
          find.descendant(
            of: find.byType(Button),
            matching: find.byType(MouseRegion),
          ),
        ),
        contains(
          isA<MouseRegion>().having(
            (region) => region.cursor,
            'cursor',
            SystemMouseCursors.progress,
          ),
        ),
      );
      // Loading does not disable the button.
      await tester.tap(find.text('Exporting'));
      expect(taps, 1);
    });

    testWidgets('the loader keeps turning under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          Button(
            loading: true,
            onPressed: () {},
            child: const Text('Exporting'),
          ),
          disableAnimations: true,
        ),
      );
      RotationTransition rotation() =>
          tester.widget<RotationTransition>(find.byType(RotationTransition));
      final before = rotation().turns.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(rotation().turns.value, isNot(before));
    });
  });
}
