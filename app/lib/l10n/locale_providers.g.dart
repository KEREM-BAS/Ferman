// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The operating system's preferred locales, most preferred first, as
/// `systemLocalesProvider`.
///
/// It follows the system while the app runs (`didChangeLocales`), so a
/// language or region that follows the system changes with it.

@ProviderFor(SystemLocales)
final systemLocalesProvider = SystemLocalesProvider._();

/// The operating system's preferred locales, most preferred first, as
/// `systemLocalesProvider`.
///
/// It follows the system while the app runs (`didChangeLocales`), so a
/// language or region that follows the system changes with it.
final class SystemLocalesProvider
    extends $NotifierProvider<SystemLocales, List<Locale>> {
  /// The operating system's preferred locales, most preferred first, as
  /// `systemLocalesProvider`.
  ///
  /// It follows the system while the app runs (`didChangeLocales`), so a
  /// language or region that follows the system changes with it.
  SystemLocalesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemLocalesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemLocalesHash();

  @$internal
  @override
  SystemLocales create() => SystemLocales();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Locale> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Locale>>(value),
    );
  }
}

String _$systemLocalesHash() => r'9ff8477eaa1310ef367c4c35bd73727d303a0033';

/// The operating system's preferred locales, most preferred first, as
/// `systemLocalesProvider`.
///
/// It follows the system while the app runs (`didChangeLocales`), so a
/// language or region that follows the system changes with it.

abstract class _$SystemLocales extends $Notifier<List<Locale>> {
  List<Locale> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Locale>, List<Locale>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Locale>, List<Locale>>,
              List<Locale>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The operating system's most preferred locale, or US English when the
/// system reports none.

@ProviderFor(systemLocale)
final systemLocaleProvider = SystemLocaleProvider._();

/// The operating system's most preferred locale, or US English when the
/// system reports none.

final class SystemLocaleProvider
    extends $FunctionalProvider<Locale, Locale, Locale>
    with $Provider<Locale> {
  /// The operating system's most preferred locale, or US English when the
  /// system reports none.
  SystemLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemLocaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemLocaleHash();

  @$internal
  @override
  $ProviderElement<Locale> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Locale create(Ref ref) {
    return systemLocale(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale>(value),
    );
  }
}

String _$systemLocaleHash() => r'f37eb3539752d372aeac7f4def5d24aee31b6f40';

/// The first of the system's preferred languages that is one of the 21
/// interface languages, or null when none is (a1-1 marks it "System
/// language"). A system that prefers Swahili, then Turkish, gets Turkish,
/// as the framework's own locale resolution walks the whole list; the
/// region still follows the first locale ([region]).

@ProviderFor(systemLanguage)
final systemLanguageProvider = SystemLanguageProvider._();

/// The first of the system's preferred languages that is one of the 21
/// interface languages, or null when none is (a1-1 marks it "System
/// language"). A system that prefers Swahili, then Turkish, gets Turkish,
/// as the framework's own locale resolution walks the whole list; the
/// region still follows the first locale ([region]).

final class SystemLanguageProvider
    extends $FunctionalProvider<AppLanguage?, AppLanguage?, AppLanguage?>
    with $Provider<AppLanguage?> {
  /// The first of the system's preferred languages that is one of the 21
  /// interface languages, or null when none is (a1-1 marks it "System
  /// language"). A system that prefers Swahili, then Turkish, gets Turkish,
  /// as the framework's own locale resolution walks the whole list; the
  /// region still follows the first locale ([region]).
  SystemLanguageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemLanguageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemLanguageHash();

  @$internal
  @override
  $ProviderElement<AppLanguage?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLanguage? create(Ref ref) {
    return systemLanguage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLanguage? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLanguage?>(value),
    );
  }
}

String _$systemLanguageHash() => r'ba2e6cf5ae412d89e8d9e0a8a6aa773ca06ed7a2';

