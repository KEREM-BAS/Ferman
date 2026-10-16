import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/l10n/region_names.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerWith({
    AppSettings settings = const AppSettings(),
    List<Locale> system = const [Locale('en', 'US')],
  }) {
    binding.platformDispatcher.localesTestValue = system;
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(MemorySettingsStore(settings)),
        initialSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AppLanguage', () {
    test('lists the 21 languages of a1-1 with en, tr and ar translated', () {
      expect(AppLanguage.values, hasLength(21));
      expect(
        [
          for (final language in AppLanguage.values)
            if (language.translated) language.tag,
        ],
        ['en', 'tr', 'ar'],
      );
      expect(
        [
          for (final language in AppLanguage.values)
            if (language.rightToLeft) language.tag,
        ],
        ['ar', 'fa', 'he'],
      );
    });

    test('every translated language has a generated localization', () {
      for (final language in AppLanguage.values.where((l) => l.translated)) {
        expect(
          AppLocalizations.supportedLocales,
          contains(language.uiLocale),
          reason: language.tag,
        );
      }
    });

    test('untranslated languages show the English UI', () {
      expect(AppLanguage.german.uiLocale, const Locale('en'));
      expect(AppLanguage.persian.uiLocale, const Locale('en'));
      expect(AppLanguage.arabic.uiLocale, const Locale('ar'));
    });

    test('tags round-trip and carry their subtags', () {
      for (final language in AppLanguage.values) {
        expect(AppLanguage.fromTag(language.tag), language);
      }
      expect(AppLanguage.fromTag('xx'), isNull);
      expect(AppLanguage.fromTag(null), isNull);
      expect(
        AppLanguage.chineseTraditional.locale,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(
        AppLanguage.portugueseBrazil.locale,
        const Locale.fromSubtags(languageCode: 'pt', countryCode: 'BR'),
      );
    });

    test('maps system locales to the picker languages', () {
      expect(
        AppLanguage.forLocale(const Locale('tr', 'TR')),
        AppLanguage.turkish,
      );
      expect(
        AppLanguage.forLocale(const Locale('ar', 'SA')),
        AppLanguage.arabic,
      );
      expect(
        AppLanguage.forLocale(const Locale('pt', 'PT')),
        AppLanguage.portugueseBrazil,
      );
      expect(
        AppLanguage.forLocale(const Locale('zh', 'TW')),
        AppLanguage.chineseTraditional,
      );
      expect(
        AppLanguage.forLocale(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
        AppLanguage.chineseTraditional,
      );
      expect(
        AppLanguage.forLocale(const Locale('zh', 'CN')),
        AppLanguage.chineseSimplified,
      );
      expect(AppLanguage.forLocale(const Locale('iw')), AppLanguage.hebrew);
      expect(AppLanguage.forLocale(const Locale('in')), AppLanguage.indonesian);
      expect(AppLanguage.forLocale(const Locale('sw', 'KE')), isNull);
    });
  });

  group('appLocaleProvider', () {
    test('follows a translated system language while none is chosen', () {
      expect(
        containerWith(system: const [Locale('tr', 'TR')])
            .read(appLocaleProvider),
        const Locale('tr'),
      );
      expect(
        containerWith(system: const [Locale('ar', 'EG')])
            .read(appLocaleProvider),
        const Locale('ar'),
      );
    });

    test('falls back to English, never to the first supported locale', () {
      // AppLocalizations.supportedLocales starts with Arabic, which the
      // framework's own fallback would pick for German.
      for (final system in const [Locale('de', 'DE'), Locale('sw', 'KE')]) {
        final container = containerWith(system: [system]);
        expect(container.read(appLocaleProvider), const Locale('en'));
      }
      expect(
        containerWith(system: const []).read(appLocaleProvider),
        const Locale('en'),
      );
    });

    test('the chosen language wins over the system', () {
      final container = containerWith(
        settings: const AppSettings(languageCode: 'ar'),
        system: const [Locale('tr', 'TR')],
      );
      expect(container.read(appLanguageProvider), AppLanguage.arabic);
      expect(container.read(appLocaleProvider), const Locale('ar'));
    });

    test(
      'a chosen untranslated language keeps its choice and shows English',
      () {
        final container = containerWith(
          settings: const AppSettings(languageCode: 'fa'),
        );
        expect(container.read(appLanguageProvider), AppLanguage.persian);
        expect(container.read(appLocaleProvider), const Locale('en'));
      },
    );

    test('an unknown stored code shows English', () {
      final container = containerWith(
        settings: const AppSettings(languageCode: 'tlh'),
        system: const [Locale('tr', 'TR')],
      );
      expect(container.read(appLanguageProvider), AppLanguage.english);
    });

    test('changes with the setting at once', () async {
      final container = containerWith();
      expect(container.read(appLocaleProvider), const Locale('en'));
      await container
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(languageCode: () => 'tr'));
      expect(container.read(appLocaleProvider), const Locale('tr'));
      await container
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(languageCode: () => null));
      expect(container.read(appLocaleProvider), const Locale('en'));
    });

    test('takes the first interface language among the system’s preferred '
        'ones; the region keeps the first locale', () {
      final container = containerWith(
        system: const [Locale('sw', 'KE'), Locale('tr', 'TR')],
      );
      expect(container.read(systemLanguageProvider), AppLanguage.turkish);
      expect(container.read(appLocaleProvider), const Locale('tr'));
      expect(container.read(regionProvider).region.code, 'KE');
    });

    test('no interface language among the system’s gives English', () {
      final container = containerWith(
        system: const [Locale('sw', 'KE'), Locale('am', 'ET')],
      );
      expect(container.read(systemLanguageProvider), isNull);
      expect(container.read(appLanguageProvider), AppLanguage.english);
    });

    test('follows the system while the app runs', () {
      final container = containerWith();
      expect(container.read(appLocaleProvider), const Locale('en'));
      expect(container.read(systemLanguageProvider), AppLanguage.english);
      binding.platformDispatcher.localesTestValue = const [Locale('tr', 'TR')];
      expect(container.read(systemLanguageProvider), AppLanguage.turkish);
      expect(container.read(appLocaleProvider), const Locale('tr'));
    });
  });

  group('regionProvider', () {
    test('derives the region from the system locale while none is set', () {
      final container = containerWith(system: const [Locale('tr', 'TR')]);
      final region = container.read(regionProvider);
      expect(region.region, Region.turkiye);
      expect(region.paperSize, PaperSize.a4);
      expect(region.lengthUnit, LengthUnit.millimetre);
      expect(region.firstDayOfWeek, FirstDayOfWeek.monday);
    });

    test('formats for the region, not the UI language (G34)', () {
      final container = containerWith(
        settings: const AppSettings(languageCode: 'en', regionCode: 'TR'),
      );
      final format = container.read(regionProvider).format;
      final moment = DateTime(2026, 10, 13, 14, 32);
      expect(format.date(moment), '13.10.2026');
      expect(format.time(moment), '14:32');
      expect(format.decimal(18500.5, minFractionDigits: 2), '18.500,50');
      expect(format.pointSize(10.5), '10,5\u00A0pt');
    });

    test('applies the paper, unit and week overrides', () {
      final container = containerWith(
        settings: const AppSettings(
          regionCode: 'TR',
          paperSize: PaperSize.letter,
          lengthUnit: LengthUnit.inch,
          firstDayOfWeek: FirstDayOfWeek.sunday,
        ),
      );
      final region = container.read(regionProvider);
      expect(region.region, Region.turkiye);
      expect(region.paperSize, PaperSize.letter);
      expect(region.lengthUnit, LengthUnit.inch);
      expect(region.firstDayOfWeek, FirstDayOfWeek.sunday);
    });

    test('a chosen region keeps the system language’s own locale', () {
      final container = containerWith(
        settings: const AppSettings(regionCode: 'CA'),
        system: const [Locale('fr', 'FR')],
      );
      expect(container.read(regionProvider).region.formatLocale, 'fr_CA');
    });

    test('the United States defaults to Letter, inches and Sunday', () {
      final region = containerWith().read(regionProvider);
      expect(region, RegionSettings.defaults(Region.unitedStates));
      expect(region.paperSize, PaperSize.letter);
      expect(region.lengthUnit, LengthUnit.inch);
      expect(region.firstDayOfWeek, FirstDayOfWeek.sunday);
    });
  });

  group('regionDisplayName', () {
    test('names the region in the UI language, then its own name', () {
      expect(regionDisplayName('TR', 'en'), 'Türkiye');
      expect(regionDisplayName('TR', 'ar'), 'تركيا (Türkiye)');
      expect(regionDisplayName('DE', 'en'), 'Germany (Deutschland)');
      expect(regionDisplayName('DE', 'tr'), 'Almanya (Deutschland)');
      expect(regionDisplayName('US', 'de'), 'United States');
      // A code CLDR does not name stays a code.
      expect(regionDisplayName('xx', 'en'), 'XX');
      expect(hasRegionName('XX'), isFalse);
    });

    test('has a name for every region of the setting', () {
      for (final region in Region.all) {
        expect(hasRegionName(region.code), isTrue, reason: region.code);
      }
    });

    test('names regions the system can report outside the list (CLDR)', () {
      expect(hasRegionName('BE'), isTrue);
      expect(regionDisplayName('BE', 'en'), 'Belgium (België)');
      expect(regionDisplayName('be', 'tr'), 'Belçika (België)');
      expect(regionDisplayName('BE', 'ar'), 'بلجيكا (België)');
      expect(regionDisplayName('JO', 'en'), 'Jordan (الأردن)');
      expect(regionDisplayName('JO', 'ar'), 'الأردن');
      expect(regionDisplayName('LR', 'en'), 'Liberia');
      expect(regionDisplayName('MV', 'tr'), 'Maldivler (Maldives)');
      // Deprecated codes and groupings are not regions.
      for (final code in ['YU', 'BU', 'EU', 'UN', 'ZZ']) {
        expect(hasRegionName(code), isFalse, reason: code);
      }
    });
  });

  group('sortRegionCodes', () {
    List<String> names(String language) => [
      for (final code in sortRegionCodes([
        for (final region in Region.all) region.code,
      ], language))
        regionDisplayName(code, language),
    ];

    test('follows the Turkish alphabet: Ç after C, İ after I', () {
      final turkish = names('tr');
      final brazil = turkish.indexOf('Brezilya (Brasil)');
      final czechia = turkish.indexOf('Çekya (Česko)');
      final china = turkish.indexOf('Çin (中国)');
      final denmark = turkish.indexOf('Danimarka (Danmark)');
      expect(brazil, lessThan(czechia));
      expect(czechia, lessThan(china));
      expect(china, lessThan(denmark));
      expect(turkish.last, 'Yunanistan (Ελλάδα)');
      expect(
        turkish.indexOf('Hong Kong (香港)'),
        lessThan(turkish.indexOf('İran (ایران)')),
      );
    });

    test('sorts Arabic alef with and without hamza as one letter', () {
      final arabic = names('ar');
      final emirates = arabic.indexOf('الإمارات العربية المتحدة');
      final germany = arabic.indexOf('ألمانيا (Deutschland)');
      final indonesia = arabic.indexOf('إندونيسيا (Indonesia)');
      expect(emirates, lessThan(germany));
      expect(germany, lessThan(indonesia));
      expect(arabic.indexOf('أوكرانيا (Україна)'), greaterThan(emirates));
    });

    test('other languages take the English order; unnamed codes go last', () {
      expect(sortRegionCodes(['US', 'XX', 'DE', 'AT'], 'de'), [
        'AT',
        'DE',
        'US',
        'XX',
      ]);
      expect(sortRegionCodes(['TR', 'DE'], 'en'), ['DE', 'TR']);
    });
  });
}
