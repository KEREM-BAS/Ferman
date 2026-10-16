import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:path_provider/path_provider.dart';

/// The desktop [SettingsStore]: `settings.json` in a directory of the app's
/// own (the app support directory, [open]).
///
/// - **Safe writes.** [save] writes `settings.json.tmp`, flushes it to disk
///   and renames it over `settings.json`, so a crash or a full disk leaves
///   either the old or the new file, never a half-written one (the file
///   safety rule of CLAUDE.md, applied to the app's own file). Saves run one
///   at a time in call order.
/// - **Never stuck on a bad file.** A file that is not valid JSON is moved
///   aside to `settings.json.unreadable` (replacing an earlier one) and the
///   defaults are used, so the app always starts.
/// - **Forward compatible.** Unknown keys and a newer format version are
///   kept ([AppSettings.unknown], [AppSettings.version]).
///
/// Chosen over shared_preferences, which on macOS writes to the user's
/// preferences domain outside the app data directory (ARCHITECTURE.md §12).
final class FileSettingsStore implements SettingsStore {
  /// A store for `settings.json` in [directory].
  new(this.directory);

  /// The store in the app support directory (inside the container while the
  /// macOS App Sandbox is on, Q18).
  static Future<FileSettingsStore> open() async =>
      FileSettingsStore(await getApplicationSupportDirectory());

  /// The settings file's name.
  static const String fileName = 'settings.json';

  /// The directory that holds [file].
  final Directory directory;

  Future<void> _lastSave = Future<void>.value();

  /// The settings file.
  File get file => File('${directory.path}${Platform.pathSeparator}$fileName');

  File get _temporary => File('${file.path}.tmp');

  File get _unreadable => File('${file.path}.unreadable');

  @override
  Future<AppSettings> load() async {
    final String text;
    try {
      if (!file.existsSync()) return const AppSettings();
      text = await file.readAsString();
    } on FileSystemException {
      return const AppSettings();
    }
    try {
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) return AppSettings.fromJson(json);
    } on FormatException {
      // Set aside below.
    }
    try {
      await file.rename(_unreadable.path);
    } on FileSystemException {
      // Keep using the defaults; the next save replaces the file.
    }
    return const AppSettings();
  }

  @override
  Future<void> save(AppSettings settings) {
    final next = _lastSave.then((_) => _write(settings));
    // A failed save must not block the ones after it.
    _lastSave = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(AppSettings settings) async {
    final text =
        '${const JsonEncoder.withIndent('  ').convert(settings.toJson())}\n';
    try {
      await directory.create(recursive: true);
      await _temporary.writeAsString(text, flush: true);
      await _temporary.rename(file.path);
    } on FileSystemException catch (error) {
      try {
        if (_temporary.existsSync()) await _temporary.delete();
      } on FileSystemException {
        // Nothing more to clean up.
      }
      final code = error.osError?.errorCode;
      throw SettingsStoreException(
        'could not write the settings (OS error ${code ?? 'unknown'})',
      );
    }
  }
}

/// Opens the settings store of this platform.
Future<SettingsStore> openSettingsStore() => FileSettingsStore.open();
