import 'package:ferman/app/app.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/engine_service_frb.dart';
import 'package:ferman/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// One file on purpose: on Linux desktop, `flutter test integration_test`
// cannot start the app a second time for a second file ("The log reader
// stopped unexpectedly"), so every integration test lives here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the built app starts and shows the root widget', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.byType(FermanApp), findsOneWidget);
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
      final watch = Stopwatch()..start();
      final length = await engine.debugBytesLength(1024 * 1024);
      watch.stop();
      expect(length, 1024 * 1024);
      // Recorded for ARCHITECTURE §3.4; the 0.2 ms budget is checked on R1
      // and R2 with a release build.
      // ignore: avoid_print
      print('debug_bytes 1 MiB round trip: ${watch.elapsedMicroseconds} us');
    });
  });
}
