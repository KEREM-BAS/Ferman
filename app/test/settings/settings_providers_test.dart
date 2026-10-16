import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FailingStore implements SettingsStore {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async =>
      throw const SettingsStoreException('disk full');
}

void main() {
  ProviderContainer containerWith(
    SettingsStore store, {
    AppSettings initial = const AppSettings(),
  }) {
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        initialSettingsProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('settingsProvider', () {
    test('starts from the loaded settings', () {
      final container = containerWith(
        MemorySettingsStore(),
        initial: const AppSettings(languageCode: 'ar'),
      );
      expect(container.read(settingsProvider).languageCode, 'ar');
    });

    test('a change applies at once and is stored', () async {
      final store = MemorySettingsStore();
      final container = containerWith(store);
      await container
          .read(settingsProvider.notifier)
          .change((s) => s.copyWith(regionCode: () => 'TR'));
      expect(container.read(settingsProvider).regionCode, 'TR');
      expect((await store.load()).regionCode, 'TR');
      expect(store.saves, 1);
    });

    test('an unchanged result stores nothing', () async {
      final store = MemorySettingsStore();
      final container = containerWith(store);
      await container.read(settingsProvider.notifier).change((s) => s);
      expect(store.saves, 0);
    });

    test('a failed save throws but keeps the change for the session', () async {
      final container = containerWith(_FailingStore());
      await expectLater(
        container
            .read(settingsProvider.notifier)
            .change((s) => s.copyWith(languageCode: () => 'tr')),
        throwsA(isA<SettingsStoreException>()),
      );
      expect(container.read(settingsProvider).languageCode, 'tr');
    });
  });

  group('themeModeProvider', () {
    test('is the stored theme', () {
      final container = containerWith(
        MemorySettingsStore(),
        initial: const AppSettings(themeMode: AppThemeMode.dark),
      );
      expect(container.read(themeModeProvider), AppThemeMode.dark);
    });

    test('select changes and stores the theme', () async {
      final store = MemorySettingsStore();
      final container = containerWith(store);
      await container
          .read(themeModeProvider.notifier)
          .select(AppThemeMode.light);
      expect(container.read(themeModeProvider), AppThemeMode.light);
      expect((await store.load()).themeMode, AppThemeMode.light);
    });

    test('a failed save still switches the theme', () async {
      final container = containerWith(_FailingStore());
      await container
          .read(themeModeProvider.notifier)
          .select(AppThemeMode.dark);
      expect(container.read(themeModeProvider), AppThemeMode.dark);
    });
  });
}
