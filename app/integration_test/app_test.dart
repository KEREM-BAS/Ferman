import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

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

    test('searches a PDF through the bridge', () async {
      final dir = await Directory.systemTemp.createTemp('ferman-search');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/text.pdf')
        ..writeAsStringSync(_onePagePdf(text: 'KIRA bedeli'));
      final document = await engine.open(file.path);
      final updates = await engine
          .search(document.id, 'kira', const SearchOptions())
          .toList();
      expect(updates.last, isA<SearchDone>());
      final matches = updates.whereType<SearchMatches>().single.matches;
      final found = matches.single;
      expect(found.page, 0);
      expect(
        found.snippet.substring(found.snippetStart, found.snippetEnd),
        'KIRA',
      );
      final rect = found.rects.single;
      // The text sits 40 points above the bottom of a 100-point page: y down.
      expect(rect.left, greaterThanOrEqualTo(10));
      expect(rect.bottom, closeTo(100 - 40 + 12 * 0.2, 0.5));
      await engine.close(document.id);
    });

    test('opens a PDF, renders its thumbnail and closes it', () async {
      // The temporary directory, because the sandboxed macOS app may read
      // only its own container.
      final dir = await Directory.systemTemp.createTemp('ferman-open');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/one-page.pdf')
        ..writeAsStringSync(_onePagePdf());
      final document = await engine.open(file.path);
      expect(document.readOnly, isNull);
      expect(document.rightToLeft, isFalse);
      expect(document.pages, hasLength(1));
      expect(document.pages.single.width, 200);
      expect(document.pages.single.height, 100);

      final view = await engine.openView(document.id);
      const thumbnail = ThumbnailItem(page: 0, size: 64);
      await engine.requestView(view.id, 1, const [
        WantedItem(thumbnail, RenderPriority.visibleThumbnail),
      ]);
      final update = await view.updates.first;
      expect(update, isA<RenderedItem>());
      final rendered = update as RenderedItem;
      expect(rendered.item, thumbnail);
      expect(rendered.generation, 1);
      expect(rendered.width, 64);
      expect(rendered.pixels, hasLength(rendered.stride * rendered.height));
      // A red page, opaque, in BGRA.
      expect(rendered.pixels.take(4), [0, 0, 255, 255]);
      // The canvas decodes the bitmap as BGRA (DocumentView).
      final decoded = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rendered.pixels,
        rendered.width,
        rendered.height,
        ui.PixelFormat.bgra8888,
        decoded.complete,
        rowBytes: rendered.stride,
      );
      final image = await decoded.future;
      addTearDown(image.dispose);
      expect((image.width, image.height), (rendered.width, rendered.height));
      final rgba = await image.toByteData();
      expect(rgba!.buffer.asUint8List(0, 4), [255, 0, 0, 255]);

      await engine.close(document.id);
      await expectLater(
        engine.close(document.id),
        throwsA(
          isA<EngineException>().having(
            (error) => error.kind,
            'kind',
            EngineErrorKind.notFound,
          ),
        ),
      );
    });

    test('a missing file fails with its kind and message key', () async {
      final missing = '${Directory.systemTemp.path}/ferman-no-such-file.pdf';
      await expectLater(
        engine.open(missing),
        throwsA(
          isA<EngineException>()
              .having((error) => error.kind, 'kind', EngineErrorKind.notFound)
              .having(
                (error) => error.messageKey,
                'messageKey',
                'errorFileNotFound',
              ),
        ),
      );
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

/// A one-page PDF of 200 × 100 points filled red, with an exact
/// cross-reference table, written by hand so the test needs no file from
/// outside the app. Red tells BGRA from RGBA.
/// A red 200 × 100 page, with [text] in Helvetica when given.
String _onePagePdf({String? text}) {
  final content =
      '1 0 0 rg 0 0 200 100 re f'
      '${text == null ? '' : ' 0 g BT /F1 12 Tf 10 40 Td ($text) Tj ET'}';
  const page =
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Contents 4 0 R '
      '/Resources << /Font << /F1 5 0 R >> >> >>';
  const font =
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
      '/Encoding /WinAnsiEncoding >>';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    page,
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
    font,
  ];
  // ASCII only, so string offsets are byte offsets.
  final pdf = StringBuffer('%PDF-1.7\n');
  final offsets = <int>[];
  for (final (index, object) in objects.indexed) {
    offsets.add(pdf.length);
    pdf.write('${index + 1} 0 obj\n$object\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final offset in offsets) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return pdf.toString();
}
