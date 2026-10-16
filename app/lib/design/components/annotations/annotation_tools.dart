import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/annotations/annotation_tool.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/navigation/roving_focus.dart';
import 'package:ferman/design/components/navigation/tool_button.dart';
import 'package:ferman/design/components/navigation/toolbar.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The Comment mode's tool row, the design-system `AnnotationTools`
/// component (`AnnotationTools.jsx`; `components/annotations/annotations.css`,
/// `.fm-annot-colors`, `.fm-annot-color`): a [Toolbar] with one
/// [ToolButton] per [AnnotationTool], a [ToolbarSeparator] and the colour
/// radio group.
///
/// The row is controlled: [tool] is the active tool and [color] the current
/// annotation colour; [onToolChanged] and [onColorChanged] are called with
/// the user's choice. The active tool is drawn on (`aria-pressed`); when it
/// is [AnnotationTool.colored] its button shows a swatch of [color], and
/// otherwise the colour group is disabled (opacity 0.4, as the bundle's
/// inline style).
///
/// **Disabled tools** (G10): a tool in [disabledReasons] is a
/// disabled-with-reason tool button: it stays focusable, shows its reason
/// as tooltip and hint and cannot be selected. M1 passes the localized
/// "Available in a future version" for every unshipped tool.
/// [colorsDisabledReason] does the same for the whole colour group,
/// independently of the active tool.
///
/// **Labels.** Tool and colour names come from the caller ([toolLabelOf],
/// [colorLabelOf]), as do the names of the row ([semanticLabel], "Comment
/// tools") and of the colour group ([colorsSemanticLabel], "Color").
///
/// **Keyboard:** ArrowLeft and ArrowRight move between the tools as in
/// [Toolbar]; each tool's single-key shortcut ([AnnotationTool.shortcut]:
/// V, H, U, S, N, X, C, P, R, M) selects it while focus is in the row, and
/// shows in its tooltip; inside the colour group ArrowLeft and ArrowRight
/// move and check (radio-group pattern; not in the bundle), with only the
/// checked colour a Tab stop. A tool with a menu ([AnnotationTool.hasMenu])
/// asks for it with ArrowDown through [onToolMenuRequested].
class AnnotationTools extends StatefulWidget {
  /// The tool row for [tools], with [tool] active and [color] current.
  const new({
    required this.semanticLabel,
    required this.toolLabelOf,
    required this.colorsSemanticLabel,
    required this.colorLabelOf,
    super.key,
    this.tool = AnnotationTool.highlight,
    this.onToolChanged,
    this.color = AnnotationColor.yellow,
    this.onColorChanged,
    this.showLabels = false,
    this.variant = ToolbarVariant.bar,
    this.tools = AnnotationTool.values,
    this.disabledReasons = const {},
    this.colorsDisabledReason,
    this.onToolMenuRequested,
  });

  /// The active tool.
  final AnnotationTool tool;

  /// Called with the tool the user selects; null makes the tools inert.
  final ValueChanged<AnnotationTool>? onToolChanged;

  /// The current annotation colour.
  final AnnotationColor color;

  /// Called with the colour the user checks; null makes the colours inert.
  final ValueChanged<AnnotationColor>? onColorChanged;

  /// Whether the tool buttons show their labels (FmWindow shows them).
  final bool showLabels;

  /// How the row is drawn.
  final ToolbarVariant variant;

  /// The tools shown, in order; all eleven by default.
  final List<AnnotationTool> tools;

  /// The reason each disabled tool gives (G10); a tool not in the map is
  /// enabled.
  final Map<AnnotationTool, String> disabledReasons;

  /// The reason the whole colour group is disabled (G10); null leaves it to
  /// the active tool.
  final String? colorsDisabledReason;

  /// The accessible name of the row, the localized "Comment tools". Not a
  /// design-system prop: the bundle hard-codes the English name.
  final String semanticLabel;

  /// The localized name of a tool: its label, tooltip and accessible name.
  /// Not a design-system prop.
  final String Function(AnnotationTool tool) toolLabelOf;

  /// The accessible name of the colour group, the localized "Color". Not a
  /// design-system prop.
  final String colorsSemanticLabel;

  /// The localized name of a colour, its accessible name. Not a
  /// design-system prop.
  final String Function(AnnotationColor color) colorLabelOf;

  /// Called with a tool that has a menu when ArrowDown asks for the menu;
  /// null falls back to selecting the tool. Not a design-system prop.
  final ValueChanged<AnnotationTool>? onToolMenuRequested;

