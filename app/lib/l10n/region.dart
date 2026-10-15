import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:intl/number_symbols_data.dart';

/// The paper sizes the region setting offers (a11-1b: "A4", "Letter").
enum PaperSize {
  /// ISO 216 A4: 210 × 297 mm.
  a4(widthPoints: 210 * 72 / 25.4, heightPoints: 297 * 72 / 25.4),

  /// US Letter: 8.5 × 11 in.
  letter(widthPoints: 8.5 * 72, heightPoints: 11 * 72);

  new({required this.widthPoints, required this.heightPoints});

  /// The width in PDF points (1/72 in).
  final double widthPoints;

  /// The height in PDF points (1/72 in).
  final double heightPoints;
}

/// The length units the region setting offers (a11-1b: mm, cm, in, pt).
enum LengthUnit {
  /// Millimetres.
  millimetre('mm', 72 / 25.4),

  /// Centimetres.
  centimetre('cm', 72 / 2.54),

  /// Inches.
  inch('in', 72),

  /// PDF points, 1/72 in (the typographic point of PDF and PostScript).
  point('pt', 1);

  new(this.symbol, this.pointsPerUnit);

  /// The unit symbol: lowercase, international and the same in every UI
  /// language, as the design writes it ("10,5 pt" in Turkish, "١٠٫٥ pt" in
  /// a12-1ar).
  final String symbol;

  /// How many PDF points one unit is.
  final double pointsPerUnit;

  /// A length of [points] PDF points in this unit.
  double fromPoints(double points) => points / pointsPerUnit;
}

/// The first day of the week. a11-1b offers Monday, Sunday and Saturday;
/// CLDR also has Friday (the Maldives), so the settings picker adds a
/// Friday option for a region whose default it is (G34).
enum FirstDayOfWeek {
  /// Monday ([DateTime.monday]).
  monday(DateTime.monday),

  /// Friday ([DateTime.friday]).
  friday(DateTime.friday),

  /// Saturday ([DateTime.saturday]).
  saturday(DateTime.saturday),

  /// Sunday ([DateTime.sunday]).
  sunday(DateTime.sunday);

  new(this.weekday);

  /// The day as `DateTime.weekday` numbers it (Monday is 1, Sunday is 7).
  final int weekday;
}

/// The region setting (a11-1b "Region formats"): the conventions for
/// numbers, dates, times, digits, paper size, units and the first day of
/// the week, independent of the UI language (ADR 0014, G34). With the
/// Türkiye region an English UI shows "13.10.2026", "14:32", "18.500,50"
/// and "10,5 pt"; `RegionFormat` (format.dart) does the formatting.
///
/// A region is an ISO 3166-1 alpha-2 [code] and the intl locale whose
/// conventions it uses ([formatLocale]), never the UI language. [all] lists
/// the regions the setting offers, one locale each. Their format locales
/// were checked against CLDR 48 (ICU 78.3 in Node.js 24.22.0): the numeric
/// date, the short time and decimal numbers match it for every region
/// except Mexico, whose "p.m." intl writes with a narrow no-break space
/// inside ("p. m."), and Iran, whose CLDR date uses the Persian calendar.
/// intl ignores CLDR's `minimumGroupingDigits`; `RegionFormat` applies it,
/// so Spain, Italy, Poland, Portugal and Hungary write "1500" as CLDR does.
///
/// The operating system's default ([Region.fromLocale]) keeps the OS
/// language where intl has a locale for that language in that country:
/// French in Canada formats with fr_CA ("14 h 32"), English in India with
/// en_IN. The six such locales (fr_CA, fr_CH, it_CH, en_IN, en_MY, es_US)
/// match CLDR 48 too, except fr_CH's digit grouping: a narrow no-break
/// space where CLDR 48 writes an apostrophe. Other combinations get the
/// listed locale; Chinese in Singapore gets en_SG, as intl has no zh_SG.
///
/// Paper size, length unit and first day of the week are the region's
/// defaults, taken from the CLDR territory data for [code]; the user can
/// change each of them on its own in a11-1b.
///
/// Digits follow the region: Saudi Arabia, Egypt and Iran use their native
/// digits (Arabic-Indic "١٠٫٥ pt" and "١٢/١٠/٢٠٢٦" as a12-1ar and a12-2a
/// draw them, Extended Arabic-Indic "۱۰٫۵ pt"), while the United Arab
/// Emirates uses Latin digits as CLDR's ar-AE does ("12/10/2026"; no board
/// draws it). Arabic dates carry U+200F RIGHT-TO-LEFT MARK after the day
/// and the month. Iran keeps the Gregorian calendar: intl has no Solar
/// Hijri calendar.
@immutable
final class Region {
  const new _(this.code, this.formatLocale);

