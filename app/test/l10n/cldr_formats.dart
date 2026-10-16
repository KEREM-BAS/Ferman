import 'dart:ui' show Locale;

import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter_test/flutter_test.dart';

/// What [RegionFormat] writes for 2 October 2026, 14:32: the numeric date,
/// the short time, 18500.5, 1500 and the date with the time.
typedef CldrFormats = ({
  String date,
  String time,
  String number,
  String fourDigits,
  String dateTime,
});

/// The formats of every region in [Region.all], keyed by its code, in its
/// order.
///
/// They equal CLDR 48 (ICU 78.3 in Node.js 24.22.0, `formatToParts`, which
/// keeps the U+202F that `format` turns into a space) except:
/// - Mexico: intl writes "p.\u202Fm.", CLDR 48 "p.m.".
/// - Iran: CLDR 48's fa-IR uses the Persian calendar; the date equals its
///   `-u-ca-gregory` form, the date-time glue does not.
/// - The date-time glue of Brazil, Denmark and Indonesia (CLDR 48 adds a
///   comma) and Finland (CLDR 48 adds "klo"): intl's data is older.
const Map<String, CldrFormats> cldrFormats = {
  'AE': (
    date: '2\u200F/10\u200F/2026',
    time: '2:32 م',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2\u200F/10\u200F/2026، 2:32 م',
  ),
  'AT': (
    date: '2.10.2026',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '2.10.2026, 14:32',
  ),
  'AU': (
    date: '02/10/2026',
    time: '2:32\u202Fpm',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '02/10/2026, 2:32\u202Fpm',
  ),
  'BR': (
    date: '02/10/2026',
    time: '14:32',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '02/10/2026 14:32',
  ),
  'CA': (
    date: '2026-10-02',
    time: '2:32\u202Fp.m.',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2026-10-02, 2:32\u202Fp.m.',
  ),
  'CH': (
    date: '2.10.2026',
    time: '14:32',
    number: "18'500.5",
    fourDigits: "1'500",
    dateTime: '2.10.2026, 14:32',
  ),
  'CN': (
    date: '2026/10/2',
    time: '14:32',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2026/10/2 14:32',
  ),
  'CZ': (
    date: '2. 10. 2026',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '2. 10. 2026 14:32',
  ),
  'DE': (
    date: '2.10.2026',
    time: '14:32',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '2.10.2026, 14:32',
  ),
  'DK': (
    date: '2.10.2026',
    time: '14.32',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '2.10.2026 14.32',
  ),
  'EG': (
    date: '٢\u200F/١٠\u200F/٢٠٢٦',
    time: '٢:٣٢ م',
    number: '١٨٬٥٠٠٫٥',
    fourDigits: '١٬٥٠٠',
    dateTime: '٢\u200F/١٠\u200F/٢٠٢٦، ٢:٣٢ م',
  ),
  'ES': (
    date: '2/10/2026',
    time: '14:32',
    number: '18.500,5',
    fourDigits: '1500',
    dateTime: '2/10/2026, 14:32',
  ),
  'FI': (
    date: '2.10.2026',
    time: '14.32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '2.10.2026 14.32',
  ),
  'FR': (
    date: '02/10/2026',
    time: '14:32',
    number: '18\u202F500,5',
    fourDigits: '1\u202F500',
    dateTime: '02/10/2026 14:32',
  ),
  'GB': (
    date: '02/10/2026',
    time: '14:32',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '02/10/2026, 14:32',
  ),
  'GR': (
    date: '2/10/2026',
    time: '2:32\u202Fμ.μ.',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '2/10/2026, 2:32\u202Fμ.μ.',
  ),
  'HK': (
    date: '2/10/2026',
    time: '下午2:32',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2/10/2026\u2009下午2:32',
  ),
  'HU': (
    date: '2026. 10. 02.',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1500',
    dateTime: '2026. 10. 02. 14:32',
  ),
  'ID': (
    date: '2/10/2026',
    time: '14.32',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '2/10/2026 14.32',
  ),
  'IE': (
    date: '2/10/2026',
    time: '14:32',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2/10/2026, 14:32',
  ),
  'IL': (
    date: '2.10.2026',
    time: '14:32',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2.10.2026, 14:32',
  ),
  'IN': (
    date: '2/10/2026',
    time: '2:32 pm',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2/10/2026, 2:32 pm',
  ),
  'IR': (
    date: '۲۰۲۶/۱۰/۲',
    time: '۱۴:۳۲',
    number: '۱۸٬۵۰۰٫۵',
    fourDigits: '۱٬۵۰۰',
    dateTime: '۲۰۲۶/۱۰/۲،\u200F ۱۴:۳۲',
  ),
  'IT': (
    date: '02/10/2026',
    time: '14:32',
    number: '18.500,5',
    fourDigits: '1500',
    dateTime: '02/10/2026, 14:32',
  ),
  'JP': (
    date: '2026/10/2',
    time: '14:32',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2026/10/2 14:32',
  ),
  'KR': (
    date: '2026. 10. 2.',
    time: '오후 2:32',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2026. 10. 2. 오후 2:32',
  ),
  'MX': (
    date: '2/10/2026',
    time: '2:32\u202Fp.\u202Fm.',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2/10/2026, 2:32\u202Fp.\u202Fm.',
  ),
  'MY': (
    date: '2/10/2026',
    time: '2:32\u202FPTG',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2/10/2026, 2:32\u202FPTG',
  ),
  'NL': (
    date: '2-10-2026',
    time: '14:32',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '2-10-2026, 14:32',
  ),
  'NO': (
    date: '2.10.2026',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '2.10.2026, 14:32',
  ),
  'NZ': (
    date: '2/10/2026',
    time: '2:32\u202Fpm',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2/10/2026, 2:32\u202Fpm',
  ),
  'PH': (
    date: '10/2/2026',
    time: '2:32\u202FPM',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '10/2/2026, 2:32\u202FPM',
  ),
  'PL': (
    date: '2.10.2026',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1500',
    dateTime: '2.10.2026, 14:32',
  ),
  'PT': (
    date: '02/10/2026',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1500',
    dateTime: '02/10/2026, 14:32',
  ),
  'RO': (
    date: '02.10.2026',
    time: '14:32',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '02.10.2026, 14:32',
  ),
  'RU': (
    date: '02.10.2026',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '02.10.2026, 14:32',
  ),
  'SA': (
    date: '٢\u200F/١٠\u200F/٢٠٢٦',
    time: '٢:٣٢ م',
    number: '١٨٬٥٠٠٫٥',
    fourDigits: '١٬٥٠٠',
    dateTime: '٢\u200F/١٠\u200F/٢٠٢٦، ٢:٣٢ م',
  ),
  'SE': (
    date: '2026-10-02',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '2026-10-02 14:32',
  ),
  'SG': (
    date: '02/10/2026',
    time: '2:32\u202Fpm',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '02/10/2026, 2:32\u202Fpm',
  ),
  'TR': (
    date: '02.10.2026',
    time: '14:32',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '02.10.2026 14:32',
  ),
  'TW': (
    date: '2026/10/2',
    time: '下午2:32',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2026/10/2\u2009下午2:32',
  ),
  'UA': (
    date: '02.10.2026',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '02.10.2026, 14:32',
  ),
  'US': (
    date: '10/2/2026',
    time: '2:32\u202FPM',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '10/2/2026, 2:32\u202FPM',
  ),
  'VN': (
    date: '2/10/2026',
    time: '14:32',
    number: '18.500,5',
    fourDigits: '1.500',
    dateTime: '14:32 2/10/2026',
  ),
  'ZA': (
    date: '2026/10/02',
    time: '14:32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '2026/10/02, 14:32',
  ),
};

