import 'dart:ui' show SemanticsValidationResult;

import 'package:ferman/design/components/forms/field.dart';
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:intl/number_symbols_data.dart';

/// A numeric field with stacked up and down arrows, step, clamp and
/// precision, the design-system `NumberStepper` component
/// (`components/forms/NumberStepper.jsx`, `.fm-stepper`).
///
/// The box is a [Field] box of [size], [width] wide with [label] above:
/// the value, [unit] in tertiary caption text, then a column of two 18 px
/// arrow buttons (`chevron-up`, `chevron-down`, 11 px) behind a 1 px
/// border on the inline end. The arrows are not Tab stops; the pointer
/// tints them, and each turns the disabled icon colour at its limit
/// (Increase at [max], Decrease at [min]).
///
/// **Region formats.** The value shows in the region's number format with
/// exactly [precision] decimals ("10,5" for Türkiye, "10.5" for the United
/// States, "١٠٫٥" for Saudi Arabia) through `RegionFormat`, never in the UI
/// language's (G34). A typed draft accepts either decimal separator and
/// the region's digits ([parse], BACKLOG B003).
///
/// **Committing.** The widget is controlled. ArrowUp and ArrowDown (or the
/// arrow buttons) commit [value] ± [step], ten steps with Shift. A typed
/// draft commits on Enter or when focus leaves; a draft that is not a
/// number is dropped. A commit rounds to [step], clamps to [min] and [max],
/// fixes [precision] decimals and reports the result through [onChanged].
///
/// [error] shows under the box with the danger border (FmNumber's error
/// state); the bundle's NumberStepper has none.
///
/// For screen readers the field is a text field named by [label] (or
/// [semanticLabel]) whose value is the formatted number with its unit, with
/// increase and decrease actions and their resulting values (the bundle's
/// `role="spinbutton"`; Flutter's spin-button role has no checks yet).
class NumberStepper extends StatefulWidget {
  /// Creates a stepper showing [value] in [region]'s number format.
  const new({
    required this.value,
    required this.region,
    super.key,
    this.label,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.step = 1,
    this.unit,
    this.precision = 0,
    this.size = FieldSize.sm,
    this.width = 84,
    this.disabled = false,
    this.onChanged,
    this.error,
    this.semanticLabel,
    this.focusNode,
  }) : assert(step > 0, 'step must be positive'),
       assert(precision >= 0, 'precision must not be negative');

  /// `.fm-stepper__arrow` `width`.
  static const double arrowWidth = 18;

  /// The arrows' glyph size (`Icon size={11}`).
  static const double arrowIconSize = 11;

  /// The arrows' glyph stroke (`strokeWidth={2}`).
  static const double arrowIconStroke = 2;

  /// How many steps ArrowUp and ArrowDown take with Shift.
  static const int shiftMultiplier = 10;

  /// The label above the box; null shows none.
  final String? label;

  /// The value shown.
  final double value;

  /// The smallest value a commit allows.
  final double min;

  /// The largest value a commit allows.
  final double max;

  /// The amount an arrow adds or takes away, and the grid a commit rounds
  /// to.
  final double step;

  /// The unit after the value, such as "pt"; null shows none.
  final String? unit;

  /// The number of decimals shown and kept.
  final int precision;

  /// The height, padding and text size of the box.
  final FieldSize size;

  /// The width of the field (`style={{ width }}`).
  final double width;

  /// Whether the stepper is disabled.
  final bool disabled;

  /// Called with each committed value; null disables the stepper.
  final ValueChanged<double>? onChanged;

  /// The region whose number format the field shows and reads. Not a
  /// design-system prop: formats follow the region setting (G34).
  final Region region;

  /// The error under the box; null for none. Not a design-system prop
  /// (FmNumber's error state).
  final String? error;

  /// The accessible name when no [label] is shown. Not a design-system
  /// prop.
  final String? semanticLabel;

  /// The focus node of the text control; one is created when null. Not a
  /// design-system prop.
  final FocusNode? focusNode;

  /// [value] in [region]'s format with exactly [precision] decimals.
  static String format(double value, Region region, int precision) =>
      RegionFormat.forRegion(region).decimal(
        value,
        minFractionDigits: precision,
        maxFractionDigits: precision,
      );

