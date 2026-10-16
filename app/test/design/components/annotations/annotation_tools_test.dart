import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/annotations/annotation_tool.dart';
import 'package:ferman/design/components/annotations/annotation_tools.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:ferman/design/components/navigation/tool_button.dart';
import 'package:ferman/design/components/navigation/toolbar.dart';
import 'package:ferman/design/components/overlays/menu.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';
import '../navigation/navigation_test_helpers.dart';

const Map<AnnotationTool, String> _toolLabels = {
  AnnotationTool.select: 'Select',
  AnnotationTool.highlight: 'Highlight',
  AnnotationTool.underline: 'Underline',
  AnnotationTool.strikethrough: 'Strikethrough',
  AnnotationTool.note: 'Note',
  AnnotationTool.text: 'Text',
  AnnotationTool.callout: 'Callout',
  AnnotationTool.pen: 'Draw',
  AnnotationTool.shapes: 'Shapes',
  AnnotationTool.stamp: 'Stamp',
  AnnotationTool.measure: 'Measure',
};

const Map<AnnotationColor, String> _colorLabels = {
  AnnotationColor.yellow: 'Yellow',
  AnnotationColor.green: 'Green',
  AnnotationColor.blue: 'Blue',
  AnnotationColor.pink: 'Pink',
  AnnotationColor.orange: 'Orange',
  AnnotationColor.red: 'Red',
  AnnotationColor.ink: 'Black',
};

/// AnnotationTools that keeps its own tool and colour.
class _Host extends StatefulWidget {
  const new({
    this.tool = AnnotationTool.highlight,
    this.onTool,
    this.onColor,
    this.onMenu,
    this.disabledReasons = const {},
    this.colorsDisabledReason,
    this.showLabels = false,
    this.toolsInert = false,
    this.colorsInert = false,
    this.tools = AnnotationTool.values,
    this.width = 1200,
    this.overflowLabel,
  });

  final AnnotationTool tool;
  final ValueChanged<AnnotationTool>? onTool;
  final ValueChanged<AnnotationColor>? onColor;
  final ValueChanged<AnnotationTool>? onMenu;
  final Map<AnnotationTool, String> disabledReasons;
  final String? colorsDisabledReason;
  final bool showLabels;
  final bool toolsInert;
  final bool colorsInert;
  final List<AnnotationTool> tools;
  final double width;
  final String? overflowLabel;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late AnnotationTool _tool = widget.tool;
  AnnotationColor _color = AnnotationColor.yellow;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    child: AnnotationTools(
      overflowLabel: widget.overflowLabel,
      semanticLabel: 'Comment tools',
      colorsSemanticLabel: 'Color',
      toolLabelOf: (tool) => _toolLabels[tool]!,
      colorLabelOf: (color) => _colorLabels[color]!,
      tool: _tool,
      color: _color,
      tools: widget.tools,
      showLabels: widget.showLabels,
      disabledReasons: widget.disabledReasons,
      colorsDisabledReason: widget.colorsDisabledReason,
      onToolMenuRequested: widget.onMenu,
      onToolChanged: widget.toolsInert
          ? null
          : (tool) {
              setState(() => _tool = tool);
              widget.onTool?.call(tool);
            },
      onColorChanged: widget.colorsInert
          ? null
          : (color) {
              setState(() => _color = color);
              widget.onColor?.call(color);
            },
    ),
  );
}

ToolButton _button(WidgetTester tester, String label) =>
    tester.widget<ToolButton>(
      find.byWidgetPredicate(
        (widget) => widget is ToolButton && widget.label == label,
      ),
    );

Finder _swatch(String label) => find.bySemanticsLabel(label);

/// The label of the tool with focus, or the debug label of the focused
/// node when it is not a tool (a colour).
String? _focused() {
  final focus = FocusManager.instance.primaryFocus;
  return focus?.context?.findAncestorWidgetOfExactType<ToolButton>()?.label ??
      focus?.debugLabel;
}

