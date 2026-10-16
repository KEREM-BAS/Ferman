import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/components/navigation/roving_focus.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// One segment of a [SegmentedControl]: the design-system `SegmentOption`.
///
/// A segment shows a [label], an [icon], or both. An icon-only segment
/// (an [icon] and no [label]) takes [tooltip] as its tooltip and accessible
/// name (the design's `title`).
@immutable
class SegmentOption<T> {
  /// A segment for [value].
  const new({
    required this.value,
    this.label,
    this.icon,
    this.tooltip,
    this.flipRtl,
    this.disabled = false,
    this.disabledReason,
  });

  /// The value the segment stands for.
  final T value;

  /// The visible text, localized; null for an icon-only segment.
  final String? label;

  /// The glyph shown before the label, or alone.
  final IconName? icon;

  /// The tooltip and accessible name of an icon-only segment (the design's
  /// `title`).
  final String? tooltip;

  /// Passed to the [Icon]: whether to mirror the glyph in right to left;
  /// null follows [IconName.directional].
  final bool? flipRtl;

  /// Whether this segment is disabled.
  final bool disabled;

  /// Why this segment is disabled (G10); it stays focusable and shows the
  /// reason as its tooltip and semantics hint.
  final String? disabledReason;

  /// Whether the segment shows only its icon.
  bool get iconOnly => icon != null && label == null;
}

/// A radio group of text, icon-and-text or icon-only segments in a sunken
/// track, the design-system `SegmentedControl` component
/// (`components/navigation/navigation.css`, `.fm-segmented`,
/// `.fm-segment`; `SegmentedControl.jsx`).
///
/// The control is controlled: [value] is the checked option and
/// [onChanged] is called with the option the user picks; a null
/// [onChanged] makes it inert. [fullWidth] stretches the track and shares
/// its width equally between the segments. Sidebar tabs are a
/// SegmentedControl over an `IndexedStack` (ADR 0011).
///
/// **Disabled.** [disabled] disables every segment, a segment's own
/// `disabled` only that one. With a reason ([disabledReason], or the
/// segment's own) a disabled segment keeps its look of disabled, shows the
/// reason as tooltip and semantics hint, stays focusable and cannot be
/// checked (G10); without one it is skipped by the keyboard.
///
/// **Keyboard** (`SegmentedControl.jsx`): ArrowLeft and ArrowRight move to
/// the previous and next segment in the visual direction (mirrored in right
/// to left), wrap, and check the segment they land on. Plain disabled
/// segments are skipped; disabled-with-reason segments take focus without
/// being checked. Only the checked segment is a Tab stop (roving Tab stop).
/// Focus shows the inset ring (`--focus-ring-inset`, G22).
///
/// **Semantics:** a radio group labelled [semanticLabel]; each segment is a
/// radio in a mutually exclusive group, checked or not, named by its label
/// or tooltip.
class SegmentedControl<T> extends StatefulWidget {
  /// A segmented control over [options], with [value] checked.
  const new({
    required this.options,
    required this.value,
    required this.semanticLabel,
    super.key,
    this.onChanged,
    this.fullWidth = false,
    this.disabled = false,
    this.disabledReason,
  });

  /// The segments, in order.
  final List<SegmentOption<T>> options;

  /// The checked value.
  final T value;

  /// Called with the value the user checks; null makes the control inert.
  final ValueChanged<T>? onChanged;

  /// The accessible name of the group (the design's `label`).
  final String semanticLabel;

  /// Whether the track fills the available width, with equal segments.
  final bool fullWidth;

  /// Whether the whole control is disabled.
  final bool disabled;

  /// Why the whole control is disabled (G10), for example the localized
  /// "Available in a future version" on a Settings control.
  final String? disabledReason;

  /// `.fm-segment` `height: calc(var(--control-h-sm) - 6px)`: the track's
  /// 2 px padding and 1 px border on each side.
  static const double trackInset = 6;

  /// `.fm-segment` `min-width: 24px`.
  static const double minSegmentWidth = 24;

  /// `.fm-segment--icon` `padding: 0 5px`.
  static const double iconOnlyPadding = 5;

