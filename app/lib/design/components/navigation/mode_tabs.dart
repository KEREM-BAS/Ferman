import 'dart:math' as math;

import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/design/components/navigation/label_collapse.dart';
import 'package:ferman/design/components/navigation/roving_focus.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
/// **Narrow windows** (G21). When the labelled tabs do not fit the width
/// the strip is given, every tab falls back to its mode's icon, with the
/// label as its tooltip (and still as its accessible name); they come back
/// as soon as they fit. All tabs change together, so the strip keeps one
/// rhythm. The choice follows the measured width, never the platform, and
/// the tabs keep their state and focus. When even the icons do not fit,
/// the strip scrolls without a scroll bar, as the CSS
/// `overflow-x: auto; scrollbar-width: none` does. As in CSS, the track's
/// 2 px padding scrolls with the tabs and the clip is the inside of the
/// track's border, so the selected tab keeps its ring and shadow. A tab
/// the arrow keys move to is brought into view at once, as the bundle's
/// `focus()` does.
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

  /// Whether the tabs show only their icons (G21), as the strip last laid
  /// them out. The strip applies a change at once and reports it; the
  /// tooltips follow after the frame.
  bool _iconsOnly = false;
  bool? _pendingIconsOnly;

  /// How the viewport reaches the strip inside the scroll view.
  final _ModeStripLink _link = _ModeStripLink();

  void _onIconsOnly(bool value) {
    if (_pendingIconsOnly == null && value == _iconsOnly) return;
    final scheduled = _pendingIconsOnly != null;
    _pendingIconsOnly = value;
    if (scheduled) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final next = _pendingIconsOnly;
      _pendingIconsOnly = null;
      if (!mounted || next == null || next == _iconsOnly) return;
      setState(() => _iconsOnly = next);
    });
  }

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
          icon: mode.icon,
          showIcon: widget.showIcons,
          iconsOnly: _iconsOnly,
          selected: mode == widget.value,
          segmented: segmented,
          focusNode: _nodeFor(mode)..skipTraversal = mode != stop,
          onPressed: onChanged == null ? null : () => onChanged(mode),
        ),
    ];
    // `.fm-modetabs` `padding: 2px` inside the scrolling box: the clip edge
    // is the inside of the border, 2 px clear of the tabs.
    final inset = segmented ? theme.space.space0_5 : 0.0;
    final spacing = segmented ? theme.space.space0_5 : theme.space.space1;
    Widget strip = Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.tabBar,
      label: widget.semanticLabel,
      child: _ModeStrip(
        spacing: spacing,
        link: _link,
        textDirection: Directionality.of(context),
        onIconsOnly: _onIconsOnly,
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
    // The viewport tells the strip how wide it may be, as a LayoutBuilder
    // would, but answers intrinsic and dry-layout queries.
    return _track(
      context,
      _ModeStripViewport(
        inset: inset,
        link: _link,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: segmented
                ? EdgeInsetsDirectional.all(theme.space.space0_5)
                : null,
            child: strip,
          ),
        ),
      ),
    );
  }

  /// [strip] in the segmented variant's sunken track.
  Widget _track(BuildContext context, Widget strip) {
    final theme = context.ferman;
    final segmented = widget.variant == ModeTabsVariant.segmented;
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
    required this.showIcon,
    required this.iconsOnly,
    required this.selected,
    required this.segmented,
    required this.focusNode,
    required this.onPressed,
  });

  final String label;

  /// The mode's icon: before the label when [showIcon], alone when
  /// [iconsOnly].
  final IconName icon;
  final bool showIcon;
  final bool iconsOnly;
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
    builder: (context, states, _) => Tooltip(
      // An icon-only tab gives its label as the tooltip (G21), on hover
      // and on keyboard focus. The tooltip is always there, closed while
      // the label shows, so the tab keeps its subtree, state and focus when
      // the strip collapses. It sits inside the tab's semantics node: an
      // overlay anchor between a tab bar and its tabs would break the tab
      // bar. The label is the tab's accessible name either way.
      message: label,
      open: iconsOnly ? null : false,
      // The tab's own keyboard focus, which the tooltip's listener below
      // the tab's focus node does not see: after the delay, closed by
      // Escape.
      focused: states.contains(WidgetState.focused),
      excludeFromSemantics: true,
      child: ExcludeSemantics(child: _visual(context, states)),
    ),
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
    // The label is passed as text while the tabs show only icons, so the
    // strip still knows how wide the labelled tabs would be.
    final content = CollapsibleLabel(
      compact: iconsOnly,
      leadingInFull: showIcon,
      gap: theme.space.space1_5,
      // Always there, so the icon-only width is known (the strip's minimum
      // intrinsic width); drawn only when it shows.
      leading: Icon(icon, size: theme.density.iconMd, color: iconColor),
      label: iconsOnly ? null : Text(label, maxLines: 1, softWrap: false),
      hiddenLabel: iconsOnly ? label : null,
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

/// Connects the viewport around the scroll view to the strip inside it.
class _ModeStripLink {
  _RenderModeStrip? strip;
}

/// Lays out the scroll view with the strip and tells the strip, first, the
/// width it has (less the track's [inset] on each side): the strip decides
/// in the same layout whether the labels fit. Unlike a `LayoutBuilder` it
/// passes intrinsic queries through and answers dry layout, so ModeTabs
/// can be measured.
class _ModeStripViewport extends SingleChildRenderObjectWidget {
  const new({required this.inset, required this.link, super.child});

  final double inset;
  final _ModeStripLink link;

  @override
  _RenderModeStripViewport createRenderObject(BuildContext context) =>
      _RenderModeStripViewport(inset: inset, link: link);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderModeStripViewport renderObject,
  ) {
    renderObject
      ..inset = inset
      ..link = link;
  }
}