  /// The number a user typed in a field of [region], or null when [text]
  /// is not a number (BACKLOG B003, ADR 0014).
  ///
  /// - Either decimal separator is accepted ("10,5" and "10.5" are both
  ///   10.5 in every region), as are the Arabic decimal and group signs.
  /// - Grouping is read as the region writes it: with both "." and "," the
  ///   last one is the decimal separator ("1.234,5" and "1,234.5"); a
  ///   separator that appears more than once groups ("1.234.567"); a single
  ///   region group separator followed by exactly three digits groups too
  ///   ("1.234" is 1234 for Türkiye, "1,234" for the United States), as the
  ///   field itself shows such numbers. Spaces, no-break spaces and
  ///   apostrophes are group separators (France, Switzerland).
  /// - The region's digits, Arabic-Indic and Extended Arabic-Indic digits
  ///   and ASCII digits are all read.
  /// - A leading minus (`-`, `−`, with any direction marks) negates.
  /// - [unit], when given, may follow the number ("10,5 pt").
  static double? parse(String text, Region region, {String? unit}) {
    var source = text.trim();
    if (unit != null && unit.isNotEmpty && source.endsWith(unit)) {
      source = source.substring(0, source.length - unit.length);
    }
    final symbols = numberFormatSymbols[region.formatLocale];
    final group = symbols?.GROUP_SEP ?? ',';
    final zero = region.zeroDigit.codeUnitAt(0);
    final out = StringBuffer();
    var negative = false;
    var seenDigit = false;
    for (final rune in source.runes) {
      if (_ignored.contains(rune)) continue;
      final digit = _digitValue(rune, zero);
      if (digit != null) {
        out.writeCharCode(0x30 + digit);
        seenDigit = true;
      } else if (rune == 0x2D || rune == 0x2212) {
        // A minus only counts before the first digit.
        if (seenDigit || negative) return null;
        negative = true;
      } else if (rune == 0x2E || rune == 0x2C) {
        out.writeCharCode(rune);
      } else if (rune == _arabicDecimal) {
        out.write('d');
      } else if (rune == _arabicGroup) {
        // Dropped: always a group separator.
      } else {
        return null;
      }
    }
    var digits = out.toString();
    final dots = '.'.allMatches(digits).length;
    final commas = ','.allMatches(digits).length;
    String? decimal;
    if (digits.contains('d')) {
      decimal = 'd';
      digits = digits.replaceAll('.', '').replaceAll(',', '');
    } else if (dots > 0 && commas > 0) {
      decimal = digits.lastIndexOf('.') > digits.lastIndexOf(',') ? '.' : ',';
      digits = digits.replaceAll(decimal == '.' ? ',' : '.', '');
    } else if (dots + commas > 0) {
      final mark = dots > 0 ? '.' : ',';
      final at = digits.indexOf(mark);
      final groups =
          dots + commas > 1 ||
          (mark == group && at > 0 && digits.length - at - 1 == 3);
      if (groups) {
        digits = digits.replaceAll(mark, '');
      } else {
        decimal = mark;
      }
    }
    if (decimal != null) {
      if (decimal.allMatches(digits).length > 1) return null;
      digits = digits.replaceAll(decimal, '.');
    }
    if (!_number.hasMatch(digits)) return null;
    final value = double.tryParse(digits);
    if (value == null) return null;
    return negative ? -value : value;
  }

  /// Spaces, no-break spaces, thin and narrow spaces, apostrophes used for
  /// grouping, and direction marks.
  static const Set<int> _ignored = {
    0x20, 0xA0, 0x2009, 0x202F, 0x27, 0x2019, //
    0x200E, 0x200F, 0x061C, 0x2066, 0x2067, 0x2068, 0x2069,
  };

  /// U+066B ARABIC DECIMAL SEPARATOR.
  static const int _arabicDecimal = 0x066B;

  /// U+066C ARABIC THOUSANDS SEPARATOR.
  static const int _arabicGroup = 0x066C;

  static final RegExp _number = RegExp(r'^(\d+\.?\d*|\.\d+)$');

  static int? _digitValue(int rune, int zero) {
    for (final start in [0x30, 0x0660, 0x06F0, zero]) {
      if (rune >= start && rune <= start + 9) return rune - start;
    }
    return null;
  }

  /// The value a commit of [raw] gives: rounded to [step], clamped to
  /// [min] and [max], with [precision] decimals.
  static double commitValue(
    double raw, {
    required double step,
    required double min,
    required double max,
    required int precision,
  }) {
    final stepped = (raw / step).round() * step;
    final clamped = stepped.clamp(min, max);
    return double.parse(clamped.toStringAsFixed(precision));
  }

  @override
  State<NumberStepper> createState() => _NumberStepperState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(DoubleProperty('value', value))
      ..add(DoubleProperty('min', min, defaultValue: double.negativeInfinity))
      ..add(DoubleProperty('max', max, defaultValue: double.infinity))
      ..add(DoubleProperty('step', step, defaultValue: 1))
      ..add(StringProperty('unit', unit, defaultValue: null))
      ..add(IntProperty('precision', precision, defaultValue: 0))
      ..add(EnumProperty<FieldSize>('size', size, defaultValue: FieldSize.sm))
      ..add(DoubleProperty('width', width, defaultValue: 84))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(DiagnosticsProperty<Region>('region', region))
      ..add(StringProperty('error', error, defaultValue: null));
  }
}

