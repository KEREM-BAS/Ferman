// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'engine_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The started engine. `bootstrap()` overrides it with the service it
/// started; reading it without an override is a programming error, never
/// retried.

@ProviderFor(engineService)
final engineServiceProvider = EngineServiceProvider._();

/// The started engine. `bootstrap()` overrides it with the service it
/// started; reading it without an override is a programming error, never
/// retried.

final class EngineServiceProvider
    extends $FunctionalProvider<EngineService, EngineService, EngineService>
    with $Provider<EngineService> {
  /// The started engine. `bootstrap()` overrides it with the service it
  /// started; reading it without an override is a programming error, never
  /// retried.
  EngineServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: _never,
        name: r'engineServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$engineServiceHash();

  @$internal
  @override
  $ProviderElement<EngineService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EngineService create(Ref ref) {
    return engineService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EngineService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EngineService>(value),
    );
  }
}

String _$engineServiceHash() => r'05ed3d4c79955c7a829815d8b9919c3d0aeb4b01';

/// The engine's versions and build facts. A failure is not retried: a
/// missing or mismatched engine library stays so for the process.

@ProviderFor(engineStatus)
final engineStatusProvider = EngineStatusProvider._();

/// The engine's versions and build facts. A failure is not retried: a
/// missing or mismatched engine library stays so for the process.

final class EngineStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<EngineStatus>,
          EngineStatus,
          FutureOr<EngineStatus>
        >
    with $FutureModifier<EngineStatus>, $FutureProvider<EngineStatus> {
  /// The engine's versions and build facts. A failure is not retried: a
  /// missing or mismatched engine library stays so for the process.
  EngineStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: _never,
        name: r'engineStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$engineStatusHash();

  @$internal
  @override
  $FutureProviderElement<EngineStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<EngineStatus> create(Ref ref) {
    return engineStatus(ref);
  }
}

String _$engineStatusHash() => r'be435a7db65e392577d99bae030d85eb87692759';

/// What keeps the engine from opening PDF files, or null when it can, while
/// it starts, and in the web build (G101). The start screen shows it as a
/// warning banner and disables opening with its title as the reason.
///
/// An error counts in every state, the loading state that keeps an error
/// included.

@ProviderFor(engineProblem)
final engineProblemProvider = EngineProblemProvider._();

/// What keeps the engine from opening PDF files, or null when it can, while
/// it starts, and in the web build (G101). The start screen shows it as a
/// warning banner and disables opening with its title as the reason.
///
/// An error counts in every state, the loading state that keeps an error
/// included.

final class EngineProblemProvider
    extends $FunctionalProvider<EngineProblem?, EngineProblem?, EngineProblem?>
    with $Provider<EngineProblem?> {
  /// What keeps the engine from opening PDF files, or null when it can, while
  /// it starts, and in the web build (G101). The start screen shows it as a
  /// warning banner and disables opening with its title as the reason.
  ///
  /// An error counts in every state, the loading state that keeps an error
  /// included.
  EngineProblemProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'engineProblemProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$engineProblemHash();

  @$internal
  @override
  $ProviderElement<EngineProblem?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EngineProblem? create(Ref ref) {
    return engineProblem(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EngineProblem? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EngineProblem?>(value),
    );
  }
}

String _$engineProblemHash() => r'7113bb098fd76300e2e4dd920270cbf0f72532b1';
