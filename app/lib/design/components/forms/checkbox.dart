import 'package:ferman/design/components/forms/check_row.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// A 16 px checkbox with a label and a description, the design-system
/// `Checkbox` component (`components/forms/Checkbox.jsx`, `.fm-check`).
/// Material has a `Checkbox` too: files that import Material hide it.
///
/// The box has 3 px corners and a 1 px strong border on the raised
/// surface; [checked] or [indeterminate] fill it with the accent and show
/// a white `check` or `minus` (12 px, 2.75 stroke, `.fm-check__mark`). The
/// pointer turns the border `--paper-500` (`--soot-500` in dark), checked
/// or not, as `.fm-check:hover .fm-check__input` does. Keyboard focus adds
/// the outer focus ring. The whole row is the hit target (the bundle's
/// `<label>`), and Space toggles.
///
/// The widget is controlled: activating it calls [onChanged] with the
/// opposite of [checked] (an indeterminate box reports true).
///
/// **Disabled.** [disabled] gives the sunken, subtle-bordered box (strong
/// grey when checked, `.fm-check__input:disabled:checked`) and the disabled
/// label colour. With [disabledReason] (G10) the box stays focusable and
/// shows the reason as its tooltip and semantics hint.
///
/// For screen readers it is a checkbox, checked, unchecked or mixed, named
/// by [label], with [description] as its hint.
class Checkbox extends StatelessWidget {
  /// Creates a checkbox.
  const new({
    required this.checked,
    super.key,
    this.label,
    this.description,
    this.indeterminate = false,
    this.disabled = false,
    this.disabledReason,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  /// `.fm-check__input` `border-radius`.
  static const double radius = 3;

  /// The mark's size (`Icon size={12}`).
  static const double markSize = 12;

  /// The mark's stroke (`strokeWidth={2.75}`).
  static const double markStroke = 2.75;

  /// The label beside the box; null shows none.
  final String? label;

  /// The description under the label; null shows none.
  final String? description;

  /// Whether the box is checked.
  final bool checked;

  /// Whether the box shows the mixed state (a minus), over [checked].
  final bool indeterminate;

  /// Whether the checkbox is disabled.
  final bool disabled;

  /// Why the checkbox is disabled: its tooltip and semantics hint while
  /// disabled (G10).
  final String? disabledReason;

  /// Called with the new value when the user toggles the box; null
  /// disables it.
  final ValueChanged<bool>? onChanged;

  /// The focus node; one is created when null. Not a design-system prop.
  final FocusNode? focusNode;

  /// Whether the box takes focus when it first appears. Not a
  /// design-system prop.
  final bool autofocus;

  Widget _box(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final on = checked || indeterminate;
    final isDisabled = states.contains(WidgetState.disabled);
    final Color fill;
    Color border;
    if (isDisabled) {
      fill = on ? colors.borderStrong : colors.surfaceSunken;
      border = on ? colors.borderStrong : colors.borderSubtle;
    } else {
      fill = on ? colors.accent : colors.surfaceRaised;
      border = on ? colors.accent : colors.borderStrong;
      if (states.contains(WidgetState.hovered)) {
        border = checkHoverBorder(theme);
      }
    }
    const shape = BorderRadius.all(Radius.circular(radius));
    return FocusRing(
      visible: states.contains(WidgetState.focused),
      borderRadius: shape,
      child: AnimatedContainer(
        duration: theme.motion.durFast,
        curve: theme.motion.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: shape,
          border: Border.all(color: border, width: theme.border.borderWidth),
        ),
        child: on
            ? Icon(
                indeterminate ? IconName.minus : IconName.check,
                size: markSize,
                strokeWidth: markStroke,
                color: colors.textOnAccent,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return FermanInteractive(
      onPressed: change == null
          ? null
          : () => change(indeterminate || !checked),
      disabled: disabled,
      disabledReason: disabledReason,
      isButton: false,
      focusNode: focusNode,
      autofocus: autofocus,
      builder: (context, states, _) => Semantics(
        checked: indeterminate ? null : checked,
        mixed: indeterminate ? true : null,
        hint: description,
        child: CheckRow(
          label: label,
          description: description,
          disabled: states.contains(WidgetState.disabled),
          box: _box(context, states),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(StringProperty('description', description, defaultValue: null))
      ..add(FlagProperty('checked', value: checked, ifTrue: 'checked'))
      ..add(
        FlagProperty(
          'indeterminate',
          value: indeterminate,
          ifTrue: 'indeterminate',
        ),
      )
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      );
  }
}
