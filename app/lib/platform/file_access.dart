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

/// Why [FileAccess.swapIn] could not put a file in place.
enum SwapFailure {
  /// No permission to change the file or its folder, or the volume is
  /// read-only.
  permission,

  /// The volume is full.
  diskFull,

  /// Another app holds the file.
  locked,

  /// The file's folder or volume is gone.
  volumeGone,

  /// Anything else, or no answer from the runner.
  other,
}

/// Reaching files again after a restart under the macOS App Sandbox (Q18,
/// ADR 0021): a security-scoped bookmark made while the user's grant holds
/// (the open panel, a drop, "Open with"), resolved when the file is opened
/// from the recent files. Every such call goes through it, as
/// `fileAccessProvider`, and tests give it a fake. Windows and Linux need
/// none: there it makes no bookmarks. It also shows a file in the system's
/// file manager on every system (a1-9b).
abstract interface class FileAccess {
  /// A bookmark of the file at [path], made while Ferman may read it; null
  /// where none is needed or it cannot be made.
  Future<String?> bookmark(String path);

  /// Starts access to the file of [bookmark] for this session; null when it
  /// cannot be resolved (the file is gone, or the bookmark is not one).
  Future<BookmarkAccess?> access(String bookmark);

  /// Ends the access [access] started to the file at [path], once its
  /// document closed (B029); nothing when none was started.
  Future<void> release(String path);

  /// Shows the file at [path] selected in Finder, File Explorer or the file
  /// manager; false when it could not.
  Future<bool> show(String path);

  /// Under the macOS App Sandbox, a directory on the volume of [path] where
  /// a file for it may be written first (the system's item-replacement
  /// directory, ADR 0008); null where the engine writes beside the file.
  Future<String?> staging(String path);

  /// Puts the written file [staged] in place of [path] (`replaceItemAt`)
  /// and removes its staging directory; why not when it could not, or null,
  /// and the staged file is gone either way.
  Future<SwapFailure?> swapIn(String staged, String path);

  /// Removes the empty [directory] that [staging] named, when the engine
  /// stopped before staging anything (a refused save).
  Future<void> discardStaging(String directory);
}

/// No bookmarks: Windows, Linux and the web, and tests by default.
final class NoFileAccess implements FileAccess {
  /// Makes and resolves none.
  const new();

  @override
  Future<String?> bookmark(String path) async => null;

  @override
  Future<BookmarkAccess?> access(String bookmark) async => null;

  @override
  Future<void> release(String path) async {}

  @override
  Future<bool> show(String path) async => false;

  @override
  Future<String?> staging(String path) async => null;

  @override
  Future<SwapFailure?> swapIn(String staged, String path) async =>
      SwapFailure.other;

  @override
  Future<void> discardStaging(String directory) async {}
}

/// The runner's file access over the `ferman/files` channel
/// (`MainFlutterWindow.swift`; on Windows `file_manager.cpp` and on Linux
/// `my_application.cc`, which answer only "show"); a runner without a
/// handler makes no bookmarks, shows nothing and names no staging
/// directory.
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

  @override
  Future<void> release(String path) async {
    try {
      await _channel.invokeMethod<void>('release', path);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  @override
  Future<bool> show(String path) async {
    try {
      return await _channel.invokeMethod<bool>('show', path) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<String?> staging(String path) async {
    try {
      return await _channel.invokeMethod<String>('staging', path);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<SwapFailure?> swapIn(String staged, String path) async {
    try {
      final reply = await _channel.invokeMethod<Object?>('swapIn', {
        'staged': staged,
        'path': path,
      });
      return reply == true
          ? null
          : SwapFailure.values.asNameMap()[reply] ?? SwapFailure.other;
    } on MissingPluginException {
      return SwapFailure.other;
    } on PlatformException {
      return SwapFailure.other;
    }
  }

  @override
  Future<void> discardStaging(String directory) async {
    try {
      await _channel.invokeMethod<void>('discardStaging', directory);
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

/// The platform's bookmarks, as `fileAccessProvider`; `bootstrap()` gives
/// the runner's.
@Riverpod(keepAlive: true)
FileAccess fileAccess(Ref ref) => const NoFileAccess();