  /// The region with the ISO 3166-1 alpha-2 [code] (any case).
  ///
  /// A code in [all] gives that region, unless intl has a locale for
  /// [languageCode] in that country other than the listed one: then the
  /// region formats with it (`forCode('CA', languageCode: 'fr')` with
  /// fr_CA). Any other code gives a region with the CLDR defaults of [code]
  /// for paper, units and week, and the formats of [languageCode] (the intl
  /// locale `<language>_<code>` when intl has it, else `<language>`, else
  /// en-US).
  factory forCode(String code, {String? languageCode}) {
    final upper = code.toUpperCase();
    final language = _normalizedLanguage(languageCode);
    final known = _byCode[upper];
    if (known == null) {
      return Region._(upper, _formatLocaleFor(language, upper));
    }
    final own = '${language}_$upper';
    return language != null &&
            own != known.formatLocale &&
            numberFormatSymbols.containsKey(own)
        ? Region._(upper, own)
        : known;
  }

  /// The default region for the operating system's [locale]
  /// (`PlatformDispatcher.locale`): its country when it has one, with the
  /// OS language's own intl locale for that country when intl has one
  /// (see [Region.forCode]); else the language's most likely country from
  /// CLDR likely subtags (`ar` → Egypt, `zh-Hant` → Taiwan); else
  /// [unitedStates], the region of the app's source language.
  factory fromLocale(Locale locale) {
    final country = locale.countryCode;
    final language = locale.languageCode.toLowerCase();
    if (country != null && country.isNotEmpty) {
      return Region.forCode(country, languageCode: language);
    }
    final script = locale.scriptCode;
    final likely =
        (script == null ? null : _likelyCountry['${language}_$script']) ??
        _likelyCountry[language];
    return likely == null ? unitedStates : Region.forCode(likely);
  }

  /// The regions the setting offers, sorted by [code].
  static const List<Region> all = [
    Region._('AE', 'ar'),
    Region._('AT', 'de_AT'),
    Region._('AU', 'en_AU'),
    Region._('BR', 'pt_BR'),
    Region._('CA', 'en_CA'),
    Region._('CH', 'de_CH'),
    Region._('CN', 'zh_CN'),
    Region._('CZ', 'cs'),
    Region._('DE', 'de'),
    Region._('DK', 'da'),
    Region._('EG', 'ar_EG'),
    Region._('ES', 'es_ES'),
    Region._('FI', 'fi'),
    Region._('FR', 'fr'),
    Region._('GB', 'en_GB'),
    Region._('GR', 'el'),
    Region._('HK', 'zh_HK'),
    Region._('HU', 'hu'),
    Region._('ID', 'id'),
    Region._('IE', 'en_IE'),
    Region._('IL', 'he'),
    Region._('IN', 'hi'),
    Region._('IR', 'fa'),
    Region._('IT', 'it'),
    Region._('JP', 'ja'),
    Region._('KR', 'ko'),
    Region._('MX', 'es_MX'),
    Region._('MY', 'ms'),
    Region._('NL', 'nl'),
    Region._('NO', 'nb'),
    Region._('NZ', 'en_NZ'),
    // intl has no en_PH; CLDR's en-PH date, time and numbers equal en-US.
    Region._('PH', 'en_US'),
    Region._('PL', 'pl'),
    Region._('PT', 'pt_PT'),
    Region._('RO', 'ro'),
    Region._('RU', 'ru'),
    // intl has no ar_SA; ar_EG has CLDR's ar-SA formats (Arabic-Indic
    // digits, the same patterns).
    Region._('SA', 'ar_EG'),
    Region._('SE', 'sv'),
    Region._('SG', 'en_SG'),
    turkiye,
    Region._('TW', 'zh_TW'),
    Region._('UA', 'uk'),
    unitedStates,
    Region._('VN', 'vi'),
    Region._('ZA', 'en_ZA'),
  ];

  /// Türkiye: "13.10.2026", "14:32", "18.500,50", "10,5 pt", A4, mm,
  /// Monday (the a11-1b examples).
  static const Region turkiye = Region._('TR', 'tr');

  /// The United States: "10/13/2026", "2:32 PM", "18,500.5", Letter,
  /// inches, Sunday.
  static const Region unitedStates = Region._('US', 'en_US');

  static final Map<String, Region> _byCode = {
    for (final region in all) region.code: region,
  };

  /// The ISO 3166-1 alpha-2 code, upper case ("TR").
  final String code;

  /// The intl locale that formats numbers and dates for this region
  /// ("tr", "en_US", "ar_EG").
  final String formatLocale;

  /// The default paper size: Letter where CLDR's `paperSize` says
  /// US-Letter, A4 everywhere else.
  PaperSize get defaultPaperSize =>
      _letterCountries.contains(code) ? PaperSize.letter : PaperSize.a4;

  /// The default length unit: inches where CLDR's `measurementSystem` is
  /// "US", millimetres everywhere else (CLDR's "UK" system, Britain and
  /// Myanmar, measures paper in millimetres too).
  LengthUnit get defaultLengthUnit =>
      _inchCountries.contains(code) ? LengthUnit.inch : LengthUnit.millimetre;

