// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current [AppThemeMode], as `themeModeProvider`.
///
/// The app restyles at once when it changes, without a restart. It is the
/// theme of the stored settings (`settingsProvider`), so a choice persists
/// across restarts.

@ProviderFor(AppThemeModeNotifier)
final themeModeProvider = AppThemeModeNotifierProvider._();

/// The current [AppThemeMode], as `themeModeProvider`.
///
/// The app restyles at once when it changes, without a restart. It is the
/// theme of the stored settings (`settingsProvider`), so a choice persists
/// across restarts.
final class AppThemeModeNotifierProvider
    extends $NotifierProvider<AppThemeModeNotifier, AppThemeMode> {
  /// The current [AppThemeMode], as `themeModeProvider`.
  ///
  /// The app restyles at once when it changes, without a restart. It is the
  /// theme of the stored settings (`settingsProvider`), so a choice persists
  /// across restarts.
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
    r'556732103ac36215ab750eac7b931afd76e967ad';

/// The current [AppThemeMode], as `themeModeProvider`.
///
/// The app restyles at once when it changes, without a restart. It is the
/// theme of the stored settings (`settingsProvider`), so a choice persists
/// across restarts.

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