/// The swatch edges drawn, by colour.
List<Color> _edges(WidgetTester tester) => [
  for (final decoration
      in tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>())
    if (decoration.shape == BoxShape.circle && decoration.border != null)
      (decoration.border! as Border).top.color,
];

BoxDecoration _swatchFill(WidgetTester tester, Color color) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .firstWhere(
      (decoration) =>
          decoration.color == color && decoration.shape == BoxShape.circle,
    );

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('AnnotationTools', () {
    testWidgets('a toolbar of eleven tools, a separator and six colours', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(const _Host()));
      expect(find.byType(Toolbar), findsOneWidget);
      expect(find.byType(ToolButton), findsNWidgets(11));
      expect(find.byType(ToolbarSeparator), findsOneWidget);
      for (final label in ['Yellow', 'Green', 'Blue', 'Pink', 'Red', 'Black']) {
        expect(_swatch(label), findsOneWidget);
      }
      expect(_swatch('Orange'), findsNothing);
      // Icon-only by default; the label is the tooltip and name.
      final highlight = _button(tester, 'Highlight');
      expect(highlight.showLabel, isFalse);
      expect(highlight.active, isTrue);
      expect(highlight.shortcut, ['H']);
      expect(_button(tester, 'Select').active, isFalse);
      expect(_button(tester, 'Shapes').hasMenu, isTrue);
      expect(_button(tester, 'Stamp').shortcut, isNull);
      handle.dispose();
    });

    testWidgets('the active coloured tool shows a swatch of the colour', (
      tester,
    ) async {
      await tester.pumpWidget(componentHost(const _Host()));
      final theme = FermanTheme.light;
      expect(_button(tester, 'Highlight').swatch, theme.ramps.annotYellow);
      expect(_button(tester, 'Underline').swatch, isNull);
      await tester.tap(_swatch('Blue'));
      await tester.pump();
      expect(_button(tester, 'Highlight').swatch, theme.ramps.annotBlue);
    });

    testWidgets('labels show when asked (FmWindow)', (tester) async {
      tester.view.physicalSize = const Size(1600, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(componentHost(const _Host(showLabels: true)));
      expect(find.text('Highlight'), findsOneWidget);
      expect(find.text('Draw'), findsOneWidget);
    });

    testWidgets('a tap selects a tool; its single-key shortcut does too', (
      tester,
    ) async {
      final tools = <AnnotationTool>[];
      await tester.pumpWidget(componentHost(_Host(onTool: tools.add)));
      await tester.tap(find.bySemanticsLabel('Note'));
      await tester.pump();
      expect(tools, [AnnotationTool.note]);
      expect(_button(tester, 'Note').active, isTrue);

      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(tools.last, AnnotationTool.pen);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(tools.last, AnnotationTool.measure);
    });

    testWidgets('the colour group is disabled when the tool is not coloured', (
      tester,
    ) async {
      final colors = <AnnotationColor>[];
      await tester.pumpWidget(
        componentHost(_Host(tool: AnnotationTool.select, onColor: colors.add)),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(of: _swatch('Green'), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, AnnotationTools.disabledColorsOpacity);
      await tester.tap(_swatch('Green'), warnIfMissed: false);
      expect(colors, isEmpty);
      expect(tabStops, isNot(contains('AnnotationTools yellow')));
    });

    testWidgets('colours: tap checks; the checked colour has the double ring', (
      tester,
    ) async {
      final colors = <AnnotationColor>[];
      await tester.pumpWidget(componentHost(_Host(onColor: colors.add)));
      final theme = FermanTheme.light;
      expect(tester.getSize(_swatch('Yellow')), const Size(18, 18));
      final checked = _swatchFill(tester, theme.ramps.annotYellow);
      expect(checked.boxShadow, [
        BoxShadow(color: theme.colors.textPrimary, spreadRadius: 4),
        BoxShadow(color: theme.colors.surfacePanel, spreadRadius: 2),
      ]);
      expect(_swatchFill(tester, theme.ramps.annotGreen).boxShadow, isEmpty);
      final ring = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (decoration) =>
                decoration.border ==
                Border.all(color: AnnotationTools.swatchRingLight),
          );
      expect(ring.shape, BoxShape.circle);
      await tester.tap(_swatch('Red'));
      await tester.pump();
      expect(colors, [AnnotationColor.red]);
    });

    testWidgets('hover adds the border-strong halo', (tester) async {
      await tester.pumpWidget(
        componentHost(const _Host(), forcedStates: const {WidgetState.hovered}),
      );
      final theme = FermanTheme.light;
      expect(_swatchFill(tester, theme.ramps.annotGreen).boxShadow, [
        BoxShadow(color: theme.colors.borderStrong, spreadRadius: 2),
      ]);
    });

    testWidgets('dark: the swatch edge is a light ring at rest; checked and '
        'hovered swatches keep the dark edge (the later CSS rules win)', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const _Host(), brightness: Brightness.dark),
      );
      final edges = _edges(tester);
      expect(edges, hasLength(6));
      expect(
        edges.where((edge) => edge == AnnotationTools.swatchRingDark),
        hasLength(5),
      );
      // The checked yellow (a4-1d).
      expect(
        edges.where((edge) => edge == AnnotationTools.swatchRingLight),
        hasLength(1),
      );
      await tester.pumpWidget(
        componentHost(
          const _Host(),
          brightness: Brightness.dark,
          forcedStates: const {WidgetState.hovered},
        ),
      );
      expect(_edges(tester), List.filled(6, AnnotationTools.swatchRingLight));
    });

    testWidgets('colour group keyboard: only the checked colour is a Tab '
        'stop; arrows move and check; focus shows the ring', (tester) async {
      final colors = <AnnotationColor>[];
      await tester.pumpWidget(componentHost(_Host(onColor: colors.add)));
      expect(tabStops.where((label) => label!.startsWith('AnnotationTools')), [
        'AnnotationTools yellow',
      ]);
      tabStopNodes
          .firstWhere((node) => node.debugLabel == 'AnnotationTools yellow')
          .requestFocus();
      await tester.pumpAndSettle();
      final ring = tester.widget<FocusRing>(
        find.descendant(
          of: _swatch('Yellow'),
          matching: find.byType(FocusRing),
        ),
      );
      expect(ring.visible, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(colors, [AnnotationColor.green]);
      expect(focusLabel, 'AnnotationTools green');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(colors.last, AnnotationColor.ink);
    });

    testWidgets('right to left: ArrowLeft moves to the next colour', (
      tester,
    ) async {
      final colors = <AnnotationColor>[];
      await tester.pumpWidget(
        componentHost(
          _Host(onColor: colors.add),
          textDirection: TextDirection.rtl,
        ),
      );
      tabStopNodes
          .firstWhere((node) => node.debugLabel == 'AnnotationTools yellow')
          .requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(colors, [AnnotationColor.green]);
    });

    testWidgets('a tool disabled with a reason stays focusable and cannot be '
        'selected, by tap or shortcut', (tester) async {
      final tools = <AnnotationTool>[];
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) => _Host(
              onTool: tools.add,
              disabledReasons: {
                AnnotationTool.callout: futureVersionReason(context),
              },
            ),
          ),
        ),
      );
      final callout = _button(tester, 'Callout');
      expect(callout.disabled, isTrue);
      expect(callout.disabledReason, 'Available in a future version');
      await tester.tap(find.bySemanticsLabel('Callout'));
      await focusFirstTabStop(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(tools, isEmpty);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Callout')),
        isSemantics(
          hint: 'Available in a future version',
          isEnabled: false,
          isFocusable: true,
        ),
      );
    });

    testWidgets('colours disabled with a reason: focusable, nothing changes', (
      tester,
    ) async {
      final colors = <AnnotationColor>[];
      await tester.pumpWidget(
        componentHost(
          _Host(onColor: colors.add, colorsDisabledReason: 'Not yet'),
        ),
      );
      expect(tabStops, contains('AnnotationTools yellow'));
      await tester.tap(_swatch('Blue'));
      expect(colors, isEmpty);
      tabStopNodes
          .firstWhere((node) => node.debugLabel == 'AnnotationTools yellow')
          .requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusLabel, 'AnnotationTools green');
      expect(colors, isEmpty);
      expect(
        tester.getSemantics(_swatch('Green')),
        isSemantics(hint: 'Not yet', isEnabled: false, isFocusable: true),
      );
      // The swatches are dimmed, but the focus ring is not (G22).
      final ring = find.descendant(
        of: _swatch('Green'),
        matching: find.byType(FocusRing),
      );
      expect(tester.widget<FocusRing>(ring).visible, isTrue);
      expect(
        find.ancestor(of: ring, matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: ring, matching: find.byType(Opacity)),
            )
            .opacity,
        AnnotationTools.disabledColorsOpacity,
      );
    });

    testWidgets('a coloured active tool missing from tools keeps the colours '
        "enabled (the bundle's cur && !cur.colored)", (tester) async {
      final colors = <AnnotationColor>[];
      await tester.pumpWidget(
        componentHost(
          _Host(
            tool: AnnotationTool.shapes,
            tools: const [AnnotationTool.select, AnnotationTool.highlight],
            onColor: colors.add,
          ),
        ),
      );
      expect(find.byType(Opacity), findsNothing);
      await tester.tap(_swatch('Blue'));
      expect(colors, [AnnotationColor.blue]);
    });

    testWidgets('arrow keys move across the tools as in Toolbar, visiting a '
        'tool disabled with a reason, then into the colour group', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const _Host(disabledReasons: {AnnotationTool.callout: 'Later'}),
        ),
      );
      await focusFirstTabStop(tester);
      expect(_focused(), 'Select');
      final visited = <String?>[];
      for (var i = 0; i < 11; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        visited.add(_focused());
      }
      expect(visited, [
        'Highlight',
        'Underline',
        'Strikethrough',
        'Note',
        'Text',
        'Callout',
        'Draw',
        'Shapes',
        'Stamp',
        'Measure',
        // The colour group's only Tab stop, the checked colour.
        'AnnotationTools yellow',
      ]);
      // Inside the colour group its own arrows win.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_focused(), 'AnnotationTools ink');
      // From the first tool, ArrowLeft wraps to the colour group.
      await focusFirstTabStop(tester);
      expect(_focused(), 'Select');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_focused(), 'AnnotationTools ink');
    });

    testWidgets('right to left: ArrowLeft moves to the next tool', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(const _Host(), textDirection: TextDirection.rtl),
      );
      await focusFirstTabStop(tester);
      expect(_focused(), 'Select');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_focused(), 'Highlight');
    });

    testWidgets('inert tools and colours have no Tab stops', (tester) async {
      await tester.pumpWidget(
        componentHost(const _Host(toolsInert: true, colorsInert: true)),
      );
      expect(tabStops, isEmpty);
    });

    testWidgets('tools that become active keep the arrow order: ArrowRight '
        'from Draw lands on Shapes', (tester) async {
      await tester.pumpWidget(componentHost(const _Host(toolsInert: true)));
      await tester.pumpWidget(componentHost(const _Host()));
      tabStopNodes
          .firstWhere(
            (node) =>
                node.context
                    ?.findAncestorWidgetOfExactType<ToolButton>()
                    ?.label ==
                'Draw',
          )
          .requestFocus();
      await tester.pumpAndSettle();
      expect(_focused(), 'Draw');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_focused(), 'Shapes');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_focused(), 'Stamp');
    });

    testWidgets('ArrowDown on a tool with a menu asks for the menu', (
      tester,
    ) async {
      final menus = <AnnotationTool>[];
      await tester.pumpWidget(componentHost(_Host(onMenu: menus.add)));
      tabStopNodes[8].requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(menus, [AnnotationTool.shapes]);
    });

    testWidgets('semantics: a toolbar with a colour radio group', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(componentHost(const _Host()));
      expect(find.bySemanticsLabel('Comment tools'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Color')),
        isSemantics(role: SemanticsRole.radioGroup),
      );
      expect(
        tester.getSemantics(_swatch('Yellow')),
        isSemantics(
          isInMutuallyExclusiveGroup: true,
          hasCheckedState: true,
          isChecked: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Highlight')),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      handle.dispose();
    });
    testWidgets('in a narrow row the tools move into "More tools" from the '
        'end, with their shortcut and state, and the colours stay (G21)', (
      tester,
    ) async {
      final tools = <AnnotationTool>[];
      await tester.pumpWidget(
        componentHost(
          _Host(width: 360, overflowLabel: 'More tools', onTool: tools.add),
          size: const Size(1000, 600),
        ),
      );
      await tester.pump();
      await tester.pump();
      bool shown(Finder finder) => finder.hitTestable().evaluate().isNotEmpty;
      Finder tool(String label) => find.byWidgetPredicate(
        (widget) => widget is ToolButton && widget.label == label,
      );
      for (final label in _colorLabels.values) {
        if (label == 'Orange') continue;
        expect(shown(_swatch(label)), isTrue, reason: label);
      }
      final moved = [
        for (final label in _toolLabels.values)
          if (!shown(tool(label))) label,
      ];
      final labels = _toolLabels.values.toList();
      expect(moved, isNotEmpty);
      expect(moved, labels.sublist(labels.length - moved.length));
      expect(shown(tool('More tools')), isTrue);

      await tester.tap(tool('More tools'));
      await tester.pumpAndSettle();
      final menu = tester.widget<Menu>(find.byType(Menu));
      expect(menu.items.map((item) => item.label), moved);
      final measure = menu.items.last;
      expect(measure.label, 'Measure');
      expect(measure.shortcut, ['M']);
      expect(measure.checked, isFalse);
      expect(measure.icon, AnnotationTool.measure.icon);

      await tester.tap(
        find.descendant(of: find.byType(Menu), matching: find.text('Measure')),
      );
      await tester.pumpAndSettle();
      expect(tools, [AnnotationTool.measure]);
      await tester.tap(tool('More tools'));
      await tester.pumpAndSettle();
      expect(tester.widget<Menu>(find.byType(Menu)).items.last.checked, isTrue);
    });

    testWidgets('when every tool has moved, the colours move too, as a Color '
        'submenu with the current colour checked', (tester) async {
      final colors = <AnnotationColor>[];
      await tester.pumpWidget(
        componentHost(
          _Host(width: 90, overflowLabel: 'More tools', onColor: colors.add),
          size: const Size(1000, 600),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is ToolButton && widget.label == 'More tools',
        ),
      );
      await tester.pumpAndSettle();
      final items = tester.widget<Menu>(find.byType(Menu)).items;
      expect(items.map((item) => item.separator ? '—' : item.label), [
        ..._toolLabels.values,
        '—',
        'Color',
      ]);
      final color = items.last;
      expect(color.submenu?.map((item) => item.label), [
        'Yellow',
        'Green',
        'Blue',
        'Pink',
        'Red',
        'Black',
      ]);
      expect(color.submenu?.first.checked, isTrue);
      expect(color.submenu?[1].checked, isFalse);
      await tester.tap(
        find.descendant(of: find.byType(Menu), matching: find.text('Color')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();
      expect(colors, [AnnotationColor.blue]);
    });
  });
}
