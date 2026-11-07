import 'package:ferman/engine/engine_models.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'print_service.g.dart';

/// The system's printing (a9-6, decision 29): no package, a channel to the
/// runner. [begin] shows the system print dialog, which picks the printer,
/// the copies and both sides; the pages then go one at a time, each sent
/// once the one before is drawn, so a long document never waits in memory;
/// [end] hands the job to the system's spooler, [abort] drops it.
abstract interface class PrintService {
  /// Shows the system print dialog for a print of [pages] pages named
  /// [name]; false when the person cancelled it or no printer could start.
  /// With [fit], each page is scaled to the printable area; without, it
  /// prints at its own size, centred.
  Future<bool> begin({
    required String name,
    required int pages,
    required bool fit,
  });

  /// Draws [page], the print's page [at] (from 0), when the system asks for
  /// it; the print's page the system wants next, `at + 1` when it takes them
  /// in order and the page count once the print is complete, or null when
  /// the print stopped. Linux's dialog picks pages, reverses them and repeats
  /// them for copies itself, so its runner names the page it wants.
  Future<int?> page(PrintPage page, {required int at});

  /// Sends what was drawn to the printer.
  Future<void> end();

  /// Drops the print, after a failure.
  Future<void> abort();
}

/// No printing: the web, and tests by default.
final class NoPrintService implements PrintService {
  /// Prints nothing.
  const new();

  @override
  Future<bool> begin({
    required String name,
    required int pages,
    required bool fit,
  }) async => false;

  @override
  Future<int?> page(PrintPage page, {required int at}) async => null;

  @override
  Future<void> end() async {}

  @override
  Future<void> abort() async {}
}

/// The runner's printing over the `ferman/print` channel
/// (`MainFlutterWindow.swift`, `print_channel.cpp`, `my_application.cc`); a
/// runner without a handler prints nothing.
final class PlatformPrintService implements PrintService {
  /// Talks to the runner over `ferman/print`, or over the channel given
  /// (tests).
  const new([this._channel = const MethodChannel(channelName)]);

  /// The channel's name.
  static const String channelName = 'ferman/print';

  final MethodChannel _channel;

  Future<bool> _call(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> begin({
    required String name,
    required int pages,
    required bool fit,
  }) => _call('begin', {'name': name, 'pages': pages, 'fit': fit});

  /// A runner that answers `true` takes the pages in order; one that
  /// answers a number names the page it wants next.
  @override
  Future<int?> page(PrintPage page, {required int at}) async {
    try {
      final answer = await _channel.invokeMethod<Object?>('page', {
        'index': at,
        'width': page.width,
        'height': page.height,
        'widthPoints': page.widthPoints,
        'heightPoints': page.heightPoints,
        'pixels': page.pixels,
      });
      return switch (answer) {
        final int next when next >= 0 => next,
        true => at + 1,
        _ => null,
      };
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> end() => _call('end');

  @override
  Future<void> abort() => _call('abort');
}

/// The system's printing, as `printServiceProvider`; `bootstrap()` gives the
/// runner's.
@Riverpod(keepAlive: true)
PrintService printService(Ref ref) => const NoPrintService();
