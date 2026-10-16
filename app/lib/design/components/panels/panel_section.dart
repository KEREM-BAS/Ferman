import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// A collapsible section of the right panel, the design-system
/// `PanelSection` component (`components/panels/panels.css`,
/// `.fm-panelsection`; `PanelSection.jsx`).
///
/// A 1 px subtle line above (off with [showTopBorder] for the first
/// section), a header at least 36 px tall with the [title] in panel-title
/// type and the header [actions] (usually extra-small `IconButton`s) at the
/// end, then the body [child], padded 12 px at the sides and 14 px below.
/// Several body parts sit [bodyGap] apart, as the design's grid sets them.
///
/// With [collapsible] (the default) the title is a toggle with a 14 px
/// chevron that turns −90° when collapsed (+90° in right to left) over
/// `--dur-fast`; a collapsed section removes its body. [open] controls the
/// state from outside; when it is null the section keeps its own state,
/// starting from [initiallyOpen]. Either way [onOpenChanged] reports the
/// new state. Without [collapsible] the title is a static heading.
///
/// Keyboard: Tab reaches the toggle; Enter and Space toggle it; focus shows
/// the inset ring.
///
/// For screen readers the section is a region named by [title]; the toggle
/// is a button with the expanded state, the static title a heading.
class PanelSection extends StatefulWidget {
  /// Creates a section titled [title] around [child].
  const new({
    required this.title,
    required this.child,
    super.key,
    this.collapsible = true,
    this.initiallyOpen = true,
    this.open,
    this.onOpenChanged,
    this.actions = const [],
    this.showTopBorder = true,
  });

  /// `.fm-panelsection__head` `min-height: 36px`.
  static const double headMinHeight = 36;

  /// `.fm-panelsection__toggle` `height: 28px`.
  static const double toggleHeight = 28;

  /// `PanelSection.jsx` chevron size.
  static const double chevronSize = 14;

  /// `.fm-panelsection__body` `gap: 10px`, between body parts.
  static const double bodyGap = 10;

  /// `.fm-panelsection__body` `padding: 0 12px 14px`: the bottom padding.
  static const double bodyPaddingBottom = 14;

  /// The heading text and the region's name.
  final String title;

  /// Whether the title toggles the body.
  final bool collapsible;

  /// Whether the section starts open when [open] is null.
  final bool initiallyOpen;

  /// Whether the section is open; null lets the section keep its own
  /// state.
  final bool? open;

  /// Called with the new open state when the toggle is activated.
  final ValueChanged<bool>? onOpenChanged;

  /// The header buttons at the end.
  final List<Widget> actions;

  /// The body.
  final Widget child;

  /// Whether the 1 px line above shows. The design drops it on the first
  /// section (`:first-child`), which a widget cannot see, so the panel
  /// passes false there. Not a design-system prop.
  final bool showTopBorder;

  @override
  State<PanelSection> createState() => _PanelSectionState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('title', title))
      ..add(
        FlagProperty(
          'collapsible',
          value: collapsible,
          ifFalse: 'not collapsible',
        ),
      )
      ..add(
        FlagProperty(
          'initiallyOpen',
          value: initiallyOpen,
          ifFalse: 'initially closed',
        ),
      )
      ..add(
        FlagProperty('open', value: open, ifTrue: 'open', ifFalse: 'closed'),
      )
      ..add(
        ObjectFlagProperty<ValueChanged<bool>>.has(
          'onOpenChanged',
          onOpenChanged,
        ),
      )
      ..add(
        FlagProperty(
          'showTopBorder',
          value: showTopBorder,
          ifFalse: 'no top border',
        ),
      );
  }
}

class _PanelSectionState extends State<PanelSection> {
  late bool _open = widget.initiallyOpen;

  bool get _isOpen => widget.open ?? _open;

  void _toggle() {
    final next = !_isOpen;
    if (widget.open == null) setState(() => _open = next);
    widget.onOpenChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final isOpen = !widget.collapsible || _isOpen;
    final titleStyle = theme.typography.panelTitle.copyWith(
      color: colors.textPrimary,
    );
    // `.fm-panelsection__toggle` `margin-inline-start: -4px;
    // padding-inline-start: 4px`: the toggle starts 4 px before the
    // chevron, so its hover and focus area does too.
    final toggleInset = theme.space.space1;
    final heading = widget.collapsible
        ? _toggleButton(context, isOpen, titleStyle, toggleInset)
        : Semantics(header: true, child: Text(widget.title, style: titleStyle));
    final head = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PanelSection.headMinHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          theme.space.space3 - (widget.collapsible ? toggleInset : 0),
          0,
          theme.space.space2,
          0,
        ),
        child: Row(
          spacing: theme.space.space1,
          children: [
            Expanded(child: heading),
            if (widget.actions.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space0_5,
                children: widget.actions,
              ),
          ],
        ),
      ),
    );
    final section = DecoratedBox(
      decoration: BoxDecoration(
        border: widget.showTopBorder
            ? Border(
                top: BorderSide(
                  color: colors.borderSubtle,
                  width: theme.border.borderWidth,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: widget.showTopBorder ? theme.border.borderWidth : 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            if (isOpen)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  theme.space.space3,
                  0,
                  theme.space.space3,
                  PanelSection.bodyPaddingBottom,
                ),
                child: widget.child,
              ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.region,
      label: widget.title,
      child: section,
    );
  }

  Widget _toggleButton(
    BuildContext context,
    bool isOpen,
    TextStyle titleStyle,
    double inset,
  ) {
    final theme = context.ferman;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
    return FermanInteractive(
      onPressed: _toggle,
      builder: (context, states, _) => Semantics(
        expanded: isOpen,
        child: FocusRing(
          visible: states.contains(WidgetState.focused),
          style: FocusRingStyle.inset,
          borderRadius: radius,
          child: Container(
            height: PanelSection.toggleHeight,
            padding: EdgeInsetsDirectional.only(start: inset),
            child: Row(
              spacing: theme.space.space1_5,
              children: [
                AnimatedRotation(
                  turns: isOpen ? 0 : (rtl ? 0.25 : -0.25),
                  duration: theme.motion.durFast,
                  curve: theme.motion.easeOut,
                  child: Icon(
                    IconName.chevronDown,
                    size: PanelSection.chevronSize,
                    color: theme.colors.iconSecondary,
                  ),
                ),
                Flexible(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
