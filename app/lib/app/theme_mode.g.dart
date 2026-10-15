// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current [AppThemeMode], as `themeModeProvider`.
///
/// The app restyles at once when it changes, without a restart. It is held
/// in memory for now and starts at [AppThemeMode.system]; the settings store
/// (M1 step 9) loads and persists it.

@ProviderFor(AppThemeModeNotifier)
final themeModeProvider = AppThemeModeNotifierProvider._();

/// The current [AppThemeMode], as `themeModeProvider`.
///
/// The app restyles at once when it changes, without a restart. It is held
/// in memory for now and starts at [AppThemeMode.system]; the settings store
/// (M1 step 9) loads and persists it.
final class AppThemeModeNotifierProvider
    extends $NotifierProvider<AppThemeModeNotifier, AppThemeMode> {
  /// The current [AppThemeMode], as `themeModeProvider`.
  ///
  /// The app restyles at once when it changes, without a restart. It is held
  /// in memory for now and starts at [AppThemeMode.system]; the settings store
  /// (M1 step 9) loads and persists it.
  AppThemeModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appThemeModeNotifierHash();

  @$internal
  @override
  AppThemeModeNotifier create() => AppThemeModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeMode>(value),
    );
  }
}

String _$appThemeModeNotifierHash() =>
    r'ab5a7821bdae339b810698cd7c4fedacd576f75b';

/// The current [AppThemeMode], as `themeModeProvider`.
///
/// The app restyles at once when it changes, without a restart. It is held
/// in memory for now and starts at [AppThemeMode.system]; the settings store
/// (M1 step 9) loads and persists it.

abstract class _$AppThemeModeNotifier extends $Notifier<AppThemeMode> {
  AppThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppThemeMode, AppThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppThemeMode, AppThemeMode>,
              AppThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
