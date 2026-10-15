import 'dart:io';

import 'package:ferman/bridge/frb.dart' as bridge;
import 'package:ferman/bridge/frb_generated.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

/// The [EngineService] backed by the Rust engine through flutter_rust_bridge.
/// This file and the generated `app/lib/bridge/` are the only Dart code that
/// touches the bridge (tools/checks imports rule).
class FrbEngineService implements EngineService {
  new _();

  /// Loads the engine library, checks its API version and returns the
  /// service. Throws an [EngineUnavailableException] when the library cannot
  /// be loaded or speaks an API version this app does not accept.
  static Future<FrbEngineService> start() async {
    final library = bundledEngineLibraryPath();
    try {
      // The bridge loads the library once per process; a second start (for
      // example an integration test after the app started) reuses it.
      if (!FermanBridge.instance.initialized) {
        await FermanBridge.init(externalLibrary: ExternalLibrary.open(library));
      }
    } on Object {
      throw const EngineUnavailableException(
        EngineUnavailableReason.libraryMissing,
      );
    }
    final service = FrbEngineService._();
    final engine = service.apiVersion();
    if (!kAppApiVersion.acceptsEngine(engine)) {
      throw EngineUnavailableException(
        EngineUnavailableReason.apiMismatch,
        engineApiVersion: engine,
      );
    }
    return service;
  }

  @override
  EngineApiVersion apiVersion() {
    final version = bridge.apiVersion();
    return EngineApiVersion(major: version.major, minor: version.minor);
  }

  @override
  Future<EngineStatus> status() async {
    try {
      final info = await bridge.engineInfo();
      return EngineStatus(
        appVersion: info.appVersion,
        apiVersion: EngineApiVersion(
          major: info.apiVersion.major,
          minor: info.apiVersion.minor,
        ),
        isDebugBuild: info.buildProfile == bridge.BuildProfile.debug,
        pdfium: switch (info.pdfium.state) {
          bridge.PdfiumState.notLoaded => PdfiumState.notLoaded,
          bridge.PdfiumState.loaded => PdfiumState.loaded,
          bridge.PdfiumState.failed => PdfiumState.failed,
        },
        pdfiumTag: info.pdfium.tag,
        pdfiumReason: info.pdfium.reason,
      );
    } on bridge.ApiError catch (error) {
      throw EngineException(
        messageKey: error.messageKey,
        details: error.details,
      );
    }
  }

  /// Panics inside the engine's API guard (debug builds only) and returns
  /// the resulting error, for the test that a Rust panic reaches Dart as an
  /// error and the app keeps running.
  Future<EngineException?> debugPanic() async {
    try {
      await bridge.debugPanic();
      return null;
    } on bridge.ApiError catch (error) {
      return EngineException(
        messageKey: error.messageKey,
        details: error.details,
      );
    }
  }

  /// Returns [length] bytes from the engine, for the bridge benchmark.
  Future<int> debugBytesLength(int length) async =>
      (await bridge.debugBytes(len: length)).length;
}

/// The engine library the build bundles with the app, as an absolute path
/// next to the running executable (where the Rust engine also finds PDFium).
///
/// The bridge's default loader is not used: it first tries a folder relative
/// to the current directory, so a packaged app could load a library from
/// wherever it was started, and on macOS it looks for a framework named after
/// the crate, while cargokit links the engine into the `rust_lib_ferman`
/// plugin framework.
String bundledEngineLibraryPath({String? executable, String? operatingSystem}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  final separator = os == 'windows' ? r'\' : '/';
  final exe = executable ?? Platform.resolvedExecutable;
  final cut = exe.lastIndexOf(separator);
  final dir = cut < 0 ? '.' : exe.substring(0, cut);
  String join(List<String> parts) => [dir, ...parts].join(separator);
  return switch (os) {
    'linux' => join(['lib', 'libferman_api.so']),
    'windows' => join(['ferman_api.dll']),
    'macos' => join([
      '..',
      'Frameworks',
      'rust_lib_ferman.framework',
      'rust_lib_ferman',
    ]),
    _ => throw const EngineUnavailableException(
      EngineUnavailableReason.unsupportedPlatform,
    ),
  };
}

/// Starts the engine for this platform.
Future<EngineService> startEngine() => FrbEngineService.start();
