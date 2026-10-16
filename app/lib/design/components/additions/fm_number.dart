import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/number_stepper.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A locale-aware number field with the NumberStepper anatomy, the
/// `FmNumber` building block (`design/FmNumber.dc.html`, the "FmNumber ·
/// locale-aware stepper" card of `DS additions.dc.html`). It keeps its Fm
/// name (ROADMAP step 7); where porting notes say FermanNumberField, read
/// FmNumber.
///
/// It is a small [NumberStepper] (`.fm-input.fm-stepper.fm-input--sm`),
/// [width] wide: [label] above, the value with exactly [precision]
/// decimals in the region's format ("10,5 pt" for Türkiye, "10.5 pt" for
/// the United States, "١٠٫٥ pt" for Saudi Arabia, "1.234,5 mm" for
/// Germany) in the body role (13 px, the board's `font: var(--type-body)`
/// over the small field's 12 px), [unit] after it in 12 px caption text,
/// the arrow column at the inline end, and [error] under it as text only
/// with the danger border. In right to left the arrows
/// sit on the left and the value lines up on the right.
///
/// The board's `lang` prop is a board convenience: the format follows the
/// region setting ([region]), never a prop or the UI language (G34,
/// COMPONENTS.md decision 13). Typing accepts either decimal separator
/// and the region's digits ([NumberStepper.parse], BACKLOG B003).
///
/// The widget is controlled: ArrowUp and ArrowDown (Shift for ten steps),
/// the arrow buttons, Enter and leaving the field commit a value rounded to
/// [step] and clamped to [min] and [max], reported through [onChanged].
///
/// For screen readers it is a text field named by [label] (or
/// [semanticLabel], the board's `aria`), whose value is the formatted
/// number with its unit, with increase and decrease actions.
class FmNumber extends StatelessWidget {
  /// Creates the field for [value] in [region]'s format.
  const new({
    required this.region,
    super.key,
    this.value = 10.5,
    this.precision = 1,
    this.unit = 'pt',
    this.label,
    this.width = 84,
    this.error,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.step = 1,
    this.onChanged,
    this.semanticLabel,
    this.disabled = false,
    this.focusNode,
  });

  /// The value shown.
  final double value;

  /// The number of decimals shown and kept.
  final int precision;

  /// The unit after the value; null shows none. Unit symbols are
  /// international and not translated ("10,5 pt" in Turkish, "١٠٫٥ pt" in
  /// Arabic).
  final String? unit;

  /// The label above the box; null shows none.
  final String? label;

  /// The width of the field.
  final double width;

  /// The error under the box ("Enter 4–96 pt."); null for none.
  final String? error;

  /// The smallest value a commit allows.
  final double min;

  /// The largest value a commit allows.
  final double max;

  /// The amount an arrow adds or takes away.
  final double step;

  /// Called with each committed value; null disables the field.
  final ValueChanged<double>? onChanged;

  /// The region whose number format the field shows and reads. Not a
  /// board prop: it replaces `lang` (G34).
  final Region region;

  /// The accessible name when no [label] is shown (the board's `aria`).
  final String? semanticLabel;

  /// Whether the field is disabled. Not a board prop.
  final bool disabled;

  /// The focus node of the text control; one is created when null. Not a
  /// board prop.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => NumberStepper(
    // FmNumber.dc.html: `font: var(--type-body); font-variant-numeric:
    // tabular-nums` on the control.
    controlStyle: context.ferman.typography.body.copyWith(
      fontFeatures: [
        ...context.ferman.typeScale.featuresUi,
        ...context.ferman.typeScale.numericTabular,
      ],
    ),
    value: value,
    region: region,
    label: label,
    min: min,
    max: max,
    step: step,
    unit: unit,
    precision: precision,
    width: width,
    disabled: disabled,
    onChanged: onChanged,
    error: error,
    semanticLabel: semanticLabel,
    focusNode: focusNode,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('value', value, defaultValue: 10.5))
      ..add(IntProperty('precision', precision, defaultValue: 1))
      ..add(StringProperty('unit', unit, defaultValue: 'pt'))
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(DoubleProperty('width', width, defaultValue: 84))
      ..add(StringProperty('error', error, defaultValue: null))
      ..add(DiagnosticsProperty<Region>('region', region))
      ..add(EnumProperty<FieldSize>('size', FieldSize.sm));
  }
}
