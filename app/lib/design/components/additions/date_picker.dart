import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

/// A popover calendar: a month header with previous and next, a weekday
/// row, a 6 × 7 day grid, a format note and Today, the DatePicker drawn in
/// `design/DocForm.dc.html` (lines 33–37; component spec `DatePicker`).
/// Never `showDatePicker` (ADR 0011); a custom popup on every platform,
/// also on mobile (G55).
///
/// The calendar is its own surface (260 px, 10 px of padding, large
/// corners, the popover shadow) and opens inside a `Popover` with
/// `surface: false` under the date field.
///
/// - The header shows [previousMonthButton], the month ([monthLabel], by
///   default the UI language's month and year with the region's digits)
///   in body-strong type, and [nextMonthButton]: IconButtons the screen
///   composes, calling [onMonthChanged].
/// - The weekday row starts on [firstDayOfWeek] (`DateTime.monday` is 1;
///   from the region setting) in label type, tertiary ([weekdayLabels],
///   Monday first; by default the UI language's short names).
/// - The grid shows six weeks around [month]: days of other months in the
///   disabled text colour, the selected day ([value]) on the accent with
///   on-accent semibold text, day numbers in the region's digits
///   (`RegionFormat`, G34).
/// - The footer shows [formatNote] ("Format DD.MM.YYYY · from the form")
///   and [todayButton], when either is given.
///
/// **Keyboard** (not in the bundle; the grid pattern its roles imply). The
/// grid is one Tab stop holding a focused day, which shows the inset focus
/// ring under keyboard focus (G22). ArrowLeft and ArrowRight move by a day
/// (mirrored in right to left), ArrowUp and ArrowDown by a week, PageUp and
/// PageDown by a month, Home and End to the start and end of the week;
/// moving out of the shown month calls [onMonthChanged]. Enter or Space
/// choose the focused day ([onChanged]); Escape calls [onDismiss]. A click
/// on a day chooses it.
///
/// For screen readers the calendar is a dialog named by [semanticLabel]
/// ("Choose a date"); days are buttons named by their full date, the
/// chosen one selected.
class DatePicker extends StatefulWidget {
  /// Creates a calendar showing [month].
  const new({
    required this.month,
    required this.region,
    super.key,
    this.value,
    this.firstDayOfWeek = DateTime.monday,
    this.formatNote,
    this.onChanged,
    this.onMonthChanged,
    this.onDismiss,
    this.semanticLabel,
    this.monthLabel,
    this.weekdayLabels,
    this.previousMonthButton,
    this.nextMonthButton,
    this.todayButton,
    this.autofocus = false,
  }) : assert(
         firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday,
         'firstDayOfWeek is a DateTime weekday (1 to 7)',
       );

  /// The calendar's `width`.
  static const double width = 260;

  /// A day cell's `height`.
  static const double dayHeight = 30;

  /// The grid's `gap`.
  static const double gridGap = 2;

  /// The footer's `margin-top` above its border.
  static const double footerMargin = 6;

  /// The chosen date; null for none.
  final DateTime? value;

  /// The month shown (any day of it).
  final DateTime month;

  /// The first day of the week, as `DateTime.weekday` numbers it (Monday
  /// is 1), from the region setting.
  final int firstDayOfWeek;

  /// The note in the footer; null shows none.
  final String? formatNote;

  /// Called with the chosen day.
  final ValueChanged<DateTime>? onChanged;

  /// Called with the first day of the month to show next.
  final ValueChanged<DateTime>? onMonthChanged;

  /// Called on Escape.
  final VoidCallback? onDismiss;

  /// The region whose digits the days show. Not in the spec (G34).
  final Region region;

  /// The accessible name of the calendar ("Choose a date"). Not in the
  /// spec.
  final String? semanticLabel;

  /// The month heading; null formats [month] for the UI language.
  final String? monthLabel;

  /// The seven weekday names, Monday first; null takes the UI language's
  /// short names.
  final List<String>? weekdayLabels;

  /// The "Previous month" IconButton (`chevron-left`, small); null shows
  /// none.
  final Widget? previousMonthButton;

  /// The "Next month" IconButton (`chevron-right`, small); null shows
  /// none.
  final Widget? nextMonthButton;

