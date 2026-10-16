import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/design/components/navigation/roving_focus.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// How [ModeTabs] draws its strip (`.fm-modetabs`, `.fm-modetabs--underline`).
enum ModeTabsVariant {
  /// Tabs in a sunken track; the selected tab is a raised segment. The
  /// desktop mode bar.
  segmented,

  /// Bare tabs with an accent bar under the selected one, for the web build
  /// (design-system readme).
  underline,
}

/// The tab strip of the editor's modes, the design-system `ModeTabs`
/// component (`components/navigation/navigation.css`, `.fm-modetabs`,
/// `.fm-modetab`; `ModeTabs.jsx`).
///
/// It is a custom segmented control, never a `TabBar`: the shell shows the
/// mode's content in an `IndexedStack`, so each mode keeps its state when
/// the user switches away (ADR 0011).
///
/// The control is controlled: [value] is the current mode and [onChanged]
/// is called with the mode the user picks; a null [onChanged] makes the
/// tabs inert. [labelOf] gives each mode's localized name; [FermanMode]
/// itself carries only the id and icon.
///
/// **Keyboard** (`ModeTabs.jsx`): ArrowLeft and ArrowRight move to the
/// previous and next tab in the visual direction (mirrored in right to
/// left) and wrap; Home and End move to the first and last tab. Selection
/// follows focus, and only the selected tab is a Tab stop (a roving Tab
/// stop). Focus shows the inset ring (`--focus-ring-inset`, G22).
///
/// **Semantics:** a tab bar labelled [semanticLabel] whose tabs are named by
/// their mode labels and say whether they are selected.
///
/// When the modes do not fit, the strip scrolls without a scroll bar, as the
/// CSS `overflow-x: auto; scrollbar-width: none` does. As in CSS, the
/// track's 2 px padding scrolls with the tabs and the clip is the inside of
/// the track's border, so the selected tab keeps its ring and shadow. A
/// tab the arrow keys move to is brought into view at once, as the
/// bundle's `focus()` does.
class ModeTabs extends StatefulWidget {
  /// The mode tabs for [modes], with [value] selected.
  const new({
    required this.value,
    required this.labelOf,
    required this.semanticLabel,
    super.key,
    this.modes = FermanMode.values,
    this.onChanged,
    this.variant = ModeTabsVariant.segmented,
    this.showIcons = false,
  });

  /// The modes shown, in order; all eight by default.
  final List<FermanMode> modes;

  /// The selected mode.
  final FermanMode value;

  /// Called with the mode the user selects; null makes the tabs inert.
  final ValueChanged<FermanMode>? onChanged;

  /// How the strip is drawn.
  final ModeTabsVariant variant;

  /// Whether each tab shows its mode's icon before the label.
  final bool showIcons;

  /// The accessible name of the strip (the design's `label`, "Mode").
  final String semanticLabel;

  /// The localized name of a mode, shown on its tab. Not a design-system
  /// prop: the design's mode objects carry an English label.
  final String Function(FermanMode mode) labelOf;

  /// `.fm-modetabs--underline .fm-modetab[aria-selected="true"]::after`
  /// `height: 2px`: the accent bar under the selected tab of the underline
  /// variant.
  static const double underlineThickness = 2;

  @override
  State<ModeTabs> createState() => _ModeTabsState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<FermanMode>('value', value))
      ..add(IterableProperty<FermanMode>('modes', modes))
      ..add(
        EnumProperty<ModeTabsVariant>(
          'variant',
          variant,
          defaultValue: ModeTabsVariant.segmented,
        ),
      )
      ..add(FlagProperty('showIcons', value: showIcons, ifTrue: 'showIcons'))
      ..add(StringProperty('semanticLabel', semanticLabel))
      ..add(
        FlagProperty('enabled', value: onChanged != null, ifFalse: 'disabled'),
      );
  }
}

class _ModeTabsState extends State<ModeTabs> {
  final Map<FermanMode, FocusNode> _nodes = {};

  FocusNode _nodeFor(FermanMode mode) => _nodes.putIfAbsent(
    mode,
    () => FocusNode(debugLabel: 'ModeTabs ${mode.id}'),
  );

