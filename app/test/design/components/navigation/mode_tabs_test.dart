import 'dart:ui' show SemanticsRole, Tristate;

import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/design/components/navigation/mode_tabs.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import 'navigation_test_helpers.dart';

const Map<FermanMode, String> _labels = {
  FermanMode.view: 'View',
  FermanMode.edit: 'Edit',
  FermanMode.comment: 'Comment',
  FermanMode.sign: 'Fill & Sign',
  FermanMode.organize: 'Organize',
  FermanMode.convert: 'Convert',
  FermanMode.protect: 'Protect',
  FermanMode.tools: 'Tools',
};

String _labelOf(FermanMode mode) => _labels[mode]!;

/// A ModeTabs that keeps its own value, as the shell's provider would.
class _Host extends StatefulWidget {
  const new({
    this.onChanged,
    this.variant = ModeTabsVariant.segmented,
    this.showIcons = false,
  });

  final ValueChanged<FermanMode>? onChanged;
  final ModeTabsVariant variant;
  final bool showIcons;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  FermanMode _value = FermanMode.edit;

  @override
  Widget build(BuildContext context) => ModeTabs(
    value: _value,
    labelOf: _labelOf,
    semanticLabel: 'Mode',
    variant: widget.variant,
    showIcons: widget.showIcons,
    onChanged: (mode) {
      setState(() => _value = mode);
      widget.onChanged?.call(mode);
    },
  );
}

