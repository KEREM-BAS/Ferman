import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const target = SizedBox(width: 40, height: 20, key: Key('target'));
  final targetFinder = find.byKey(const Key('target'));

  Future<TestGesture> hover(WidgetTester tester) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(targetFinder));
    await tester.pump();
    return gesture;
  }

  group('Tooltip', () {
    testWidgets('opens after the delay on hover and hides at once on exit', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const Tooltip(message: 'Rotate page', child: target)),
      );
      final gesture = await hover(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Rotate page'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsOneWidget);

      await gesture.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(find.text('Rotate page'), findsNothing);
    });

    testWidgets('a hover the platform reports opens it after the delay and '
        'closes it when it ends', (tester) async {
      Widget tooltip({required bool hovered}) => componentHost(
        Tooltip(message: 'Maximize', hovered: hovered, child: target),
      );
      await tester.pumpWidget(tooltip(hovered: false));
      await tester.pumpWidget(tooltip(hovered: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Maximize'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('Maximize'), findsOneWidget);

      await tester.pumpWidget(tooltip(hovered: false));
      await tester.pump();
      expect(find.text('Maximize'), findsNothing);
      // No bubble later either.
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Maximize'), findsNothing);
    });

    testWidgets('focus the owner reports (an icon-only tab) opens it after '
        'the delay; Escape hides it until the focus changes', (tester) async {
      Widget tooltip({required bool focused}) => componentHost(
        Tooltip(message: 'Comment', focused: focused, child: target),
      );
      await tester.pumpWidget(tooltip(focused: false));
      await tester.pumpWidget(tooltip(focused: true));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Comment'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('Comment'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Comment'), findsNothing);
      await tester.pumpWidget(tooltip(focused: false));
      await tester.pumpAndSettle();
      expect(find.text('Comment'), findsNothing);
    });

    testWidgets('a platform hover present from the start opens it too', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const Tooltip(message: 'Maximize', hovered: true, child: target),
        ),
      );
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Maximize'), findsOneWidget);
    });

    testWidgets('Escape hides it', (tester) async {
      await tester.pumpWidget(
        componentHost(const Tooltip(message: 'Rotate page', child: target)),
      );
      await hover(tester);
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Rotate page'), findsNothing);
    });

    testWidgets('keyboard focus opens it after the delay', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          Tooltip(
            message: 'Rotate page',
            child: Focus(focusNode: node, child: target),
          ),
        ),
      );
      node.requestFocus();
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsOneWidget);
      node.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsNothing);
    });

    testWidgets('open: true forces it open; false keeps it closed', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const Tooltip(message: 'Rotate page', open: true, child: target),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsOneWidget);

      await tester.pumpWidget(
        componentHost(
          const Tooltip(message: 'Rotate page', open: false, child: target),
        ),
      );
      await tester.pump();
      expect(find.text('Rotate page'), findsNothing);
      await hover(tester);
      await tester.pump(Tooltip.defaultDelay);
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsNothing);
    });

    testWidgets('opening later shows it in the next frame without waiting', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const Tooltip(message: 'Rotate page', open: false, child: target),
        ),
      );
      await tester.pumpWidget(
        componentHost(
          const Tooltip(message: 'Rotate page', open: true, child: target),
        ),
      );
      // The switch to open was built in the frame above; the bubble is
      // shown after it and built in the next frame, which it asks for.
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(find.text('Rotate page'), findsOneWidget);
    });

    testWidgets('shows the shortcut as inverse key caps', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const Tooltip(
            message: 'Rotate page',
            shortcut: ['Ctrl', 'R'],
            open: true,
            child: target,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final kbd = tester.widget<Kbd>(find.byType(Kbd));
      expect(kbd.keys, ['Ctrl', 'R']);
      expect(kbd.tone, KbdTone.inverse);
    });

    testWidgets('the bubble: inverse surface and text, caption type', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const Tooltip(message: 'Rotate page', open: true, child: target),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('Rotate page'));
      expect(text.style!.color, FermanColorTokens.light.textInverse);
      final bubble = tester.widget<Container>(
        find.ancestor(
          of: find.text('Rotate page'),
          matching: find.byType(Container),
        ),
      );
      final decoration = bubble.decoration! as BoxDecoration;
      expect(decoration.color, FermanColorTokens.light.surfaceInverse);
    });

    testWidgets('sits 6 px below the child by default', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const Tooltip(message: 'Rotate page', open: true, child: target),
        ),
      );
      await tester.pumpAndSettle();
      final child = tester.getRect(targetFinder);
      final bubble = tester.getRect(
        find
            .ancestor(
              of: find.text('Rotate page'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(bubble.top, child.bottom + Tooltip.gap);
      expect(bubble.center.dx, closeTo(child.center.dx, 0.01));
    });

    testWidgets('left opens before the child, mirrored in right to left', (
      tester,
    ) async {
      Future<Rect> bubbleFor(TextDirection direction) async {
        await tester.pumpWidget(
          componentHost(
            const Tooltip(
              message: 'Rotate page',
              side: TooltipSide.left,
              open: true,
              child: target,
            ),
            textDirection: direction,
          ),
        );
        await tester.pumpAndSettle();
        return tester.getRect(
          find
              .ancestor(
                of: find.text('Rotate page'),
                matching: find.byType(Container),
              )
              .first,
        );
      }

      final ltr = await bubbleFor(TextDirection.ltr);
      expect(ltr.right, tester.getRect(targetFinder).left - Tooltip.gap);
      final rtl = await bubbleFor(TextDirection.rtl);
      expect(rtl.left, tester.getRect(targetFinder).right + Tooltip.gap);
    });

    testWidgets('gives the child the message as its tooltip', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(const Tooltip(message: 'Rotate page', child: target)),
      );
      expect(
        tester.getSemantics(targetFinder),
        matchesSemantics(tooltip: 'Rotate page'),
      );
      handle.dispose();
    });

    testWidgets('does nothing without an overlay', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Tooltip(message: 'Rotate page', open: true, child: target),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rotate page'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
