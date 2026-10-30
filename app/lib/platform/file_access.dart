import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_access.g.dart';

/// A file reached again through its bookmark: where it is now, and a fresh
/// bookmark when the old one went stale.
@immutable
final class BookmarkAccess {
  /// The file at [path], with [renewed] to keep in place of the old
  /// bookmark when it went stale.
  const new({required this.path, this.renewed});

  /// Where the file is now; it may have moved since the bookmark was made.
  final String path;

  /// The bookmark to keep from now on, or null when the old one holds.
  final String? renewed;
}

/// Reaching files again after a restart under the macOS App Sandbox (Q18,
/// ADR 0021): a security-scoped bookmark made while the user's grant holds
/// (the open panel, a drop, "Open with"), resolved when the file is opened
/// from the recent files. Every such call goes through it, as
/// `fileAccessProvider`, and tests give it a fake. Windows and Linux need
/// none: there it makes no bookmarks.
abstract interface class FileAccess {
  /// A bookmark of the file at [path], made while Ferman may read it; null
  /// where none is needed or it cannot be made.
  Future<String?> bookmark(String path);

  /// Starts access to the file of [bookmark] for this session; null when it
  /// cannot be resolved (the file is gone, or the bookmark is not one).
  Future<BookmarkAccess?> access(String bookmark);
}

/// No bookmarks: Windows, Linux and the web, and tests by default.
final class NoFileAccess implements FileAccess {
  /// Makes and resolves none.
  const new();

  @override
  Future<String?> bookmark(String path) async => null;

  @override
  Future<BookmarkAccess?> access(String bookmark) async => null;
}

/// The runner's bookmarks over the `ferman/files` channel
/// (`MainFlutterWindow.swift`); a runner without a handler makes none.
final class PlatformFileAccess implements FileAccess {
  /// Talks to the runner over `ferman/files`, or over the channel given
  /// (tests).
  const new([this._channel = const MethodChannel(channelName)]);

  /// The channel's name.
  static const String channelName = 'ferman/files';

  final MethodChannel _channel;

  @override
  Future<String?> bookmark(String path) async {
    try {
      return await _channel.invokeMethod<String>('bookmark', path);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<BookmarkAccess?> access(String bookmark) async {
    Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>('access', bookmark);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    if (reply is! Map) return null;
    final path = reply['path'];
    final renewed = reply['renewed'];
    if (path is! String || path.isEmpty) return null;
    return BookmarkAccess(
      path: path,
      renewed: renewed is String ? renewed : null,
    );
  }
}

/// The platform's bookmarks, as `fileAccessProvider`; `bootstrap()` gives
/// the runner's.
@Riverpod(keepAlive: true)
FileAccess fileAccess(Ref ref) => const NoFileAccess();
