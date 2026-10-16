// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_save_failure.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the last change made in Settings could not be stored, as
/// `settingsSaveFailedProvider`.
///
/// `SettingsNotifier.change` keeps a change for the session when the
/// settings file cannot be written (`SettingsStoreException`); Settings then
/// shows a warning Banner saying so, until the next change is stored or
/// the person dismisses it. No board draws this state (G90).

@ProviderFor(SettingsSaveFailed)
final settingsSaveFailedProvider = SettingsSaveFailedProvider._();

/// Whether the last change made in Settings could not be stored, as
/// `settingsSaveFailedProvider`.
///
/// `SettingsNotifier.change` keeps a change for the session when the
/// settings file cannot be written (`SettingsStoreException`); Settings then
/// shows a warning Banner saying so, until the next change is stored or
/// the person dismisses it. No board draws this state (G90).
final class SettingsSaveFailedProvider
    extends $NotifierProvider<SettingsSaveFailed, bool> {
  /// Whether the last change made in Settings could not be stored, as
  /// `settingsSaveFailedProvider`.
  ///
  /// `SettingsNotifier.change` keeps a change for the session when the
  /// settings file cannot be written (`SettingsStoreException`); Settings then
  /// shows a warning Banner saying so, until the next change is stored or
  /// the person dismisses it. No board draws this state (G90).
  SettingsSaveFailedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsSaveFailedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsSaveFailedHash();

  @$internal
  @override
  SettingsSaveFailed create() => SettingsSaveFailed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$settingsSaveFailedHash() =>
    r'781b0150de1b58fe93fce043c504b9cbfeefc3ee';

/// Whether the last change made in Settings could not be stored, as
/// `settingsSaveFailedProvider`.
///
/// `SettingsNotifier.change` keeps a change for the session when the
/// settings file cannot be written (`SettingsStoreException`); Settings then
/// shows a warning Banner saying so, until the next change is stored or
/// the person dismisses it. No board draws this state (G90).

abstract class _$SettingsSaveFailed extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
