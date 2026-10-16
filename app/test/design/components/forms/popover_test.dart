import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const anchorKey = Key('anchor');
  const contentKey = Key('content');

  Widget host(Widget child, {TextDirection? textDirection}) => TapRegionSurface(
    child: componentHost(
      ColoredBox(
        color: const Color(0x00000000),
        child: SizedBox.expand(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(40),
              child: child,
            ),
          ),
        ),
      ),
      textDirection: textDirection,
    ),
  );

  Widget popover({
    required bool open,
    VoidCallback? onDismiss,
    bool surface = true,
    bool matchAnchorWidth = false,
    FocusNode? anchorNode,
  }) => Popover(
    open: open,
    onDismiss: onDismiss,
    surface: surface,
    matchAnchorWidth: matchAnchorWidth,
    anchor: Focus(
      focusNode: anchorNode,
      child: const SizedBox(key: anchorKey, width: 120, height: 26),
    ),
    child: const SizedBox(key: contentKey, width: 80, height: 50),
  );

  group('Popover', () {
    testWidgets('closed: only the anchor', (tester) async {
      await tester.pumpWidget(host(popover(open: false)));
      expect(find.byKey(contentKey), findsNothing);
    });

    testWidgets('open: 4 px under the anchor, start edges lined up, raised '
        'surface with medium corners and the popover shadow', (tester) async {
      await tester.pumpWidget(host(popover(open: true)));
      await tester.pumpAndSettle();
      final anchor = tester.getRect(find.byKey(anchorKey));
      final content = tester.getRect(find.byKey(contentKey));
      expect(content.top, anchor.bottom + Popover.gap);
      expect(content.left, anchor.left);
      final surface = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PopoverSurface),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = surface.decoration as BoxDecoration;
      final theme = FermanTheme.light;
      expect(decoration.color, theme.colors.surfaceRaised);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(6)),
      );
      expect(decoration.boxShadow, theme.elevation.shadowPopover);
    });

    testWidgets('opens and closes when open changes', (tester) async {
      await tester.pumpWidget(host(popover(open: false)));
      await tester.pumpWidget(host(popover(open: true)));
      await tester.pumpAndSettle();
      expect(find.byKey(contentKey), findsOneWidget);
      await tester.pumpWidget(host(popover(open: false)));
      await tester.pumpAndSettle();
      expect(find.byKey(contentKey), findsNothing);
    });

    testWidgets('rises in over --dur-base', (tester) async {
      await tester.pumpWidget(host(popover(open: true)));
      await tester.pump();
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(contentKey),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1));
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.byKey(contentKey),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        1,
      );
    });

    testWidgets('a click outside dismisses; a click on the anchor does not', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        host(popover(open: true, onDismiss: () => dismissed++)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(anchorKey));
      expect(dismissed, 0);
      await tester.tap(find.byKey(contentKey));
      expect(dismissed, 0);
      await tester.tapAt(const Offset(700, 500));
      expect(dismissed, 1);
    });

    testWidgets('Escape dismisses while open', (tester) async {
      var dismissed = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        host(
          popover(open: true, onDismiss: () => dismissed++, anchorNode: node),
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissed, 1);
      await tester.pumpWidget(
        host(
          popover(open: false, onDismiss: () => dismissed++, anchorNode: node),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissed, 1);
    });

    testWidgets('matchAnchorWidth', (tester) async {
      await tester.pumpWidget(
        host(popover(open: true, matchAnchorWidth: true)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(PopoverSurface)).width,
        tester.getSize(find.byKey(anchorKey)).width,
      );
    });

    testWidgets('surface: false places the child as it is', (tester) async {
      await tester.pumpWidget(host(popover(open: true, surface: false)));
      await tester.pumpAndSettle();
      expect(find.byType(PopoverSurface), findsNothing);
      expect(find.byKey(contentKey), findsOneWidget);
    });

    testWidgets('right to left: end edges lined up', (tester) async {
      await tester.pumpWidget(
        host(popover(open: true), textDirection: TextDirection.rtl),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(contentKey)).right,
        tester.getRect(find.byKey(anchorKey)).right,
      );
    });

    testWidgets('PopoverSection: label type, tertiary, tracking', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const PopoverSection('Standard')));
      final text = tester.widget<Text>(find.text('Standard'));
      expect(text.style!.fontSize, 11);
      expect(text.style!.color, FermanTheme.light.colors.textTertiary);
      expect(text.style!.letterSpacing, closeTo(0.22, 0.001));
    });
  });
}