  /// The "Today" Button (small, ghost); null shows none.
  final Widget? todayButton;

  /// Whether the day grid takes focus when the calendar appears (as it
  /// does when it opens from a date field). Not in the spec.
  final bool autofocus;

  /// The 42 days the grid shows for [month], starting on [firstDayOfWeek].
  static List<DateTime> daysOf(DateTime month, int firstDayOfWeek) {
    final first = DateTime(month.year, month.month);
    final lead = (first.weekday - firstDayOfWeek + 7) % 7;
    return [
      for (var i = 0; i < 42; i++)
        DateTime(first.year, first.month, first.day - lead + i),
    ];
  }

  @override
  State<DatePicker> createState() => _DatePickerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<DateTime>('value', value, defaultValue: null))
      ..add(DiagnosticsProperty<DateTime>('month', month))
      ..add(IntProperty('firstDayOfWeek', firstDayOfWeek, defaultValue: 1))
      ..add(StringProperty('formatNote', formatNote, defaultValue: null))
      ..add(DiagnosticsProperty<Region>('region', region));
  }
}

class _DatePickerState extends State<DatePicker> {
  final FocusNode _grid = FocusNode(debugLabel: 'DatePicker grid');
  late DateTime _focused = _initialFocus();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      // After the first frame: the field that opened the calendar may
      // still hold focus in the same scope, so `autofocus` would not apply.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _grid.requestFocus();
      });
    }
  }

  DateTime _initialFocus() {
    final value = widget.value;
    if (value != null && _sameMonth(value, widget.month)) {
      return DateTime(value.year, value.month, value.day);
    }
    return DateTime(widget.month.year, widget.month.month);
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool _sameDay(DateTime a, DateTime b) =>
      _sameMonth(a, b) && a.day == b.day;

  @override
  void didUpdateWidget(DatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMonth(widget.month, oldWidget.month) &&
        !_sameMonth(_focused, widget.month)) {
      _focused = _initialFocus();
    }
  }

  @override
  void dispose() {
    _grid.dispose();
    super.dispose();
  }

  void _moveTo(DateTime day) {
    setState(() => _focused = day);
    if (!_sameMonth(day, widget.month)) {
      widget.onMonthChanged?.call(DateTime(day.year, day.month));
    }
  }

  DateTime _addMonths(DateTime day, int months) {
    final target = DateTime(day.year, day.month + months);
    final last = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, day.day.clamp(1, last));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final day = _focused;
    DateTime shift(int days) => DateTime(day.year, day.month, day.day + days);
    final offset = (day.weekday - widget.firstDayOfWeek + 7) % 7;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveTo(shift(rtl ? 1 : -1));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveTo(shift(rtl ? -1 : 1));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveTo(shift(-7));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveTo(shift(7));
    } else if (key == LogicalKeyboardKey.pageUp) {
      _moveTo(_addMonths(day, -1));
    } else if (key == LogicalKeyboardKey.pageDown) {
      _moveTo(_addMonths(day, 1));
    } else if (key == LogicalKeyboardKey.home) {
      _moveTo(shift(-offset));
    } else if (key == LogicalKeyboardKey.end) {
      _moveTo(shift(6 - offset));
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      widget.onChanged?.call(day);
    } else if (key == LogicalKeyboardKey.escape && widget.onDismiss != null) {
      widget.onDismiss?.call();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// [text] with its ASCII digits in the region's digits.
  String _regionDigits(String text) {
    final zero = widget.region.zeroDigit.codeUnitAt(0);
    if (zero == 0x30) return text;
    return String.fromCharCodes(
      text.codeUnits.map(
        (unit) => unit >= 0x30 && unit <= 0x39 ? zero + unit - 0x30 : unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    initializeRegionFormats();
    final locale = Localizations.localeOf(context).toString();
    final intlLocale = DateFormat.localeExists(locale) ? locale : 'en';
    final format = RegionFormat.forRegion(widget.region);
    final monthLabel =
        widget.monthLabel ??
        _regionDigits(
          (DateFormat.yMMMM(
            intlLocale,
          )..useNativeDigits = false).format(widget.month),
        );
    final fullDate = DateFormat.yMMMMEEEEd(intlLocale)..useNativeDigits = false;
    final symbols = DateFormat(null, intlLocale).dateSymbols;
    // intl lists weekdays from Sunday; Monday-first names come from the
    // parameter.
    final mondayFirst =
        widget.weekdayLabels ??
        [for (var i = 1; i <= 7; i++) symbols.STANDALONESHORTWEEKDAYS[i % 7]];
    final weekdays = [
      for (var i = 0; i < 7; i++)
        mondayFirst[(widget.firstDayOfWeek - 1 + i) % 7],
    ];
    final days = DatePicker.daysOf(widget.month, widget.firstDayOfWeek);
    final forced = FermanForcedStates.of(context);
    final ring =
        forced.contains(WidgetState.focused) ||
        (_grid.hasFocus &&
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional);
    final value = widget.value;
    final label = theme.typography.label;
    final previous = widget.previousMonthButton;
    final next = widget.nextMonthButton;
    final today = widget.todayButton;
    final note = widget.formatNote;
    Widget cell(DateTime day) {
      final selected = value != null && _sameDay(day, value);
      final outside = !_sameMonth(day, widget.month);
      final focused = ring && _sameDay(day, _focused);
      final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: _regionDigits(fullDate.format(day)),
          onTap: () => widget.onChanged?.call(day),
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _focused = day);
                widget.onChanged?.call(day);
              },
              child: Container(
                height: DatePicker.dayHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.accent : null,
                  borderRadius: radius,
                ),
                foregroundDecoration: focused
                    ? BoxDecoration(
                        borderRadius: radius,
                        border: Border.fromBorderSide(
                          theme.focus.focusRingInset,
                        ),
                      )
                    : null,
                child: Text(
                  format.integer(day.day),
                  style: theme.typography.body.copyWith(
                    fontFeatures: theme.typeScale.numericTabular,
                    fontWeight: selected
                        ? theme.typeScale.weightSemibold
                        : theme.typeScale.weightRegular,
                    color: selected
                        ? colors.textOnAccent
                        : (outside ? colors.textDisabled : colors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final calendar = Container(
      width: DatePicker.width,
      padding: EdgeInsetsDirectional.all(theme.space.space2_5),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusLg)),
        boxShadow: theme.elevation.shadowPopover,
      ),
      child: DefaultTextStyle.merge(
        style: theme.typography.body.copyWith(color: colors.textPrimary),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(bottom: theme.space.space2),
              child: Row(
                spacing: theme.space.space1,
                children: [
                  ?previous,
                  Expanded(
                    child: Text(
                      monthLabel,
                      textAlign: TextAlign.center,
                      style: theme.typography.bodyStrong.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  ?next,
                ],
              ),
            ),
            Focus(
              focusNode: _grid,
              includeSemantics: false,
              onKeyEvent: _onKey,
              onFocusChange: (_) => setState(() {}),
              child: Column(
                spacing: DatePicker.gridGap,
                children: [
                  ExcludeSemantics(
                    child: Row(
                      spacing: DatePicker.gridGap,
                      children: [
                        for (final name in weekdays)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.symmetric(
                                vertical: theme.space.space1,
                              ),
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                style: label.copyWith(
                                  color: colors.textTertiary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (var week = 0; week < 6; week++)
                    Row(
                      spacing: DatePicker.gridGap,
                      children: [
                        for (var d = 0; d < 7; d++) cell(days[week * 7 + d]),
                      ],
                    ),
                ],
              ),
            ),
            if (note != null || today != null)
              Container(
                margin: const EdgeInsetsDirectional.only(
                  top: DatePicker.footerMargin,
                ),
                padding: EdgeInsetsDirectional.only(top: theme.space.space2),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.borderSubtle,
                      width: theme.border.borderWidth,
                    ),
                  ),
                ),
                child: Row(
                  spacing: theme.space.space2,
                  children: [
                    Expanded(
                      child: note == null
                          ? const SizedBox()
                          : Text(
                              note,
                              style: theme.typography.caption.copyWith(
                                color: colors.textTertiary,
                              ),
                            ),
                    ),
                    ?today,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      scopesRoute: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      label: widget.semanticLabel,
      child: calendar,
    );
  }
}
