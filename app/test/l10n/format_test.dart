import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'cldr_formats.dart';

/// U+00A0 NO-BREAK SPACE, between a number and its unit.
const String _nbsp = '\u00A0';

/// U+200F RIGHT-TO-LEFT MARK, inside CLDR's Arabic dates.
const String _rlm = '\u200F';

void main() {
  final october13 = DateTime(2026, 10, 13, 14, 32);
  final october12 = DateTime(2026, 10, 12, 9, 5);
  final turkiye = RegionFormat.forRegion(Region.turkiye);
  final unitedStates = RegionFormat.forRegion(Region.unitedStates);
  final germany = RegionFormat.forRegion(Region.forCode('DE'));
  final emirates = RegionFormat.forRegion(Region.forCode('AE'));
  final saudiArabia = RegionFormat.forRegion(Region.forCode('SA'));
  final iran = RegionFormat.forRegion(Region.forCode('IR'));

  group('ROADMAP §5 step 10 and a11-1b', () {
    test('an English UI with the Türkiye region gets Turkish formats', () {
      // The UI language is English; the region decides the formats.
      Intl.withLocale('en_US', () {
        final f = RegionFormat.forRegion(Region.turkiye);
        expect(
          '${f.date(october13)} · ${f.time(october13)}',
          '13.10.2026 · 14:32',
        );
        expect(f.pointSize(10.5), '10,5${_nbsp}pt');
        // The four examples of a11-1b: date, time, number, font size.
        expect(f.date(october13), '13.10.2026');
        expect(f.time(october13), '14:32');
        expect(f.decimal(18500.5, minFractionDigits: 2), '18.500,50');
        expect(f.pointSize(10.5), '10,5${_nbsp}pt');
      });
    });

    test('the same values with the United States region', () {
      Intl.withLocale('tr', () {
        final f = RegionFormat.forRegion(Region.unitedStates);
        expect(f.date(october13), '10/13/2026');
        expect(f.time(october13), '2:32\u202FPM');
        expect(f.decimal(18500.5, minFractionDigits: 2), '18,500.50');
        expect(f.pointSize(10.5), '10.5${_nbsp}pt');
      });
    });
  });

  group('every listed region', () {
    // Without flutter_localizations: intl's own date data only. The two
    // load orders of the app are format_init_test.dart and
    // format_bootstrap_order_test.dart.
    test('formats dates, times and numbers as CLDR does', expectCldrFormats);
  });

  group('Türkiye', () {
    test('numbers', () {
      expect(turkiye.integer(18500), '18.500');
      expect(turkiye.integer(-1200000), '-1.200.000');
      expect(turkiye.decimal(18500.5), '18.500,5');
      expect(turkiye.decimal(0.125, maxFractionDigits: 3), '0,125');
      expect(turkiye.decimal(2.0), '2');
    });

    test('dates and times', () {
      expect(turkiye.date(october12), '12.10.2026');
      expect(turkiye.time(october12), '09:05');
      expect(turkiye.dateTime(october13), '13.10.2026 14:32');
    });

    test('font sizes have at most one decimal', () {
      expect(turkiye.pointSize(11), '11${_nbsp}pt');
      expect(turkiye.pointSize(10.5), '10,5${_nbsp}pt');
      expect(turkiye.pointSize(9.96), '10${_nbsp}pt');
      expect(turkiye.pointSize(10.25), '10,3${_nbsp}pt');
    });
  });

  group('United States', () {
    test('numbers, dates and times', () {
      expect(unitedStates.integer(18500), '18,500');
      expect(unitedStates.decimal(18500.5), '18,500.5');
      expect(unitedStates.date(october12), '10/12/2026');
      expect(unitedStates.time(october12), '9:05\u202FAM');
      expect(unitedStates.dateTime(october13), '10/13/2026, 2:32\u202FPM');
    });
  });

  group('Germany', () {
    test('numbers, dates and times', () {
      expect(germany.decimal(18500.5, minFractionDigits: 2), '18.500,50');
      expect(germany.date(october13), '13.10.2026');
      expect(germany.date(DateTime(2026, 10, 2)), '2.10.2026');
      expect(germany.time(october13), '14:32');
      expect(germany.dateTime(october13), '13.10.2026, 14:32');
      expect(germany.pointSize(10.5), '10,5${_nbsp}pt');
    });
  });

  group('Arabic regions', () {
    test('the United Arab Emirates uses Latin digits, as CLDR ar-AE does', () {
      expect(emirates.date(october12), '12$_rlm/10$_rlm/2026');
      expect(emirates.time(october13), '2:32 م');
      expect(emirates.decimal(18500.5), '18,500.5');
      expect(emirates.pointSize(10.5), '10.5${_nbsp}pt');
      expect(emirates.dateTime(october13), '13$_rlm/10$_rlm/2026، 2:32 م');
    });

    test('Saudi Arabia uses Arabic-Indic digits, as a12-1ar and a12-2a '
        'draw', () {
      expect(saudiArabia.date(october13), '١٣$_rlm/١٠$_rlm/٢٠٢٦');
      expect(saudiArabia.date(october12), '١٢$_rlm/١٠$_rlm/٢٠٢٦'); // a12-2a
      expect(saudiArabia.time(october13), '٢:٣٢ م');
      expect(saudiArabia.integer(18500), '١٨٬٥٠٠');
      expect(saudiArabia.decimal(18500.5), '١٨٬٥٠٠٫٥');
      // a12-1ar: "IBM Plex Serif · ١٠٫٥ pt".
      expect(saudiArabia.pointSize(10.5), '١٠٫٥${_nbsp}pt');
      expect(saudiArabia.fileSize(24600000), '٢٤٫٦${_nbsp}MB');
      expect(
        saudiArabia.paperSize(PaperSize.a4, LengthUnit.millimetre),
        '٢١٠$_nbsp×$_nbsp٢٩٧${_nbsp}mm',
      );
    });
  });

  group('Iran', () {
    test('Persian digits and separators, Gregorian calendar', () {
      expect(iran.date(october13), '۲۰۲۶/۱۰/۱۳');
      expect(iran.time(october13), '۱۴:۳۲');
      expect(iran.decimal(18500.5), '۱۸٬۵۰۰٫۵');
      expect(iran.pointSize(10.5), '۱۰٫۵${_nbsp}pt');
      expect(iran.dateTime(october13), '۲۰۲۶/۱۰/۱۳،\u200F ۱۴:۳۲');
    });
  });

  group('four-digit numbers', () {
    final spain = RegionFormat.forRegion(Region.forCode('ES'));
    final poland = RegionFormat.forRegion(Region.forCode('PL'));

    test('stay ungrouped where CLDR groups from five digits', () {
      expect(spain.integer(1500), '1500');
      expect(spain.integer(-9999), '-9999');
      expect(spain.integer(15000), '15.000');
      expect(spain.decimal(1500.5), '1500,5');
      expect(spain.decimal(1500, minFractionDigits: 2), '1500,00');
      expect(poland.integer(1500), '1500');
      expect(poland.integer(1234567), '1${_nbsp}234${_nbsp}567');
      expect(
        RegionFormat.forRegion(Region.forCode('IT')).integer(1500),
        '1500',
      );
    });

    test('are counted after rounding', () {
      expect(spain.decimal(9999.4, maxFractionDigits: 0), '9999');
      expect(spain.decimal(9999.96, maxFractionDigits: 1), '10.000');
      expect(spain.fileSize(1500000000000000), '1500${_nbsp}TB');
      expect(turkiye.fileSize(1500000000000000), '1.500${_nbsp}TB');
    });

    test('are grouped everywhere else', () {
      expect(turkiye.integer(1500), '1.500');
      expect(unitedStates.integer(1500), '1,500');
      expect(
        RegionFormat.forRegion(Region.forCode('MX')).integer(1500),
        '1,500',
      );
      expect(saudiArabia.integer(1500), '١٬٥٠٠');
    });
  });

  group('date-time patterns', () {
    test('Chinese dates and times are joined by a thin space, as CLDR 48 '
        'does', () {
      final taiwan = RegionFormat.forRegion(Region.forCode('TW'));
      final hongKong = RegionFormat.forRegion(Region.forCode('HK'));
      expect(taiwan.dateTime(october13), '2026/10/13\u2009下午2:32');
      expect(hongKong.dateTime(october13), '13/10/2026\u2009下午2:32');
    });
  });

  group('file sizes', () {
    test('decimal units, whole bytes and kilobytes', () {
      expect(turkiye.fileSize(0), '0${_nbsp}B');
      expect(turkiye.fileSize(999), '999${_nbsp}B');
      expect(turkiye.fileSize(1000), '1${_nbsp}KB');
      expect(turkiye.fileSize(18400), '18${_nbsp}KB');
      expect(turkiye.fileSize(284000), '284${_nbsp}KB');
      expect(turkiye.fileSize(999499), '999${_nbsp}KB');
    });

    test('one decimal from megabytes up, as the design shows', () {
      expect(turkiye.fileSize(24600000), '24,6${_nbsp}MB');
      expect(turkiye.fileSize(6849999), '6,8${_nbsp}MB');
      expect(turkiye.fileSize(12000000), '12${_nbsp}MB');
      expect(turkiye.fileSize(4100000000), '4,1${_nbsp}GB');
      expect(unitedStates.fileSize(24600000), '24.6${_nbsp}MB');
    });

    test('a value that rounds to 1000 moves to the next unit', () {
      expect(turkiye.fileSize(999500), '1${_nbsp}MB');
      expect(turkiye.fileSize(999960000), '1${_nbsp}GB');
      expect(turkiye.fileSize(5000000000000), '5${_nbsp}TB');
      expect(turkiye.fileSize(2000000000000000), '2.000${_nbsp}TB');
    });

    test('negative sizes keep their sign', () {
      expect(turkiye.fileSize(-400), '-400${_nbsp}B');
      expect(turkiye.fileSize(-1500000), '-1,5${_nbsp}MB');
    });
  });

  group('lengths', () {
    const mm = LengthUnit.millimetre;

    test('in each unit, from PDF points', () {
      expect(turkiye.length(158.7 * mm.pointsPerUnit, mm), '158,7${_nbsp}mm');
      expect(
        turkiye.length(
          7.5 * LengthUnit.centimetre.pointsPerUnit,
          LengthUnit.centimetre,
        ),
        '7,5${_nbsp}cm',
      );
      expect(unitedStates.length(36, LengthUnit.inch), '0.5${_nbsp}in');
      expect(unitedStates.length(72, LengthUnit.inch), '1${_nbsp}in');
      expect(turkiye.length(44, LengthUnit.point), '44${_nbsp}pt');
    });

    test('with more decimals on request', () {
      expect(
        turkiye.length(0.125, LengthUnit.point, maxFractionDigits: 3),
        '0,125${_nbsp}pt',
      );
      expect(
        turkiye.length(0.25, LengthUnit.point, maxFractionDigits: 3),
        '0,25${_nbsp}pt',
      );
    });

    test('dimensions joined by a multiplication sign', () {
      expect(
        turkiye.dimensions(28 * mm.pointsPerUnit, 35 * mm.pointsPerUnit, mm),
        '28$_nbsp×${_nbsp}35${_nbsp}mm',
      );
    });
  });

  group('paper sizes', () {
    test('A4 and Letter in every unit', () {
      String size(RegionFormat f, PaperSize paper, LengthUnit unit) =>
          f.paperSize(paper, unit).replaceAll(_nbsp, ' ');
      expect(
        size(turkiye, PaperSize.a4, LengthUnit.millimetre),
        '210 × 297 mm',
      );
      expect(
        size(turkiye, PaperSize.letter, LengthUnit.millimetre),
        '216 × 279 mm',
      );
      expect(
        size(turkiye, PaperSize.a4, LengthUnit.centimetre),
        '21 × 29,7 cm',
      );
      expect(size(turkiye, PaperSize.a4, LengthUnit.point), '595 × 842 pt');
      expect(
        size(unitedStates, PaperSize.letter, LengthUnit.inch),
        '8.5 × 11 in',
      );
      expect(
        size(unitedStates, PaperSize.a4, LengthUnit.inch),
        '8.27 × 11.69 in',
      );
      expect(
        size(unitedStates, PaperSize.letter, LengthUnit.point),
        '612 × 792 pt',
      );
    });

    test('the region default paper in the region default unit', () {
      for (final (region, expected) in [
        (Region.turkiye, '210 × 297 mm'),
        (Region.unitedStates, '8.5 × 11 in'),
        (Region.forCode('CA'), '216 × 279 mm'),
        (Region.forCode('DE'), '210 × 297 mm'),
      ]) {
        final f = RegionFormat.forRegion(region);
        expect(
          f
              .paperSize(region.defaultPaperSize, region.defaultLengthUnit)
              .replaceAll(_nbsp, ' '),
          expected,
          reason: '$region',
        );
      }
    });
  });

  group('bidiIsolate', () {
    test('wraps a value in first-strong and pop isolates', () {
      expect(bidiIsolate('10,5 pt'), '\u206810,5 pt\u2069');
      expect(bidiIsolate(''), '\u2068\u2069');
    });
  });

  group('RegionFormat.forRegion', () {
    test('caches one formatter per region', () {
      expect(RegionFormat.forRegion(Region.turkiye), same(turkiye));
      expect(
        RegionFormat.forRegion(Region.forCode('CL', languageCode: 'es')),
        same(RegionFormat.forRegion(Region.forCode('CL', languageCode: 'es'))),
      );
    });

    test('formats an unlisted region with its language', () {
      final chile = RegionFormat.forRegion(
        Region.forCode('CL', languageCode: 'es'),
      );
      expect(chile.decimal(18500.5), '18.500,5');
      expect(chile.date(october13), '13/10/2026');
    });
  });
}
