import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ferman/app/app.dart';
import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/app/window_frame.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/engine_service_frb.dart';
import 'package:ferman/main.dart' as app;
import 'package:ferman/platform/open_requests.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'corpus_pdfs.dart';

// One file on purpose: on Linux desktop, `flutter test integration_test`
// cannot start the app a second time for a second file ("The log reader
// stopped unexpectedly"), so every integration test lives here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the built app starts with its own title bar', (tester) async {
    await app.main(const []);
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
    // The runner answers the open channel (ADR 0021), with nothing kept
    // back, since nothing asked it to open a file.
    expect(container.read(openRequestsProvider).launch, isEmpty);
    expect(
      await const MethodChannel(PlatformOpenRequests.channelName)
          .invokeMethod<List<Object?>>('ready'),
      isEmpty,
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

    test('sorts names in Turkish order (ADR 0021)', () async {
      // Ç after C, ı before i, digits by their value.
      expect(
        await engine.collationOrder('tr', [
          'Çağrı.pdf',
          'ikna.pdf',
          'Cuma.pdf',
          'Fatura 10.pdf',
          'ılık.pdf',
          'Fatura 2.pdf',
        ]),
        [2, 0, 5, 3, 4, 1],
      );
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
      expect(document.version, isNotEmpty);
      expect(document.fileSize, file.lengthSync());
      expect(document.security, isNull);
      expect(document.scripts, 0);
      expect(await engine.unlockOwner(document.id, ''), isNull);

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

    // M2 budgets (ARCHITECTURE §14): the engine and bridge parts of the
    // first page and of search on 500 pages, timed in Dart. The budgets
    // hold for a profile build on R1 and R2 (`flutter drive --profile`);
    // a debug build only logs its numbers.
    test('M2 budgets: the first page of 500 pages', () async {
      final dir = await Directory.systemTemp.createTemp('ferman-budget');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/pages-500.pdf')
        ..writeAsStringSync(_pagesPdf(500));
      final watch = Stopwatch()..start();
      final document = await engine.open(file.path);
      expect(document.pages, hasLength(500));
      final view = await engine.openView(document.id);
      const tile = TileItem(
        page: 0,
        zoomBucket: 0,
        devicePixelRatio: 2,
        column: 0,
        row: 0,
      );
      await engine.requestView(view.id, 1, const [
        WantedItem(tile, RenderPriority.visible),
      ]);
      final update = await view.updates.firstWhere(
        (update) => update is RenderedItem,
      );
      watch.stop();
      expect((update as RenderedItem).item, tile);
      // The measurement goes to the test log; there is no other reporter.
      // ignore: avoid_print
      print(
        'M2 budget: open 500 pages and the first tile through the bridge: '
        '${watch.elapsedMilliseconds} ms (budget 1,000 ms)',
      );
      if (kProfileMode) expect(watch.elapsedMilliseconds, lessThan(1000));
      await engine.close(document.id);
    });

    test('M2 budgets: search across 500 pages', () async {
      final dir = await Directory.systemTemp.createTemp('ferman-budget');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/pages-500.pdf')
        ..writeAsStringSync(_pagesPdf(500));
      final document = await engine.open(file.path);
      final watch = Stopwatch()..start();
      int? first;
      var found = 0;
      await for (final update in engine.search(
        document.id,
        'caretaker',
        const SearchOptions(),
      )) {
        if (update is SearchMatches) {
          first ??= watch.elapsedMilliseconds;
          found += update.matches.length;
        }
      }
      watch.stop();
      final rate = 500 / (watch.elapsedMilliseconds / 1000);
      // The measurement goes to the test log.
      // ignore: avoid_print
      print(
        'M2 budget: search 500 pages: first match $first ms (budget 200), '
        'all $found in ${watch.elapsedMilliseconds} ms, '
        '${rate.round()} pages/s (budget 100)',
      );
      // Seven of each page's 30 lines have the word.
      expect(found, 500 * 7);
      if (kProfileMode) {
        expect(first, lessThan(200));
        expect(rate, greaterThanOrEqualTo(100));
      }
      await engine.close(document.id);
    });

    group('Flow A', () {
      late Directory dir;

      setUp(() async {
        // The temporary directory: the sandboxed macOS app may write only
        // inside its own container.
        dir = await Directory.systemTemp.createTemp('ferman-flow-a');
        addTearDown(() => dir.delete(recursive: true));
      });

      // Opens a document that goes without leaving recovery files behind, in
      // the app's real recovery folder, even when the test fails.
      Future<int> open(String path) async {
        final id = (await engine.open(path)).id;
        addTearDown(() async {
          try {
            await engine.closeDiscarding(id);
          } on EngineException {
            // The test closed it.
          }
        });
        return id;
      }

      test('open, edit, undo, redo, save, reopen and compare', () async {
        final original = base64Decode(kiraTrPdf);
        final file = File('${dir.path}/kira-tr.pdf')
          ..writeAsBytesSync(original);
        final document = await open(file.path);
        final before = [
          for (var page = 0; page < 3; page++)
            await _pageText(engine, document, page),
        ];
        final pixels = [
          for (var page = 0; page < 3; page++)
            await _thumbnail(engine, document, page),
        ];

        final transaction = await _beginFee(engine, document);
        final preview = await engine.applyEdit(
          transaction.$1,
          transaction.$2.replaceFirst('18.500', '19.500'),
        );
        expect(preview.overflowing, isFalse);
        expect(preview.missing, isEmpty);
        final committed = await engine.commitEdit(transaction.$1, 'Fee');
        expect(committed.current, 1);
        // The review list (a3-12) has the step, with nothing to warn about.
        final history = await engine.history(document);
        expect(history.steps.single.name, 'Fee');
        expect(history.steps.single.hiddenLines, 0);
        expect(history.signatureInvalidated, isFalse);
        final edited = before.first.replaceFirst('18.500', '19.500');
        expect(await _pageText(engine, document, 0), edited);
        final changed = await _thumbnail(engine, document, 0);
        expect(changed, isNot(pixels.first));

        expect((await engine.undo(document)).current, 0);
        expect(await _pageText(engine, document, 0), before.first);
        expect(await _thumbnail(engine, document, 0), pixels.first);
        expect((await engine.history(document)).redoable, hasLength(1));

        expect((await engine.redo(document)).current, 1);
        expect(await _pageText(engine, document, 0), edited);
        expect(await _thumbnail(engine, document, 0), changed);
        // Nothing reached the file before the save.
        expect(file.readAsBytesSync(), original);

        expect(await engine.save(document), isNull);
        await engine.close(document);
        // An incremental update: every byte of the original stays.
        final saved = file.readAsBytesSync();
        expect(saved.length, greaterThan(original.length));
        expect(saved.sublist(0, original.length), original);

        final reopened = await open(file.path);
        expect(await _pageText(engine, reopened, 0), edited);
        expect(await _thumbnail(engine, reopened, 0), changed);
        for (final page in [1, 2]) {
          expect(await _pageText(engine, reopened, page), before[page]);
          expect(await _thumbnail(engine, reopened, page), pixels[page]);
        }
      });

      test('a signed document asks before its first change', () async {
        final original = base64Decode(kiraTrSignedPdf);
        final file = File('${dir.path}/kira-tr-signed.pdf')
          ..writeAsBytesSync(original);
        final isConfirmationRequired = throwsA(
          isA<EngineException>().having(
            (error) => error.kind,
            'kind',
            EngineErrorKind.confirmationRequired,
          ),
        );
        final document = await open(file.path);
        final transaction = await _beginFee(engine, document);
        await engine.applyEdit(
          transaction.$1,
          transaction.$2.replaceFirst('18.500', '19.500'),
        );
        await expectLater(
          engine.commitEdit(transaction.$1, 'Fee'),
          isConfirmationRequired,
        );
        expect(file.readAsBytesSync(), original);

        // "Edit anyway" (a3-16a): the same transaction commits.
        await engine.confirmEditSigned(document);
        expect((await engine.commitEdit(transaction.$1, 'Fee')).current, 1);
        expect((await engine.history(document)).signatureInvalidated, isTrue);
        expect(await engine.save(document), isNull);
        await engine.close(document);
        // The signed revision stays in the file, byte for byte.
        final saved = file.readAsBytesSync();
        expect(saved.sublist(0, original.length), original);

        // Closing ends the confirmation: the file still counts as signed.
        final reopened = await open(file.path);
        expect(await _pageText(engine, reopened, 0), contains('19.500'));
        final again = await _beginFee(engine, reopened, fee: '19.500');
        await engine.applyEdit(
          again.$1,
          again.$2.replaceFirst('19.500', '20.500'),
        );
        await expectLater(
          engine.commitEdit(again.$1, 'Fee'),
          isConfirmationRequired,
        );
        await engine.rollbackEdit(again.$1);
      });

      test('a background job streams through the bridge to its file', () async {
        final original = base64Decode(kiraTrPdf);
        final file = File('${dir.path}/kira-tr.pdf')
          ..writeAsBytesSync(original);
        final document = await open(file.path);
        final output = '${dir.path}/copy.pdf';
        final updates = await engine.copyDocumentJob(document, output).toList();
        expect(updates.first.state, JobState.running);
        expect(updates.last.state, JobState.done);
        expect(updates.last.revision, 0);
        expect(updates.last.outputs.single.path, output);
        expect(File(output).readAsBytesSync(), original);
        await engine.close(document);
      });

      test('unsaved edits come back after the engine restarts', () async {
        final original = base64Decode(kiraTrPdf);
        final file = File('${dir.path}/kira-tr.pdf')
          ..writeAsBytesSync(original);
        final document = await open(file.path);
        final transaction = await _beginFee(engine, document);
        await engine.applyEdit(
          transaction.$1,
          transaction.$2.replaceFirst('18.500', '19.500'),
        );
        await engine.commitEdit(transaction.$1, 'Fee');
        final edited = await _pageText(engine, document, 0);
        await engine.close(document);

        // shortcut: the engine is one per process and this test cannot start
        // a second one, so the files move to a session whose lock nobody
        // holds, what a killed instance leaves. crates/ferman-api/tests/
        // recovery.rs kills a real process; a test driver that relaunches the
        // app could do the same here.
        final name = _lastSegment(dir);
        final root = Directory(engine.recoveryRoot!);
        final files = _recoveryFilesOf(root, name);
        final session = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
        final crashed = Directory('${root.path}/$session')..createSync();
        File('${crashed.path}/instance.lock').writeAsStringSync('0\n0\n');
        addTearDown(() async {
          try {
            await engine.discardRecovery(session);
          } on EngineException {
            // Restoring took the files.
          }
        });
        await _renameRetrying(files, '${crashed.path}/${_lastSegment(files)}');

        final recoverable = (await engine.listRecoverable())
            .where((found) => found.original.contains(name))
            .single;
        expect(recoverable.session, session);
        expect(recoverable.changes, 1);
        expect(recoverable.originalChanged, isFalse);
        expect(recoverable.encrypted, isFalse);

        final restored = await engine.restoreRecovered(
          recoverable.session,
          recoverable.document,
        );
        final id = restored.opened.id;
        addTearDown(() async {
          try {
            await engine.closeDiscarding(id);
          } on EngineException {
            // The test closed it.
          }
        });
        expect(restored.originalChanged, isFalse);
        expect(await _pageText(engine, id, 0), edited);
        // The change is unsaved: the file on disk is as it was.
        expect(file.readAsBytesSync(), original);

        expect(await engine.save(id), isNull);
        await engine.close(id);
        // A save deletes the recovery files.
        expect(
          (await engine.listRecoverable()).where(
            (found) => found.original.contains(name),
          ),
          isEmpty,
        );
        final reopened = await open(file.path);
        expect(await _pageText(engine, reopened, 0), edited);
      });
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

/// The transaction on the block of kira-tr's page 1 with the monthly [fee],
/// and that block's text.
Future<(int, String)> _beginFee(
  EngineService engine,
  int document, {
  String fee = '18.500',
}) async {
  final page = await engine.textBlocks(document, 0);
  final block = page.blocks.firstWhere((block) => block.text.contains(fee));
  return (await engine.beginEdit(document, 0, block.id), block.text);
}

/// The text of [page] of [document], block by block.
Future<String> _pageText(EngineService engine, int document, int page) async =>
    (await engine.textBlocks(
      document,
      page,
    )).blocks.map((block) => block.text).join('\n\n');

/// A bitmap of [page] of [document] as it stands.
Future<Uint8List> _thumbnail(
  EngineService engine,
  int document,
  int page,
) async {
  final view = await engine.openView(document);
  await engine.requestView(view.id, 1, [
    WantedItem(
      ThumbnailItem(page: page, size: 512),
      RenderPriority.visibleThumbnail,
    ),
  ]);
  final update = await view.updates.firstWhere(
    (update) => update is RenderedItem,
  );
  await engine.closeView(view.id);
  return (update as RenderedItem).pixels;
}

/// The recovery files of the document whose manifest names [name], in any
/// session under [root].
Directory _recoveryFilesOf(Directory root, String name) {
  for (final session in root.listSync().whereType<Directory>()) {
    for (final files in session.listSync().whereType<Directory>()) {
      final manifest = File('${files.path}/manifest.json');
      if (manifest.existsSync() && manifest.readAsStringSync().contains(name)) {
        return files;
      }
    }
  }
  throw StateError('No recovery files name $name');
}

String _lastSegment(Directory directory) =>
    directory.uri.pathSegments.lastWhere((part) => part.isNotEmpty);

/// Renames [from] to [to], retrying while Windows still has a file of it open
/// just after the document closed.
Future<void> _renameRetrying(Directory from, String to) async {
  for (var attempt = 0; ; attempt++) {
    try {
      await from.rename(to);
      return;
    } on FileSystemException {
      if (attempt == 20) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
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

/// [count] A4 pages of text in Helvetica, each with its number and 30
/// lines, seven of which have "caretaker", for the M2 budgets.
String _pagesPdf(int count) {
  const font =
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
      '/Encoding /WinAnsiEncoding >>';
  const lines = [
    'The water tanks in the loft are inspected every year for corrosion,',
    'and their lids are kept closed to stop debris and insects getting in.',
    'Smoke alarms are tested monthly by the caretaker of the building, and',
    'the batteries are replaced every year, whether or not the alarm sounded.',
  ];
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    // The page tree, filled in below.
    '',
    font,
  ];
  final kids = <String>[];
  for (var page = 0; page < count; page++) {
    final text = StringBuffer(
      'BT /F1 11 Tf 72 770 Td 14 TL (Page ${page + 1}) Tj',
    );
    for (var line = 0; line < 30; line++) {
      text.write(' T* (${lines[line % lines.length]}) Tj');
    }
    text.write(' ET');
    final content = text.toString();
    // This page's content is object `objects.length + 1`, the page the next.
    final pageId = objects.length + 2;
    objects
      ..add('<< /Length ${content.length} >>\nstream\n$content\nendstream')
      ..add(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Contents ${pageId - 1} 0 R /Resources << /Font << /F1 3 0 R >> >> >>',
      );
    kids.add('$pageId 0 R');
  }
  objects[1] = '<< /Type /Pages /Kids [${kids.join(' ')}] /Count $count >>';
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
