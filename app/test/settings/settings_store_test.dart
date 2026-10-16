import 'dart:convert';
import 'dart:io';

import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:ferman/settings/settings_store_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late FileSettingsStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ferman_settings_');
    store = FileSettingsStore(Directory('${root.path}/support'));
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('FileSettingsStore', () {
    test('loads the defaults when nothing is stored', () async {
      expect(await store.load(), const AppSettings());
      expect(store.directory.existsSync(), isFalse);
    });

    test('saves and loads, creating the directory', () async {
      const settings = AppSettings(
        themeMode: AppThemeMode.dark,
        languageCode: 'tr',
        onboardingCompleted: true,
      );
      await store.save(settings);
      expect(store.file.existsSync(), isTrue);
      expect(await FileSettingsStore(store.directory).load(), settings);
      final json = jsonDecode(store.file.readAsStringSync());
      expect(json, containsPair('version', 1));
      expect(json, containsPair('theme', 'dark'));
    });

    test('replaces the file and leaves no temporary file', () async {
      await store.save(const AppSettings(themeMode: AppThemeMode.light));
      await store.save(const AppSettings(themeMode: AppThemeMode.dark));
      expect((await store.load()).themeMode, AppThemeMode.dark);
      expect(store.directory.listSync().map((e) => e.uri.pathSegments.last), [
        FileSettingsStore.fileName,
      ]);
    });

    test('saves run in call order', () async {
      await Future.wait([
        for (final mode in [
          AppThemeMode.light,
          AppThemeMode.dark,
          AppThemeMode.system,
          AppThemeMode.dark,
        ])
          store.save(AppSettings(themeMode: mode)),
      ]);
      expect((await store.load()).themeMode, AppThemeMode.dark);
    });

    test(
      'sets an unreadable file aside and starts from the defaults',
      () async {
        store.directory.createSync(recursive: true);
        store.file.writeAsStringSync('{"theme": "dark",');
        expect(await store.load(), const AppSettings());
        expect(store.file.existsSync(), isFalse);
        final aside = File('${store.file.path}.unreadable');
        expect(aside.readAsStringSync(), '{"theme": "dark",');

        // A JSON value that is not an object is unreadable too.
        store.file.writeAsStringSync('[1, 2]');
        expect(await store.load(), const AppSettings());
        expect(aside.readAsStringSync(), '[1, 2]');
      },
    );

    test('keeps keys written by a newer build', () async {
      store.directory.createSync(recursive: true);
      store.file.writeAsStringSync(
        jsonEncode({'version': 2, 'theme': 'light', 'later': 'kept'}),
      );
      final loaded = await store.load();
      await store.save(loaded.copyWith(themeMode: AppThemeMode.dark));
      final json = jsonDecode(store.file.readAsStringSync()) as Map;
      expect(json['later'], 'kept');
      expect(json['version'], 2);
      expect(json['theme'], 'dark');
    });

    test('a failed save throws and keeps the previous file', () async {
      await store.save(const AppSettings(themeMode: AppThemeMode.light));
      // A directory where the temporary file must go makes the write fail.
      Directory('${store.file.path}.tmp').createSync();
      await expectLater(
        store.save(const AppSettings(themeMode: AppThemeMode.dark)),
        throwsA(isA<SettingsStoreException>()),
      );
      expect((await store.load()).themeMode, AppThemeMode.light);
      // A later save still runs.
      Directory('${store.file.path}.tmp').deleteSync();
      await store.save(const AppSettings(themeMode: AppThemeMode.dark));
      expect((await store.load()).themeMode, AppThemeMode.dark);
    });
  });

  group('MemorySettingsStore', () {
    test('holds the settings and counts saves', () async {
      final memory = MemorySettingsStore(const AppSettings(regionCode: 'TR'));
      expect((await memory.load()).regionCode, 'TR');
      await memory.save(const AppSettings(regionCode: 'US'));
      expect((await memory.load()).regionCode, 'US');
      expect(memory.saves, 1);
    });
  });
}
