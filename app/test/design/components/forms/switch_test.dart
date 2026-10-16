import 'package:ferman/design/components/forms/switch.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;
  final dark = FermanTheme.dark.colors;

  final trackFinder = find.descendant(
    of: find.byType(Switch),
    matching: find.byType(AnimatedContainer),
  );
  final thumbFinder = find.descendant(
    of: find.byType(AnimatedPositionedDirectional),
    matching: find.byType(DecoratedBox),
  );

  Color trackColor(WidgetTester tester) =>
      (tester.widget<AnimatedContainer>(trackFinder).decoration!
              as BoxDecoration)
          .color!;

  Widget toggle({
    bool value = false,
    ValueChanged<bool>? onChanged,
    String? label = 'Mark edited text',
    String? semanticLabel,
    bool disabled = false,
    String? disabledReason,
    FocusNode? focusNode,
  }) => Switch(
    value: value,
    onChanged: onChanged,
    label: label,
    semanticLabel: semanticLabel,
    disabled: disabled,
    disabledReason: disabledReason,
    focusNode: focusNode,
  );

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('Switch', () {
    testWidgets('off: 28 × 16 strong track, 12 px white thumb at the start', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(toggle(onChanged: (_) {})));
      expect(tester.getSize(trackFinder), const Size(28, 16));
      expect(trackColor(tester), light.borderStrong);
      final track = tester.getRect(trackFinder);
      final thumb = tester.getRect(thumbFinder);
      expect(thumb.size, const Size.square(12));
      expect(thumb.topLeft, track.topLeft + const Offset(2, 2));
      final decoration =
          tester.widget<DecoratedBox>(thumbFinder).decoration as BoxDecoration;
      expect(decoration.color, Switch.thumbColor);
      expect(decoration.boxShadow, [Switch.thumbShadow]);
    });

    testWidgets('on: accent track, thumb 14 px from the start', (tester) async {
      await tester.pumpWidget(
        componentHost(toggle(value: true, onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(trackColor(tester), light.accent);
      final track = tester.getRect(trackFinder);
      expect(tester.getRect(thumbFinder).left, track.left + 14);
    });

    testWidgets('label 8 px after the track in body text', (tester) async {
      await tester.pumpWidget(componentHost(toggle(onChanged: (_) {})));
      final label = tester.widget<Text>(find.text('Mark edited text'));
      expect(label.style!.color, light.textPrimary);
      expect(
        tester.getTopLeft(find.text('Mark edited text')).dx,
        tester.getRect(trackFinder).right + 8,
      );
    });

    testWidgets('a tap on the row toggles', (tester) async {
      final values = <bool>[];
      await tester.pumpWidget(componentHost(toggle(onChanged: values.add)));
      await tester.tap(find.text('Mark edited text'));
      await tester.pumpWidget(
        componentHost(toggle(value: true, onChanged: values.add)),
      );
      await tester.tap(trackFinder);
      expect(values, [true, false]);
    });

    testWidgets('Space toggles; keyboard focus rings the track', (
      tester,
    ) async {
      final values = <bool>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(toggle(onChanged: values.add, focusNode: node)),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      final ring = tester.widget<FocusRing>(find.byType(FocusRing));
      expect(ring.visible, isTrue);
      expect(ring.style, FocusRingStyle.outer);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, [true]);
    });

    testWidgets('forced focus shows the ring', (tester) async {
      await tester.pumpWidget(
        componentHost(
          toggle(onChanged: (_) {}),
          forcedStates: {WidgetState.focused},
        ),
      );
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);
    });

    testWidgets('disabled: half opacity, disabled label, no toggle', (
      tester,
    ) async {
      final values = <bool>[];
      await tester.pumpWidget(
        componentHost(toggle(onChanged: values.add, disabled: true)),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(Switch),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.5);
      expect(
        tester.widget<Text>(find.text('Mark edited text')).style!.color,
        light.textDisabled,
      );
      await tester.tap(trackFinder, warnIfMissed: false);
      expect(values, isEmpty);
    });

    testWidgets('disabled with a reason: focusable, reason as tooltip and '
        'hint', (tester) async {
      final handle = tester.ensureSemantics();
      final values = <bool>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          toggle(
            onChanged: values.add,
            disabled: true,
            disabledReason: 'Available in a future version',
            focusNode: node,
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(values, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Available in a future version'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Mark edited text')),
        isSemantics(
          label: 'Mark edited text',
          hint: 'Available in a future version',
          hasToggledState: true,
          isToggled: false,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('semantics: toggled, named by the label or semanticLabel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(toggle(value: true, onChanged: (_) {})),
      );
      expect(
        tester.getSemantics(find.byType(Switch)),
        isSemantics(
          label: 'Mark edited text',
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.pumpWidget(
        componentHost(
          toggle(label: null, semanticLabel: 'Update check', onChanged: (_) {}),
        ),
      );
      expect(
        tester.getSemantics(find.byType(Switch)),
        isSemantics(label: 'Update check', hasToggledState: true),
      );
      handle.dispose();
    });

    testWidgets('right to left: the thumb starts on the right and the '
        'label sits to the left', (tester) async {
      await tester.pumpWidget(
        componentHost(
          toggle(onChanged: (_) {}),
          textDirection: TextDirection.rtl,
        ),
      );
      final track = tester.getRect(trackFinder);
      expect(tester.getRect(thumbFinder).right, track.right - 2);
      expect(
        tester.getTopRight(find.text('Mark edited text')).dx,
        track.left - 8,
      );
    });

    testWidgets('touch density: 44 × 26 track, 22 px thumb', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => FermanThemeScope(
              touch: true,
              child: toggle(value: true, onChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(trackFinder), const Size(44, 26));
      final track = tester.getRect(trackFinder);
      final thumb = tester.getRect(thumbFinder);
      expect(thumb.size, const Size.square(22));
      expect(thumb.left, track.left + 20);
    });

    testWidgets('reduced motion: the thumb moves at once', (tester) async {
      await tester.pumpWidget(
        componentHost(toggle(onChanged: (_) {}), disableAnimations: true),
      );
      await tester.pumpWidget(
        componentHost(
          toggle(value: true, onChanged: (_) {}),
          disableAnimations: true,
        ),
      );
      await tester.pump();
      expect(
        tester.getRect(thumbFinder).left,
        tester.getRect(trackFinder).left + 14,
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          toggle(value: true, onChanged: (_) {}),
          brightness: Brightness.dark,
        ),
      );
      expect(trackColor(tester), dark.accent);
    });
  });
}
