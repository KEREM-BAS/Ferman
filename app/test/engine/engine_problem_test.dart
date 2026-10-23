import 'package:ferman/engine/engine_problem.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

EngineStatus _status(PdfiumState pdfium, {String? reason}) => EngineStatus(
  appVersion: '0.1.0',
  apiVersion: kAppApiVersion,
  isDebugBuild: false,
  pdfium: pdfium,
  pdfiumTag: pdfium == PdfiumState.loaded ? 'chromium/7881' : null,
  pdfiumReason: reason,
);

void main() {
  test('a loaded PDFium is no problem', () {
    expect(EngineProblem.ofStatus(_status(PdfiumState.loaded)), isNull);
  });

  test('PDFium not loaded or failed is one, with the facts', () {
    expect(
      EngineProblem.ofStatus(_status(PdfiumState.notLoaded))?.technicalDetails,
      'engine: 0.1.0 (API 0.1)\npdfium: not loaded (no library found)',
    );
    expect(
      EngineProblem.ofStatus(
        _status(PdfiumState.failed, reason: 'dlopen failed'),
      )?.technicalDetails,
      'engine: 0.1.0 (API 0.1)\npdfium: failed: dlopen failed',
    );
  });

  test('an engine that did not start is one, except on the web', () {
    expect(
      EngineProblem.ofError(
        const EngineUnavailableException(
          EngineUnavailableReason.apiMismatch,
          engineApiVersion: EngineApiVersion(major: 1, minor: 0),
        ),
      )?.technicalDetails,
      'engine: API 1.0, the app needs 0.1',
    );
    expect(
      EngineProblem.ofError(
        const EngineException(messageKey: 'errorInternal', details: 'panic'),
      )?.technicalDetails,
      'engine: errorInternal: panic',
    );
    expect(
      EngineProblem.ofError(
        const EngineUnavailableException(
          EngineUnavailableReason.unsupportedPlatform,
        ),
      ),
      isNull,
    );
    expect(
      EngineProblem.ofError(StateError('other')),
      const EngineProblem('engine: the status could not be read'),
    );
  });
}
