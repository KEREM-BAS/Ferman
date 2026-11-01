import 'package:ferman/platform/file_access.dart';

/// File access that makes no bookmarks and records the files shown in the
/// file manager and the accesses released; with [stagingDirectory] it
/// names that staging directory and records the files swapped in.
final class RecordingFileAccess implements FileAccess {
  /// The paths [show] was asked for, oldest first.
  final List<String> shown = [];

  /// The paths [release] was asked for, oldest first.
  final List<String> released = [];

  @override
  Future<String?> bookmark(String path) async => null;

  @override
  Future<BookmarkAccess?> access(String bookmark) async => null;

  @override
  Future<void> release(String path) async => released.add(path);

  @override
  Future<bool> show(String path) async {
    shown.add(path);
    return true;
  }

  /// The staging directory [staging] names, as the macOS sandbox does.
  String? stagingDirectory;

  /// The staged files swapped in, with their paths, oldest first.
  final List<(String, String)> swapped = [];

  @override
  Future<String?> staging(String path) async => stagingDirectory;

  @override
  Future<bool> swapIn(String staged, String path) async {
    swapped.add((staged, path));
    return true;
  }
}
