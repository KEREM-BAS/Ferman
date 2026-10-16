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
/// arrow buttons (`chevron-up`, `chevron-down`, 11 px) split by a 1 px
/// subtle line, behind a 1 px border on their inline start, outside the
/// 18 px. The arrows are not Tab stops; the pointer tints them, and each
/// turns the disabled icon colour at its limit (Increase at [max], Decrease
/// at [min]). A click on [label] focuses the field.
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
/// number (a typo such as "10..5", or a number too long to hold) is
/// dropped. A commit rounds to [step], clamps to [min] and [max], fixes
/// [precision] decimals and reports the result through [onChanged]; the
/// field then shows [value] as the owner passes it, so an owner that keeps
/// or adjusts its value is shown as it is.
///
/// [error] shows under the box with the danger border, as text only
/// (FmNumber's error state); the bundle's NumberStepper has none.
///
/// For screen readers the field is a text field named by [label] (or
/// [semanticLabel]) whose value is the formatted number with its unit, or
/// the draft being typed, with increase and decrease actions and their
/// resulting values (the bundle's `role="spinbutton"`; Flutter's
/// spin-button role has no checks yet).
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
    this.controlStyle,
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

  /// The value's text style; null takes the box's control style for
  /// [size] (12 px at [FieldSize.sm]). The colour is always the primary or
  /// disabled text colour. Not a design-system prop: FmNumber's board sets
  /// `font: var(--type-body)` on its control.
  final TextStyle? controlStyle;

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
  /// - Spaces, no-break spaces, thin spaces and apostrophes between digits
  ///   are group separators (France, Switzerland), and a run of them is
  ///   one ("1  234"). Beside a separator, before the number and after it
  ///   they are only spacing ("10 ,5", "− 2,5", "10,5 pt").
  /// - The decimal separator is certain with the Arabic decimal sign, with
  ///   both "." and "," (the last one is the decimal: "1.234,5" and
  ///   "1,234.5"), and with a single "." or "," that is not the region's
  ///   group separator ("1.234" is 1.234 for the United States).
  /// - A single region group separator groups when the number it splits is
  ///   well grouped ("1.234" is 1234 for Türkiye, "1,234" for the United
  ///   States), as the field itself shows such numbers. Otherwise it is the
  ///   decimal separator ("0.500" is 0.5, "12.5" is 12.5, ",5" is 0.5),
  ///   unless four or more digits not starting with 0 lead the number and
  ///   exactly three follow the separator ("1234.567" for Türkiye): that
  ///   may be a group with a separator missing, 1000 times the decimal
  ///   reading, so it is not a number.
  /// - With no decimal separator ("1.234.567", "1 234") every separator
  ///   groups.
  /// - Once the decimal separator is chosen, one group separator before the
  ///   first digit is ignored: deleting the leading digit of "1,234.5"
  ///   leaves ",234.5", which is 234.5.
  /// - Around a certain decimal separator, groups may have any length, but
  ///   none may be empty and the first may not start with 0 ("1.34,5" is
  ///   134.5; "1..234,5" is not a number). Otherwise grouping must be well
  ///   formed: a first group of one to three digits not starting with 0,
  ///   then groups of three (in a region with Indian grouping, groups of
  ///   two before the last: "12,34,567"). Anything else ("10..5", "1.2.3",
  ///   "10 5", "1,234,56") is not a number.
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
    final indian = symbols?.DECIMAL_PATTERN.contains('#,##,##0') ?? false;
    final zero = region.zeroDigit.codeUnitAt(0);
    // Digits become ASCII, "." and "," stay, the Arabic decimal sign is
    // "d", spaces and apostrophes are "s" and the Arabic group sign is "g".
    final out = StringBuffer();
    var negative = false;
    var seenDigit = false;
    for (final rune in source.runes) {
      if (_directionMarks.contains(rune)) continue;
      final digit = _digitValue(rune, zero);
      if (digit != null) {
        out.writeCharCode(0x30 + digit);
        seenDigit = true;
      } else if (_spaces.contains(rune)) {
        // Before the number a space is only spacing ("− 2,5").
        if (seenDigit) out.write('s');
      } else if (rune == 0x2D || rune == 0x2212) {
        // A minus only counts before the first digit.
        if (seenDigit || negative) return null;
        negative = true;
      } else if (rune == 0x2E || rune == 0x2C) {
        out.writeCharCode(rune);
      } else if (rune == _arabicDecimal) {
        out.write('d');
      } else if (rune == _arabicGroup) {
        out.write('g');
      } else {
        return null;
      }
    }
    // A space after the number (before its unit) or beside a separator is
    // only spacing ("10 ,5"), and a run of spaces between digits is one
    // group separator ("1  234"), in this order.
    final digits = out
        .toString()
        .replaceFirst(_trailingSpaces, '')
        .replaceAllMapped(_spacedMark, (match) => match[1]!)
        .replaceAll(_spaceRuns, 'g');
    final dots = '.'.allMatches(digits).length;
    final commas = ','.allMatches(digits).length;
    String? decimal;
    // Whether the decimal separator can only be what it is read as; then
    // the integer part means one number however it is grouped.
    var certain = false;
    if (digits.contains('d')) {
      decimal = 'd';
      certain = true;
    } else if (dots > 0 && commas > 0) {
      decimal = digits.lastIndexOf('.') > digits.lastIndexOf(',') ? '.' : ',';
      certain = true;
    } else if (dots + commas == 1) {
      final mark = dots > 0 ? '.' : ',';
      final parts = digits.split(_groupMarks);
      if (mark != group) {
        // Not the region's group separator ("1.234" in the United States).
        decimal = mark;
        certain = true;
      } else if (!_wellGrouped(parts, indian)) {
        // A lone region group separator that splits no well-formed group
        // is the decimal separator ("0.500", "12.5", "1234.5"), unless four
        // or more digits come before it and three after ("1234.567" in
        // Türkiye): a group with a separator missing, or a decimal.
        final first = parts.first;
        if (parts.last.length == 3 &&
            first.length > 3 &&
            !first.startsWith('0')) {
          return null;
        }
        decimal = mark;
      }
      // Otherwise it groups ("1.234" in Türkiye).
    }
    var whole = digits;
    var fraction = '';
    if (decimal != null) {
      if (decimal.allMatches(digits).length > 1) return null;
      final at = digits.indexOf(decimal);
      whole = digits.substring(0, at);
      fraction = digits.substring(at + 1);
      if (fraction.contains(_groupMarks)) return null;
    }
    var groups = whole.split(_groupMarks);
    // A group separator before the first digit ("1,234.5" with its 1
    // deleted) separates nothing once the decimal is chosen.
    if (groups.length > 1 && groups.first.isEmpty) groups = groups.sublist(1);
    if (groups.length > 1 &&
        !(certain ? _plainGroups(groups) : _wellGrouped(groups, indian))) {
      return null;
    }
    final number = decimal == null
        ? groups.join()
        : '${groups.join()}.$fraction';
    if (!_number.hasMatch(number)) return null;
    final value = double.tryParse(number);
    // A digit string too long for a double reads as infinity.
    if (value == null || !value.isFinite) return null;
    return negative ? -value : value;
  }

  /// Whether [groups] (the integer part split at its group separators) is
  /// grouped as numbers are written: a first group of one to three digits
  /// not starting with 0, then groups of three, or of two before the last
  /// with [indian] grouping.
  static bool _wellGrouped(List<String> groups, bool indian) {
    final first = groups.first;
    if (first.isEmpty || first.length > 3 || first.startsWith('0')) {
      return false;
    }
    if (groups.length < 2 || groups.last.length != 3) return false;
    for (final middle in groups.sublist(1, groups.length - 1)) {
      if (middle.length != 3 && !(indian && middle.length == 2)) return false;
    }
    return true;
  }

  /// Whether [groups] (the integer part split at its group separators,
  /// before a certain decimal separator) has no empty group (a doubled
  /// mark, or a mark before the decimal) and no leading 0.
  static bool _plainGroups(List<String> groups) =>
      groups.first.isNotEmpty &&
      !groups.first.startsWith('0') &&
      groups.skip(1).every((group) => group.isNotEmpty);

  /// Spaces, no-break spaces, thin and narrow spaces and apostrophes, which
  /// group between digits.
  static const Set<int> _spaces = {0x20, 0xA0, 0x2009, 0x202F, 0x27, 0x2019};

  /// Direction marks, which are ignored.
  static const Set<int> _directionMarks = {
    0x200E, 0x200F, 0x061C, 0x2066, 0x2067, 0x2068, 0x2069, //
  };

  static final RegExp _trailingSpaces = RegExp(r's+$');

  /// A separator with the spaces beside it.
  static final RegExp _spacedMark = RegExp('s*([.,dg])s*');

  static final RegExp _spaceRuns = RegExp('s+');

  static final RegExp _groupMarks = RegExp('[.,g]');

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

  void _setDrafting(bool drafting) {
    if (_drafting == drafting) return;
    if (mounted) {
      // The spoken value follows the draft.
      setState(() => _drafting = drafting);
    } else {
      _drafting = drafting;
    }
  }

  void _commit(double raw) {
    final value = NumberStepper.commitValue(
      raw,
      step: widget.step,
      min: widget.min,
      max: widget.max,
      precision: widget.precision,
    );
    _setDrafting(false);
    if (value != widget.value) widget.onChanged?.call(value);
    // The owner's value, not the committed one: didUpdateWidget shows the
    // new value once the owner passes it, and an owner that keeps its value
    // is shown as it is.
    _controller.text = _formatted(widget.value);
  }

  void _commitDraft() {
    if (!_drafting) return;
    final parsed = NumberStepper.parse(
      _controller.text,
      widget.region,
      unit: widget.unit,
    );
    if (parsed == null) {
      _setDrafting(false);
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
    final textColor = disabled ? colors.textDisabled : colors.textPrimary;
    final input = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: FieldInput(
        controller: _controller,
        focusNode: _node,
        style:
            widget.controlStyle?.copyWith(color: textColor) ??
            FieldBox.textStyleOf(theme, widget.size, color: textColor),
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        // Rebuilds on each keystroke, so the spoken value is the draft.
        onChanged: (_) => setState(() => _drafting = true),
        onEditingComplete: () {
          _commitDraft();
          _node.unfocus();
        },
      ),
    );
    final line = theme.border.borderWidth;
    // `.fm-stepper__arrows { border-inline-start }` around 18 px arrows,
    // border-box: the column is 19 px and the arrows' fills stay clear of
    // the border.
    final arrows = DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: colors.borderDefault, width: line),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: line),
        child: Column(
          children: [
            Expanded(
              child: _StepperArrow(
                icon: IconName.chevronUp,
                enabled: canIncrease,
                onPressed: () => _stepBy(1),
              ),
            ),
            // `.fm-stepper__arrow + .fm-stepper__arrow { border-top }`.
            SizedBox(
              width: NumberStepper.arrowWidth,
              height: line,
              child: ColoredBox(color: colors.borderSubtle),
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
      ),
    );
    final hint = widget.error;
    return SizedBox(
      width: widget.width,
      child: MergeSemantics(
        child: Semantics(
          label: widget.label ?? widget.semanticLabel,
          // While typing, the draft: the unit is a suffix (after a no-break
          // space, as in [spoken]), so the text selection still points into
          // the value.
          value: _drafting
              ? (unit == null
                    ? _controller.text
                    : '${_controller.text}\u00a0$unit')
              : spoken(value),
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
            // FmNumber's board draws the error as text only.
            errorIcon: false,
            size: widget.size,
            disabled: disabled,
            onLabelTap: enabled ? _node.requestFocus : null,
            clip: true,
            padding: EdgeInsetsDirectional.only(
              start: FieldBox.sidePaddingOf(theme, widget.size),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: FieldBox.contentGap,
              children: [
                // The control takes the box's full height (`height: 100%`),
                // so a click above or below the text line lands in it.
                Expanded(child: input),
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
