import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/forms/field.dart' show FieldSize;
import 'package:ferman/design/components/forms/select.dart';
import 'package:ferman/design/components/forms/switch.dart';
import 'package:ferman/design/components/navigation/label_collapse.dart';
import 'package:ferman/design/components/navigation/tool_button.dart';
import 'package:ferman/design/components/navigation/toolbar.dart';
import 'package:ferman/design/components/overlays/menu.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import 'navigation_test_helpers.dart';

/// The labelled tools of the fixture, in row order.
const List<String> _labelled = ['Alpha', 'Bravo', 'Charlie', 'Delta'];

/// The items that move into the menu first ([ToolbarOverflow.auto]), in row
/// order; Sierra, after the spacer, moves last.
const List<String> _autos = [
  'Alpha',
  'Bravo',
  'Charlie',
  'Delta',
  'Echo',
  'Zoom',
];

/// What the fixture's items did.
final List<String> _calls = [];

final Map<String, FocusNode> _nodes = {};

FocusNode _node(String label) =>
    _nodes.putIfAbsent(label, () => FocusNode(debugLabel: label));

ToolButton _tool(
  String label,
  IconName icon, {
  bool? active,
  List<String>? shortcut,
  String? reason,
}) => ToolButton(
  icon: icon,
  label: label,
  active: active,
  shortcut: shortcut,
  disabled: reason != null,
  disabledReason: reason,
  focusNode: _node(label),
  onPressed: () => _calls.add(label),
);

/// A bar [width] wide (from a listenable, so it can change while the bar
/// keeps its state): a toggle on, a toggle off and a plain tool, a
/// separator, a tool disabled with a reason, an icon button and a
/// zoom-like item with a submenu entry, then after the spacer a hint and a
/// switch.
Widget _bar(
  ValueListenable<double> width, {
  TextDirection textDirection = TextDirection.ltr,
  String? overflowLabel = 'More tools',
}) => componentHost(
  ValueListenableBuilder<double>(
    valueListenable: width,
    builder: (context, value, _) => SizedBox(
      width: value,
      child: Toolbar(
        semanticLabel: 'Tools',
        overflowLabel: overflowLabel,
        children: [
          _tool('Alpha', IconName.hand, active: true),
          _tool('Bravo', IconName.type, active: false),
          _tool('Charlie', IconName.link, shortcut: const ['Ctrl', 'K']),
          const ToolbarSeparator(),
          _tool('Delta', IconName.crop, reason: 'Later'),
          IconButton(
            icon: IconName.zoomIn,
            label: 'Echo',
            focusNode: _node('Echo'),
            onPressed: () => _calls.add('Echo'),
          ),
          ToolbarItem(
            menuItem: const MenuItem(
              id: 'zoom',
              label: 'Zoom',
              submenu: [
                MenuItem(id: '50', label: '50%', checked: false),
                MenuItem(id: '100', label: '100%', checked: true),
              ],
            ),
            onMenuSelected: (item) => _calls.add('Zoom ${item.id}'),
            child: const ColoredBox(
              key: ValueKey('Zoom'),
              color: Color(0x00000000),
              child: SizedBox(width: 60, height: 26),
            ),
          ),
          const ToolbarSpacer(),
          const Text('Drag to reorder'),
          Switch(
            value: false,
            label: 'Sierra',
            focusNode: _node('Sierra'),
            onChanged: (value) => _calls.add('Sierra $value'),
          ),
        ],
      ),
    ),
  ),
  textDirection: textDirection,
  size: const Size(1000, 400),
);

Finder _item(String label) => switch (label) {
  'Echo' => find.byType(IconButton),
  'Zoom' => find.byKey(const ValueKey('Zoom')),
  'Sierra' => find.byType(Switch),
  'hint' => find.text('Drag to reorder'),
  _ => find.byWidgetPredicate(
    (widget) => widget is ToolButton && widget.label == label,
  ),
};

/// Whether [label]'s item is in the row (painted and hit-tested).
bool _shown(String label) => _item(label).hitTestable().evaluate().isNotEmpty;