  /// The default first day of the week, from CLDR's `weekData`.
  FirstDayOfWeek get defaultFirstDayOfWeek {
    if (_sundayCountries.contains(code)) return FirstDayOfWeek.sunday;
    if (_saturdayCountries.contains(code)) return FirstDayOfWeek.saturday;
    if (_fridayCountries.contains(code)) return FirstDayOfWeek.friday;
    return FirstDayOfWeek.monday;
  }

  /// The digit zero of the region's digits: "0" (Latin), "٠" (Arabic-Indic)
  /// or "۰" (Extended Arabic-Indic, Persian), among others.
  String get zeroDigit => numberFormatSymbols[formatLocale]?.ZERO_DIGIT ?? '0';

  @override
  bool operator ==(Object other) =>
      other is Region &&
      other.code == code &&
      other.formatLocale == formatLocale;

  @override
  int get hashCode => Object.hash(code, formatLocale);

  @override
  String toString() => 'Region($code, $formatLocale)';
}

/// [languageCode] in lower case, with the legacy codes intl also knows
/// replaced by the current ones (Norwegian `no` by `nb`, whose formats it
/// shares), or null when there is none.
String? _normalizedLanguage(String? languageCode) {
  final language = languageCode?.toLowerCase();
  if (language == null || language.isEmpty) return null;
  return _legacyLanguages[language] ?? language;
}

const Map<String, String> _legacyLanguages = {
  'in': 'id',
  'iw': 'he',
  'no': 'nb',
};

/// The intl locale for a region outside [Region.all].
String _formatLocaleFor(String? language, String countryCode) {
  if (language == null) return 'en_US';
  for (final candidate in ['${language}_$countryCode', language]) {
    if (numberFormatSymbols.containsKey(candidate)) return candidate;
  }
  return 'en_US';
}

// dart format off
// CLDR territory data. The paper and measurement lists are CLDR 44.1's
// supplemental `measurementData`, read through ICU 74.2's
// ulocdata_getPaperSize and ulocdata_getMeasurementSystem; the week lists
// are CLDR 48's `weekData`, read through ICU 78.3 (Node.js 24.22.0,
// Intl.Locale.prototype.getWeekInfo). Unicode License v3.

/// `<paperSize type="US-Letter">`.
const Set<String> _letterCountries = {
  'BZ', 'CA', 'CL', 'CO', 'CR', 'GT', 'MX', 'NI', 'PA', 'PH', 'PR', 'SV',
  'US', 'VE',
};

/// `<measurementSystem type="US">`.
const Set<String> _inchCountries = {'LR', 'US'};

/// `<firstDay day="sun">`.
const Set<String> _sundayCountries = {
  'AG', 'AS', 'BD', 'BR', 'BS', 'BT', 'BW', 'BZ', 'CA', 'CO', 'DM', 'DO',
  'ET', 'GT', 'GU', 'HK', 'HN', 'ID', 'IL', 'IN', 'IS', 'JM', 'JP', 'KE',
  'KH', 'KR', 'LA', 'MH', 'MM', 'MO', 'MT', 'MX', 'MZ', 'NI', 'NP', 'PA',
  'PE', 'PH', 'PK', 'PR', 'PT', 'PY', 'SA', 'SG', 'SV', 'TH', 'TT', 'TW',
  'UM', 'US', 'VE', 'VI', 'WS', 'YE', 'ZA', 'ZW',
};

/// `<firstDay day="sat">`.
const Set<String> _saturdayCountries = {
  'AF', 'BH', 'DJ', 'DZ', 'EG', 'IQ', 'IR', 'JO', 'KW', 'LY', 'OM', 'QA',
  'SD', 'SY',
};

/// `<firstDay day="fri">`.
const Set<String> _fridayCountries = {'MV'};
// dart format on

/// The country of CLDR's likely subtags for each language with a region in
/// [Region.all] (Node.js 24.22.0, `Intl.Locale.prototype.maximize`).
const Map<String, String> _likelyCountry = {
  'ar': 'EG',
  'cs': 'CZ',
  'da': 'DK',
  'de': 'DE',
  'el': 'GR',
  'en': 'US',
  'es': 'ES',
  'fa': 'IR',
  'fi': 'FI',
  'fr': 'FR',
  'he': 'IL',
  'hi': 'IN',
  'hu': 'HU',
  'id': 'ID',
  'in': 'ID',
  'it': 'IT',
  'iw': 'IL',
  'ja': 'JP',
  'ko': 'KR',
  'ms': 'MY',
  'nb': 'NO',
  'nl': 'NL',
  'no': 'NO',
  'pl': 'PL',
  'pt': 'BR',
  'ro': 'RO',
  'ru': 'RU',
  'sv': 'SE',
  'tr': 'TR',
  'uk': 'UA',
  'vi': 'VN',
  'zh': 'CN',
  'zh_Hans': 'CN',
  'zh_Hant': 'TW',
};