BoxDecoration _tabDecoration(WidgetTester tester, String label) {
  final container = find.ancestor(
    of: find.text(label),
    matching: find.byType(AnimatedContainer),
  );
  return tester.widget<AnimatedContainer>(container.first).decoration!
      as BoxDecoration;
}

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('ModeTabs', () {
    testWidgets('shows the eight modes with the labels from labelOf', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const _Host()));
      for (final label in _labels.values) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('segmented track and tabs use the navigation.css tokens', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const _Host()));
      final theme = FermanTheme.light;
      final track = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = track.decoration as BoxDecoration;
      expect(decoration.color, theme.colors.surfaceSunken);
      expect(decoration.border, Border.all(color: theme.colors.borderSubtle));
      expect(decoration.borderRadius, BorderRadius.circular(6));
      // 26 px tabs, 2 px padding and a 1 px border: 32 px.
      expect(tester.getSize(find.byType(ModeTabs)).height, 32);
      final tab = find.ancestor(
        of: find.text('View'),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(tab).height, 26);

      final selected = _tabDecoration(tester, 'Edit');
      expect(selected.color, theme.colors.surfaceRaised);
      expect(selected.borderRadius, BorderRadius.circular(4));
      expect(selected.boxShadow, [
        BoxShadow(color: theme.colors.borderSubtle, spreadRadius: 1),
        ...theme.elevation.shadowSm,
      ]);
      expect(textColor(tester, 'Edit'), theme.colors.textPrimary);

      final idle = _tabDecoration(tester, 'View');
      expect(idle.color, const Color(0x00000000));
      expect(idle.boxShadow, isEmpty);
      expect(textColor(tester, 'View'), theme.colors.textSecondary);
      final style = textStyle(tester, 'View');
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w500);
    });

    testWidgets('dark: the selected tab is soot-200 without a shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const _Host(), brightness: Brightness.dark),
      );
      final theme = FermanTheme.dark;
      final selected = _tabDecoration(tester, 'Edit');
      expect(selected.color, theme.ramps.soot200);
      expect(selected.boxShadow, isEmpty);
      expect(textColor(tester, 'Edit'), theme.colors.textPrimary);
      expect(textColor(tester, 'View'), theme.colors.textSecondary);
    });

    testWidgets('hover tints an unselected tab, not the selected one', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const _Host(), forcedStates: const {WidgetState.hovered}),
      );
      await tester.pumpAndSettle();
      final theme = FermanTheme.light;
      expect(_tabDecoration(tester, 'View').color, theme.colors.surfaceHover);
      expect(textColor(tester, 'View'), theme.colors.textPrimary);
      expect(_tabDecoration(tester, 'Edit').color, theme.colors.surfaceRaised);
    });

    testWidgets('icons: secondary, accent on the selected tab', (tester) async {
      await tester.pumpWidget(componentHost(const _Host(showIcons: true)));
      final theme = FermanTheme.light;
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons, hasLength(8));
      expect(icons[1].name, IconName.filePenLine);
      expect(icons[1].color, theme.colors.textAccent);
      expect(icons[0].color, theme.colors.iconSecondary);
      expect(icons[0].size, 16);
    });

    testWidgets('a tap selects the mode', (tester) async {
      final changes = <FermanMode>[];
      await tester.pumpWidget(componentHost(_Host(onChanged: changes.add)));
      await tester.tap(find.text('Organize'));
      await tester.pump();
      expect(changes, [FermanMode.organize]);
    });

    testWidgets('only the selected tab is a Tab stop; focus shows the inset '
        'ring', (tester) async {
      await tester.pumpWidget(componentHost(const _Host()));
      expect(tabStops, ['ModeTabs edit']);
      await focusFirstTabStop(tester);
      expect(focusLabel, 'ModeTabs edit');
      final ring = tester.widget<FocusRing>(
        find.ancestor(of: find.text('Edit'), matching: find.byType(FocusRing)),
      );
      expect(ring.visible, isTrue);
      expect(ring.style, FocusRingStyle.inset);
      final idle = tester.widget<FocusRing>(
        find.ancestor(of: find.text('View'), matching: find.byType(FocusRing)),
      );
      expect(idle.visible, isFalse);
    });

    testWidgets('arrow keys move and select, wrapping; Home and End', (
      tester,
    ) async {
      final changes = <FermanMode>[];
      await tester.pumpWidget(componentHost(_Host(onChanged: changes.add)));
      await focusFirstTabStop(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changes.last, FermanMode.comment);
      expect(focusLabel, 'ModeTabs comment');
      // The roving Tab stop follows the selection.
      expect(tabStops, ['ModeTabs comment']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changes.last, FermanMode.tools);
      expect(focusLabel, 'ModeTabs tools');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changes.last, FermanMode.view);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(changes.last, FermanMode.tools);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(changes.last, FermanMode.view);
      expect(focusLabel, 'ModeTabs view');
      expect(tabStops, ['ModeTabs view']);
    });

    testWidgets('arrow keys with a modifier held are left to the app', (
      tester,
    ) async {
      final changes = <FermanMode>[];
      await tester.pumpWidget(componentHost(_Host(onChanged: changes.add)));
      await focusFirstTabStop(tester);
      for (final modifier in [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.sendKeyUpEvent(modifier);
        await tester.pumpAndSettle();
      }
      expect(changes, isEmpty);
      expect(focusLabel, 'ModeTabs edit');
    });

    testWidgets('when the modes overflow, a tab moved to off screen scrolls '
        'into view at once', (tester) async {
      await tester.pumpWidget(
        componentHost(const SizedBox(width: 240, child: _Host())),
      );
      Rect tab(String label) => tester.getRect(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final viewport = tester.getRect(find.byType(Scrollable));
      expect(tab('Tools').left, greaterThan(viewport.right));
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      // No scroll animation: in view after one frame.
      await tester.pump();
      expect(tab('Tools').right, lessThanOrEqualTo(viewport.right));
      expect(tab('Tools').left, greaterThanOrEqualTo(viewport.left));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(tab('View').left, greaterThanOrEqualTo(viewport.left));
    });

    testWidgets('when the modes overflow, the clip is the inside of the '
        'track border, 2 px clear of the tabs (CSS padding box)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const SizedBox(width: 200, child: _Host())),
      );
      final track = tester.getRect(find.byType(ModeTabs));
      final viewport = tester.getRect(find.byType(Scrollable));
      final edit = tester.getRect(
        find.ancestor(
          of: find.text('Edit'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(track.width, 200);
      // The viewport (the clip) is inside the 1 px border …
      expect(viewport, track.deflate(1));
      // … and the selected tab's 1 px ring and shadow have 2 px inside it.
      expect(edit.top - viewport.top, 2);
      expect(viewport.bottom - edit.bottom, 2);
      expect(viewport.height, edit.height + 4);
    });

    testWidgets('right to left: ArrowRight moves to the previous tab and the '
        'strip mirrors', (tester) async {
      final changes = <FermanMode>[];
      await tester.pumpWidget(
        componentHost(
          _Host(onChanged: changes.add),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.text('View')).dx,
        greaterThan(tester.getCenter(find.text('Edit')).dx),
      );
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changes.last, FermanMode.view);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(changes.last, FermanMode.edit);
    });

    testWidgets('semantics: a tab bar of tabs that say whether selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(const _Host()));
      final bar = tester.getSemantics(find.bySemanticsLabel('Mode'));
      expect(bar.getSemanticsData().role, SemanticsRole.tabBar);

      final edit = tester.getSemantics(find.bySemanticsLabel('Edit'));
      expect(edit.getSemanticsData().role, SemanticsRole.tab);
      expect(
        edit.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(
        edit,
        isSemantics(
          label: 'Edit',
          isFocusable: true,
          isEnabled: true,
          hasTapAction: true,
          isButton: false,
        ),
      );
      final view = tester.getSemantics(find.bySemanticsLabel('View'));
      expect(view.getSemanticsData().role, SemanticsRole.tab);
      expect(
        view.getSemanticsData().flagsCollection.isSelected,
        Tristate.isFalse,
      );
      // One node per tab: no extra child repeating the selected state.
      expect(view.childrenCount, 0);
      expect(edit.childrenCount, 0);
      expect(find.bySemanticsLabel('Fill & Sign'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('without onChanged the tabs are inert', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const ModeTabs(
            value: FermanMode.view,
            labelOf: _labelOf,
            semanticLabel: 'Mode',
          ),
        ),
      );
      expect(tabStops, isEmpty);
    });

    testWidgets('underline variant: 40 px tabs, an accent bar under the '
        'selected one, no track', (tester) async {
      await tester.pumpWidget(
        componentHost(const _Host(variant: ModeTabsVariant.underline)),
      );
      final theme = FermanTheme.light;
      expect(tester.getSize(find.byType(ModeTabs)).height, 40);
      expect(_tabDecoration(tester, 'Edit').color, const Color(0x00000000));
      final bar = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).color == theme.colors.accent,
      );
      expect(bar, findsOneWidget);
      expect(tester.getSize(bar).height, ModeTabs.underlineThickness);
      final edit = tester.getRect(
        find.ancestor(
          of: find.text('Edit'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final barRect = tester.getRect(bar);
      expect(barRect.left, edit.left + 10);
      expect(barRect.right, edit.right - 10);
      expect(barRect.bottom, edit.bottom);
    });

    testWidgets('touch density: 44 px tabs', (tester) async {
      await tester.pumpWidget(
        componentHost(const FermanThemeScope(touch: true, child: _Host())),
      );
      final tab = find.ancestor(
        of: find.text('View'),
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(tab).height, 44);
    });
  });
}
