import 'package:ferman/design/components/forms/popover.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const anchorKey = Key('anchor');
  const contentKey = Key('content');

  Widget host(
    Widget child, {
    TextDirection? textDirection,
    Brightness brightness = Brightness.light,
    bool disableAnimations = false,
  }) => TapRegionSurface(
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
      brightness: brightness,
      disableAnimations: disableAnimations,
    ),
  );

  BoxDecoration surfaceOf(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(PopoverSurface),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  double opacityOf(WidgetTester tester) => tester
      .widget<Opacity>(
        find.ancestor(
          of: find.byKey(contentKey),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

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

    testWidgets('rises in over --dur-base: fades in and moves up 4 px', (
      tester,
    ) async {
      await tester.pumpWidget(host(popover(open: true)));
      await tester.pump();
      final anchor = tester.getRect(find.byKey(anchorKey));
      expect(opacityOf(tester), lessThan(1));
      // `fm-rise-in` starts `translateY(4px)` lower.
      final first = tester.getRect(find.byKey(contentKey)).top;
      expect(first, greaterThan(anchor.bottom + Popover.gap));
      expect(
        first,
        lessThanOrEqualTo(anchor.bottom + Popover.gap + Popover.riseDistance),
      );
      await tester.pump(const Duration(milliseconds: 180));
      expect(opacityOf(tester), 1);
      expect(
        tester.getRect(find.byKey(contentKey)).top,
        anchor.bottom + Popover.gap,
      );
    });

    testWidgets('reduced motion: in place at once', (tester) async {
      await tester.pumpWidget(
        host(popover(open: true), disableAnimations: true),
      );
      await tester.pump();
      final anchor = tester.getRect(find.byKey(anchorKey));
      expect(opacityOf(tester), 1);
      expect(
        tester.getRect(find.byKey(contentKey)).top,
        anchor.bottom + Popover.gap,
      );
    });

    testWidgets('dark theme: the dark raised surface and popover shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(popover(open: true), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      final theme = FermanTheme.dark;
      expect(surfaceOf(tester).color, theme.colors.surfaceRaised);
      expect(surfaceOf(tester).boxShadow, theme.elevation.shadowPopover);
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
      // `.fm-popover__section { padding: 8px 10px 4px }`.
      final section = tester.getRect(find.byType(PopoverSection));
      final label = tester.getRect(find.text('Standard'));
      expect(label.topLeft - section.topLeft, const Offset(10, 8));
      expect(section.bottom - label.bottom, 4);
      expect(section.right - label.right, 10);
      await tester.pumpWidget(
        componentHost(
          const PopoverSection('Standard'),
          textDirection: TextDirection.rtl,
        ),
      );
      final rtlSection = tester.getRect(find.byType(PopoverSection));
      final rtlLabel = tester.getRect(find.text('Standard'));
      expect(rtlSection.right - rtlLabel.right, 10);
      expect(rtlLabel.top - rtlSection.top, 8);
    });
    testWidgets('an open popover whose anchor leaves the screen hides and '
        'asks to be dismissed once; it does not reopen by itself (G21)', (
      tester,
    ) async {
      var dismissed = 0;
      var visible = true;
      var open = true;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return PopoverAnchorVisibility(
                visible: visible,
                child: popover(
                  open: open,
                  onDismiss: () {
                    dismissed++;
                    setState(() => open = false);
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(contentKey), findsOneWidget);
      update(() => visible = false);
      await tester.pumpAndSettle();
      expect(find.byKey(contentKey), findsNothing);
      expect(dismissed, 1);
      update(() => visible = true);
      await tester.pumpAndSettle();
      expect(find.byKey(contentKey), findsNothing);
      expect(dismissed, 1);
    });

    testWidgets('a popover opened while its anchor is hidden shows nothing', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        host(
          PopoverAnchorVisibility(
            visible: false,
            child: popover(open: false, onDismiss: () => dismissed++),
          ),
        ),
      );
      await tester.pumpWidget(
        host(
          PopoverAnchorVisibility(
            visible: false,
            child: popover(open: true, onDismiss: () => dismissed++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(contentKey), findsNothing);
      expect(
        PopoverAnchorVisibility.isVisible(
          tester.element(find.byKey(anchorKey)),
        ),
        isFalse,
      );
    });
  });
}
