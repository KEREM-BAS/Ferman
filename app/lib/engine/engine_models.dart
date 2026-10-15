/// App-side views of what the engine reports. Feature code uses these, never
/// the generated bridge types (`app/lib/bridge/`), so only `app/lib/engine/`
/// depends on the bridge (ARCHITECTURE §3, ADR 0003).
library;

import 'package:flutter/foundation.dart';

/// The API version the app was built against. The engine must report the
/// same major version at start-up (ARCHITECTURE §3.8).
const EngineApiVersion kAppApiVersion = EngineApiVersion(major: 0, minor: 1);

/// The version of the API between the engine and the UI.
@immutable
class EngineApiVersion {
  /// Creates a version.
  const new({required this.major, required this.minor});

  /// Incremented on a breaking change.
  final int major;

  /// Incremented on a compatible addition.
  final int minor;

  /// Whether an app built for this version can talk to an engine that
  /// reports [engine]: same major version, and the engine at least as new.
  bool acceptsEngine(EngineApiVersion engine) =>
      engine.major == major && engine.minor >= minor;

  @override
  bool operator ==(Object other) =>
      other is EngineApiVersion && other.major == major && other.minor == minor;

  @override
  int get hashCode => Object.hash(major, minor);

  @override
  String toString() => '$major.$minor';
}

/// Whether PDFium, the page rasteriser, is loaded.
enum PdfiumState {
  /// No library was found or loading was not attempted.
  notLoaded,

  /// The library is bound and a real PDFium call succeeded.
  loaded,

  /// Loading failed; [EngineStatus.pdfiumReason] says why.
  failed,
}

/// Versions and build facts of the running engine.
@immutable
class EngineStatus {
  /// Creates a status.
  const new({
    required this.appVersion,
    required this.apiVersion,
    required this.isDebugBuild,
    required this.pdfium,
    this.pdfiumTag,
    this.pdfiumReason,
  });

  /// The engine's version, such as `0.1.0`.
  final String appVersion;

  /// The API version the engine speaks.
  final EngineApiVersion apiVersion;

  /// Whether the engine library was built with debug assertions.
  final bool isDebugBuild;

  /// Whether PDFium is loaded.
  final PdfiumState pdfium;

  /// The PDFium build tag when [pdfium] is [PdfiumState.loaded], such as
  /// `chromium/7881`.
  final String? pdfiumTag;

  /// Why loading failed when [pdfium] is [PdfiumState.failed]. Never holds a
  /// file path.
  final String? pdfiumReason;
}

/// An error the engine returned. [messageKey] names the ARB string the UI
/// shows; [details] holds structural facts only.
@immutable
class EngineException implements Exception {
  /// Creates an exception.
  const new({required this.messageKey, this.details});

  /// The ARB key of the message to show, such as `errorInternal`.
  final String messageKey;

  /// Technical details for "Copy technical details".
  final String? details;

  @override
  String toString() =>
      'EngineException($messageKey${details == null ? '' : ': $details'})';
}
