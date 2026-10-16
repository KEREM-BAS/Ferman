import 'package:ferman/engine/engine_models.dart';

export 'package:ferman/engine/engine_models.dart';

/// The app's only way to reach the Rust engine. Feature code depends on this
/// interface; the bridge implementation lives in `engine_service_frb.dart`
/// and tests use `FakeEngineService`.
abstract interface class EngineService {
  /// The API version the engine speaks. The only synchronous engine call.
  EngineApiVersion apiVersion();

  /// Versions and build facts of the running engine, including PDFium.
  ///
  /// Throws an [EngineException] when the engine reports an error.
  Future<EngineStatus> status();
}

/// Why the engine could not be used.
enum EngineUnavailableReason {
  /// The engine library could not be loaded.
  libraryMissing,

  /// The engine speaks an API version the app does not accept.
  apiMismatch,

  /// This platform has no engine yet (the web build until phase 5).
  unsupportedPlatform,
}

/// Thrown by [EngineService] calls when the engine cannot be used at all.
class EngineUnavailableException implements Exception {
  /// Creates an exception.
  const new(this.reason, {this.engineApiVersion});

  /// Why the engine is unavailable.
  final EngineUnavailableReason reason;

  /// The version the engine reported, for
  /// [EngineUnavailableReason.apiMismatch].
  final EngineApiVersion? engineApiVersion;

  @override
  String toString() => 'EngineUnavailableException($reason)';
}

/// The [EngineService] used when the engine could not be started: every call
/// throws the [EngineUnavailableException] that explains why, so the app
/// still opens and can tell the person what is wrong.
class UnavailableEngineService implements EngineService {
  /// Creates a service that fails with [error].
  const new(this.error);

  /// Why the engine is unavailable.
  final EngineUnavailableException error;

  @override
  EngineApiVersion apiVersion() => throw error;

  @override
  Future<EngineStatus> status() async => throw error;
}
