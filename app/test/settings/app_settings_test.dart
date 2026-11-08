import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('defaults follow the system and onboarding is not done', () {
      const settings = AppSettings();
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.markEdited, isTrue);
      expect(settings.languageCode, isNull);
      expect(settings.regionCode, isNull);
      expect(settings.paperSize, isNull);
      expect(settings.onboardingCompleted, isFalse);
      expect(settings.toJson(), {
        'version': 1,
        'theme': 'system',
        'onboardingCompleted': false,
        'reopenDocuments': true,
        'lastDocuments': <String>[],
        'askDefaultApp': true,
        'pageLook': 'paper',
        'pageLayout': 'scroll',
        'zoom': 'fitWidth',
        'missingGlyphs': 'similar',
        'recoveryCopies': true,
        'reflow': true,
        'markEdited': true,
        'keepVersions': true,
        'aiClients': false,
        'myStamps': <String>[],
        'shortcuts': <String, List<String>>{},
      });
    });

    test('round-trips through JSON', () {
      const settings = AppSettings(
        themeMode: AppThemeMode.dark,
        languageCode: 'tr',
        regionCode: 'TR',
        paperSize: PaperSize.a4,
        lengthUnit: LengthUnit.millimetre,
        firstDayOfWeek: FirstDayOfWeek.monday,
        onboardingCompleted: true,
      );
      expect(AppSettings.fromJson(settings.toJson()), settings);
      expect(settings.toJson(), {
        'version': 1,
        'theme': 'dark',
        'language': 'tr',
        'region': 'TR',
        'paperSize': 'a4',
        'lengthUnit': 'millimetre',
        'firstDayOfWeek': 'monday',
        'onboardingCompleted': true,
        'reopenDocuments': true,
        'lastDocuments': <String>[],
        'askDefaultApp': true,
        'pageLook': 'paper',
        'pageLayout': 'scroll',
        'zoom': 'fitWidth',
        'missingGlyphs': 'similar',
        'recoveryCopies': true,
        'reflow': true,
        'markEdited': true,
        'keepVersions': true,
        'aiClients': false,
        'myStamps': <String>[],
        'shortcuts': <String, List<String>>{},
      });
    });

    test('the third choice and reflow off round-trip', () {
      const settings = AppSettings(
        missingGlyphs: MissingGlyphPolicy.mark,
        reflow: false,
      );
      expect(settings.toJson()['missingGlyphs'], 'mark');
      expect(AppSettings.fromJson(settings.toJson()), settings);
    });

    test('unreadable values fall back to the defaults', () {
      final settings = AppSettings.fromJson(const {
        'theme': 'purple',
        'language': 42,
        'region': '',
        'paperSize': 'a5',
        'onboardingCompleted': 'yes',
      });
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.languageCode, isNull);
      expect(settings.regionCode, isNull);
      expect(settings.paperSize, isNull);
      expect(settings.onboardingCompleted, isFalse);
    });

    test("keeps a newer build's keys and version", () {
      final settings = AppSettings.fromJson(const {
        'version': 3,
        'theme': 'light',
        'futureOption': {'nested': true},
      });
      expect(settings.unknown, {
        'futureOption': {'nested': true},
      });
      final json = settings.copyWith(themeMode: AppThemeMode.dark).toJson();
      expect(json['version'], 3);
      expect(json['theme'], 'dark');
      expect(json['futureOption'], {'nested': true});
    });

    test('"Ask each time" round-trips, and an unknown policy is the '
        'default', () {
      const ask = AppSettings(missingGlyphs: MissingGlyphPolicy.ask);
      expect(ask.toJson()['missingGlyphs'], 'ask');
      expect(AppSettings.fromJson(ask.toJson()), ask);
      expect(
        AppSettings.fromJson(const {'missingGlyphs': 'keep'}).missingGlyphs,
        MissingGlyphPolicy.similar,
      );
    });

    test('an older version is written as the current one', () {
      expect(AppSettings.fromJson(const {'version': 0}).toJson()['version'], 1);
    });

    test('copyWith can set a choice back to null', () {
      const settings = AppSettings(languageCode: 'ar', regionCode: 'SA');
      final system = settings.copyWith(languageCode: () => null);
      expect(system.languageCode, isNull);
      expect(system.regionCode, 'SA');
      expect(settings.copyWith(), settings);
    });

    test('equality and hash code', () {
      expect(
        const AppSettings(languageCode: 'tr'),
        const AppSettings(languageCode: 'tr'),
      );
      expect(
        const AppSettings(languageCode: 'tr').hashCode,
        const AppSettings(languageCode: 'tr').hashCode,
      );
      expect(
        const AppSettings(languageCode: 'tr'),
        isNot(const AppSettings(languageCode: 'en')),
      );
    });

    test('Keep versions off round-trips', () {
      const settings = AppSettings(keepVersions: false);
      expect(AppSettings.fromJson(settings.toJson()), settings);
    });

    test('the export leaves out the documents open last', () {
      const settings = AppSettings(lastDocuments: ['/a.pdf'], reflow: false);
      final exported = settings.toExport();
      expect(exported.containsKey('lastDocuments'), isFalse);
      expect(exported['reflow'], isFalse);
    });

    group('imported (decision 34)', () {
      const current = AppSettings(
        onboardingCompleted: true,
        lastDocuments: ['/mine.pdf'],
      );

      test('refuses what is not a settings file', () {
        for (final json in <Object?>[
          null,
          [1],
          'text',
          <String, Object?>{},
          {'version': 'one'},
          {'version': 0},
          {'version': AppSettings.currentVersion + 1},
        ]) {
          expect(AppSettings.imported(json, current), isNull, reason: '$json');
        }
      });

      test('takes the choices, but not the documents, first run or keys '
          'it does not know', () {
        final settings = AppSettings.imported({
          'version': 1,
          'theme': 'dark',
          'language': 'tr',
          'region': 'TR',
          'keepVersions': false,
          'onboardingCompleted': false,
          'lastDocuments': ['/theirs.pdf'],
          'unknownKey': 1,
        }, current)!;
        expect(settings.themeMode, AppThemeMode.dark);
        expect(settings.languageCode, 'tr');
        expect(settings.regionCode, 'TR');
        expect(settings.keepVersions, isFalse);
        expect(settings.onboardingCompleted, isTrue);
        expect(settings.lastDocuments, ['/mine.pdf']);
        expect(settings.unknown, isEmpty);
      });

      test('values out of bounds take their defaults', () {
        final settings = AppSettings.imported({
          'version': 1,
          'language': '../../etc',
          'region': 'T R',
          'theme': 'neon',
          'commenterName': 'x' * (AppSettings.largestImportedText + 1),
          'markEdited': 'yes',
        }, current)!;
        expect(settings.languageCode, isNull);
        expect(settings.regionCode, isNull);
        expect(settings.themeMode, AppThemeMode.system);
        expect(settings.commenterName, isNull);
        expect(settings.markEdited, isTrue);
      });
    });
  });
}
