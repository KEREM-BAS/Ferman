import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('defaults follow the system and onboarding is not done', () {
      const settings = AppSettings();
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.languageCode, isNull);
      expect(settings.regionCode, isNull);
      expect(settings.paperSize, isNull);
      expect(settings.onboardingCompleted, isFalse);
      expect(settings.toJson(), {
        'version': 1,
        'theme': 'system',
        'onboardingCompleted': false,
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
      });
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
  });
}