  /// The colours of the colour group, in order (the bundle's `PALETTE`).
  static const List<AnnotationColor> palette = [
    AnnotationColor.yellow,
    AnnotationColor.green,
    AnnotationColor.blue,
    AnnotationColor.pink,
    AnnotationColor.red,
    AnnotationColor.ink,
  ];

  /// The opacity of the disabled colour group (the bundle's inline
  /// `opacity: 0.4`).
  static const double disabledColorsOpacity = 0.4;

  /// `.fm-annot-color` `width` and `height: 18px`.
  static const double swatchSize = 18;

  /// `.fm-annot-color` `box-shadow: inset 0 0 0 1px rgba(0,0,0,.16)`.
  static const Color swatchRingLight = Color(0x29000000);

  /// `[data-theme="dark"] .fm-annot-color`
  /// `box-shadow: inset 0 0 0 1px rgba(255,255,255,.28)`.
  static const Color swatchRingDark = Color(0x47FFFFFF);

  /// The inner outside ring of a hovered or checked colour:
  /// `0 0 0 2px var(--border-strong)` on hover,
  /// `0 0 0 2px var(--surface-panel)` when checked.
  static const double swatchHaloInner = 2;

  /// The outer ring of a checked colour: `0 0 0 4px var(--text-primary)`.
  static const double swatchHaloOuter = 4;

  @override
  State<AnnotationTools> createState() => _AnnotationToolsState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<AnnotationTool>('tool', tool))
      ..add(EnumProperty<AnnotationColor>('color', color))
      ..add(FlagProperty('showLabels', value: showLabels, ifTrue: 'labels'))
      ..add(
        EnumProperty<ToolbarVariant>(
          'variant',
          variant,
          defaultValue: ToolbarVariant.bar,
        ),
      )
      ..add(IterableProperty<AnnotationTool>('tools', tools))
      ..add(
        IterableProperty<AnnotationTool>(
          'disabled tools',
          disabledReasons.keys,
          ifEmpty: 'none',
        ),
      )
      ..add(
        StringProperty(
          'colorsDisabledReason',
          colorsDisabledReason,
          defaultValue: null,
        ),
      );
  }
}

class _AnnotationToolsState extends State<AnnotationTools> {
  bool _toolEnabled(AnnotationTool tool) =>
      widget.onToolChanged != null && !widget.disabledReasons.containsKey(tool);

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    for (final tool in widget.tools) {
      if (tool.shortcutKey != event.logicalKey) continue;
      if (!_toolEnabled(tool)) return KeyEventResult.ignored;
      widget.onToolChanged?.call(tool);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final onToolChanged = widget.onToolChanged;
    final onMenu = widget.onToolMenuRequested;
    final active = widget.tool;
    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Toolbar(
        variant: widget.variant,
        semanticLabel: widget.semanticLabel,
        children: [
          for (final tool in widget.tools)
            ToolButton(
              icon: tool.icon,
              label: widget.toolLabelOf(tool),
              showLabel: widget.showLabels,
              active: tool == active,
              hasMenu: tool.hasMenu,
              swatch: tool.colored && tool == active
                  ? widget.color.resolve(theme)
                  : null,
              shortcut: switch (tool.shortcut) {
                final key? => [key],
                null => null,
              },
              disabled: widget.disabledReasons.containsKey(tool),
              disabledReason: widget.disabledReasons[tool],
              onPressed: onToolChanged == null
                  ? null
                  : () => onToolChanged(tool),
              onMenuRequested: tool.hasMenu && onMenu != null
                  ? () => onMenu(tool)
                  : null,
            ),
          const ToolbarSeparator(),
          _ColorGroup(
            value: widget.color,
            onChanged: widget.onColorChanged,
            semanticLabel: widget.colorsSemanticLabel,
            labelOf: widget.colorLabelOf,
            disabled:
                widget.colorsDisabledReason != null ||
                !(widget.tools.contains(active) && active.colored),
            disabledReason: widget.colorsDisabledReason,
          ),
        ],
      ),
    );
  }
}

/// The colour radio group: `.fm-annot-colors`.
class _ColorGroup extends StatefulWidget {
  const new({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    required this.labelOf,
    required this.disabled,
    required this.disabledReason,
  });

  final AnnotationColor value;
  final ValueChanged<AnnotationColor>? onChanged;
  final String semanticLabel;
  final String Function(AnnotationColor color) labelOf;
  final bool disabled;
  final String? disabledReason;

