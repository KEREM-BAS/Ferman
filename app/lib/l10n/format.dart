import 'dart:async';

import 'package:ferman/l10n/region.dart';
import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/date_time_patterns.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';

/// Formats numbers, sizes, lengths, dates and times for a [Region], never
/// for the UI language (ARCHITECTURE.md §11.3, ADR 0014, G34).
///
/// With [Region.turkiye] an English UI gets "13.10.2026", "14:32",
/// "18.500,50" and "10,5 pt", as a11-1b draws; with [Region.unitedStates]
/// it gets "10/13/2026", "2:32 PM", "18,500.5" and "10.5 pt".
///
/// - Numbers use the region's decimal and grouping separators and digits
///   (intl `NumberFormat.decimalPattern`). Where CLDR groups only from five
///   integer digits (`minimumGroupingDigits` 2: Spain, Italy, Poland,
///   Portugal, Hungary and others), four-digit numbers stay ungrouped:
///   "1500", "15.000". intl ignores that setting, so this class applies it.
/// - Dates are numeric with a four-digit year, CLDR's `yMd` skeleton
///   ("13.10.2026", "10/13/2026", Arabic "١٣/١٠/٢٠٢٦" with U+200F
///   RIGHT-TO-LEFT MARK after the day and the month; German "2.10.2026" for
///   2 October, unpadded as CLDR has it). Times are CLDR's `jm` skeleton
///   in the region's 12- or 24-hour clock ("14:32"; "2:32 PM" with U+202F
///   NARROW NO-BREAK SPACE before "PM", as CLDR and intl write it).
/// - Digits are the region's number digits ([Region.zeroDigit]) in numbers,
///   dates and times alike, whichever date data intl holds (see
///   [initializeRegionFormats]).
/// - A unit follows its number after U+00A0 NO-BREAK SPACE, so the pair
///   never wraps: "10,5 pt", "210 × 297 mm", "24,6 MB". Unit symbols are
///   international and not translated ([LengthUnit.symbol]).
/// - Percentages take the region's sign and its place ([percent]): "%40"
///   (Türkiye), "40%" (United States), "٤٠٪؜" (Saudi Arabia), as CLDR
///   writes them (G34, G74).
///
/// The strings carry no direction marks of their own beyond what CLDR puts
/// in them (the Arabic date has U+200F RIGHT-TO-LEFT MARK after the day and
/// month). In right-to-left UI text, wrap a value in [bidiIsolate] so it
/// keeps its own order ("10,5 pt", not "pt 10,5"; a12-2c).
///
/// Instances are cached per region and cheap to get again.
final class RegionFormat {
  new _(this.region)
    : _groupsFromFiveDigits = _minimumGroupingDigits2.contains(
        region.formatLocale,
      ),
      // flutter_localizations replaces the date symbols of its own locales,
      // and its `ar` carries Arabic-Indic digits that CLDR's ar-AE does not
      // use: the digits come from the region's number symbols instead.
      _date = DateFormat.yMd(region.formatLocale)
        ..useNativeDigits = region.zeroDigit != '0',
      _time = DateFormat.jm(region.formatLocale)
        ..useNativeDigits = region.zeroDigit != '0';

  /// The formatter for [region].
  ///
  /// Loads intl's date data first if needed ([initializeRegionFormats]), so
  /// formatting never throws for a missing locale.
  factory forRegion(Region region) {
    initializeRegionFormats();
    return _cache[region] ??= RegionFormat._(region);
  }

  static final Map<Region, RegionFormat> _cache = {};

  /// The region whose conventions this formatter follows.
  final Region region;

  /// Whether CLDR's `minimumGroupingDigits` is 2 for the region's locale.
  final bool _groupsFromFiveDigits;
  final DateFormat _date;
  final DateFormat _time;
  final Map<int, NumberFormat> _decimals = {};
  final Map<int, NumberFormat> _percents = {};

  /// An integer with the region's grouping: "18.500" (Türkiye), "18,500"
  /// (United States), "١٨٬٥٠٠" (Saudi Arabia); "1500" but "15.000" (Spain).
  String integer(int value) => decimal(value, maxFractionDigits: 0);

