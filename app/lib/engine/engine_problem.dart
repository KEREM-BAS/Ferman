import 'package:ferman/engine/engine_service.dart';
import 'package:flutter/foundation.dart';

/// What keeps the engine from opening PDF files (G101): the engine library
/// is missing or speaks another API version, or PDFium did not load.
@immutable
class EngineProblem {
  /// Creates a problem with its [technicalDetails].
  const new(this.technicalDetails);

  /// The problem a started engine reports, or null when PDFium is loaded.
  static EngineProblem? ofStatus(EngineStatus status) =>
      switch (status.pdfium) {
        PdfiumState.loaded => null,
        PdfiumState.notLoaded => EngineProblem(
          '${_engine(status)}\npdfium: not loaded (no library found)',
        ),
        PdfiumState.failed => EngineProblem(
          '${_engine(status)}\n'
          'pdfium: failed: ${status.pdfiumReason ?? 'no reason given'}',
        ),
      };

  /// The problem behind [error], from starting the engine or asking it for
  /// its status, or null for the web build: its engine is stubbed until
  /// phase 5 and it keeps the future-version state instead.
  static EngineProblem? ofError(Object error) => switch (error) {
    EngineUnavailableException(
      reason: EngineUnavailableReason.unsupportedPlatform,
    ) =>
      null,
    EngineUnavailableException(
      reason: EngineUnavailableReason.libraryMissing,
    ) =>
      const EngineProblem('engine: the engine library could not be loaded'),
    EngineUnavailableException(
      reason: EngineUnavailableReason.apiMismatch,
      :final engineApiVersion,
    ) =>
      EngineProblem(
        'engine: API ${engineApiVersion ?? 'unknown'}, '
        'the app needs $kAppApiVersion',
      ),
    EngineException(:final messageKey, :final details) => EngineProblem(
      'engine: $messageKey${details == null ? '' : ': $details'}',
    ),
    _ => const EngineProblem('engine: the status could not be read'),
  };

  static String _engine(EngineStatus status) =>
      'engine: ${status.appVersion} (API ${status.apiVersion})';

  /// What "Copy technical details" copies: one fact per line, in English,
  /// never a file path.
  final String technicalDetails;

  @override
  bool operator ==(Object other) =>
      other is EngineProblem && other.technicalDetails == technicalDetails;

  @override
  int get hashCode => technicalDetails.hashCode;

  @override
  String toString() => 'EngineProblem($technicalDetails)';
}