class _RenderModeStripViewport extends RenderProxyBox {
  new({required this._inset, required this.link});

  double get inset => _inset;
  double _inset;
  set inset(double value) {
    if (value == _inset) return;
    _inset = value;
    markNeedsLayout();
  }

  _ModeStripLink link;

  /// Whether a strip given [constraints] shows only icons: the labelled
  /// width does not fit.
  bool _iconsOnlyFor(RenderBox child, BoxConstraints constraints) =>
      constraints.hasBoundedWidth &&
      child.getMaxIntrinsicWidth(constraints.maxHeight) >
          constraints.maxWidth + 0.01;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final height = constraints.maxHeight;
    final width = _iconsOnlyFor(child, constraints)
        ? child.getMinIntrinsicWidth(height)
        : child.getMaxIntrinsicWidth(height);
    return constraints.constrain(
      Size(width, child.getMaxIntrinsicHeight(width)),
    );
  }

  @override
  void performLayout() {
    final strip = link.strip;
    final available = constraints.maxWidth - 2 * inset;
    if (strip != null && strip.available != available) {
      // The strip sits in this subtree; like a LayoutBuilder's builder,
      // this may mark it for layout before the child is laid out.
      invokeLayoutCallback<BoxConstraints>((_) {
        strip.available = available;
      });
    }
    super.performLayout();
  }
}

/// The tabs in a row, 2 px apart (4 px underlined), all icon-only when the
/// labelled tabs are wider than the width the viewport gave it (G21).
class _ModeStrip extends MultiChildRenderObjectWidget {
  const new({
    required this.spacing,
    required this.link,
    required this.textDirection,
    required this.onIconsOnly,
    super.children,
  });

  final double spacing;
  final _ModeStripLink link;
  final TextDirection textDirection;
  final ValueChanged<bool> onIconsOnly;