/// Whether [label]'s tool draws its label hidden.
bool _compact(WidgetTester tester, String label) => tester
    .renderObject<RenderCollapsibleLabel>(
      find.descendant(
        of: _item(label),
        matching: find.byType(CollapsibleLabel),
      ),
    )
    .isCompact;

bool get _moreShown => _shown('More tools');

Future<void> _pumpAt(
  WidgetTester tester,
  ValueNotifier<double> width,
  double value,
) async {
  width.value = value;
  await tester.pump();
  await tester.pump();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(_item('More tools'));
  await tester.pumpAndSettle();
}

List<String> _menuLabels(WidgetTester tester) => [
  for (final item in tester.widget<Menu>(find.byType(Menu)).items)
    if (item.separator) '—' else item.label,
];

MenuItem _menuItem(WidgetTester tester, String label) => tester
    .widget<Menu>(find.byType(Menu))
    .items
    .firstWhere((item) => item.label == label);

void main() {
  setUp(() {
    _calls.clear();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    for (final node in _nodes.values) {
      node.dispose();
    }
    _nodes.clear();
  });

  group('Toolbar in a narrow window (G21)', () {
    testWidgets('a wide bar shows every item with its label and no overflow '
        'button', (tester) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      await tester.pump();
      for (final label in [..._autos, 'Sierra', 'hint']) {
        expect(_shown(label), isTrue, reason: label);
      }
      for (final label in _labelled) {
        expect(_compact(tester, label), isFalse, reason: label);
      }
      expect(_moreShown, isFalse);
    });

    testWidgets('frees room in the decided order as the bar narrows: the hint '
        'hides, labels hide from the end, then items move into the menu from '
        'the end, the end actions last', (tester) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      var collapsed = 0;
      final seen = <String>{};
      for (var value = 1000.0; value >= 120; value -= 10) {
        await _pumpAt(tester, width, value);
        expect(tester.takeException(), isNull, reason: '$value');
        final bar = tester.getRect(find.byType(Toolbar)).deflate(8);
        final shownLabelled = [
          for (final label in _labelled)
            if (_shown(label)) label,
        ];
        final compact = [
          for (final label in shownLabelled)
            if (_compact(tester, label)) label,
        ];
        final moved = [
          for (final label in [..._autos, 'Sierra'])
            if (!_shown(label)) label,
        ];
        // The hint goes before any label.
        if (compact.isNotEmpty || moved.isNotEmpty) {
          expect(_shown('hint'), isFalse, reason: '$value');
        }
        // Labels hide from the end, and all are hidden before an item moves.
        expect(
          compact,
          shownLabelled.sublist(shownLabelled.length - compact.length),
          reason: '$value',
        );
        if (moved.isNotEmpty) {
          expect(compact, shownLabelled, reason: '$value');
        }
        // Items move from the end; the switch after the spacer moves last.
        final movedAutos = moved.where(_autos.contains).toList();
        expect(
          movedAutos,
          _autos.sublist(_autos.length - movedAutos.length),
          reason: '$value',
        );
        if (moved.contains('Sierra')) {
          expect(movedAutos, _autos, reason: '$value');
        }
        expect(_moreShown, moved.isNotEmpty, reason: '$value');
        // Nothing shown leaves the bar.
        for (final label in [..._autos, 'Sierra', 'More tools']) {
          if (!_shown(label)) continue;
          final rect = tester.getRect(_item(label));
          expect(rect.left, greaterThanOrEqualTo(bar.left - 0.01));
          expect(rect.right, lessThanOrEqualTo(bar.right + 0.01));
        }
        final now = compact.length + moved.length + (_shown('hint') ? 0 : 1);
        expect(now, greaterThanOrEqualTo(collapsed), reason: '$value');
        collapsed = now;
        seen.addAll([
          if (!_shown('hint')) 'hint',
          if (compact.isNotEmpty) 'compact',
          ...moved,
        ]);
      }
      // The sweep went through every step.
      expect(seen, containsAll(['hint', 'compact', ..._autos, 'Sierra']));
    });

    testWidgets('the menu lists exactly the items that moved, in row order, '
        'with their state, shortcut and reason, and invokes them', (
      tester,
    ) async {
      final width = ValueNotifier<double>(120);
      await tester.pumpWidget(_bar(width));
      await tester.pump();
      await tester.pump();
      expect(_moreShown, isTrue);
      await _openMenu(tester);
      // A divider where the row had a separator, and for the spacer; the
      // hint is never listed.
      expect(_menuLabels(tester), [
        'Alpha',
        'Bravo',
        'Charlie',
        '—',
        'Delta',
        'Echo',
        'Zoom',
        '—',
        'Sierra',
      ]);
      expect(_menuItem(tester, 'Alpha').checked, isTrue);
      expect(_menuItem(tester, 'Bravo').checked, isFalse);
      expect(_menuItem(tester, 'Charlie').checked, isNull);
      expect(_menuItem(tester, 'Charlie').shortcut, ['Ctrl', 'K']);
      expect(_menuItem(tester, 'Alpha').icon, IconName.hand);
      expect(_menuItem(tester, 'Delta').disabled, isTrue);
      expect(_menuItem(tester, 'Delta').disabledReason, 'Later');
      expect(_menuItem(tester, 'Sierra').checked, isFalse);
      expect(_menuItem(tester, 'Zoom').submenu?.map((item) => item.label), [
        '50%',
        '100%',
      ]);

      // A disabled entry does nothing.
      await tester.tap(
        find.descendant(of: find.byType(Menu), matching: find.text('Delta')),
      );
      await tester.pumpAndSettle();
      expect(_calls, isEmpty);
      expect(find.byType(Menu), findsOneWidget);

      // Choosing an entry closes the menu, gives focus back to the overflow
      // button and does what the item does.
      await tester.tap(
        find.descendant(of: find.byType(Menu), matching: find.text('Bravo')),
      );
      await tester.pumpAndSettle();
      expect(_calls, ['Bravo']);
      expect(find.byType(Menu), findsNothing);
      expect(focusLabel, 'Toolbar overflow');

      await _openMenu(tester);
      await tester.tap(
        find.descendant(of: find.byType(Menu), matching: find.text('Sierra')),
      );
      await tester.pumpAndSettle();
      expect(_calls, ['Bravo', 'Sierra true']);

      await _openMenu(tester);
      await tester.tap(
        find.descendant(of: find.byType(Menu), matching: find.text('Zoom')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('50%'));
      await tester.pumpAndSettle();
      expect(_calls, ['Bravo', 'Sierra true', 'Zoom 50']);
      expect(find.byType(Menu), findsNothing);
    });

    testWidgets('the overflow button is in the arrow-key order; Enter, Space '
        'and ArrowDown open its menu, Escape closes it', (tester) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      // The widest bar with an item in the menu.
      var value = 1000.0;
      while (!_moreShown) {
        value -= 10;
        await _pumpAt(tester, width, value);
      }
      final last = _autos.lastWhere(_shown);
      _node(last).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(focusLabel, 'Toolbar overflow');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(focusLabel, last);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(find.byType(Menu), findsOneWidget, reason: '$key');
        // The menu takes focus.
        expect(focusLabel, startsWith('Menu item'), reason: '$key');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(Menu), findsNothing, reason: '$key');
        expect(focusLabel, 'Toolbar overflow', reason: '$key');
      }
    });

    testWidgets('a focused tool that moves into the menu hands focus to the '
        'overflow button, which hands it back when the tool returns', (
      tester,
    ) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      _node('Delta').requestFocus();
      await tester.pump();
      var value = 1000.0;
      while (_shown('Delta')) {
        value -= 10;
        await _pumpAt(tester, width, value);
      }
      await tester.pump();
      expect(focusLabel, 'Toolbar overflow');
      await _pumpAt(tester, width, 1000);
      await tester.pump();
      expect(_shown('Delta'), isTrue);
      expect(focusLabel, 'Delta');
    });

    testWidgets('a focused tool keeps its focus node when its label hides', (
      tester,
    ) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      _node('Delta').requestFocus();
      await tester.pump();
      var value = 1000.0;
      while (!_compact(tester, 'Delta')) {
        value -= 10;
        await _pumpAt(tester, width, value);
      }
      expect(_shown('Delta'), isTrue);
      expect(FocusManager.instance.primaryFocus, same(_node('Delta')));
      await _pumpAt(tester, width, 1000);
      expect(FocusManager.instance.primaryFocus, same(_node('Delta')));
    });

    testWidgets('an icon-only tool names itself in its tooltip', (
      tester,
    ) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      var value = 1000.0;
      while (!_compact(tester, 'Charlie')) {
        value -= 10;
        await _pumpAt(tester, width, value);
      }
      final charlie = tester.widget<ToolButton>(_item('Charlie'));
      // The label no longer shows; the button still names itself.
      expect(
        find.descendant(of: _item('Charlie'), matching: find.text('Charlie')),
        findsNothing,
      );
      expect(charlie.label, 'Charlie');
      _node('Charlie').requestFocus();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('right to left: the overflow button sits at the end of the '
        'tools shown, on their left', (tester) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width, textDirection: TextDirection.rtl));
      var value = 1000.0;
      while (!_moreShown) {
        value -= 10;
        await _pumpAt(tester, width, value);
      }
      final bar = tester.getRect(find.byType(Toolbar));
      final last = _autos.lastWhere(_shown);
      expect(tester.getRect(_item('Alpha')).right, bar.right - 8);
      expect(
        tester.getRect(_item('More tools')).right,
        lessThan(tester.getRect(_item(last)).left),
      );
      // The switch after the spacer is at the left end.
      expect(tester.getRect(_item('Sierra')).left, bar.left + 8);
    });

    testWidgets('without an overflow label nothing moves into a menu: the '
        'labels hide and the rest is clipped', (tester) async {
      final width = ValueNotifier<double>(160);
      await tester.pumpWidget(_bar(width, overflowLabel: null));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_item('More tools'), findsNothing);
      expect(_compact(tester, 'Alpha'), isTrue);
    });
    testWidgets('focus goes back to the tool that handed it over as soon as '
        'that tool returns, while others are still in the menu', (
      tester,
    ) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      _node('Charlie').requestFocus();
      await tester.pump();
      var value = 1000.0;
      while (_shown('Charlie')) {
        value -= 2;
        await _pumpAt(tester, width, value);
      }
      await tester.pump();
      expect(focusLabel, 'Toolbar overflow');
      while (value > 140) {
        value -= 20;
        await _pumpAt(tester, width, value);
      }
      while (!_shown('Charlie')) {
        value += 2;
        await _pumpAt(tester, width, value);
      }
      await tester.pump();
      // Delta, Echo and the zoom are still in the menu.
      expect(_moreShown, isTrue);
      expect(focusLabel, 'Charlie');
    });

    testWidgets('after a jump from very narrow to wide, focus goes back to '
        'the tool that handed it over, not the first that returned', (
      tester,
    ) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      _node('Echo').requestFocus();
      await tester.pump();
      var value = 1000.0;
      while (_shown('Echo')) {
        value -= 10;
        await _pumpAt(tester, width, value);
      }
      await tester.pump();
      expect(focusLabel, 'Toolbar overflow');
      await _pumpAt(tester, width, 120);
      await _pumpAt(tester, width, 1000);
      await tester.pump();
      expect(focusLabel, 'Echo');
    });

    testWidgets('a tool that returns while the menu is open leaves focus in '
        'the menu', (tester) async {
      final width = ValueNotifier<double>(1000);
      await tester.pumpWidget(_bar(width));
      _node('Charlie').requestFocus();
      await tester.pump();
      var value = 1000.0;
      while (_shown('Charlie')) {
        value -= 2;
        await _pumpAt(tester, width, value);
      }
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(focusLabel, startsWith('Menu item'));
      while (!_shown('Charlie')) {
        value += 2;
        await _pumpAt(tester, width, value);
      }
      await tester.pump();
      expect(_moreShown, isTrue);
      expect(find.byType(Menu), findsOneWidget);
      expect(focusLabel, startsWith('Menu item'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Menu), findsNothing);
      expect(focusLabel, 'Toolbar overflow');
    });

    testWidgets('an item added before a focused keyed tool leaves its focus '
        'and its place in the row alone', (tester) async {
      final width = ValueNotifier<double>(1000);
      Widget keyed({required bool added}) => componentHost(
        ValueListenableBuilder<double>(
          valueListenable: width,
          builder: (context, value, _) => SizedBox(
            width: value,
            child: Toolbar(
              semanticLabel: 'Tools',
              overflowLabel: 'More tools',
              children: [
                if (added) const SizedBox.shrink(key: ValueKey('New')),
                for (final label in ['Alpha', 'Bravo', 'Charlie'])
                  KeyedSubtree(
                    key: ValueKey(label),
                    child: _tool(label, IconName.hand),
                  ),
                KeyedSubtree(
                  key: const ValueKey('Delta'),
                  child: _tool('Delta', IconName.crop),
                ),
                KeyedSubtree(
                  key: const ValueKey('Echo'),
                  child: _tool('Echo', IconName.link),
                ),
              ],
            ),
          ),
        ),
        size: const Size(1000, 400),
      );
      await tester.pumpWidget(keyed(added: false));
      var value = 1000.0;
      while (_shown('Delta')) {
        value -= 4;
        await _pumpAt(tester, width, value);
      }
      expect(_shown('Charlie'), isTrue);
      _node('Charlie').requestFocus();
      await tester.pump();
      await tester.pumpWidget(keyed(added: true));
      expect(focusLabel, 'Charlie');
      await tester.pump();
      await tester.pump();
      expect(focusLabel, 'Charlie');
      expect(_shown('Charlie'), isTrue);
      expect(_shown('Delta'), isFalse);
    });

    testWidgets('an item that moves into the menu closes the list it opened; '
        'the keys then act on the overflow button', (tester) async {
      final width = ValueNotifier<double>(600);
      var zoom = '100';
      await tester.pumpWidget(
        componentHost(
          ValueListenableBuilder<double>(
            valueListenable: width,
            builder: (context, value, _) => SizedBox(
              width: value,
              child: StatefulBuilder(
                builder: (context, setState) => Toolbar(
                  semanticLabel: 'Tools',
                  overflowLabel: 'More tools',
                  children: [
                    _tool('Alpha', IconName.hand),
                    _tool('Bravo', IconName.type),
                    _tool('Charlie', IconName.link),
                    ToolbarItem(
                      menuItem: const MenuItem(id: 'zoom', label: 'Zoom'),
                      child: SizedBox(
                        width: 92,
                        child: Select<String>(
                          size: FieldSize.sm,
                          semanticLabel: 'Zoom',
                          value: zoom,
                          onChanged: (value) => setState(() => zoom = value),
                          options: const [
                            SelectOption(value: '50', label: 'Fifty'),
                            SelectOption(value: '100', label: 'Hundred'),
                            SelectOption(value: '200', label: 'Twohundred'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          size: const Size(1000, 600),
        ),
      );
      await tester.tap(find.byType(Select<String>));
      await tester.pumpAndSettle();
      expect(find.text('Twohundred'), findsOneWidget);
      await _pumpAt(tester, width, 150);
      await tester.pumpAndSettle();
      expect(_moreShown, isTrue);
      expect(find.byType(Select<String>).hitTestable(), findsNothing);
      // The list closed with its anchor out of the row; focus is on the
      // overflow button.
      expect(find.text('Twohundred'), findsNothing);
      expect(focusLabel, 'Toolbar overflow');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(zoom, '100');
      expect(find.text('Twohundred'), findsNothing);
      // Back in the row, nothing reopens by itself.
      await _pumpAt(tester, width, 600);
      await tester.pumpAndSettle();
      expect(find.text('Twohundred'), findsNothing);
      expect(zoom, '100');
    });
  });
}
