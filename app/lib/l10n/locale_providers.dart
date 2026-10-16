import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_providers.g.dart';

/// The operating system's preferred locales, most preferred first, as
/// `systemLocalesProvider`.
///
/// It follows the system while the app runs (`didChangeLocales`), so a
/// language or region that follows the system changes with it.
@Riverpod(keepAlive: true)
class SystemLocales extends _$SystemLocales with WidgetsBindingObserver {
  @override
  List<Locale> build() {
    final binding = WidgetsBinding.instance..addObserver(this);
    ref.onDispose(() => binding.removeObserver(this));
    return binding.platformDispatcher.locales;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    state = locales ?? WidgetsBinding.instance.platformDispatcher.locales;
  }
}

/// The operating system's most preferred locale, or US English when the
/// system reports none.
@Riverpod(keepAlive: true)
Locale systemLocale(Ref ref) {
  final locales = ref.watch(systemLocalesProvider);
  return locales.isEmpty ? const Locale('en', 'US') : locales.first;
}

/// The first of the system's preferred languages that is one of the 21
/// interface languages, or null when none is (a1-1 marks it "System
/// language"). A system that prefers Swahili, then Turkish, gets Turkish,
/// as the framework's own locale resolution walks the whole list; the
/// region still follows the first locale ([region]).
@Riverpod(keepAlive: true)
AppLanguage? systemLanguage(Ref ref) {
  for (final locale in ref.watch(systemLocalesProvider)) {
    final language = AppLanguage.forLocale(locale);
    if (language != null) return language;
  }
  return null;
}

/// The app language the user chose (Settings → Language and region, a1-1):
/// `AppSettings.languageCode`, or the system's language while it is null,
/// or English when the system's language is none of the 21 or the stored
/// code is unknown.
///
/// It may be a language without a translation yet (G20); [appLocale] is
/// what the UI shows.
@Riverpod(keepAlive: true)
AppLanguage appLanguage(Ref ref) {
  final code = ref.watch(
    settingsProvider.select((settings) => settings.languageCode),
  );
  if (code != null) return AppLanguage.fromTag(code) ?? AppLanguage.english;
  return ref.watch(systemLanguageProvider) ?? AppLanguage.english;
}

/// The locale of the UI's strings, which `FermanApp` gives
/// `MaterialApp.locale`: the [appLanguage] when it is translated (English,
/// Turkish, Arabic), otherwise English (G20, ADR 0014).
///
/// Always one of `AppLocalizations.supportedLocales`, so the framework's
/// own fallback, which would pick the first supported locale (Arabic),
/// never applies. The UI's direction does not come from this locale but
/// from the [appLanguage] itself (`AppLanguage.textDirection`, which
/// `FermanApp` applies above every route): Arabic, Persian and Hebrew make
/// the whole UI right to left at once (G20), Persian and Hebrew with the
/// English strings until they are translated.
@Riverpod(keepAlive: true)
Locale appLocale(Ref ref) => ref.watch(appLanguageProvider).uiLocale;

/// The region formats in force (a11-1b): the region and its paper size,
/// length unit and first day of the week, each either the user's choice or
/// the region's default (G34, ADR 0014).
@immutable
final class RegionSettings {
  /// The settings of [region] with these values.
  const new({
    required this.region,
    required this.paperSize,
    required this.lengthUnit,
    required this.firstDayOfWeek,
  });

  /// The settings of [region] with its own defaults.
  new defaults(this.region)
    : paperSize = region.defaultPaperSize,
      lengthUnit = region.defaultLengthUnit,
      firstDayOfWeek = region.defaultFirstDayOfWeek;

  /// The region whose conventions format numbers, dates and times.
  final Region region;

  /// The paper size for new pages.
  final PaperSize paperSize;

  /// The unit for lengths.
  final LengthUnit lengthUnit;

  /// The first day of the week in calendars.
  final FirstDayOfWeek firstDayOfWeek;

  /// The formatter for [region].
  RegionFormat get format => RegionFormat.forRegion(region);

  @override
  bool operator ==(Object other) =>
      other is RegionSettings &&
      other.region == region &&
      other.paperSize == paperSize &&
      other.lengthUnit == lengthUnit &&
      other.firstDayOfWeek == firstDayOfWeek;

  @override
  int get hashCode =>
      Object.hash(region, paperSize, lengthUnit, firstDayOfWeek);

  @override
  String toString() =>
      'RegionSettings($region, ${paperSize.name}, ${lengthUnit.name}, '
      '${firstDayOfWeek.name})';
}

/// The region formats in force, as `regionProvider`: `AppSettings.regionCode`
/// (null: the region of the system's locale, [Region.fromLocale]) with the
/// paper size, length unit and first-day overrides of the settings, each
/// falling back to the region's default.
///
/// A chosen region formats with the system language's own locale for that
/// country when intl has one ([Region.forCode]), as the system's default
/// region does, so choosing the system's own region changes nothing. The
/// UI language never takes part (G34).
@Riverpod(keepAlive: true)
RegionSettings region(Ref ref) {
  final (code, paper, unit, firstDay) = ref.watch(
    settingsProvider.select(
      (settings) => (
        settings.regionCode,
        settings.paperSize,
        settings.lengthUnit,
        settings.firstDayOfWeek,
      ),
    ),
  );
  final system = ref.watch(systemLocaleProvider);
  final region = code == null
      ? Region.fromLocale(system)
      : Region.forCode(code, languageCode: system.languageCode);
  return RegionSettings(
    region: region,
    paperSize: paper ?? region.defaultPaperSize,
    lengthUnit: unit ?? region.defaultLengthUnit,
    firstDayOfWeek: firstDay ?? region.defaultFirstDayOfWeek,
  );
}
