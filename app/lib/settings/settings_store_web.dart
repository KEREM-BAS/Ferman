import 'dart:convert';
import 'dart:js_interop';

import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_store.dart';

@JS('localStorage')
external _Storage? get _localStorage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

/// The web [SettingsStore]: the settings JSON in the browser's
/// `localStorage`, which stays in this browser on this device.
///
/// Storage that is blocked or full (a private window, site data turned off)
/// loads the defaults and fails saves with a [SettingsStoreException], as
/// the desktop store does on a disk error.
final class LocalStorageSettingsStore implements SettingsStore {
  /// The key the settings are stored under.
  static const String key = 'ferman.settings';

  @override
  Future<AppSettings> load() async {
    try {
      final text = _localStorage?.getItem(key);
      if (text == null) return const AppSettings();
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) return AppSettings.fromJson(json);
    } on Object {
      // Blocked storage or an unreadable value: the defaults.
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) async {
    final storage = _localStorage;
    try {
      if (storage == null) throw StateError('no localStorage');
      storage.setItem(key, jsonEncode(settings.toJson()));
    } on Object {
      throw const SettingsStoreException('could not store the settings');
    }
  }
}

/// Opens the settings store of this platform.
Future<SettingsStore> openSettingsStore() async => LocalStorageSettingsStore();
