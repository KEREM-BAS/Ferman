import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/panels/panel_section.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;

  Widget panel(Widget child) => SizedBox(width: 264, child: child);

  double chevronTurns(WidgetTester tester) =>
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('PanelSection', () {
    testWidgets('header, actions and body; panel-title type; padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          panel(
            const PanelSection(
              title: 'Text',
              actions: [SizedBox.square(dimension: 22, key: Key('action'))],
              child: SizedBox(height: 40, key: Key('body')),
            ),
          ),
        ),
      );
      final title = tester.widget<Text>(find.text('Text'));
      expect(title.style!.fontWeight, FermanTypeTokens.weightSemibold);
      expect(title.style!.fontSize, FermanTypeTokens.sizeMd);
      expect(title.style!.color, light.textPrimary);
      final section = tester.getRect(find.byType(PanelSection));
      final body = tester.getRect(find.byKey(const Key('body')));
      // 1 px border + 36 px header above the body; 12 px sides, 14 below.
      expect(body.top - section.top, 1 + PanelSection.headMinHeight);
      expect(body.left - section.left, 12);
      expect(section.right - body.right, 12);
      expect(section.bottom - body.bottom, PanelSection.bodyPaddingBottom);
      // Actions end 8 px from the edge.
      expect(
        section.right - tester.getRect(find.byKey(const Key('action'))).right,
        8,
      );
      // The chevron starts 12 px in (the toggle starts 4 px before it).
      final chevron = tester.getRect(find.byType(Icon));
      expect(chevron.left - section.left, 12);
      expect(chevron.width, PanelSection.chevronSize);
      expect(tester.widget<Icon>(find.byType(Icon)).color, light.iconSecondary);
      expect(tester.widget<Icon>(find.byType(Icon)).name, IconName.chevronDown);
    });

    testWidgets('the body is placed as it is; bodyGap is --space-2-5', (
      tester,
    ) async {
      expect(PanelSection.bodyGap, FermanSpaceTokens.space2_5);
      await tester.pumpWidget(
        componentHost(
          panel(
            const PanelSection(
              title: 'Text',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: PanelSection.bodyGap,
                children: [
                  SizedBox(height: 20, key: Key('first')),
                  SizedBox(height: 20, key: Key('second')),
                ],
              ),
            ),
          ),
        ),
      );
      // The 10 px between the parts is the caller's Column, as documented.
      expect(
        tester.getTopLeft(find.byKey(const Key('second'))).dy -
            tester.getBottomLeft(find.byKey(const Key('first'))).dy,
        10,
      );
    });

    testWidgets('top border, off for the first section', (tester) async {
      BoxDecoration decoration() =>
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(PanelSection),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      await tester.pumpWidget(
        componentHost(
          panel(const PanelSection(title: 'Text', child: SizedBox())),
        ),
      );
      final border = decoration().border! as Border;
      expect(border.top.color, light.borderSubtle);
      expect(border.top.width, 1);
      await tester.pumpWidget(
        componentHost(
          panel(
            const PanelSection(
              title: 'Text',
              showTopBorder: false,
              child: SizedBox(),
            ),
          ),
        ),
      );
      expect(decoration().border, isNull);
    });

    testWidgets('toggles on tap; the chevron turns; the body goes', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        componentHost(
          panel(
            PanelSection(
              title: 'Text',
              onOpenChanged: changes.add,
              child: const Text('Body'),
            ),
          ),
        ),
      );
      expect(find.text('Body'), findsOneWidget);
      expect(chevronTurns(tester), 0);
      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing);
      expect(chevronTurns(tester), -0.25);
      expect(changes, [false]);
      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget);
      expect(changes, [false, true]);
    });

    testWidgets('initiallyOpen false starts collapsed', (tester) async {
      await tester.pumpWidget(
        componentHost(
          panel(
            const PanelSection(
              title: 'Language',
              initiallyOpen: false,
              child: Text('Body'),
            ),
          ),
        ),
      );
      expect(find.text('Body'), findsNothing);
      expect(chevronTurns(tester), -0.25);
    });

    testWidgets('right to left turns the chevron the other way', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          panel(
            const PanelSection(
              title: 'اللغة',
              initiallyOpen: false,
              child: Text('Body'),
            ),
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(chevronTurns(tester), 0.25);
      final section = tester.getRect(find.byType(PanelSection));
      expect(section.right - tester.getRect(find.byType(Icon)).right, 12);
    });

    testWidgets('controlled: open comes from outside', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        componentHost(
          panel(
            PanelSection(
              title: 'Text',
              open: true,
              onOpenChanged: changes.add,
              child: const Text('Body'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();
      expect(changes, [false]);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('keyboard: inset focus ring, Enter and Space toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          Shortcuts(
            shortcuts: WidgetsApp.defaultShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: FocusScope(
                autofocus: true,
                child: panel(
                  const PanelSection(title: 'Text', child: Text('Body')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final ring = tester.widget<FocusRing>(find.byType(FocusRing));
      expect(ring.visible, isTrue);
      expect(ring.style, FocusRingStyle.inset);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('not collapsible: a static heading, always open', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          panel(
            const PanelSection(
              title: 'Text',
              collapsible: false,
              initiallyOpen: false,
              child: Text('Body'),
            ),
          ),
        ),
      );
      expect(find.byType(FermanInteractive), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(find.text('Body'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Text')),
        isSemantics(label: 'Text', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('a region named by the title; the toggle is an expandable '
        'button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          panel(const PanelSection(title: 'Text', child: Text('Body'))),
        ),
      );
      final region = tester.getSemantics(
        find
            .descendant(
              of: find.byType(PanelSection),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(region.getSemanticsData().role, SemanticsRole.region);
      expect(region.label, 'Text');
      expect(
        tester.getSemantics(find.text('Text')),
        isSemantics(
          label: 'Text',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Text')),
        isSemantics(hasExpandedState: true, isExpanded: false),
      );
      handle.dispose();
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          panel(const PanelSection(title: 'Text', child: SizedBox())),
          brightness: Brightness.dark,
        ),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(PanelSection),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(
        (decoration.border! as Border).top.color,
        FermanColorTokens.dark.borderSubtle,
      );
    });
  });
}
