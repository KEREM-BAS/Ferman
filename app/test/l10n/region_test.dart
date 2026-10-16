import 'dart:ui' show Locale;

import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';

/// The first day of the week of every region in [Region.all], as CLDR 48
/// gives it (ICU 78.3 in Node.js 24.22.0, `getWeekInfo`). Monday is 1 and
/// Sunday is 7, as `DateTime.weekday` and `getWeekInfo().firstDay` both
/// number them.
// dart format off
const Map<String, int> _cldr48FirstDay = {
  'AE': 1, 'AT': 1, 'AU': 1, 'BR': 7, 'CA': 7, 'CH': 1, 'CN': 1, 'CZ': 1,
  'DE': 1, 'DK': 1, 'EG': 6, 'ES': 1, 'FI': 1, 'FR': 1, 'GB': 1, 'GR': 1,
  'HK': 7, 'HU': 1, 'ID': 7, 'IE': 1, 'IL': 7, 'IN': 7, 'IR': 6, 'IT': 1,
  'JP': 7, 'KR': 7, 'MX': 7, 'MY': 1, 'NL': 1, 'NO': 1, 'NZ': 1, 'PH': 7,
  'PL': 1, 'PT': 7, 'RO': 1, 'RU': 1, 'SA': 7, 'SE': 1, 'SG': 7, 'TR': 1,
  'TW': 7, 'UA': 1, 'US': 7, 'VN': 1, 'ZA': 7,
};
// dart format on

