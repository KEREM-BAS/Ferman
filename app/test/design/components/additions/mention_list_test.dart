import 'package:ferman/design/components/additions/mention_list.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  final light = FermanTheme.light.colors;

  const people = <MentionCandidate>[
    (initials: 'DA', name: 'Av. Deniz Aksoy'),
    (initials: 'AY', name: 'Ayşe Yılmaz'),
    (initials: 'KB', name: 'Kerem Baş'),
  ];

  Color? rowColor(WidgetTester tester, String name) {
    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text(name), matching: find.byType(Container))
          .first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  group('MentionList', () {
    testWidgets('the drawing: 220 px surface, heading, avatars, rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const MentionList(people: people, heading: 'People in this document'),
        ),
      );
      expect(tester.getSize(find.byType(MentionList)).width, 220);
      expect(
        tester.widget<Text>(find.text('People in this document')).style!.color,
        light.textTertiary,
      );
      expect(rowColor(tester, 'Av. Deniz Aksoy'), light.surfaceSelectedStrong);
      expect(
        tester.widget<Text>(find.text('Av. Deniz Aksoy')).style!.color,
        light.textPrimary,
      );
      expect(
        tester.widget<Text>(find.text('Ayşe Yılmaz')).style!.color,
        light.textSecondary,
      );
      final initials = tester.widget<Text>(find.text('DA'));
      expect(initials.style!.fontSize, 10);
      expect(initials.style!.fontWeight, FontWeight.w600);
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('DA'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .width,
        MentionList.avatarSize,
      );
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Av. Deniz Aksoy'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        MentionList.rowHeight,
      );
    });

    testWidgets('pointer: hover reports the row, a click chooses it', (
      tester,
    ) async {
      final active = <int>[];
      final chosen = <MentionCandidate>[];
      await tester.pumpWidget(
        componentHost(
          MentionList(
            people: people,
            onActiveIndexChanged: active.add,
            onSelected: chosen.add,
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Kerem Baş')));
      await tester.pump();
      expect(active, [2]);
      await tester.tap(find.text('Ayşe Yılmaz'));
      expect(chosen.single.name, 'Ayşe Yılmaz');
    });

    testWidgets('keyboard through the compose field: arrows, Enter, Tab, '
        'Escape', (tester) async {
      var index = 0;
      final chosen = <MentionCandidate>[];
      var dismissed = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        componentHost(
          StatefulBuilder(
            builder: (context, setState) {
              final list = MentionList(
                people: people,
                activeIndex: index,
                onActiveIndexChanged: (next) => setState(() => index = next),
                onSelected: chosen.add,
                onDismiss: () => dismissed++,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Focus(
                    onKeyEvent: list.onKeyEvent,
                    child: Focus(
                      focusNode: node,
                      child: const SizedBox(width: 200, height: 26),
                    ),
                  ),
                  list,
                ],
              );
            },
          ),
        ),
      );
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(rowColor(tester, 'Ayşe Yılmaz'), light.surfaceSelectedStrong);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(index, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(chosen.map((p) => p.name), ['Ayşe Yılmaz', 'Ayşe Yılmaz']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissed, 1);
      expect(node.hasFocus, isTrue);
    });

    testWidgets('semantics: rows named by the person, the active selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          MentionList(
            people: people,
            activeIndex: 1,
            semanticLabel: 'Mention someone',
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.bySemanticsLabel('Mention someone'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Ayşe Yılmaz')),
        isSemantics(
          label: 'Ayşe Yılmaz',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('right to left: avatar on the right', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const MentionList(people: people),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.text('DA')).dx,
        greaterThan(tester.getCenter(find.text('Av. Deniz Aksoy')).dx),
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const MentionList(people: people),
          brightness: Brightness.dark,
        ),
      );
      expect(
        rowColor(tester, 'Av. Deniz Aksoy'),
        FermanTheme.dark.colors.surfaceSelectedStrong,
      );
    });
  });
}
