import 'dart:convert';
import 'dart:io';

import 'package:ferman/recent/recent_files.dart';
import 'package:path_provider/path_provider.dart';

/// The desktop [RecentFilesStore]: `recent_files.json` beside
/// `settings.json` in the app support directory (ADR 0021), written the
/// same way.
///
/// - **Safe writes.** [save] writes `recent_files.json.tmp`, flushes it
///   and renames it over the file, one save at a time in call order, so a
///   crash leaves the old list or the new one.
/// - **Never stuck on a bad file.** A file that is not the list is moved
///   aside to `recent_files.json.unreadable` and the list starts empty.
/// - **Versioned.** `{"version": 1, "files": [...]}`; an entry that does not
///   read is skipped.
final class FileRecentFilesStore implements RecentFilesStore {
  /// A store for `recent_files.json` in [directory].
  new(this.directory);

  /// The store in the app support directory (inside the container while the
  /// macOS App Sandbox is on, Q18).
  static Future<FileRecentFilesStore> open() async =>
      FileRecentFilesStore(await getApplicationSupportDirectory());

  /// The file's name.
  static const String fileName = 'recent_files.json';

  /// The format this store writes.
  static const int version = 1;

  /// The directory that holds [file].
  final Directory directory;

  Future<void> _lastSave = Future<void>.value();

  /// The recent files' file.
  File get file => File('${directory.path}${Platform.pathSeparator}$fileName');

  File get _temporary => File('${file.path}.tmp');

  File get _unreadable => File('${file.path}.unreadable');

  @override
  Future<List<RecentEntry>> load() async {
    final String text;
    try {
      if (!file.existsSync()) return const [];
      text = await file.readAsString();
    } on FileSystemException {
      return const [];
    }
    try {
      final json = jsonDecode(text);
      if (json is Map<String, Object?> && json['files'] is List) {
        return [
          for (final entry in json['files']! as List)
            ?RecentEntry.fromJson(entry),
        ];
      }
    } on FormatException {
      // Set aside below.
    }
    try {
      await file.rename(_unreadable.path);
    } on FileSystemException {
      // The next save replaces the file.
    }
    return const [];
  }

  @override
  Future<void> save(List<RecentEntry> files) {
    final next = _lastSave.then((_) => _write(files));
    // A failed save must not block the ones after it.
    _lastSave = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(List<RecentEntry> files) async {
    final text =
        '${const JsonEncoder.withIndent('  ').convert({
          'version': version,
          'files': [for (final file in files) file.toJson()],
        })}\n';
    try {
      await directory.create(recursive: true);
      await _temporary.writeAsString(text, flush: true);
      await _temporary.rename(file.path);
    } on FileSystemException {
      try {
        if (_temporary.existsSync()) await _temporary.delete();
      } on FileSystemException {
        // Nothing more to clean up.
      }
      rethrow;
    }
  }
}

/// Opens the recent files' store of this platform.
Future<RecentFilesStore> openRecentFilesStore() => FileRecentFilesStore.open();

/// The user's home directory on macOS and Linux, which the recent files
/// show as "~"; null on Windows, whose paths keep their drive. Under the
/// macOS App Sandbox `HOME` is the app's container
/// (`~/Library/Containers/<id>/Data`), so the part before it is taken.
String? userHomeDirectory() {
  if (Platform.isWindows) return null;
  return homeOutsideContainer(Platform.environment['HOME']);
}

/// [home] without a macOS sandbox container's part; null when it is not a
/// usable directory.
String? homeOutsideContainer(String? home) {
  if (home == null || home.length < 2) return null;
  const container = '/Library/Containers/';
  final at = home.indexOf(container);
  return at > 0 ? home.substring(0, at) : home;
}
