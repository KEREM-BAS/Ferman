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

  /// The bookmarks [access] was asked for, oldest first.
  final List<String> accessed = [];

  /// Runs when [access] is asked for a bookmark.
  void Function()? onAccess;

  @override
  Future<BookmarkAccess?> access(String bookmark) async {
    accessed.add(bookmark);
    onAccess?.call();
    return null;
  }

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

  /// Why [swapIn] fails, if it does: the staged file is then gone, as on
  /// macOS.
  SwapFailure? swapFailure;

  @override
  Future<SwapFailure?> swapIn(String staged, String path) async {
    if (swapFailure == null) swapped.add((staged, path));
    return swapFailure;
  }

  /// The staging directories discarded, oldest first.
  final List<String> discarded = [];

  @override
  Future<void> discardStaging(String directory) async =>
      discarded.add(directory);
}