  @override
  _RenderModeStrip createRenderObject(BuildContext context) => _RenderModeStrip(
    spacing: spacing,
    link: link,
    textDirection: textDirection,
    onIconsOnly: onIconsOnly,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderModeStrip renderObject) {
    renderObject
      ..spacing = spacing
      ..link = link
      ..textDirection = textDirection
      ..onIconsOnly = onIconsOnly;
  }
}

class _RenderModeStrip extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ModeStripParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ModeStripParentData> {
  new({
    required this._spacing,
    required this._link,
    required this._textDirection,
    required this.onIconsOnly,
  });

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  _ModeStripLink get link => _link;
  _ModeStripLink _link;
  set link(_ModeStripLink value) {
    if (identical(value, _link)) return;
    if (identical(_link.strip, this)) _link.strip = null;
    _link = value;
    if (attached) _link.strip = this;
  }

  /// The width the strip has, from the viewport; unbounded until then.
  double get available => _available;
  double _available = double.infinity;
  set available(double value) {
    if (value == _available) return;
    _available = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link.strip = this;
  }

  @override
  void detach() {
    if (identical(_link.strip, this)) _link.strip = null;
    super.detach();
  }

  ValueChanged<bool> onIconsOnly;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ModeStripParentData) {
      child.parentData = _ModeStripParentData();
    }
  }

  double _gaps(int count) => spacing * math.max(0, count - 1);

  @override
  double computeMinIntrinsicWidth(double height) {
    final children = getChildrenAsList();
    return children.fold(
      _gaps(children.length),
      (width, child) => width + child.getMinIntrinsicWidth(height),
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = getChildrenAsList();
    return children.fold(
      _gaps(children.length),
      (width, child) => width + child.getMaxIntrinsicWidth(height),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => getChildrenAsList().fold(
    0,
    (height, child) =>
        math.max(height, child.getMinIntrinsicHeight(double.infinity)),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => getChildrenAsList().fold(
    0,
    (height, child) =>
        math.max(height, child.getMaxIntrinsicHeight(double.infinity)),
  );

  /// Whether the labelled tabs are wider than [width].
  bool _iconsOnlyFor(double height, double width) =>
      computeMaxIntrinsicWidth(height) > width + 0.01;

  BoxConstraints _childConstraints(
    RenderBox child,
    double maxHeight, {
    required bool iconsOnly,
  }) => iconsOnly
      ? BoxConstraints(
          maxWidth: child.getMinIntrinsicWidth(maxHeight),
          maxHeight: maxHeight,
        )
      : BoxConstraints(maxHeight: maxHeight);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final children = getChildrenAsList();
    // Dry layout reads no layout state: the width it may take is the one
    // asked about.
    final iconsOnly = _iconsOnlyFor(
      constraints.maxHeight,
      constraints.maxWidth,
    );
    var width = _gaps(children.length);
    var height = 0.0;
    for (final child in children) {
      final size = child.getDryLayout(
        _childConstraints(child, constraints.maxHeight, iconsOnly: iconsOnly),
      );
      width += size.width;
      height = math.max(height, size.height);
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() {
    final children = getChildrenAsList();
    final maxHeight = constraints.maxHeight;
    final iconsOnly = _iconsOnlyFor(maxHeight, available);
    var width = _gaps(children.length);
    var height = 0.0;
    for (final child in children) {
      child.layout(
        _childConstraints(child, maxHeight, iconsOnly: iconsOnly),
        parentUsesSize: true,
      );
      width += child.size.width;
      height = math.max(height, child.size.height);
    }
    size = constraints.constrain(Size(width, height));
    final rtl = textDirection == TextDirection.rtl;
    var x = 0.0;
    for (final child in children) {
      final dy = (size.height - child.size.height) / 2;
      final dx = rtl ? size.width - x - child.size.width : x;
      (child.parentData! as _ModeStripParentData).offset = Offset(dx, dy);
      x += child.size.width + spacing;
    }
    onIconsOnly(iconsOnly);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _ModeStripParentData extends ContainerBoxParentData<RenderBox>;
