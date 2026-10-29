import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EngineApiVersion.acceptsEngine', () {
    const app = EngineApiVersion(major: 0, minor: 1);

    test('accepts the same version and newer minor versions', () {
      expect(
        app.acceptsEngine(const EngineApiVersion(major: 0, minor: 1)),
        isTrue,
      );
      expect(
        app.acceptsEngine(const EngineApiVersion(major: 0, minor: 2)),
        isTrue,
      );
    });

    test('rejects an older minor version and any other major version', () {
      expect(
        app.acceptsEngine(const EngineApiVersion(major: 0, minor: 0)),
        isFalse,
      );
      expect(
        app.acceptsEngine(const EngineApiVersion(major: 1, minor: 1)),
        isFalse,
      );
    });
  });

  test('UnavailableEngineService throws the reason on every call', () async {
    const error = EngineUnavailableException(
      EngineUnavailableReason.libraryMissing,
    );
    const service = UnavailableEngineService(error);
    expect(service.apiVersion, throwsA(same(error)));
    await expectLater(service.status(), throwsA(same(error)));
  });

  test(
    'FakeEngineService reports the app API version and PDFium loaded',
    () async {
      final service = FakeEngineService();
      expect(service.apiVersion(), kAppApiVersion);
      final status = await service.status();
      expect(status.pdfium, PdfiumState.loaded);
      expect(status.pdfiumTag, 'chromium/7881');
    },
  );

  test('render items are equal by value, so updates match what was wanted', () {
    const tile = TileItem(
      page: 2,
      zoomBucket: -3,
      devicePixelRatio: 2,
      column: 1,
      row: 4,
    );
    expect(
      tile,
      const TileItem(
        page: 2,
        zoomBucket: -3,
        devicePixelRatio: 2,
        column: 1,
        row: 4,
      ),
    );
    expect(
      tile,
      isNot(
        const TileItem(
          page: 2,
          zoomBucket: -3,
          devicePixelRatio: 2,
          column: 1,
          row: 5,
        ),
      ),
    );
    expect({
      const ThumbnailItem(page: 0, size: 64),
    }, contains(const ThumbnailItem(page: 0, size: 64)));
    expect(
      const ThumbnailItem(page: 0, size: 64),
      isNot(const ThumbnailItem(page: 1, size: 64)),
    );
  });

  test('the fake opens its documents and no other path', () async {
    const document = OpenedDocument(
      id: 7,
      pages: [PageInfo(width: 595, height: 842)],
    );
    final engine = FakeEngineService(documents: {'/a.pdf': document});
    expect(await engine.open('/a.pdf'), same(document));
    await expectLater(
      engine.open('/b.pdf'),
      throwsA(
        isA<EngineException>().having(
          (error) => error.kind,
          'kind',
          EngineErrorKind.notFound,
        ),
      ),
    );
  });
}
