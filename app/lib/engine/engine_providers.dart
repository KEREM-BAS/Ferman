import 'package:ferman/engine/engine_problem.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'engine_providers.g.dart';

/// The started engine. `bootstrap()` overrides it with the service it
/// started; reading it without an override is a programming error, never
/// retried.
@Riverpod(keepAlive: true, retry: _never)
EngineService engineService(Ref ref) => throw const EngineUnavailableException(
  EngineUnavailableReason.libraryMissing,
);

/// The engine's versions and build facts. A failure is not retried: a
/// missing or mismatched engine library stays so for the process.
@Riverpod(retry: _never)
Future<EngineStatus> engineStatus(Ref ref) =>
    ref.watch(engineServiceProvider).status();

Duration? _never(int retryCount, Object error) => null;

/// What keeps the engine from opening PDF files, or null when it can, while
/// it starts, and in the web build (G101). The start screen shows it as a
/// warning banner and disables opening with its title as the reason.
///
/// An error counts in every state, the loading state that keeps an error
/// included.
@riverpod
EngineProblem? engineProblem(Ref ref) {
  final status = ref.watch(engineStatusProvider);
  if (status.error case final Object error) {
    return EngineProblem.ofError(error);
  }
  if (status.value case final EngineStatus value) {
    return EngineProblem.ofStatus(value);
  }
  return null;
}