  /// A decimal number with at least [minFractionDigits] and at most
  /// [maxFractionDigits] digits after the separator: "18.500,5"; with
  /// `minFractionDigits: 2`, "18.500,50" (Türkiye). Spain, Italy, Poland,
  /// Portugal and Hungary write "1500,5" ungrouped (CLDR
  /// `minimumGroupingDigits`).
  String decimal(
    num value, {
    int minFractionDigits = 0,
    int maxFractionDigits = 2,
  }) {
    final grouped = _decimalFormat(minFractionDigits, maxFractionDigits);
    if (!_groupsFromFiveDigits) return grouped.format(value);
    final ungrouped = _decimalFormat(
      minFractionDigits,
      maxFractionDigits,
      grouping: false,
    ).format(value);
    // Counted after rounding, so 9999,96 with one decimal is "10.000".
    return _integerDigits(ungrouped, grouped.symbols.ZERO_DIGIT) <
            _minimumGroupedIntegerDigits
        ? ungrouped
        : grouped.format(value);
  }

  /// [value] percent with the region's percent sign in its place and at
  /// most [maxFractionDigits] decimals: "%40" (Türkiye), "40%" (United
  /// States), "40 %" with U+00A0 (Germany), "٤٠٪؜" (Saudi Arabia, CLDR's
  /// Arabic percent sign U+066A with U+061C ARABIC LETTER MARK), as zoom
  /// levels show (G34, G74). [value] is the percentage itself: 40 for 40 %.
  /// Grouped like [decimal]: "6400 %" in Spain, "%6.400" in Türkiye.
  String percent(num value, {int maxFractionDigits = 0}) {
    final fraction = value / 100;
    final grouped = _percentFormat(maxFractionDigits);
    if (!_groupsFromFiveDigits) return grouped.format(fraction);
    final ungrouped = _percentFormat(
      maxFractionDigits,
      grouping: false,
    ).format(fraction);
    return _integerDigits(ungrouped, grouped.symbols.ZERO_DIGIT) <
            _minimumGroupedIntegerDigits
        ? ungrouped
        : grouped.format(fraction);
  }

  /// A font size in points, with at most one decimal: "10,5 pt" (Türkiye),
  /// "10.5 pt" (United States), "11 pt".
  String pointSize(num points) =>
      _withUnit(decimal(points, maxFractionDigits: 1), LengthUnit.point.symbol);

  /// A length of [points] PDF points in [unit]: "158,7 mm", "7,5 cm",
  /// "0.5 in". At most [maxFractionDigits] decimals; by default 1 for mm
  /// and pt and 2 for cm and in, a resolution of 0.1 mm or finer.
  String length(double points, LengthUnit unit, {int? maxFractionDigits}) =>
      _withUnit(
        decimal(
          unit.fromPoints(points),
          maxFractionDigits: maxFractionDigits ?? _lengthDigits(unit),
        ),
        unit.symbol,
      );

  /// A width and height of PDF points in [unit], joined by "×" (U+00D7
  /// MULTIPLICATION SIGN): "210 × 297 mm", "8.5 × 11 in". Decimals as in
  /// [length].
  String dimensions(
    double widthPoints,
    double heightPoints,
    LengthUnit unit, {
    int? maxFractionDigits,
  }) {
    final digits = maxFractionDigits ?? _lengthDigits(unit);
    final width = decimal(
      unit.fromPoints(widthPoints),
      maxFractionDigits: digits,
    );
    final height = decimal(
      unit.fromPoints(heightPoints),
      maxFractionDigits: digits,
    );
    return _withUnit('$width$_noBreakSpace×$_noBreakSpace$height', unit.symbol);
  }

  /// The size of a sheet of [size] paper in [unit], rounded as the design
  /// shows paper sizes: whole millimetres and points, centimetres to one
  /// decimal, inches to two. A4 is "210 × 297 mm" and "8.27 × 11.69 in";
  /// Letter is "216 × 279 mm" and "8.5 × 11 in".
  String paperSize(PaperSize size, LengthUnit unit) => dimensions(
    size.widthPoints,
    size.heightPoints,
    unit,
    maxFractionDigits: switch (unit) {
      LengthUnit.millimetre || LengthUnit.point => 0,
      LengthUnit.centimetre => 1,
      LengthUnit.inch => 2,
    },
  );