void main() {
  setUpAll(initializeRegionFormats);

  group('Region.all', () {
    test('is sorted by code, with unique upper-case codes', () {
      final codes = [for (final region in Region.all) region.code];
      expect(codes, [...codes]..sort());
      expect(codes.toSet(), hasLength(codes.length));
      for (final code in codes) {
        expect(code, matches(RegExp(r'^[A-Z]{2}$')));
      }
    });

    test('covers the countries of the UI languages and the a11-1b list', () {
      final codes = {for (final region in Region.all) region.code};
      // a11-1b offers Türkiye, Germany and the United States; ADR 0014
      // tests Saudi Arabia and Iran; the rest are the main countries of
      // the 21 UI languages.
      expect(
        codes,
        containsAll(<String>[
          'TR',
          'DE',
          'US',
          'SA',
          'IR',
          'FR',
          'ES',
          'BR',
          'IT',
          'NL',
          'PL',
          'RU',
          'UA',
          'IL',
          'IN',
          'JP',
          'KR',
          'CN',
          'TW',
          'ID',
          'VN',
        ]),
      );
    });

    test('formats with locales that intl has', () {
      for (final region in Region.all) {
        expect(
          numberFormatSymbols.containsKey(region.formatLocale),
          isTrue,
          reason: '$region',
        );
        expect(
          DateFormat.localeExists(region.formatLocale),
          isTrue,
          reason: '$region',
        );
      }
    });

    test('first days of the week match CLDR 48', () {
      expect(_cldr48FirstDay.keys, [for (final r in Region.all) r.code]);
      for (final region in Region.all) {
        expect(
          region.defaultFirstDayOfWeek.weekday,
          _cldr48FirstDay[region.code],
          reason: '$region',
        );
      }
    });
  });

  group('defaults from CLDR territory data', () {
    test('Letter paper in the US-Letter countries, A4 elsewhere', () {
      const letter = [
        'BZ', 'CA', 'CL', 'CO', 'CR', 'GT', 'MX', 'NI', 'PA', 'PH', 'PR', //
        'SV', 'US', 'VE',
      ];
      for (final code in letter) {
        expect(
          Region.forCode(code).defaultPaperSize,
          PaperSize.letter,
          reason: code,
        );
      }
      for (final code in ['TR', 'DE', 'SA', 'IR', 'GB', 'JP', 'AE', 'BR']) {
        expect(Region.forCode(code).defaultPaperSize, PaperSize.a4);
      }
    });

    test('inches in the US measurement system, millimetres elsewhere', () {
      expect(Region.unitedStates.defaultLengthUnit, LengthUnit.inch);
      expect(Region.forCode('LR').defaultLengthUnit, LengthUnit.inch);
      for (final code in ['TR', 'GB', 'CA', 'MX', 'PH', 'MM', 'SA']) {
        expect(
          Region.forCode(code).defaultLengthUnit,
          LengthUnit.millimetre,
          reason: code,
        );
      }
    });

    test('first day of the week', () {
      expect(Region.turkiye.defaultFirstDayOfWeek, FirstDayOfWeek.monday);
      expect(Region.unitedStates.defaultFirstDayOfWeek, FirstDayOfWeek.sunday);
      expect(
        Region.forCode('EG').defaultFirstDayOfWeek,
        FirstDayOfWeek.saturday,
      );
      expect(Region.forCode('MV').defaultFirstDayOfWeek, FirstDayOfWeek.friday);
      expect(Region.forCode('KE').defaultFirstDayOfWeek, FirstDayOfWeek.sunday);
    });

    test('digits follow the region', () {
      expect(Region.turkiye.zeroDigit, '0');
      expect(Region.unitedStates.zeroDigit, '0');
      expect(Region.forCode('AE').zeroDigit, '0');
      expect(Region.forCode('SA').zeroDigit, '٠');
      expect(Region.forCode('EG').zeroDigit, '٠');
      expect(Region.forCode('IR').zeroDigit, '۰');
    });
  });

  group('Region.forCode', () {
    test('returns the listed region in any case', () {
      expect(Region.forCode('TR'), same(Region.turkiye));
      expect(Region.forCode('tr'), same(Region.turkiye));
      expect(Region.forCode('us'), same(Region.unitedStates));
    });

    test('builds an unlisted region from its language', () {
      final chile = Region.forCode('CL', languageCode: 'es');
      expect(chile.code, 'CL');
      expect(chile.formatLocale, 'es');
      expect(chile.defaultPaperSize, PaperSize.letter);
      expect(Region.forCode('BE', languageCode: 'fr').formatLocale, 'fr');
      expect(Region.forCode('LU', languageCode: 'de').formatLocale, 'de');
      expect(Region.forCode('KE', languageCode: 'en').formatLocale, 'en');
      expect(Region.forCode('ZZ').formatLocale, 'en_US');
      expect(Region.forCode('ZZ', languageCode: 'xx').formatLocale, 'en_US');
      // Legacy language codes.
      expect(Region.forCode('SJ', languageCode: 'no').formatLocale, 'nb');
      expect(Region.forCode('BN', languageCode: 'in').formatLocale, 'id');
    });

    test("formats a listed country with the language's own intl locale", () {
      final frenchCanada = Region.forCode('CA', languageCode: 'fr');
      expect(frenchCanada.code, 'CA');
      expect(frenchCanada.formatLocale, 'fr_CA');
      expect(frenchCanada, isNot(Region.forCode('CA')));
      // The territory defaults still come from the country.
      expect(frenchCanada.defaultPaperSize, PaperSize.letter);
      expect(frenchCanada.defaultFirstDayOfWeek, FirstDayOfWeek.sunday);
      expect(Region.forCode('ch', languageCode: 'IT').formatLocale, 'it_CH');
      expect(Region.forCode('IN', languageCode: 'en').formatLocale, 'en_IN');
    });

    test('keeps the listed locale for its own language or without one', () {
      expect(Region.forCode('CA'), same(Region.forCode('CA')));
      expect(Region.forCode('CA').formatLocale, 'en_CA');
      expect(Region.forCode('CA', languageCode: 'en').formatLocale, 'en_CA');
      expect(Region.forCode('TR', languageCode: 'tr'), same(Region.turkiye));
      expect(Region.forCode('TR', languageCode: 'en'), same(Region.turkiye));
      expect(Region.forCode('NO', languageCode: 'no'), Region.forCode('NO'));
      // intl has no ar_SA, zh_SG or ta_IN.
      expect(Region.forCode('SA', languageCode: 'ar').formatLocale, 'ar_EG');
      expect(Region.forCode('SG', languageCode: 'zh').formatLocale, 'en_SG');
      expect(Region.forCode('IN', languageCode: 'ta').formatLocale, 'hi');
      expect(Region.forCode('DE', languageCode: '').formatLocale, 'de');
    });

    test('compares by code and format locale', () {
      expect(
        Region.forCode('CL', languageCode: 'es'),
        Region.forCode('cl', languageCode: 'ES'),
      );
      expect(
        Region.forCode('CL', languageCode: 'es').hashCode,
        Region.forCode('CL', languageCode: 'es').hashCode,
      );
      expect(
        Region.forCode('CL', languageCode: 'es'),
        isNot(Region.forCode('CL', languageCode: 'en')),
      );
      expect('${Region.turkiye}', 'Region(TR, tr)');
    });
  });

  group('Region.fromLocale', () {
    test('takes the country of the OS locale', () {
      expect(Region.fromLocale(const Locale('tr', 'TR')), Region.turkiye);
      expect(Region.fromLocale(const Locale('en', 'TR')), Region.turkiye);
      expect(Region.fromLocale(const Locale('en', 'US')), Region.unitedStates);
      expect(Region.fromLocale(const Locale('de', 'DE')).formatLocale, 'de');
      expect(Region.fromLocale(const Locale('ar', 'SA')).zeroDigit, '٠');
      final chile = Region.fromLocale(const Locale('es', 'CL'));
      expect(chile, Region.forCode('CL', languageCode: 'es'));
    });

    test('keeps the OS language where intl has it for that country', () {
      expect(Region.fromLocale(const Locale('fr', 'CA')).formatLocale, 'fr_CA');
      expect(Region.fromLocale(const Locale('fr', 'CH')).formatLocale, 'fr_CH');
      expect(Region.fromLocale(const Locale('en', 'IN')).formatLocale, 'en_IN');
      expect(Region.fromLocale(const Locale('en', 'MY')).formatLocale, 'en_MY');
      expect(Region.fromLocale(const Locale('es', 'US')).formatLocale, 'es_US');
      expect(Region.fromLocale(const Locale('zh', 'SG')).formatLocale, 'en_SG');
    });

    test('takes the likely country of a language without a country', () {
      expect(Region.fromLocale(const Locale('tr')), Region.turkiye);
      expect(Region.fromLocale(const Locale('en')), Region.unitedStates);
      expect(Region.fromLocale(const Locale('ar')).code, 'EG');
      expect(Region.fromLocale(const Locale('fa')).code, 'IR');
      expect(Region.fromLocale(const Locale('he')).code, 'IL');
      expect(Region.fromLocale(const Locale('pt')).code, 'BR');
      expect(Region.fromLocale(const Locale('zh')).code, 'CN');
      expect(
        Region.fromLocale(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ).code,
        'TW',
      );
    });

    test('falls back to the United States', () {
      expect(Region.fromLocale(const Locale('sw')), Region.unitedStates);
      expect(Region.fromLocale(const Locale('und')), Region.unitedStates);
    });
  });

  group('units and paper', () {
    test('convert from PDF points', () {
      expect(LengthUnit.inch.fromPoints(72), 1);
      expect(LengthUnit.point.fromPoints(72), 72);
      expect(LengthUnit.millimetre.fromPoints(72), closeTo(25.4, 1e-9));
      expect(LengthUnit.centimetre.fromPoints(72), closeTo(2.54, 1e-9));
      expect(
        LengthUnit.millimetre.fromPoints(PaperSize.a4.widthPoints),
        closeTo(210, 1e-9),
      );
      expect(PaperSize.letter.widthPoints, 612);
      expect(PaperSize.letter.heightPoints, 792);
    });

    test('symbols are lowercase', () {
      expect(
        [for (final unit in LengthUnit.values) unit.symbol],
        ['mm', 'cm', 'in', 'pt'],
      );
    });
  });
}