  @override
  void didUpdateWidget(ModeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final gone = _nodes.keys.where((mode) => !widget.modes.contains(mode));
    for (final mode in gone.toList()) {
      _nodes.remove(mode)?.dispose();
    }
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final step = RovingFocus.stepFor(
      event,
      Directionality.of(context),
      homeAndEnd: true,
    );
    final onChanged = widget.onChanged;
    if (step == null || onChanged == null) return KeyEventResult.ignored;
    final modes = widget.modes;
    final from = modes.indexWhere((mode) => _nodes[mode]?.hasFocus ?? false);
    if (from < 0) return KeyEventResult.ignored;
    final to = RovingFocus.target(from, modes.length, step, (_) => true);
    if (to == null) return KeyEventResult.handled;
    final next = modes[to];
    if (next != widget.value) onChanged(next);
    final node = _nodeFor(next)..requestFocus();
    final target = node.context;
    if (target != null) {
      // No animation: `btn.focus()` in ModeTabs.jsx scrolls at once.
      Scrollable.ensureVisible(
        target,
        alignmentPolicy: RovingFocus.alignmentFor(from, to),
      );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final segmented = widget.variant == ModeTabsVariant.segmented;
    final modes = widget.modes;
    // The roving Tab stop: the selected tab, or the first when the value is
    // not among the modes.
    final stop = modes.contains(widget.value)
        ? widget.value
        : (modes.isEmpty ? null : modes.first);
    final onChanged = widget.onChanged;
    final tabs = [
      for (final mode in modes)
        _ModeTab(
          label: widget.labelOf(mode),
          icon: widget.showIcons ? mode.icon : null,
          selected: mode == widget.value,
          segmented: segmented,
          focusNode: _nodeFor(mode)..skipTraversal = mode != stop,
          onPressed: onChanged == null ? null : () => onChanged(mode),
        ),
    ];
    Widget strip = Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.tabBar,
      label: widget.semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: segmented ? theme.space.space0_5 : theme.space.space1,
        children: tabs,
      ),
    );
    strip = Focus(
      canRequestFocus: false,
      includeSemantics: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: strip,
    );
    strip = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // `.fm-modetabs` `padding: 2px` inside the scrolling box: the clip
        // edge is the inside of the border, 2 px clear of the tabs.
        padding: segmented
            ? EdgeInsetsDirectional.all(theme.space.space0_5)
            : null,
        child: strip,
      ),
    );
    if (!segmented) return strip;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceSunken,
        border: Border.all(
          color: theme.colors.borderSubtle,
          width: theme.border.borderWidth,
        ),
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(theme.border.borderWidth),
        child: strip,
      ),
    );
  }
}

/// One tab: `.fm-modetab`.
class _ModeTab extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.selected,
    required this.segmented,
    required this.focusNode,
    required this.onPressed,
  });

  final String label;
  final IconName? icon;
  final bool selected;
  final bool segmented;
  final FocusNode focusNode;
  final VoidCallback? onPressed;

  // FermanInteractive states selected true or false for a tab.
  @override
  Widget build(BuildContext context) => FermanInteractive(
    focusNode: focusNode,
    onPressed: onPressed,
    selected: selected,
    semanticsRole: SemanticsRole.tab,
    isButton: false,
    semanticLabel: label,
    builder: (context, states, _) =>
        ExcludeSemantics(child: _visual(context, states)),
  );

  Widget _visual(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final hovered = states.contains(WidgetState.hovered);
    final focused = states.contains(WidgetState.focused);
    final active = selected || states.contains(WidgetState.selected);
    var background = const Color(0x00000000);
    var shadows = const <BoxShadow>[];
    final Color foreground;
    final Color iconColor;
    if (active) {
      foreground = colors.textPrimary;
      iconColor = colors.textAccent;
      if (segmented) {
        // `.fm-modetab[aria-selected="true"]`; dark: `--soot-200`, no shadow.
        background = theme.isDark ? theme.ramps.soot200 : colors.surfaceRaised;
        shadows = theme.isDark
            ? const []
            : [
                BoxShadow(
                  color: colors.borderSubtle,
                  spreadRadius: theme.border.borderWidth,
                ),
                ...theme.elevation.shadowSm,
              ];
      }
    } else if (hovered) {
      foreground = colors.textPrimary;
      iconColor = colors.iconSecondary;
      if (segmented) background = colors.surfaceHover;
    } else {
      foreground = colors.textSecondary;
      iconColor = colors.iconSecondary;
    }
    final radius = segmented
        ? BorderRadius.all(Radius.circular(theme.radius.radiusSm))
        : BorderRadius.zero;
    final glyph = icon;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: theme.space.space1_5,
      children: [
        if (glyph != null)
          Icon(glyph, size: theme.density.iconMd, color: iconColor),
        Text(label, maxLines: 1, softWrap: false),
      ],
    );
    Widget tab = AnimatedContainer(
      duration: theme.motion.durInstant,
      curve: theme.motion.easeOut,
      height: segmented ? theme.density.controlHSm : theme.density.modebarH,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: segmented ? theme.space.space3 : theme.space.space2_5,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        boxShadow: shadows,
      ),
      child: AnimatedDefaultTextStyle(
        duration: theme.motion.durInstant,
        curve: theme.motion.easeOut,
        style: DefaultTextStyle.of(context).style
            .merge(theme.typography.bodyStrong)
            .copyWith(color: foreground),
        child: content,
      ),
    );
    if (!segmented && active) {
      tab = Stack(
        children: [
          tab,
          PositionedDirectional(
            start: theme.space.space2_5,
            end: theme.space.space2_5,
            bottom: 0,
            height: ModeTabs.underlineThickness,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(theme.radius.radiusXs),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return FocusRing(
      visible: focused,
      style: FocusRingStyle.inset,
      borderRadius: radius,
      child: tab,
    );
  }
}