  /// A file size in decimal units (1 KB = 1000 bytes, as macOS and most
  /// Linux file managers count; Windows Explorer counts 1024): "512 B",
  /// "284 KB", "24,6 MB", "4,1 GB". Bytes and kilobytes are whole, larger
  /// units have at most one decimal, and a value that rounds to 1000 moves
  /// to the next unit ("1 MB", not "1.000 KB").
  String fileSize(int bytes) {
    final magnitude = bytes.abs();
    final sign = bytes.isNegative ? -1 : 1;
    if (magnitude < 1000) return _withUnit(integer(bytes), 'B');
    var value = magnitude / 1000;
    for (var unit = 0; ; unit++) {
      final digits = unit == 0 ? 0 : 1;
      final scale = digits == 0 ? 1 : 10;
      final rounded = (value * scale).round() / scale;
      if (rounded < 1000 || unit == _fileSizeUnits.length - 1) {
        return _withUnit(
          decimal(sign * rounded, maxFractionDigits: digits),
          _fileSizeUnits[unit],
        );
      }
      value /= 1000;
    }
  }

  /// A numeric date: "13.10.2026" (Türkiye), "10/13/2026" (United States),
  /// "١٣/١٠/٢٠٢٦" with two U+200F marks (Saudi Arabia). Gregorian calendar
  /// only.
  String date(DateTime value) => _date.format(value);

  /// A time of day in hours and minutes: "14:32" (Türkiye), "2:32 PM"
  /// (United States, U+202F before "PM").
  String time(DateTime value) => _time.format(value);

  /// [date] and [time] joined by the region's short date-time pattern:
  /// "13.10.2026 14:32" (Türkiye, as the comment boards show it),
  /// "10/13/2026, 2:32 PM" (United States).
  ///
  /// The pattern is intl's, which predates CLDR 48 for a few regions: CLDR
  /// 48 adds a comma for Brazil, Denmark and Indonesia ("02/10/2026,
  /// 14:32") and "klo" for Finland. Where intl's pattern and
  /// flutter_localizations' disagree, CLDR 48's is fixed here
  /// ([_dateTimePatterns]), so the result never depends on which of the two
  /// loaded last.
  String dateTime(DateTime value) =>
      (_dateTimePatterns[region.formatLocale] ??
              _date.dateSymbols.DATETIMEFORMATS[3])
          .replaceFirst('{1}', date(value))
          .replaceFirst('{0}', time(value));

  NumberFormat _decimalFormat(
    int minFractionDigits,
    int maxFractionDigits, {
    bool grouping = true,
  }) {
    final max = maxFractionDigits < 0 ? 0 : maxFractionDigits;
    final min = minFractionDigits.clamp(0, max);
    final key = (min << 8 | max) << 1 | (grouping ? 1 : 0);
    return _decimals[key] ??= _newDecimalFormat(min, max, grouping: grouping);
  }

  NumberFormat _percentFormat(int maxFractionDigits, {bool grouping = true}) {
    final max = maxFractionDigits < 0 ? 0 : maxFractionDigits;
    final key = max << 1 | (grouping ? 1 : 0);
    return _percents[key] ??= () {
      final format = NumberFormat.percentPattern(region.formatLocale)
        ..maximumFractionDigits = max;
      if (!grouping) format.turnOffGrouping();
      return format;
    }();
  }

  NumberFormat _newDecimalFormat(int min, int max, {required bool grouping}) {
    final format = NumberFormat.decimalPattern(region.formatLocale)
      ..minimumFractionDigits = min
      ..maximumFractionDigits = max;
    if (!grouping) format.turnOffGrouping();
    return format;
  }
}

/// [value] between U+2068 FIRST STRONG ISOLATE and U+2069 POP DIRECTIONAL
/// ISOLATE, so a formatted value keeps its own direction inside text of
/// the other direction (ADR 0014, a12-2c): in Arabic UI text, "10,5 pt"
/// stays "10,5 pt" and "210 × 297 mm" keeps its order.
///
/// Use it when a value is part of a longer right-to-left string. A value
/// alone in a `Text` widget under a right-to-left `Directionality` needs it
/// too: such a paragraph would otherwise show "pt 10,5".
String bidiIsolate(String value) => '\u2068$value\u2069';

