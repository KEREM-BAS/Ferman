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

  // The app's own shortcuts and actions (Enter → ActivateIntent), which
  // componentHost leaves out.
  Widget appKeys(Widget child) => Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(actions: WidgetsApp.defaultActions, child: child),
  );

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
      // `box-shadow: 0 1px 2px rgba(0,0,0,.25)`: a CSS blur of 2 px is a
      // sigma of 1, a blurRadius of 0.866.
      expect(Switch.thumbShadow.color, const Color(0x40000000));
      expect(Switch.thumbShadow.offset, const Offset(0, 1));
      expect(Switch.thumbShadow.blurRadius, closeTo(0.866, 1e-3));
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

    testWidgets('Enter does not toggle (Space only)', (tester) async {
      final values = <bool>[];
      var outer = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        appKeys(
          componentHost(
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): () => outer++,
              },
              child: toggle(onChanged: values.add, focusNode: node),
            ),
          ),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      expect(values, isEmpty);
      // Enter passes on to the enclosing handler.
      expect(outer, 1);
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

    testWidgets('disabled: the track at half opacity, the thumb opaque, '
        'disabled label, no toggle, no focus', (tester) async {
      final values = <bool>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          toggle(onChanged: values.add, disabled: true, focusNode: node),
        ),
      );
      // `.fm-switch__input:disabled { opacity: .5 }` fades the track only;
      // the thumb is its sibling.
      expect(
        find.ancestor(of: thumbFinder, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(trackColor(tester), light.borderStrong.withValues(alpha: 0.5));
      final thumb =
          tester.widget<DecoratedBox>(thumbFinder).decoration as BoxDecoration;
      expect(thumb.color, const Color(0xFFFFFFFF));
      expect(thumb.boxShadow, [Switch.thumbShadow]);
      expect(
        tester.widget<Text>(find.text('Mark edited text')).style!.color,
        light.textDisabled,
      );
      await tester.tap(trackFinder, warnIfMissed: false);
      expect(values, isEmpty);
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);
      await tester.pumpWidget(
        componentHost(
          toggle(value: true, onChanged: values.add, disabled: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(trackColor(tester), light.accent.withValues(alpha: 0.5));
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
