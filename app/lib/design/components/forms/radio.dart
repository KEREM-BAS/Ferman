import 'package:ferman/design/components/forms/check_row.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A round option in a group, with a label and a description, the
/// design-system `Radio` component (`components/forms/Radio.jsx`,
/// `.fm-check.fm-radio`). Material has a `Radio` too: files that import
/// Material hide it.
///
/// The 16 px circle has a 1 px strong border on the raised surface; checked,
/// it fills with the accent around a 6 px raised centre (the CSS draws a
/// 1 px accent border and a 4 px inset accent ring). The pointer turns an
/// unchecked circle's border `--paper-500` (`--soot-500` in dark). Keyboard
/// focus adds the outer focus ring. The whole row (circle, [label],
/// [description]) is the hit target, as the bundle's `<label>` is.
///
/// **Groups.** A radio is checked when the group value equals [value].
/// Inside a [RadioGroup] (the widgets library's group, which carries the
/// group value and `onChanged` for all its radios) the radios take the
/// group's value and report to it, and the group gives them the arrow
/// keys: ArrowUp, ArrowDown, ArrowLeft and ArrowRight move to the next or
/// previous option and select it, Space selects the focused one, and only
/// the checked radio is a Tab stop. Without a group, [groupValue] and
/// [onChanged] work the same way with Tab and Space only.
///
/// **Disabled.** [disabled] gives the sunken, subtle-bordered circle and the
/// disabled label colour, and the radio takes no focus. With
/// [disabledReason] (G10) it stays a Tab stop of its own (the group's arrow
/// keys skip it, as the browser skips disabled radios), shows the reason
/// as its tooltip and semantics hint, and cannot be selected.
///
/// For screen readers the radio is checked or not, in a mutually exclusive
/// group, named by [label], with [description] as its hint.
class Radio<T> extends StatefulWidget {
  /// Creates the radio for [value].
  const new({
    required this.value,
    super.key,
    this.label,
    this.description,
    this.disabled = false,
    this.disabledReason,
    this.groupValue,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  /// The checked centre's diameter: the 14 px inside of the border less
  /// the 4 px inset ring on both sides (`box-shadow: inset 0 0 0 4px`).
  static const double dotSize = 6;

  /// The label beside the circle; null shows none.
  final String? label;

  /// The description under the label; null shows none.
  final String? description;

  /// Whether the radio is disabled.
  final bool disabled;

  /// Why the radio is disabled: its tooltip and semantics hint while
  /// disabled (G10).
  final String? disabledReason;

  /// The value this radio stands for.
  final T value;

  /// The selected value of the group, when no [RadioGroup] is above.
  final T? groupValue;

  /// Called with [value] when the user selects this radio, when no
  /// [RadioGroup] is above; null (without a group) disables the radio.
  final ValueChanged<T>? onChanged;

  /// The focus node; one is created when null. Not a design-system prop.
  final FocusNode? focusNode;

  /// Whether the radio takes focus when it first appears. Not a
  /// design-system prop.
  final bool autofocus;

  @override
  State<Radio<T>> createState() => _RadioState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(StringProperty('description', description, defaultValue: null))
      ..add(DiagnosticsProperty<T>('value', value))
      ..add(
        DiagnosticsProperty<T>('groupValue', groupValue, defaultValue: null),
      )
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      );
  }
}

class _RadioState<T> extends State<Radio<T>> with RadioClient<T> {
  FocusNode? _ownNode;
  RadioGroupRegistry<T>? _group;

  @override
  FocusNode get focusNode =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'Radio'));

  @override
  T get radioValue => widget.value;

  @override
  bool get tristate => false;

  @override
  bool get enabled => !widget.disabled && _onChanged != null;

  ValueChanged<T>? get _onChanged {
    final group = _group;
    if (group != null) return group.onChanged;
    return widget.onChanged;
  }

  bool get _checked {
    final group = _group;
    return (group != null ? group.groupValue : widget.groupValue) ==
        widget.value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group = RadioGroup.maybeOf<T>(context);
    _register();
  }

  @override
  void didUpdateWidget(Radio<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  /// Joins the group while enabled. A radio disabled with a reason stays
  /// out of it, so the group's Tab policy (only the checked radio is a Tab
  /// stop) does not hide it and the reason can still be reached.
  void _register() {
    registry = enabled ? _group : null;
  }

  @override
  void dispose() {
    registry = null;
    _ownNode?.dispose();
    super.dispose();
  }

  void _select() {
    if (!_checked) _onChanged?.call(widget.value);
  }

  Widget _circle(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final checked = _checked;
    final disabled = states.contains(WidgetState.disabled);
    final Color fill;
    final Color border;
    if (disabled) {
      // The CSS lets `.fm-radio .fm-check__input:checked` win over
      // `:disabled:checked`, which would draw a disabled radio as an
      // enabled one; the checkbox's disabled-checked look is used instead.
      fill = checked ? colors.borderStrong : colors.surfaceSunken;
      border = checked ? colors.borderStrong : colors.borderSubtle;
    } else if (checked) {
      fill = colors.accent;
      border = colors.accent;
    } else {
      fill = colors.surfaceRaised;
      border = states.contains(WidgetState.hovered)
          ? checkHoverBorder(theme)
          : colors.borderStrong;
    }
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusFull));
    return FocusRing(
      visible: states.contains(WidgetState.focused),
      borderRadius: radius,
      child: AnimatedContainer(
        duration: theme.motion.durFast,
        curve: theme.motion.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: theme.border.borderWidth),
        ),
        child: checked
            ? Container(
                width: Radio.dotSize,
                height: Radio.dotSize,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = this.enabled;
    return FermanInteractive(
      onPressed: enabled ? _select : null,
      disabled: widget.disabled,
      disabledReason: widget.disabledReason,
      isButton: false,
      focusNode: focusNode,
      autofocus: widget.autofocus,
      builder: (context, states, _) => Semantics(
        checked: _checked,
        inMutuallyExclusiveGroup: true,
        hint: widget.description,
        child: CheckRow(
          label: widget.label,
          description: widget.description,
          disabled: states.contains(WidgetState.disabled),
          box: _circle(context, states),
        ),
      ),
    );
  }
}
