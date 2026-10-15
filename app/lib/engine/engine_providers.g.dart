// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'engine_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The started engine. `bootstrap()` overrides it with the service it
/// started; reading it without an override is a programming error.

@ProviderFor(engineService)
final engineServiceProvider = EngineServiceProvider._();

/// The started engine. `bootstrap()` overrides it with the service it
/// started; reading it without an override is a programming error.

final class EngineServiceProvider
    extends $FunctionalProvider<EngineService, EngineService, EngineService>
    with $Provider<EngineService> {
  /// The started engine. `bootstrap()` overrides it with the service it
  /// started; reading it without an override is a programming error.
  EngineServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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

String _$engineServiceHash() => r'6978125d77f8521c7187de2de28bbae6fd1fa430';

/// The engine's versions and build facts.

@ProviderFor(engineStatus)
final engineStatusProvider = EngineStatusProvider._();

/// The engine's versions and build facts.

final class EngineStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<EngineStatus>,
          EngineStatus,
          FutureOr<EngineStatus>
        >
    with $FutureModifier<EngineStatus>, $FutureProvider<EngineStatus> {
  /// The engine's versions and build facts.
  EngineStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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

String _$engineStatusHash() => r'e77337ecac59c1479576596da617fd6bd66f1a02';