  /// `.fm-segment` `border-radius: 3px`.
  static const double segmentRadius = 3;

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<T>('value', value))
      ..add(IntProperty('options', options.length))
      ..add(StringProperty('semanticLabel', semanticLabel))
      ..add(FlagProperty('fullWidth', value: fullWidth, ifTrue: 'fullWidth'))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      );
  }
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>> {
  final List<FocusNode> _nodes = [];

  void _syncNodes() {
    final count = widget.options.length;
    while (_nodes.length < count) {
      _nodes.add(FocusNode(debugLabel: 'SegmentedControl ${_nodes.length}'));
    }
    while (_nodes.length > count) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool _isDisabled(int index) =>
      widget.disabled ||
      widget.options[index].disabled ||
      widget.onChanged == null;

  /// The reason a disabled segment gives: its own when it is disabled
  /// itself, else the whole control's. An inert control (no onChanged)
  /// gives none.
  String? _reason(int index) {
    final option = widget.options[index];
    if (option.disabled) return option.disabledReason ?? widget.disabledReason;
    return widget.disabled ? widget.disabledReason : null;
  }

  bool _isFocusable(int index) => !_isDisabled(index) || _reason(index) != null;

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    final step = RovingFocus.stepFor(event, Directionality.of(context));
    if (step == null) return KeyEventResult.ignored;
    final from = _nodes.indexWhere((node) => node.hasFocus);
    if (from < 0) return KeyEventResult.ignored;
    final to = RovingFocus.target(
      from,
      widget.options.length,
      step,
      _isFocusable,
    );
    if (to == null || to == from) return KeyEventResult.handled;
    _nodes[to].requestFocus();
    if (!_isDisabled(to)) widget.onChanged?.call(widget.options[to].value);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _syncNodes();
    final theme = context.ferman;
    final options = widget.options;
    final checked = options.indexWhere(
      (option) => option.value == widget.value,
    );
    // The roving Tab stop: the checked segment, or the first focusable one
    // when the checked one cannot take focus.
    var stop = checked >= 0 && _isFocusable(checked) ? checked : -1;
    if (stop < 0) {
      stop =
          RovingFocus.target(
            -1,
            options.length,
            RovingStep.first,
            _isFocusable,
          ) ??
          -1;
    }
    final onChanged = widget.onChanged;
    final segments = <Widget>[
      for (var i = 0; i < options.length; i++)
        _Segment<T>(
          option: options[i],
          checked: i == checked,
          disabled: _isDisabled(i),
          disabledReason: _reason(i),
          expand: widget.fullWidth,
          focusNode: _nodes[i]..skipTraversal = i != stop,
          onPressed: onChanged == null
              ? null
              : () => onChanged(options[i].value),
        ),
    ];
    Widget row = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      spacing: theme.space.space0_5,
      children: [
        for (final segment in segments)
          if (widget.fullWidth) Expanded(child: segment) else segment,
      ],
    );
    row = Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.radioGroup,
      label: widget.semanticLabel,
      child: row,
    );
    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.surfaceSunken,
          border: Border.all(
            color: theme.colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusSm),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(
            theme.space.space0_5 + theme.border.borderWidth,
          ),
          child: row,
        ),
      ),
    );
  }
}

/// One segment: `.fm-segment`.
class _Segment<T> extends StatelessWidget {
  const new({
    required this.option,
    required this.checked,
    required this.disabled,
    required this.disabledReason,
    required this.expand,
    required this.focusNode,
    required this.onPressed,
  });

  final SegmentOption<T> option;
  final bool checked;
  final bool disabled;
  final String? disabledReason;
  final bool expand;
  final FocusNode focusNode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FermanInteractive(
    focusNode: focusNode,
    onPressed: onPressed,
    disabled: disabled,
    disabledReason: disabledReason,
    isButton: false,
    tooltip: option.iconOnly ? option.tooltip : null,
    semanticLabel: option.label ?? option.tooltip,
    builder: (context, states, _) => Semantics(
      inMutuallyExclusiveGroup: true,
      checked: checked,
      child: ExcludeSemantics(child: _visual(context, states)),
    ),
  );

  Widget _visual(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final isDisabled = states.contains(WidgetState.disabled);
    final isChecked = checked || states.contains(WidgetState.selected);
    final hovered = states.contains(WidgetState.hovered);
    var background = const Color(0x00000000);
    var shadows = const <BoxShadow>[];
    var foreground = colors.textSecondary;
    if (isChecked) {
      // `.fm-segment[aria-checked="true"]`; dark: `--soot-200`, no shadow.
      foreground = colors.textPrimary;
      if (theme.isDark) {
        background = theme.ramps.soot200;
      } else {
        background = colors.surfaceRaised;
        shadows = [
          BoxShadow(
            color: colors.borderSubtle,
            spreadRadius: theme.border.borderWidth,
          ),
          ...theme.elevation.shadowSm,
        ];
      }
    } else if (hovered) {
      foreground = colors.textPrimary;
      background = colors.surfaceHover;
    }
    if (isDisabled) {
      // `.fm-segment:disabled` comes after the checked rule: disabled text
      // and a transparent background. The checked shadow stays, and the
      // dark checked rule is more specific, so its fill stays too.
      foreground = colors.textDisabled;
      if (!(isChecked && theme.isDark)) {
        background = const Color(0x00000000);
      }
    }
    const radius = BorderRadius.all(
      Radius.circular(SegmentedControl.segmentRadius),
    );
    final icon = option.icon;
    final label = option.label;
    final style = DefaultTextStyle.of(context).style
        .merge(theme.typography.body)
        .copyWith(
          fontSize: theme.typeScale.sizeSm,
          fontWeight: theme.typeScale.weightMedium,
          height: 1,
          color: foreground,
        );
    return FocusRing(
      visible: states.contains(WidgetState.focused),
      style: FocusRingStyle.inset,
      borderRadius: radius,
      child: AnimatedContainer(
        duration: theme.motion.durInstant,
        curve: theme.motion.easeOut,
        height: theme.density.controlHSm - SegmentedControl.trackInset,
        constraints: const BoxConstraints(
          minWidth: SegmentedControl.minSegmentWidth,
        ),
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: option.iconOnly
              ? SegmentedControl.iconOnlyPadding
              : theme.space.space2,
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
          style: style,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: theme.space.space1,
            children: [
              if (icon != null)
                Icon(icon, size: theme.density.iconSm, flipRtl: option.flipRtl),
              if (label != null && expand)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else if (label != null)
                Text(label, maxLines: 1, softWrap: false),
            ],
          ),
        ),
      ),
    );
  }
}
