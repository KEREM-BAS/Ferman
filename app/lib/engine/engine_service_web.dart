import 'package:ferman/engine/engine_service.dart';

/// The web build has no engine until phase 5 (ROADMAP); every call fails
/// with [EngineUnavailableReason.unsupportedPlatform].
Future<EngineService> startEngine() async =>
    throw const EngineUnavailableException(
      EngineUnavailableReason.unsupportedPlatform,
    );
