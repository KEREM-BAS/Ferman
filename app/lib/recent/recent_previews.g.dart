// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_previews.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where the previews are kept. `bootstrap()` overrides it with the
/// platform's store.

@ProviderFor(recentPreviewStore)
final recentPreviewStoreProvider = RecentPreviewStoreProvider._();

/// Where the previews are kept. `bootstrap()` overrides it with the
/// platform's store.

final class RecentPreviewStoreProvider
    extends
        $FunctionalProvider<
          RecentPreviewStore,
          RecentPreviewStore,
          RecentPreviewStore
        >
    with $Provider<RecentPreviewStore> {
  /// Where the previews are kept. `bootstrap()` overrides it with the
  /// platform's store.
  RecentPreviewStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentPreviewStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentPreviewStoreHash();

  @$internal
  @override
  $ProviderElement<RecentPreviewStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RecentPreviewStore create(Ref ref) {
    return recentPreviewStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecentPreviewStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecentPreviewStore>(value),
    );
  }
}

String _$recentPreviewStoreHash() =>
    r'1ded059d165c132a61b833ff9a7f4c12f9de9c31';

/// The preview of the recent file at [path]; null when there is none.

@ProviderFor(recentPreview)
final recentPreviewProvider = RecentPreviewFamily._();

/// The preview of the recent file at [path]; null when there is none.

final class RecentPreviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  /// The preview of the recent file at [path]; null when there is none.
  RecentPreviewProvider._({
    required RecentPreviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recentPreviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recentPreviewHash();

  @override
  String toString() {
    return r'recentPreviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return recentPreview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RecentPreviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recentPreviewHash() => r'05d06622ebb735b4c4b5a70286c92a6cf4c2df94';

/// The preview of the recent file at [path]; null when there is none.

final class RecentPreviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, String> {
  RecentPreviewFamily._()
    : super(
        retry: null,
        name: r'recentPreviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The preview of the recent file at [path]; null when there is none.

  RecentPreviewProvider call(String path) =>
      RecentPreviewProvider._(argument: path, from: this);

  @override
  String toString() => r'recentPreviewProvider';
}
