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
/// The app restyles at once when it changes, without a restart. It is held
/// in memory for now and starts at [AppThemeMode.system]; the settings store
/// (M1 step 9) loads and persists it.
@Riverpod(keepAlive: true, name: 'themeModeProvider')
class AppThemeModeNotifier extends _$AppThemeModeNotifier {
  @override
  AppThemeMode build() => AppThemeMode.system;

  /// Switches the appearance to [mode]; nothing happens when it is the
  /// current one.
  void select(AppThemeMode mode) {
    if (mode == state) return;
    state = mode;
  }
}
