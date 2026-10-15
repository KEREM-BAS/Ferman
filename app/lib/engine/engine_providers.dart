import 'package:ferman/engine/engine_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'engine_providers.g.dart';

/// The started engine. `bootstrap()` overrides it with the service it
/// started; reading it without an override is a programming error.
@Riverpod(keepAlive: true)
EngineService engineService(Ref ref) => throw const EngineUnavailableException(
  EngineUnavailableReason.libraryMissing,
);

/// The engine's versions and build facts.
@riverpod
Future<EngineStatus> engineStatus(Ref ref) =>
    ref.watch(engineServiceProvider).status();