/// The formats of the OS locales that keep their own intl locale in a
/// listed country ([Region.fromLocale]), keyed by that locale. They equal
/// CLDR 48 except fr_CH's grouping, a narrow no-break space where CLDR 48
/// writes an apostrophe.
const Map<String, CldrFormats> cldrOwnLanguageFormats = {
  'fr_CA': (
    date: '2026-10-02',
    time: '14 h 32',
    number: '18\u00A0500,5',
    fourDigits: '1\u00A0500',
    dateTime: '2026-10-02 14 h 32',
  ),
  'fr_CH': (
    date: '02.10.2026',
    time: '14:32',
    number: '18\u202F500,5',
    fourDigits: '1\u202F500',
    dateTime: '02.10.2026 14:32',
  ),
  'it_CH': (
    date: '02/10/2026',
    time: '14:32',
    number: "18'500.5",
    fourDigits: '1500',
    dateTime: '02/10/2026, 14:32',
  ),
  'en_IN': (
    date: '2/10/2026',
    time: '2:32\u202Fpm',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2/10/2026, 2:32\u202Fpm',
  ),
  'en_MY': (
    date: '02/10/2026',
    time: '2:32\u202Fpm',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '02/10/2026, 2:32\u202Fpm',
  ),
  'es_US': (
    date: '2/10/2026',
    time: '2:32\u202Fp.m.',
    number: '18,500.5',
    fourDigits: '1,500',
    dateTime: '2/10/2026, 2:32\u202Fp.m.',
  ),
};

/// Expects [RegionFormat] to write [cldrFormats] for every region in
/// [Region.all] and [cldrOwnLanguageFormats] for the OS locales they name.
void expectCldrFormats() {
  expect(cldrFormats.keys, [for (final region in Region.all) region.code]);
  for (final region in Region.all) {
    _expectFormats(region, cldrFormats[region.code]!);
  }
  for (final MapEntry(key: locale, value: formats)
      in cldrOwnLanguageFormats.entries) {
    final [language, country] = locale.split('_');
    final region = Region.fromLocale(Locale(language, country));
    expect(region.formatLocale, locale);
    _expectFormats(region, formats);
  }
}

void _expectFormats(Region region, CldrFormats expected) {
  final value = DateTime(2026, 10, 2, 14, 32);
  final format = RegionFormat.forRegion(region);
  final reason = '$region';
  expect(format.date(value), expected.date, reason: reason);
  expect(format.time(value), expected.time, reason: reason);
  expect(format.decimal(18500.5), expected.number, reason: reason);
  expect(format.integer(1500), expected.fourDigits, reason: reason);
  expect(format.dateTime(value), expected.dateTime, reason: reason);
}
