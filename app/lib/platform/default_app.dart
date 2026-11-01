import 'package:ferman/platform/file_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'default_app.g.dart';

/// The app that opens PDF files when one is double-clicked.
@immutable
final class PdfHandler {
  /// The app named [name], which is Ferman when [ferman].
  const new({required this.name, required this.ferman});

  /// The app's name as the system shows it ("Preview", "Önizleme").
  final String name;

  /// Whether it is Ferman.
  final bool ferman;
}

/// Asks the system which app opens PDF files and makes Ferman that app
/// (B080, a1-3, a11-1). Only macOS can: elsewhere it knows nothing and
/// changes nothing (B101, B102).
abstract interface class DefaultPdfApp {
  /// The app that opens PDF files now; null when the system does not say.
  Future<PdfHandler?> current();

  /// Asks the system to make Ferman the app that opens PDF files; macOS
  /// asks the person to confirm. False when it did not change.
  Future<bool> makeFerman();
}

/// No default-app lookup: Windows, Linux, the web, and tests by default.
final class NoDefaultPdfApp implements DefaultPdfApp {
  /// Knows and changes nothing.
  const new();

  @override
  Future<PdfHandler?> current() async => null;

  @override
  Future<bool> makeFerman() async => false;
}

/// The macOS runner's lookup over `ferman/files` (`MainFlutterWindow.swift`,
/// `NSWorkspace`).
final class PlatformDefaultPdfApp implements DefaultPdfApp {
  /// Talks to the runner over `ferman/files`, or over the channel given
  /// (tests).
  const new([
    this._channel = const MethodChannel(PlatformFileAccess.channelName),
  ]);

  final MethodChannel _channel;

  @override
  Future<PdfHandler?> current() async {
    Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>('pdfHandler');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    if (reply is! Map) return null;
    final name = reply['name'];
    if (name is! String || name.isEmpty) return null;
    return PdfHandler(name: name, ferman: reply['ferman'] == true);
  }

  @override
  Future<bool> makeFerman() async {
    try {
      return await _channel.invokeMethod<bool>('makeDefault') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// The system's default-app lookup, as `defaultPdfAppProvider`;
/// `bootstrap()` gives the runner's on macOS.
@Riverpod(keepAlive: true)
DefaultPdfApp defaultPdfApp(Ref ref) => const NoDefaultPdfApp();

/// The app that opens PDF files now; null when the system does not say.
/// Invalidated after Ferman asks to become it.
@riverpod
Future<PdfHandler?> pdfHandler(Ref ref) =>
    ref.watch(defaultPdfAppProvider).current();

/// Asks the system to make Ferman the app that opens PDF files, then looks
/// again (Settings › General, a1-3). False when it did not change.
Future<bool> makeFermanDefault(WidgetRef ref) async {
  final made = await ref.read(defaultPdfAppProvider).makeFerman();
  ref.invalidate(pdfHandlerProvider);
  return made;
}
