import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

/// Where the settings are stored. `bootstrap()` overrides it with the
/// platform's store; without an override the settings live in memory.
@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) => MemorySettingsStore();

/// The settings loaded at start-up. `bootstrap()` loads them before the
/// first frame and overrides this, so the first frame already has the
/// user's theme and language.
@Riverpod(keepAlive: true)
AppSettings initialSettings(Ref ref) => const AppSettings();

/// The current [AppSettings], as `settingsProvider`.
///
/// Every change goes through [change], which updates the app at once and
/// then stores the new settings.
@Riverpod(keepAlive: true, name: 'settingsProvider')
class SettingsNotifier extends _$SettingsNotifier {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  /// Applies [update] to the settings and stores the result. The new
  /// settings take effect at once; a failed save throws a
  /// [SettingsStoreException] and keeps them for this session.
  Future<void> change(AppSettings Function(AppSettings current) update) async {
    final next = update(state);
    if (next == state) return;
    state = next;
    await ref.read(settingsStoreProvider).save(next);
  }
}