  @override
  State<_ColorGroup> createState() => _ColorGroupState();
}

class _ColorGroupState extends State<_ColorGroup> {
  late final List<FocusNode> _nodes = [
    for (final color in AnnotationTools.palette)
      FocusNode(debugLabel: 'AnnotationTools ${color.name}'),
  ];

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _enabled => !widget.disabled && widget.onChanged != null;

  bool get _focusable =>
      _enabled || (widget.disabled && widget.disabledReason != null);

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final step = RovingFocus.stepFor(event, Directionality.of(context));
    if (step == null || !_focusable) return KeyEventResult.ignored;
    final from = _nodes.indexWhere((node) => node.hasFocus);
    if (from < 0) return KeyEventResult.ignored;
    const palette = AnnotationTools.palette;
    final to = RovingFocus.target(from, palette.length, step, (_) => true);
    if (to == null) return KeyEventResult.handled;
    _nodes[to].requestFocus();
    if (_enabled) widget.onChanged?.call(palette[to]);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    const palette = AnnotationTools.palette;
    final checked = palette.indexOf(widget.value);
    final stop = checked < 0 ? 0 : checked;
    final onChanged = widget.onChanged;
    Widget group = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: theme.space.space1,
      children: [
        for (var i = 0; i < palette.length; i++)
          _Swatch(
            color: palette[i],
            label: widget.labelOf(palette[i]),
            checked: i == checked,
            disabled: widget.disabled,
            disabledReason: widget.disabledReason,
            focusNode: _nodes[i]..skipTraversal = i != stop,
            onPressed: onChanged == null ? null : () => onChanged(palette[i]),
          ),
      ],
    );
    group = Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.radioGroup,
      label: widget.semanticLabel,
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.space.space1,
        ),
        child: group,
      ),
    );
    if (widget.disabled) {
      group = Opacity(
        opacity: AnnotationTools.disabledColorsOpacity,
        child: group,
      );
    }
    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: group,
    );
  }
}

/// One colour: `.fm-annot-color`.
class _Swatch extends StatelessWidget {
  const new({
    required this.color,
    required this.label,
    required this.checked,
    required this.disabled,
    required this.disabledReason,
    required this.focusNode,
    required this.onPressed,
  });

  final AnnotationColor color;
  final String label;
  final bool checked;
  final bool disabled;
  final String? disabledReason;
  final FocusNode focusNode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FermanInteractive(
    focusNode: focusNode,
    onPressed: onPressed,
    disabled: disabled,
    disabledReason: disabledReason,
    isButton: false,
    semanticLabel: label,
    builder: (context, states, _) => Semantics(
      inMutuallyExclusiveGroup: true,
      checked: checked,
      child: ExcludeSemantics(child: _visual(context, states)),
    ),
  );

  Widget _visual(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final focused = states.contains(WidgetState.focused);
    final isChecked = checked || states.contains(WidgetState.selected);
    final hovered = states.contains(WidgetState.hovered);
    // The focus ring replaces the swatch's own rings, as
    // `.fm-annot-color:focus-visible` does. The CSS lets the checked rule
    // win over focus; focus wins here so it is always visible (G22).
    final List<BoxShadow> shadows;
    if (focused) {
      shadows = const [];
    } else if (isChecked) {
      shadows = [
        BoxShadow(
          color: colors.textPrimary,
          spreadRadius: AnnotationTools.swatchHaloOuter,
        ),
        BoxShadow(
          color: colors.surfacePanel,
          spreadRadius: AnnotationTools.swatchHaloInner,
        ),
      ];
    } else if (hovered) {
      shadows = [
        BoxShadow(
          color: colors.borderStrong,
          spreadRadius: AnnotationTools.swatchHaloInner,
        ),
      ];
    } else {
      shadows = const [];
    }
    final ring = theme.isDark
        ? AnnotationTools.swatchRingDark
        : AnnotationTools.swatchRingLight;
    final circle = BorderRadius.all(Radius.circular(theme.radius.radiusFull));
    return FocusRing(
      visible: focused,
      borderRadius: circle,
      child: SizedBox.square(
        dimension: AnnotationTools.swatchSize,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: focused
                ? null
                : Border.all(color: ring, width: theme.border.borderWidth),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.resolve(theme),
              shape: BoxShape.circle,
              boxShadow: shadows,
            ),
          ),
        ),
      ),
    );
  }
}