class _NumberStepperState extends State<NumberStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: _formatted(widget.value),
  );
  FocusNode? _ownNode;
  bool _drafting = false;

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'NumberStepper'));

  bool get _enabled => !widget.disabled && widget.onChanged != null;

  String _formatted(double value) =>
      NumberStepper.format(value, widget.region, widget.precision);

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownNode)?.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
    if (!_drafting &&
        (oldWidget.value != widget.value ||
            oldWidget.region != widget.region ||
            oldWidget.precision != widget.precision)) {
      _controller.text = _formatted(widget.value);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _controller.dispose();
    _ownNode?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_node.hasFocus) _commitDraft();
  }

  void _commit(double raw) {
    final value = NumberStepper.commitValue(
      raw,
      step: widget.step,
      min: widget.min,
      max: widget.max,
      precision: widget.precision,
    );
    _drafting = false;
    _controller.text = _formatted(value);
    if (value != widget.value) widget.onChanged?.call(value);
  }

  void _commitDraft() {
    if (!_drafting) return;
    final parsed = NumberStepper.parse(
      _controller.text,
      widget.region,
      unit: widget.unit,
    );
    if (parsed == null) {
      _drafting = false;
      _controller.text = _formatted(widget.value);
    } else {
      _commit(parsed);
    }
  }

  void _stepBy(int steps) {
    if (!_enabled) return;
    _commit(widget.value + steps * widget.step);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final steps = shift ? NumberStepper.shiftMultiplier : 1;
    if (key == LogicalKeyboardKey.arrowUp) {
      _stepBy(steps);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _stepBy(-steps);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final enabled = _enabled;
    final disabled = widget.disabled;
    final unit = widget.unit;
    final value = widget.value;
    String spoken(double number) {
      final text = _formatted(number);
      return unit == null ? text : '$text $unit';
    }

    final up = NumberStepper.commitValue(
      value + widget.step,
      step: widget.step,
      min: widget.min,
      max: widget.max,
      precision: widget.precision,
    );
    final down = NumberStepper.commitValue(
      value - widget.step,
      step: widget.step,
      min: widget.min,
      max: widget.max,
      precision: widget.precision,
    );
    final canIncrease = enabled && value < widget.max;
    final canDecrease = enabled && value > widget.min;
    final input = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: FieldInput(
        controller: _controller,
        focusNode: _node,
        style: FieldBox.textStyleOf(
          theme,
          widget.size,
          color: disabled ? colors.textDisabled : colors.textPrimary,
        ),
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onChanged: (_) => _drafting = true,
        onEditingComplete: () {
          _commitDraft();
          _node.unfocus();
        },
      ),
    );
    final arrows = DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: colors.borderDefault,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: _StepperArrow(
              icon: IconName.chevronUp,
              enabled: canIncrease,
              onPressed: () => _stepBy(1),
            ),
          ),
          Container(
            height: theme.border.borderWidth,
            color: colors.borderSubtle,
          ),
          Expanded(
            child: _StepperArrow(
              icon: IconName.chevronDown,
              enabled: canDecrease,
              onPressed: () => _stepBy(-1),
            ),
          ),
        ],
      ),
    );
    final hint = widget.error;
    return SizedBox(
      width: widget.width,
      child: MergeSemantics(
        child: Semantics(
          label: widget.label ?? widget.semanticLabel,
          value: spoken(value),
          increasedValue: canIncrease ? spoken(up) : null,
          decreasedValue: canDecrease ? spoken(down) : null,
          onIncrease: canIncrease ? () => _stepBy(1) : null,
          onDecrease: canDecrease ? () => _stepBy(-1) : null,
          hint: hint,
          enabled: enabled,
          validationResult: hint == null
              ? SemanticsValidationResult.none
              : SemanticsValidationResult.invalid,
          child: Field(
            label: widget.label,
            error: widget.error,
            size: widget.size,
            disabled: disabled,
            clip: true,
            padding: EdgeInsetsDirectional.only(
              start: FieldBox.sidePaddingOf(theme, widget.size),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FieldBox.contentGap,
              children: [
                Expanded(child: Center(child: input)),
                if (unit != null)
                  Center(
                    child: ExcludeSemantics(
                      child: Text(
                        unit,
                        style: theme.typography.caption.copyWith(
                          color: colors.textTertiary,
                          fontFeatures: theme.typeScale.numericTabular,
                        ),
                      ),
                    ),
                  ),
                ExcludeSemantics(child: arrows),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One arrow button of the stepper (`.fm-stepper__arrow`): not a Tab stop,
/// tinted under the pointer, disabled at its limit.
class _StepperArrow extends StatefulWidget {
  const new({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconName icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_StepperArrow> createState() => _StepperArrowState();
}

class _StepperArrowState extends State<_StepperArrow> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final enabled = widget.enabled;
    final Color? background;
    final Color iconColor;
    if (!enabled) {
      background = null;
      iconColor = colors.iconDisabled;
    } else if (_pressed) {
      background = colors.surfacePressed;
      iconColor = colors.textPrimary;
    } else if (_hovered) {
      background = colors.surfaceHover;
      iconColor = colors.textPrimary;
    } else {
      background = null;
      iconColor = colors.iconSecondary;
    }
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: Container(
          width: NumberStepper.arrowWidth,
          alignment: Alignment.center,
          color: background,
          child: Icon(
            widget.icon,
            size: NumberStepper.arrowIconSize,
            strokeWidth: NumberStepper.arrowIconStroke,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
