import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode.g.dart';

/// The appearance the user picks under Settings → General → Theme (a11-1).
///
/// The app's own enum, so settings and features never import Material for
/// its `ThemeMode`; `app.dart` maps it.
enum AppThemeMode {
  /// Follow the system's light or dark appearance ("Match system"), the
  /// default.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// The current [AppThemeMode], as `themeModeProvider`.
///
/// The app restyles at once when it changes, without a restart. It is the
/// theme of the stored settings (`settingsProvider`), so a choice persists
/// across restarts.
@Riverpod(keepAlive: true, name: 'themeModeProvider')
class AppThemeModeNotifier extends _$AppThemeModeNotifier {
  @override
  AppThemeMode build() =>
      ref.watch(settingsProvider.select((settings) => settings.themeMode));

  /// Switches the appearance to [mode] and stores it; nothing happens when
  /// it is the current one. The app restyles even if storing fails; the
  /// choice then lasts for this session (see [SettingsNotifier.change]).
  ///
  /// Completes with whether the settings are stored: false when storing
  /// failed, which Settings tells the person (`settingsSaveFailedProvider`).
  Future<bool> select(AppThemeMode mode) async {
    if (mode == state) return true;
    try {
      await ref
          .read(settingsProvider.notifier)
          .change((settings) => settings.copyWith(themeMode: mode));
      return true;
    } on SettingsStoreException {
      // Kept for this session; the caller reports it.
      return false;
    }
  }
}
