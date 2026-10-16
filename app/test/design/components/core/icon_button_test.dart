import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
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

  // The outer container animates the shadow, the inner one (the square)
  // the fill and border.
  final containers = find.descendant(
    of: find.byType(IconButton),
    matching: find.byType(AnimatedContainer),
  );
  final box = containers.last;

  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<AnimatedContainer>(box).decoration! as BoxDecoration;

  List<BoxShadow>? shadow(WidgetTester tester) =>
      (tester.widget<AnimatedContainer>(containers.first).decoration!
              as BoxDecoration)
          .boxShadow;

  FocusRing ring(WidgetTester tester) =>
      tester.widget<FocusRing>(find.byType(FocusRing));

  Icon glyph(WidgetTester tester) => tester.widget<Icon>(find.byType(Icon));

  Future<void> hover(WidgetTester tester) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(IconButton)));
    await tester.pump();
  }

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('IconButton look', () {
    testWidgets('sizes: squares of the control heights, icon sizes, radii', (
      tester,
    ) async {
      for (final (size, extent, icon, radius) in [
        (
          IconButtonSize.xs,
          desktop.controlHXs,
          14.0,
          FermanRadiusTokens.radiusXs,
        ),
        (
          IconButtonSize.sm,
          desktop.controlHSm,
          16.0,
          FermanRadiusTokens.radiusSm,
        ),
        (
          IconButtonSize.md,
          desktop.controlHMd,
          16.0,
          FermanRadiusTokens.radiusSm,
        ),
        (
          IconButtonSize.lg,
          desktop.controlHLg,
          20.0,
          FermanRadiusTokens.radiusSm,
        ),
      ]) {
        await tester.pumpWidget(
          componentHost(
            IconButton(
              key: ValueKey(size),
              icon: IconName.rotateCw,
              label: 'Rotate page',
              size: size,
              onPressed: () {},
            ),
          ),
        );
        expect(tester.getSize(box), Size.square(extent), reason: '$size');
        expect(glyph(tester).size, icon, reason: '$size');
        expect(
          decoration(tester).borderRadius,
          BorderRadius.all(Radius.circular(radius)),
          reason: '$size',
        );
      }
    });

    testWidgets('ghost (default): no fill, primary icon colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.rotateCw,
            label: 'Rotate page',
            onPressed: () {},
          ),
        ),
      );
      expect(decoration(tester).color!.a, 0);
      expect(glyph(tester).color, light.iconPrimary);
    });

    testWidgets('secondary: raised, bordered, small shadow', (tester) async {
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.rotateCw,
            label: 'Rotate page',
            variant: IconButtonVariant.secondary,
            onPressed: () {},
          ),
        ),
      );
      final decorated = decoration(tester);
      expect(decorated.color, light.surfaceRaised);
      expect((decorated.border! as Border).top.color, light.borderDefault);
      expect(shadow(tester), FermanElevationTokens.light.shadowSm);
    });

    testWidgets('primary: accent fill, on-accent icon; dark tokens', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        final colors = brightness == Brightness.dark
            ? FermanColorTokens.dark
            : light;
        await tester.pumpWidget(
          componentHost(
            IconButton(
              icon: IconName.plus,
              label: 'New tab',
              variant: IconButtonVariant.primary,
              onPressed: () {},
            ),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(decoration(tester).color, colors.accent);
        expect(glyph(tester).color, colors.textOnAccent);
      }
    });
  });

  group('IconButton states', () {
    testWidgets('hover: hover fill and primary text colour', (tester) async {
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.rotateCw,
            label: 'Rotate page',
            onPressed: () {},
          ),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      await tester.pumpAndSettle();
      expect(decoration(tester).color, light.surfaceHover);
      expect(glyph(tester).color, light.textPrimary);
    });

    testWidgets('pressed: pressed fill', (tester) async {
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.rotateCw,
            label: 'Rotate page',
            onPressed: () {},
          ),
          forcedStates: const {WidgetState.pressed},
        ),
      );
      await tester.pumpAndSettle();
      expect(decoration(tester).color, light.surfacePressed);
    });

    testWidgets('secondary and primary keep their hover fill while pressed', (
      tester,
    ) async {
      for (final (variant, expected) in [
        (
          IconButtonVariant.secondary,
          Color.alphaBlend(light.surfaceHover, light.surfaceRaised),
        ),
        (IconButtonVariant.primary, light.accentHover),
      ]) {
        await tester.pumpWidget(
          componentHost(
            IconButton(
              icon: IconName.rotateCw,
              label: 'Rotate page',
              variant: variant,
              onPressed: () {},
            ),
            forcedStates: const {WidgetState.hovered, WidgetState.pressed},
          ),
        );
        await tester.pumpAndSettle();
        expect(decoration(tester).color, expected, reason: '$variant');
      }
    });

    testWidgets('toggle on: accent-subtle fill, accent icon, toggled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.bold,
            label: 'Bold',
            active: true,
            onPressed: () {},
          ),
        ),
      );
      expect(decoration(tester).color, light.accentSubtle);
      expect(glyph(tester).color, light.textAccent);
      expect(
        tester.getSemantics(find.byType(Icon)),
        isSemantics(
          label: 'Bold',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
        ),
      );
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.bold,
            label: 'Bold',
            active: true,
            onPressed: () {},
          ),
          forcedStates: const {WidgetState.hovered},
        ),
      );
      await tester.pumpAndSettle();
      expect(decoration(tester).color, light.accentSubtleHover);
      handle.dispose();
    });

    testWidgets('toggle off and plain buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.bold,
            label: 'Bold',
            active: false,
            onPressed: () {},
          ),
        ),
      );
      expect(decoration(tester).color!.a, 0);
      expect(
        tester.getSemantics(find.byType(Icon)),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      await tester.pumpWidget(
        componentHost(
          IconButton(icon: IconName.bold, label: 'Bold', onPressed: () {}),
        ),
      );
      expect(
        tester.getSemantics(find.byType(Icon)),
        isSemantics(hasToggledState: false),
      );
      handle.dispose();
    });

    testWidgets('keyboard focus shows the outer ring; Enter and Space '
        'activate', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.rotateCw,
            label: 'Rotate page',
            focusNode: node,
            onPressed: () => taps++,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(ring(tester).visible, isTrue);
      expect(ring(tester).style, FocusRingStyle.outer);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.tap(find.byType(IconButton));
      expect(taps, 3);
    });

    testWidgets('keyboard focus on a secondary replaces its shadow with the '
        'ring', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.rotateCw,
            label: 'Rotate page',
            variant: IconButtonVariant.secondary,
            focusNode: node,
            onPressed: () {},
          ),
        ),
      );
      expect(shadow(tester), FermanElevationTokens.light.shadowSm);
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(ring(tester).visible, isTrue);
      expect(shadow(tester), isEmpty);
      node.unfocus();
      await tester.pumpAndSettle();
      expect(ring(tester).visible, isFalse);
      expect(shadow(tester), FermanElevationTokens.light.shadowSm);
    });

    testWidgets('fill and icon over --dur-instant, shadow and ring over '
        '--dur-fast', (tester) async {
      const standard = FermanMotionTokens.standard;
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.rotateCw,
            label: 'Rotate page',
            variant: IconButtonVariant.secondary,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.widget<AnimatedContainer>(box).duration,
        standard.durInstant,
      );
      expect(
        tester.widget<AnimatedContainer>(containers.first).duration,
        standard.durFast,
      );
      expect(ring(tester).duration, standard.durFast);
      expect(ring(tester).curve, standard.easeOut);
    });

    testWidgets('a focused ghost button keeps the panel colour inside, light '
        'and dark', (tester) async {
      for (final brightness in Brightness.values) {
        final colors = brightness == Brightness.dark
            ? FermanColorTokens.dark
            : light;
        await tester.pumpWidget(
          componentHost(
            onPanel(
              colors.surfacePanel,
              IconButton(
                icon: IconName.rotateCw,
                label: 'Rotate page',
                onPressed: () {},
              ),
            ),
            brightness: brightness,
            forcedStates: const {WidgetState.focused},
          ),
        );
        await tester.pumpAndSettle();
        expect(ring(tester).visible, isTrue);
        final pixels = await PanelPixels.capture(tester);
        final button = pixels.rectOf(tester, box);
        final x = button.left.floor();
        final y = button.center.dy.floor();
        // Inside, beside the icon: the panel shows through (#F7F6F3 light,
        // #161615 dark), not the ring's raised-surface gap.
        expect(pixels.at(x + 3, y), colors.surfacePanel, reason: '$brightness');
        expect(pixels.at(x + 3, y), isNot(colors.surfaceRaised));
        // The ring: 2 px of the gap, 2 px of the focus colour, then panel.
        expect(
          pixels.at(x - 1, y),
          colors.surfaceRaised,
          reason: '$brightness',
        );
        expect(pixels.at(x - 3, y), colors.borderFocus, reason: '$brightness');
        expect(pixels.at(x - 5, y), colors.surfacePanel, reason: '$brightness');
      }
    });

    testWidgets('a focused disabled-with-reason button stays transparent '
        'inside its ring', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => onPanel(
              light.surfacePanel,
              IconButton(
                icon: IconName.redo2,
                label: 'Redo',
                variant: IconButtonVariant.secondary,
                disabled: true,
                disabledReason: futureVersionReason(context),
                onPressed: () {},
              ),
            ),
          ),
          forcedStates: const {WidgetState.focused},
        ),
      );
      await tester.pumpAndSettle();
      final ringPaint = find
          .descendant(
            of: find.byType(FocusRing),
            matching: find.byType(CustomPaint),
          )
          .first;
      final painter =
          tester.widget<CustomPaint>(ringPaint).painter! as FocusRingPainter;
      expect(painter.progress, 1);
      final inner = painter.borderRadius.toRRect(
        Offset.zero & tester.getSize(box),
      );
      // Only bands outside the control; nothing fills its inside.
      expect(
        ringPaint,
        paints
          ..drrect(inner: inner)
          ..drrect(inner: inner),
      );
      expect(
        ringPaint,
        isNot(paints..rrect(rrect: inner, color: light.surfaceRaised)),
      );
      expect(decoration(tester).color!.a, 0);
      final pixels = await PanelPixels.capture(tester);
      final button = pixels.rectOf(tester, box);
      expect(
        pixels.at(button.left.floor() + 3, button.center.dy.floor()),
        light.surfacePanel,
      );
    });

    testWidgets('disabled: disabled icon colour, no fill, no tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.redo2,
            label: 'Redo',
            variant: IconButtonVariant.primary,
            disabled: true,
            onPressed: () {},
          ),
        ),
      );
      expect(decoration(tester).color!.a, 0);
      expect(glyph(tester).color, light.iconDisabled);
      await hover(tester);
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Redo'), findsNothing);
    });

    testWidgets('disabled with a reason: focusable, the reason as tooltip and '
        'hint', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => IconButton(
              icon: IconName.redo2,
              label: 'Redo',
              disabled: true,
              disabledReason: futureVersionReason(context),
              focusNode: node,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 0);
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(Icon)),
        isSemantics(
          label: 'Redo',
          hint: 'Available in a future version',
          isEnabled: false,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('loading: a spinner the icon size, in the same footprint; '
        'activation waits', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.download,
            label: 'Export',
            loading: true,
            focusNode: node,
            onPressed: () => taps++,
          ),
        ),
      );
      final spinner = tester.widget<Spinner>(find.byType(Spinner));
      expect(spinner.size, 16);
      expect(spinner.semanticLabel, 'Export');
      // The spinner sits inside the still-mounted control: no fill, no
      // border, no shadow.
      expect(
        find.descendant(
          of: find.byType(FermanInteractive),
          matching: find.byType(Spinner),
        ),
        findsOneWidget,
      );
      expect(containers, findsNothing);
      expect(
        tester.getSize(find.byType(IconButton)),
        Size.square(desktop.controlHMd),
      );
      await tester.tap(find.byType(IconButton));
      node.requestFocus();
      // The spinner never settles: two frames land the focus.
      await tester.pump();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 0);
      handle.dispose();
    });

    testWidgets('a focused button keeps its focus and ring through loading', (
      tester,
    ) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      Widget button({required bool loading}) => componentHost(
        IconButton(
          icon: IconName.download,
          label: 'Export',
          loading: loading,
          focusNode: node,
          onPressed: () => taps++,
        ),
      );
      await tester.pumpWidget(button(loading: false));
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(ring(tester).visible, isTrue);
      final control = tester.element(find.byType(FermanInteractive));

      await tester.pumpWidget(button(loading: true));
      // The spinner never settles.
      await tester.pump();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(ring(tester).visible, isTrue);
      expect(find.byType(Spinner), findsOneWidget);
      expect(tester.element(find.byType(FermanInteractive)), same(control));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 0);

      await tester.pumpWidget(button(loading: false));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      expect(ring(tester).visible, isTrue);
      expect(find.byType(Spinner), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    });
  });

  group('IconButton tooltip and semantics', () {
    testWidgets('the label is the tooltip, with the shortcut caps', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.rotateCw,
            label: 'Rotate page',
            shortcut: const ['Ctrl', 'R'],
            tooltipSide: TooltipSide.top,
            onPressed: () {},
          ),
        ),
      );
      final interactive = tester.widget<FermanInteractive>(
        find.byType(FermanInteractive),
      );
      expect(interactive.tooltipSide, TooltipSide.top);
      await hover(tester);
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsOneWidget);
      expect(tester.widget<Kbd>(find.byType(Kbd)).keys, ['Ctrl', 'R']);
    });

    testWidgets('showTooltip false keeps the name, drops the tooltip', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.x,
            label: 'Dismiss',
            showTooltip: false,
            onPressed: () {},
          ),
        ),
      );
      await hover(tester);
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Dismiss'), findsNothing);
      expect(
        tester.getSemantics(find.byType(Icon)),
        isSemantics(label: 'Dismiss', isButton: true),
      );
      handle.dispose();
    });

    testWidgets('a button named by its label, with the tooltip', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          IconButton(
            icon: IconName.settings,
            label: 'Settings',
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(Icon)),
        isSemantics(
          label: 'Settings',
          tooltip: 'Settings',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('only directional glyphs mirror in right to left', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          IconButton(icon: IconName.undo2, label: 'Undo', onPressed: () {}),
          textDirection: TextDirection.rtl,
        ),
      );
      // The Icon widget mirrors IconName.directional glyphs itself.
      expect(glyph(tester).flipRtl, isNull);
      expect(IconName.undo2.directional, isTrue);
    });
  });
}
