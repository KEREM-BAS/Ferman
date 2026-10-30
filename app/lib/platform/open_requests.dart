import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'open_requests.g.dart';

/// The files the operating system asks Ferman to open (ADR 0021): a path
/// on the command line (Windows, Linux), a double-click, "Open with" or the
/// Dock (macOS), and a second launch, which the runner forwards to the
/// running instance. Every such request reaches the app through it, as
/// `openRequestsProvider`, and tests give it a fake.
abstract interface class OpenRequests {
  /// The files Ferman was started with. They open before the first frame
  /// shows, so a cold launch with a file skips Start (G25).
  List<String> get launch;

  /// Each later request, as the paths it names. Events wait until the
  /// stream is listened to.
  Stream<List<String>> get later;
}

/// No requests: the default until `bootstrap` gives the runner's.
final class NoOpenRequests implements OpenRequests {
  /// Asks for nothing.
  const new();

  @override
  List<String> get launch => const [];

  @override
  Stream<List<String>> get later => const Stream.empty();
}

/// The runner's requests over the `ferman/open` channel.
///
/// The runners keep what the system asks for until Dart calls `ready`, which
/// answers with the paths kept so far; from then on they call `open` with
/// each request's paths. The macOS runner keeps the files of
/// `application(_:open:)`, the Windows runner those a second instance sends
/// over its pipe, and the Linux runner those of GApplication's `open`
/// signal. A platform without a handler (the web) asks for nothing.
final class PlatformOpenRequests implements OpenRequests {
  new _(this._channel) {
    _channel.setMethodCallHandler(_handle);
  }

  /// The channel's name, the same in every runner.
  static const String channelName = 'ferman/open';

  /// Starts listening on [channel]: [launch] is [arguments], the paths on
  /// the command line (the Windows and Linux runners make them absolute),
  /// then the paths the runner kept.
  static Future<PlatformOpenRequests> start(
    List<String> arguments, [
    MethodChannel channel = const MethodChannel(channelName),
  ]) async {
    final requests = PlatformOpenRequests._(channel);
    List<String>? kept;
    try {
      kept = _paths(await channel.invokeMethod<Object?>('ready'));
    } on MissingPluginException {
      // No runner handler on this platform: nothing to open.
    } on PlatformException {
      // A runner that could not answer keeps nothing back.
    } on FormatException {
      // Nor does one whose answer is not well-formed UTF-8.
    }
    requests._launch = [...arguments, ...?kept];
    return requests;
  }

  final MethodChannel _channel;

  final StreamController<List<String>> _later = StreamController();

  List<String> _launch = const [];

  @override
  List<String> get launch => _launch;

  @override
  Stream<List<String>> get later => _later.stream;

  /// Stops listening to the runner.
  void dispose() {
    _channel.setMethodCallHandler(null);
    // A stream never listened to never reports its close: don't wait for it.
    unawaited(_later.close());
  }

  Future<Object?> _handle(MethodCall call) async {
    final paths = call.method == 'open' ? _paths(call.arguments) : null;
    if (paths == null) {
      throw MissingPluginException('ferman/open has no ${call.method}');
    }
    if (paths.isNotEmpty) _later.add(paths);
    return null;
  }

  /// The non-empty strings of [value] when it is a list, else null.
  static List<String>? _paths(Object? value) => value is List
      ? [
          for (final path in value)
            if (path is String && path.isNotEmpty) path,
        ]
      : null;
}

/// The system's open requests, as `openRequestsProvider`; `bootstrap`
/// gives the runner's.
@Riverpod(keepAlive: true)
OpenRequests openRequests(Ref ref) => const NoOpenRequests();
