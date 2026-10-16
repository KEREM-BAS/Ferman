// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where the settings are stored. `bootstrap()` overrides it with the
/// platform's store; without an override the settings live in memory.

@ProviderFor(settingsStore)
final settingsStoreProvider = SettingsStoreProvider._();

/// Where the settings are stored. `bootstrap()` overrides it with the
/// platform's store; without an override the settings live in memory.

final class SettingsStoreProvider
    extends $FunctionalProvider<SettingsStore, SettingsStore, SettingsStore>
    with $Provider<SettingsStore> {
  /// Where the settings are stored. `bootstrap()` overrides it with the
  /// platform's store; without an override the settings live in memory.
  SettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsStoreHash();

  @$internal
  @override
  $ProviderElement<SettingsStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsStore create(Ref ref) {
    return settingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsStore>(value),
    );
  }
}

String _$settingsStoreHash() => r'bc03750b747fc795fad32971a2088d9176bcd739';

/// The settings loaded at start-up. `bootstrap()` loads them before the
/// first frame and overrides this, so the first frame already has the
/// user's theme and language.

@ProviderFor(initialSettings)
final initialSettingsProvider = InitialSettingsProvider._();

/// The settings loaded at start-up. `bootstrap()` loads them before the
/// first frame and overrides this, so the first frame already has the
/// user's theme and language.

final class InitialSettingsProvider
    extends $FunctionalProvider<AppSettings, AppSettings, AppSettings>
    with $Provider<AppSettings> {
  /// The settings loaded at start-up. `bootstrap()` loads them before the
  /// first frame and overrides this, so the first frame already has the
  /// user's theme and language.
  InitialSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialSettingsHash();

  @$internal
  @override
  $ProviderElement<AppSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppSettings create(Ref ref) {
    return initialSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$initialSettingsHash() => r'0ee52d46bb01b76efc2bfb545a6b92daac0db17e';

/// The current [AppSettings], as `settingsProvider`.
///
/// Every change goes through [change], which updates the app at once and
/// then stores the new settings.

@ProviderFor(SettingsNotifier)
final settingsProvider = SettingsNotifierProvider._();

/// The current [AppSettings], as `settingsProvider`.
///
/// Every change goes through [change], which updates the app at once and
/// then stores the new settings.
final class SettingsNotifierProvider
    extends $NotifierProvider<SettingsNotifier, AppSettings> {
  /// The current [AppSettings], as `settingsProvider`.
  ///
  /// Every change goes through [change], which updates the app at once and
  /// then stores the new settings.
  SettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsNotifierHash();

  @$internal
  @override
  SettingsNotifier create() => SettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$settingsNotifierHash() => r'34e5a30646b88d9e198f074214d084f0cea7eec2';

/// The current [AppSettings], as `settingsProvider`.
///
/// Every change goes through [change], which updates the app at once and
/// then stores the new settings.

abstract class _$SettingsNotifier extends $Notifier<AppSettings> {
  AppSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppSettings, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppSettings, AppSettings>,
              AppSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
