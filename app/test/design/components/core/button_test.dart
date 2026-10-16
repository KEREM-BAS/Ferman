import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import 'panel_pixels.dart';

void main() {
  const light = FermanColorTokens.light;
  const desktop = FermanDensityTokens.desktop;

  // The outer container animates the shadow, the inner one the fill,
  // border and text.
  final containers = find.descendant(
    of: find.byType(Button),
    matching: find.byType(AnimatedContainer),
  );

  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(containers.last).decoration!
          as BoxDecoration;

  List<BoxShadow>? shadow(WidgetTester tester) =>
      (tester.widget<AnimatedContainer>(containers.first).decoration!
              as BoxDecoration)
          .boxShadow;

  FocusRing ring(WidgetTester tester) => tester.widget<FocusRing>(
    find.descendant(of: find.byType(Button), matching: find.byType(FocusRing)),
  );

  Color? textColor(WidgetTester tester, String text) =>
      DefaultTextStyle.of(tester.element(find.text(text))).style.color;

  Size buttonSize(WidgetTester tester) => tester.getSize(containers.last);

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
      expect(shadow(tester), FermanElevationTokens.light.shadowSm);
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
      expect(shadow(tester), isEmpty);
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
        // The padding sits inside the 1 px border, around the label.
        final inner = tester
            .widgetList<Padding>(
              find.descendant(
                of: containers.last,
                matching: find.byType(Padding),
              ),
            )
            .where((widget) => widget.padding is EdgeInsetsDirectional);
        expect(
          inner.single.padding,
          EdgeInsetsDirectional.symmetric(horizontal: padding),
          reason: '$size',
        );
        expect(
          tester.getTopLeft(find.byType(Icon)).dx -
              tester.getTopLeft(containers.last).dx,
          FermanBorderTokens.borderWidth + padding,
          reason: '$size',
        );
        expect(tester.widget<Icon>(find.byType(Icon)).size, glyph);
        final style = DefaultTextStyle.of(tester.element(find.text('Save')))
            .style;
        expect(
          style.fontSize,
          size == ButtonSize.sm ? 12 : 13,
          reason: '$size',
        );
        // `.fm-btn--sm` keeps the 18 px line of --type-body-strong.
        expect(
          style.fontSize! * style.height!,
          moreOrLessEquals(18),
          reason: '$size',
        );
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
      expect(shadow(tester), isEmpty);
    });

    testWidgets('dark secondary hover blends the dark hover tint', (
      tester,
    ) async {
      const dark = FermanColorTokens.dark;
      await tester.pumpWidget(
        componentHost(
          Button(onPressed: () {}, child: const Text('Go')),
          brightness: Brightness.dark,
          forcedStates: const {WidgetState.hovered},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        decoration(tester).color,
        Color.alphaBlend(dark.surfaceHover, dark.surfaceRaised),
      );
      expect(
        (decoration(tester).border! as Border).top.color,
        dark.borderStrong,
      );
      expect(shadow(tester), FermanElevationTokens.dark.shadowSm);
    });

    testWidgets('danger pressed casts the inner shadow inside the border, '
        'under the label', (tester) async {
      final shadowPaint = find.descendant(
        of: containers.last,
        matching: find.byType(CustomPaint),
      );
      InsetShadowPainter? painter() =>
          tester.widget<CustomPaint>(shadowPaint.first).painter
              as InsetShadowPainter?;

      await tester.pumpWidget(
        componentHost(
          Button(
            variant: ButtonVariant.danger,
            onPressed: () {},
            child: const Text('Apply'),
          ),
        ),
      );
      expect(painter(), isNull);
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
      await tester.pumpAndSettle();
      final inset = painter()!;
      expect(inset.shadow, Button.dangerPressedShadow);
      expect(inset.shadow.color, const Color(0x33000000));
      // CSS blur 2px: sigma 1.
      expect(inset.shadow.blurSigma, moreOrLessEquals(1, epsilon: 1e-3));
      // The padding edge: 1 px inside the border, radius 4 − 1.
      expect(
        inset.borderRadius,
        FermanRadiusTokens.radiusSm - FermanBorderTokens.borderWidth,
      );
      expect(
        tester.getRect(shadowPaint.first),
        tester.getRect(containers.last).deflate(FermanBorderTokens.borderWidth),
      );
      // A background painter: the label is its child, painted over it.
      expect(
        tester.widget<CustomPaint>(shadowPaint.first).foregroundPainter,
        isNull,
      );
      expect(
        find.descendant(of: shadowPaint.first, matching: find.text('Apply')),
        findsOneWidget,
      );
    });

    testWidgets('the inner shadow fades over --dur-fast', (tester) async {
      final pressed = ValueNotifier<bool>(false);
      addTearDown(pressed.dispose);
      await tester.pumpWidget(
        componentHost(
          ValueListenableBuilder<bool>(
            valueListenable: pressed,
            builder: (context, value, _) => FermanForcedStates(
              states: {if (value) WidgetState.pressed},
              child: Button(
                variant: ButtonVariant.danger,
                onPressed: () {},
                child: const Text('Apply'),
              ),
            ),
          ),
        ),
      );
      InsetShadowPainter? painter() =>
          tester
                  .widget<CustomPaint>(
                    find
                        .descendant(
                          of: containers.last,
                          matching: find.byType(CustomPaint),
                        )
                        .first,
                  )
                  .painter
              as InsetShadowPainter?;
      expect(painter(), isNull);
      pressed.value = true;
      await tester.pump();
      await tester.pump(FermanMotionTokens.standard.durFast ~/ 2);
      final halfway = painter()!.shadow.color.a;
      expect(halfway, greaterThan(0));
      expect(halfway, lessThan(Button.dangerPressedShadow.color.a));
      await tester.pumpAndSettle();
      expect(painter()!.shadow, Button.dangerPressedShadow);
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

    testWidgets('keyboard focus shows the outer focus ring in place of the '
        'secondary shadow', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: FocusScope(
                autofocus: true,
                child: Button(
                  focusNode: node,
                  onPressed: () {},
                  child: const Text('Save'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(ring(tester).visible, isFalse);
      expect(shadow(tester), FermanElevationTokens.light.shadowSm);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(ring(tester).visible, isTrue);
      expect(ring(tester).style, FocusRingStyle.outer);
      expect(
        ring(tester).borderRadius,
        const BorderRadius.all(Radius.circular(FermanRadiusTokens.radiusSm)),
      );
      // `.fm-btn:focus-visible` replaces `--shadow-sm` with the ring.
      expect(shadow(tester), isEmpty);
      node.unfocus();
      await tester.pumpAndSettle();
      expect(ring(tester).visible, isFalse);
      expect(shadow(tester), FermanElevationTokens.light.shadowSm);
    });

    testWidgets('forced focus on a secondary: ring, no shadow', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Button(onPressed: () {}, child: const Text('Cancel')),
          forcedStates: const {WidgetState.focused},
        ),
      );
      await tester.pumpAndSettle();
      expect(ring(tester).visible, isTrue);
      expect(shadow(tester), isEmpty);
      expect(decoration(tester).color, light.surfaceRaised);
    });

    testWidgets('colours change over --dur-instant, shadows and the ring over '
        '--dur-fast; all at once under reduced motion', (tester) async {
      const standard = FermanMotionTokens.standard;
      for (final reduced in [false, true]) {
        await tester.pumpWidget(
          componentHost(
            Button(onPressed: () {}, child: const Text('Save')),
            disableAnimations: reduced,
          ),
        );
        final outer = tester.widget<AnimatedContainer>(containers.first);
        final inner = tester.widget<AnimatedContainer>(containers.last);
        expect(
          inner.duration,
          reduced ? Duration.zero : standard.durInstant,
          reason: 'reduced: $reduced',
        );
        expect(
          outer.duration,
          reduced ? Duration.zero : standard.durFast,
          reason: 'reduced: $reduced',
        );
        expect(
          ring(tester).duration,
          reduced ? Duration.zero : standard.durFast,
          reason: 'reduced: $reduced',
        );
        expect(outer.curve, standard.easeOut);
        expect(ring(tester).curve, standard.easeOut);
      }
    });

    testWidgets('a focused ghost button keeps the panel colour inside', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        final colors = brightness == Brightness.dark
            ? FermanColorTokens.dark
            : light;
        await tester.pumpWidget(
          componentHost(
            onPanel(
              colors.surfacePanel,
              Button(
                variant: ButtonVariant.ghost,
                onPressed: () {},
                child: const SizedBox.shrink(),
              ),
            ),
            brightness: brightness,
            forcedStates: const {WidgetState.focused},
          ),
        );
        await tester.pumpAndSettle();
        final pixels = await PanelPixels.capture(tester);
        final button = pixels.rectOf(tester, containers.last);
        final y = button.center.dy.floor();
        // Inside the button: the panel, not the ring's raised-surface gap.
        expect(
          pixels.at(button.left.floor() + 3, y),
          colors.surfacePanel,
          reason: '$brightness',
        );
        expect(
          pixels.at(button.left.floor() - 1, y),
          colors.surfaceRaised,
          reason: '$brightness gap',
        );
        expect(
          pixels.at(button.left.floor() - 3, y),
          colors.borderFocus,
          reason: '$brightness ring',
        );
      }
    });

    testWidgets('disabled secondary: sunken fill, no border, no shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          Button(disabled: true, onPressed: () {}, child: const Text('Go')),
        ),
      );
      final box = decoration(tester);
      expect(box.color, light.surfaceSunken);
      expect((box.border! as Border).top.color.a, 0);
      expect(shadow(tester), isEmpty);
      expect(textColor(tester, 'Go'), light.textDisabled);
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
      expect(shadow(tester), isEmpty);
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
