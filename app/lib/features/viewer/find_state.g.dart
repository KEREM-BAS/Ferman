// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'find_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Finds text in the open document, as `findProvider`; it starts over when
/// the document changes.

@ProviderFor(Find)
final findProvider = FindProvider._();

/// Finds text in the open document, as `findProvider`; it starts over when
/// the document changes.
final class FindProvider extends $NotifierProvider<Find, FindState> {
  /// Finds text in the open document, as `findProvider`; it starts over when
  /// the document changes.
  FindProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'findProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$findHash();

  @$internal
  @override
  Find create() => Find();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FindState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FindState>(value),
    );
  }
}

String _$findHash() => r'80099d206964550aec08346fa61e35e2670a2308';

/// Finds text in the open document, as `findProvider`; it starts over when
/// the document changes.

abstract class _$Find extends $Notifier<FindState> {
  FindState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FindState, FindState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FindState, FindState>,
              FindState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
