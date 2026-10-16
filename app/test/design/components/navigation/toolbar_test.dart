import 'package:ferman/design/components/forms/select.dart';
import 'package:ferman/design/components/navigation/segmented_control.dart';
import 'package:ferman/design/components/navigation/tool_button.dart';
import 'package:ferman/design/components/navigation/toolbar.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import 'navigation_test_helpers.dart';

/// The focus nodes the tools of a test use, disposed after it.
final List<FocusNode> _nodes = [];

/// The focus node labelled [label], made once per test.
FocusNode _node(String label) {
  for (final node in _nodes) {
    if (node.debugLabel == label) return node;
  }
  final node = FocusNode(debugLabel: label);
  _nodes.add(node);
  return node;
}

ToolButton _tool(String label, {bool disabled = false, String? reason}) {
  final node = _node(label);
  return ToolButton(
    icon: IconName.hand,
    label: label,
    disabled: disabled,
    disabledReason: reason,
    focusNode: node,
    onPressed: () {},
  );
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    for (final node in _nodes) {
      node.dispose();
    }
    _nodes.clear();
  });

  group('Toolbar', () {
    testWidgets('bar: 44 px on the panel surface with a bottom border', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 600,
            child: Toolbar(semanticLabel: 'View tools', children: [_tool('A')]),
          ),
        ),
      );
      final theme = FermanTheme.light;
      expect(tester.getSize(find.byType(Toolbar)), const Size(600, 44));
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Toolbar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, theme.colors.surfacePanel);
      expect(
        decoration.border,
        Border(bottom: BorderSide(color: theme.colors.borderSubtle)),
      );
      expect(box.padding, const EdgeInsetsDirectional.symmetric(horizontal: 8));
      // The first tool starts 8 px in.
      expect(
        tester.getTopLeft(find.byType(ToolButton)).dx -
            tester.getTopLeft(find.byType(Toolbar)).dx,
        8,
      );
    });

    testWidgets('floating: a raised pill with 3 px padding', (tester) async {
      await tester.pumpWidget(
        componentHost(
          Toolbar(
            variant: ToolbarVariant.floating,
            semanticLabel: 'Text tools',
            children: [_tool('A'), const ToolbarSeparator(), _tool('B')],
          ),
        ),
      );
      final theme = FermanTheme.light;
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(Toolbar),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, theme.colors.surfaceRaised);
      expect(decoration.borderRadius, BorderRadius.circular(8));
      expect(decoration.boxShadow, theme.elevation.shadowPopover);
      expect(tester.getSize(find.byType(Toolbar)).height, 30 + 2 * 3);
      // Floating separators have 3 px of margin on each side, plus the
      // toolbar's 2 px gaps.
      final a = tester.getRect(find.byType(ToolButton).first);
      final b = tester.getRect(find.byType(ToolButton).last);
      expect(b.left - a.right, 2 + 3 + 1 + 3 + 2);
    });

    testWidgets('separator: a 1 × 20 rule in border-default, 6 px margins in '
        'a bar', (tester) async {
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 600,
            child: Toolbar(
              semanticLabel: 'Tools',
              children: [_tool('A'), const ToolbarSeparator(), _tool('B')],
            ),
          ),
        ),
      );
      final theme = FermanTheme.light;
      final rule = find.descendant(
        of: find.byType(ToolbarSeparator),
        matching: find.byType(ColoredBox),
      );
      expect(tester.getSize(rule), const Size(1, 20));
      expect(tester.widget<ColoredBox>(rule).color, theme.colors.borderDefault);
      expect(tester.getSize(find.byType(ToolbarSeparator)).width, 13);
    });

    testWidgets('a spacer pushes the items after it to the end', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 600,
            child: Toolbar(
              semanticLabel: 'Tools',
              children: [_tool('A'), const ToolbarSpacer(), _tool('B')],
            ),
          ),
        ),
      );
      final toolbar = tester.getRect(find.byType(Toolbar));
      final b = tester.getRect(find.byType(ToolButton).last);
      expect(toolbar.right - b.right, 8);
    });

    testWidgets('arrow keys move between items in the visual direction, '
        'skip plain disabled items and stop on ones with a reason', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 600,
            child: Toolbar(
              semanticLabel: 'Tools',
              children: [
                _tool('A'),
                _tool('B', disabled: true),
                _tool('C', disabled: true, reason: 'Later'),
                const ToolbarSeparator(),
                SegmentedControl<int>(
                  options: const [
                    SegmentOption(value: 0, label: 'Zero'),
                    SegmentOption(value: 1, label: 'One'),
                  ],
                  value: 1,
                  semanticLabel: 'Number',
                  onChanged: (_) {},
                ),
                _tool('D'),
              ],
            ),
          ),
        ),
      );
      // Every item stays a Tab stop; the segmented control has one.
      expect(tabStops, ['A', 'C', 'SegmentedControl 1', 'D']);
      await focusFirstTabStop(tester);
      expect(focusLabel, 'A');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'C');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'SegmentedControl 1');
      // Inside the segmented control its own arrow keys win.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusLabel, 'SegmentedControl 0');
      FocusManager.instance.rootScope.descendants
          .firstWhere((node) => node.debugLabel == 'D')
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'A');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(focusLabel, 'D');
    });

    testWidgets('right to left: ArrowRight moves to the previous item', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 600,
            child: Toolbar(
              semanticLabel: 'Tools',
              children: [_tool('A'), _tool('B'), _tool('C')],
            ),
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.text('A')).dx,
        greaterThan(tester.getCenter(find.text('B')).dx),
      );
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(focusLabel, 'B');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'C');
    });

    testWidgets('the arrows follow the order on screen, also for an item '
        'added later', (tester) async {
      Widget bar(List<Widget> children) => componentHost(
        SizedBox(
          width: 600,
          child: Toolbar(semanticLabel: 'Tools', children: children),
        ),
      );
      Widget keyed(String label) =>
          KeyedSubtree(key: ValueKey(label), child: _tool(label));
      await tester.pumpWidget(bar([keyed('A'), keyed('C')]));
      await tester.pumpWidget(bar([keyed('A'), keyed('L'), keyed('C')]));
      // A and C keep their elements, so L's node was attached last.
      expect(tabStops, ['A', 'C', 'L']);
      _node('A').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'L');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'C');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(focusLabel, 'L');
    });

    testWidgets('a tool enabled later takes its place in the arrow order', (
      tester,
    ) async {
      Widget bar({required bool disabled}) => componentHost(
        SizedBox(
          width: 600,
          child: Toolbar(
            semanticLabel: 'Tools',
            children: [
              _tool('U', disabled: disabled),
              _tool('A'),
            ],
          ),
        ),
      );
      await tester.pumpWidget(bar(disabled: true));
      await tester.pumpWidget(bar(disabled: false));
      _node('A').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(focusLabel, 'U');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'A');
    });

    testWidgets('in a select the arrows stay with it, open or closed, and '
        'the open list stays attached', (tester) async {
      final select = FocusNode(debugLabel: 'zoom');
      addTearDown(select.dispose);
      await tester.pumpWidget(
        TapRegionSurface(
          child: componentHost(
            SizedBox(
              width: 600,
              child: Toolbar(
                semanticLabel: 'View tools',
                children: [
                  _tool('A'),
                  SizedBox(
                    width: 140,
                    child: Select<int>(
                      semanticLabel: 'Zoom',
                      focusNode: select,
                      value: 100,
                      onChanged: (_) {},
                      options: const [
                        SelectOption(value: 100, label: '100%'),
                        SelectOption(value: 200, label: '200%'),
                      ],
                    ),
                  ),
                  _tool('B'),
                ],
              ),
            ),
          ),
        ),
      );
      _node('A').requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'zoom');
      // Closed: the arrows do not leave the select.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'zoom');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(focusLabel, 'zoom');
      // Open: nor do they leave it while the list shows.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('200%'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(focusLabel, 'zoom');
      expect(find.text('200%'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('200%'), findsNothing);
      expect(focusLabel, 'zoom');
    });

    testWidgets('dark: the bar on the dark panel surface, the separator in '
        'the dark border colour, the floating pill raised', (tester) async {
      final dark = FermanTheme.dark;
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 600,
            child: Toolbar(
              semanticLabel: 'Tools',
              children: [_tool('A'), const ToolbarSeparator(), _tool('B')],
            ),
          ),
          brightness: Brightness.dark,
        ),
      );
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Toolbar),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, dark.colors.surfacePanel);
      expect(
        decoration.border,
        Border(bottom: BorderSide(color: dark.colors.borderSubtle)),
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byType(ToolbarSeparator),
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        dark.colors.borderDefault,
      );

      await tester.pumpWidget(
        componentHost(
          Toolbar(
            variant: ToolbarVariant.floating,
            semanticLabel: 'Text tools',
            children: [_tool('A')],
          ),
          brightness: Brightness.dark,
        ),
      );
      final pill =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(Toolbar),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(pill.color, dark.colors.surfaceRaised);
      expect(pill.boxShadow, dark.elevation.shadowPopover);
    });

    testWidgets('in a text field the arrows move the caret', (tester) async {
      final controller = TextEditingController(text: 'abc');
      final field = FocusNode(debugLabel: 'field');
      addTearDown(controller.dispose);
      addTearDown(field.dispose);
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 600,
            child: Toolbar(
              semanticLabel: 'Tools',
              children: [
                _tool('A'),
                SizedBox(
                  width: 100,
                  child: EditableText(
                    controller: controller,
                    focusNode: field,
                    style: const TextStyle(),
                    cursorColor: const Color(0xFF000000),
                    backgroundCursorColor: const Color(0xFF000000),
                  ),
                ),
                _tool('B'),
              ],
            ),
          ),
        ),
      );
      field.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'field');
    });

    testWidgets('semantics: a labelled container of separate items', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          SizedBox(
            width: 600,
            child: Toolbar(
              semanticLabel: 'View tools',
              children: [_tool('Select'), _tool('Hand')],
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('View tools'), findsOneWidget);
      expect(find.bySemanticsLabel('Select'), findsOneWidget);
      expect(find.bySemanticsLabel('Hand'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ToolbarGroup', () {
    testWidgets('a labelled group of tools 2 px apart', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          ToolbarGroup(
            semanticLabel: 'History',
            children: [_tool('Undo'), _tool('Redo')],
          ),
        ),
      );
      expect(find.bySemanticsLabel('History'), findsOneWidget);
      final undo = tester.getRect(find.byType(ToolButton).first);
      final redo = tester.getRect(find.byType(ToolButton).last);
      expect(redo.left - undo.right, 2);
      handle.dispose();
    });
  });
}
