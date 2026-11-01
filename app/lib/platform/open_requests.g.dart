// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_requests.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The system's open requests, as `openRequestsProvider`; `bootstrap`
/// gives the runner's.

@ProviderFor(openRequests)
final openRequestsProvider = OpenRequestsProvider._();

/// The system's open requests, as `openRequestsProvider`; `bootstrap`
/// gives the runner's.

final class OpenRequestsProvider
    extends $FunctionalProvider<OpenRequests, OpenRequests, OpenRequests>
    with $Provider<OpenRequests> {
  /// The system's open requests, as `openRequestsProvider`; `bootstrap`
  /// gives the runner's.
  OpenRequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openRequestsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openRequestsHash();

  @$internal
  @override
  $ProviderElement<OpenRequests> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OpenRequests create(Ref ref) {
    return openRequests(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenRequests value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenRequests>(value),
    );
  }
}

String _$openRequestsHash() => r'66d684c610df85e3f98e5dd0a1b2b860a18b26f7';
