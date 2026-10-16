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
      const service = FakeEngineService();
      expect(service.apiVersion(), kAppApiVersion);
      final status = await service.status();
      expect(status.pdfium, PdfiumState.loaded);
      expect(status.pdfiumTag, 'chromium/7881');
    },
  );
}