/// The app language the user chose (Settings → Language and region, a1-1):
/// `AppSettings.languageCode`, or the system's language while it is null,
/// or English when the system's language is none of the 21 or the stored
/// code is unknown.
///
/// It may be a language without a translation yet (G20); [appLocale] is
/// what the UI shows.

@ProviderFor(appLanguage)
final appLanguageProvider = AppLanguageProvider._();

/// The app language the user chose (Settings → Language and region, a1-1):
/// `AppSettings.languageCode`, or the system's language while it is null,
/// or English when the system's language is none of the 21 or the stored
/// code is unknown.
///
/// It may be a language without a translation yet (G20); [appLocale] is
/// what the UI shows.

final class AppLanguageProvider
    extends $FunctionalProvider<AppLanguage, AppLanguage, AppLanguage>
    with $Provider<AppLanguage> {
  /// The app language the user chose (Settings → Language and region, a1-1):
  /// `AppSettings.languageCode`, or the system's language while it is null,
  /// or English when the system's language is none of the 21 or the stored
  /// code is unknown.
  ///
  /// It may be a language without a translation yet (G20); [appLocale] is
  /// what the UI shows.
  AppLanguageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLanguageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLanguageHash();

  @$internal
  @override
  $ProviderElement<AppLanguage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppLanguage create(Ref ref) {
    return appLanguage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppLanguage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppLanguage>(value),
    );
  }
}

String _$appLanguageHash() => r'e4f7efef18196fb12e86a0756e68d2cd97f47dd8';

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

@ProviderFor(appLocale)
final appLocaleProvider = AppLocaleProvider._();

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

final class AppLocaleProvider
    extends $FunctionalProvider<Locale, Locale, Locale>
    with $Provider<Locale> {
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
  AppLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLocaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLocaleHash();

  @$internal
  @override
  $ProviderElement<Locale> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Locale create(Ref ref) {
    return appLocale(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale>(value),
    );
  }
}

String _$appLocaleHash() => r'bf05def284e11f1274133ef63ebbb660a2701dcf';

/// The region formats in force, as `regionProvider`: `AppSettings.regionCode`
/// (null: the region of the system's locale, [Region.fromLocale]) with the
/// paper size, length unit and first-day overrides of the settings, each
/// falling back to the region's default.
///
/// A chosen region formats with the system language's own locale for that
/// country when intl has one ([Region.forCode]), as the system's default
/// region does, so choosing the system's own region changes nothing. The
/// UI language never takes part (G34).

@ProviderFor(region)
final regionProvider = RegionProvider._();

/// The region formats in force, as `regionProvider`: `AppSettings.regionCode`
/// (null: the region of the system's locale, [Region.fromLocale]) with the
/// paper size, length unit and first-day overrides of the settings, each
/// falling back to the region's default.
///
/// A chosen region formats with the system language's own locale for that
/// country when intl has one ([Region.forCode]), as the system's default
/// region does, so choosing the system's own region changes nothing. The
/// UI language never takes part (G34).

final class RegionProvider
    extends $FunctionalProvider<RegionSettings, RegionSettings, RegionSettings>
    with $Provider<RegionSettings> {
  /// The region formats in force, as `regionProvider`: `AppSettings.regionCode`
  /// (null: the region of the system's locale, [Region.fromLocale]) with the
  /// paper size, length unit and first-day overrides of the settings, each
  /// falling back to the region's default.
  ///
  /// A chosen region formats with the system language's own locale for that
  /// country when intl has one ([Region.forCode]), as the system's default
  /// region does, so choosing the system's own region changes nothing. The
  /// UI language never takes part (G34).
  RegionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'regionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$regionHash();

  @$internal
  @override
  $ProviderElement<RegionSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RegionSettings create(Ref ref) {
    return region(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RegionSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RegionSettings>(value),
    );
  }
}

String _$regionHash() => r'3b1fc698775b20e1049461da16e8a229345be592';
