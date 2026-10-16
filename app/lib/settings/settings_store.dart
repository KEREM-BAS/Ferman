import 'package:ferman/settings/app_settings.dart';

/// Loads and saves the [AppSettings].
///
/// The desktop store (`FileSettingsStore`) writes `settings.json` in the
/// app's own support directory and nothing else; settings never leave the
/// device (ARCHITECTURE.md §12, ADR 0011). Tests and the web build use
/// [MemorySettingsStore].
abstract interface class SettingsStore {
  /// The stored settings, or the defaults when nothing is stored yet or the
  /// stored file cannot be read.
  Future<AppSettings> load();

  /// Stores [settings], replacing what was stored. A failure throws a
  /// [SettingsStoreException] and leaves the previous settings in place.
  Future<void> save(AppSettings settings);
}

/// Saving the settings failed.
final class SettingsStoreException implements Exception {
  /// A failure described by [message] (structural facts, never paths).
  const new(this.message);

  /// What failed.
  final String message;

  @override
  String toString() => 'SettingsStoreException: $message';
}

/// A [SettingsStore] that keeps the settings in memory only: tests, and the
/// web build until phase 5 decides its storage.
final class MemorySettingsStore implements SettingsStore {
  /// A store holding [initial].
  new([AppSettings initial = const AppSettings()]) : _settings = initial;

  AppSettings _settings;

  /// How many times [save] was called.
  int saves = 0;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    saves++;
    _settings = settings;
  }
}