/// Makes sure intl's date and time data is loaded for every locale a
/// [Region] can use. Idempotent and synchronous.
///
/// Call it once in `bootstrap()` (app/lib/app/bootstrap.dart) before
/// `runApp`, so the data is loaded before flutter_localizations' delegates
/// load their own subset of locales. [RegionFormat.forRegion] calls it too,
/// so tests and late callers are safe: when the delegates loaded first
/// (which turns `initializeDateFormatting` into a no-op), the missing
/// locales, such as the ar_EG of Saudi Arabia and Egypt, are added one by
/// one.
///
/// flutter_localizations still replaces the date symbols of its own
/// locales when it loads, so RegionFormat takes the digit system from the
/// region's number symbols, never from the date symbols, and fixes the
/// date-time pattern where the two disagree. Its data also differs from
/// intl's in the AM/PM markers of Assamese, Odia, Punjabi and Telugu, which
/// no listed region uses; a time in those languages follows whichever
/// loaded last.
void initializeRegionFormats() {
  if (_dateDataReady) return;
  // Synchronous despite the Future; it loads every locale when no date data
  // was loaded yet.
  unawaited(initializeDateFormatting());
  final missing = [
    for (final locale in numberFormatSymbols.keys)
      if (!DateFormat.localeExists(locale)) locale,
  ];
  if (missing.isNotEmpty) {
    final symbols = dateTimeSymbolMap();
    final patterns = dateTimePatternMap();
    for (final locale in missing) {
      final localeSymbols = symbols[locale];
      final localePatterns = patterns[locale];
      if (localeSymbols == null || localePatterns == null) continue;
      initializeDateFormattingCustom(
        locale: locale,
        symbols: localeSymbols,
        patterns: localePatterns,
      );
    }
  }
  _dateDataReady = true;
}

bool _dateDataReady = false;

const String _noBreakSpace = '\u00A0';

// dart format off
/// The locales whose CLDR 48 `minimumGroupingDigits` is 2: a number is
/// grouped only from five integer digits ("1500", "15.000"). Every intl
/// locale whose CLDR 48 number format leaves 1500 ungrouped and groups
/// 15000 (ICU 78.3 in Node.js 24.22.0, `NumberFormat.formatToParts`).
const Set<String> _minimumGroupingDigits2 = {
  'be', 'bg', 'es', 'es_ES', 'et', 'hu', 'hy', 'it', 'it_CH', 'ka', 'lv',
  'pl', 'pt_PT', 'sl', 'sq',
};
// dart format on

/// The fewest integer digits that are grouped in a locale of
/// [_minimumGroupingDigits2]: a group of three plus two.
const int _minimumGroupedIntegerDigits = 5;

/// CLDR 48's short date-time pattern for the locales where intl's and
/// flutter_localizations' disagree (Node.js 24.22.0, ICU 78.3). CLDR joins a
/// Chinese date and time with U+2009 THIN SPACE, where intl writes nothing
/// and flutter_localizations a space; for Malayalam intl already has
/// CLDR's comma and flutter_localizations drops it.
const Map<String, String> _dateTimePatterns = {
  'ml': '{1}, {0}',
  'zh_HK': '{1}\u2009{0}',
  'zh_TW': '{1}\u2009{0}',
};

/// The number of digits before the first non-digit after them in an
/// ungrouped [formatted] number whose digits start at [zeroDigit].
int _integerDigits(String formatted, String zeroDigit) {
  final zero = zeroDigit.codeUnitAt(0);
  var digits = 0;
  for (final unit in formatted.codeUnits) {
    if (unit >= zero && unit <= zero + 9) {
      digits++;
    } else if (digits > 0) {
      break;
    }
  }
  return digits;
}

const List<String> _fileSizeUnits = ['KB', 'MB', 'GB', 'TB'];

String _withUnit(String number, String unit) => '$number$_noBreakSpace$unit';

int _lengthDigits(LengthUnit unit) => switch (unit) {
  LengthUnit.millimetre || LengthUnit.point => 1,
  LengthUnit.centimetre || LengthUnit.inch => 2,
};
