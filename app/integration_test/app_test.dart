import 'package:ferman/app/app.dart';
import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/app/window_frame.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/engine_service_frb.dart';
import 'package:ferman/main.dart' as app;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// One file on purpose: on Linux desktop, `flutter test integration_test`
// cannot start the app a second time for a second file ("The log reader
// stopped unexpectedly"), so every integration test lives here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the built app starts with its own title bar', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.byType(FermanApp), findsOneWidget);
    // Integration tests run on the desktop, where bootstrap hides the
    // system title bar and Ferman draws its own.
    expect(find.byType(TitleBar), findsOneWidget);
    // The runner answered with the system's double-click settings.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FermanApp)),
    );
    expect(
      container.read(desktopWindowProvider).doubleClick,
      isNot(DoubleClickSettings.fallback),
    );
  });

  group('engine through the bridge', () {
    late FrbEngineService engine;

    setUpAll(() async {
      engine = await FrbEngineService.start();
    });

    test('speaks the API version the app was built for', () {
      expect(engine.apiVersion(), kAppApiVersion);
    });

    test('reports the versions, and the bundled PDFium is loaded', () async {
      final status = await engine.status();
      expect(status.appVersion, '0.1.0');
      expect(status.apiVersion, kAppApiVersion);
      // The build bundles PDFium next to the executable (CMake on Linux and
      // Windows, the Bundle Framework phase on macOS); the engine reports it
      // loaded only after a real PDFium call.
      expect(status.pdfium, PdfiumState.loaded, reason: status.pdfiumReason);
      expect(status.pdfiumTag, 'chromium/7881');
    });

    test('a panic in Rust reaches Dart as an error and the engine keeps '
        'working', () async {
      final error = await engine.debugPanic();
      expect(error, isNotNull);
      expect(error!.messageKey, isNotEmpty);
      expect((await engine.status()).apiVersion, kAppApiVersion);
    });

    test('a 1 MiB byte vector crosses the bridge', () async {
      const length = 1024 * 1024;
      // One warm-up call, then 20 timed ones; the minimum and the median
      // are recorded for ARCHITECTURE §3.4. The 0.2 ms budget applies to a
      // profile or release build on R1 and R2. The bridge uses the Dco
      // codec (`full_dep: true`, Q19), which hands the bytes over as
      // external typed data.
      expect(await engine.debugBytesLength(length), length);
      final samples = <int>[];
      for (var i = 0; i < 20; i++) {
        final watch = Stopwatch()..start();
        final received = await engine.debugBytesLength(length);
        watch.stop();
        expect(received, length);
        samples.add(watch.elapsedMicroseconds);
      }
      samples.sort();
      // The measurement goes to the test log; there is no other reporter.
      // ignore: avoid_print
      print(
        'debug_bytes 1 MiB round trip (Dco codec): min ${samples.first} us, '
        'median ${samples[samples.length ~/ 2]} us (20 samples)',
      );
    });
  });
}
