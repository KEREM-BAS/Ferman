// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_signatures.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The folder saved signatures live in, as `signatureDirectoryProvider`; null
/// where there is none (the web).

@ProviderFor(signatureDirectory)
final signatureDirectoryProvider = SignatureDirectoryProvider._();

/// The folder saved signatures live in, as `signatureDirectoryProvider`; null
/// where there is none (the web).

final class SignatureDirectoryProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The folder saved signatures live in, as `signatureDirectoryProvider`; null
  /// where there is none (the web).
  SignatureDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signatureDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signatureDirectoryHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return signatureDirectory(ref);
  }
}

String _$signatureDirectoryHash() =>
    r'9571a9ee018f060102617fca06bce648d3cccaae';

/// The signatures and initials saved on this device, by file name, so oldest
/// first in each kind, as `savedSignaturesProvider` (a5-3d's menu). What
/// cannot be read is left out; a folder that cannot be read lists none.

@ProviderFor(SavedSignatures)
final savedSignaturesProvider = SavedSignaturesProvider._();

/// The signatures and initials saved on this device, by file name, so oldest
/// first in each kind, as `savedSignaturesProvider` (a5-3d's menu). What
/// cannot be read is left out; a folder that cannot be read lists none.
final class SavedSignaturesProvider
    extends $AsyncNotifierProvider<SavedSignatures, List<SavedSignature>> {
  /// The signatures and initials saved on this device, by file name, so oldest
  /// first in each kind, as `savedSignaturesProvider` (a5-3d's menu). What
  /// cannot be read is left out; a folder that cannot be read lists none.
  SavedSignaturesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedSignaturesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedSignaturesHash();

  @$internal
  @override
  SavedSignatures create() => SavedSignatures();
}

String _$savedSignaturesHash() => r'faa79ff902a0afcddd56107bfc01a9110c2f7ba0';

/// The signatures and initials saved on this device, by file name, so oldest
/// first in each kind, as `savedSignaturesProvider` (a5-3d's menu). What
/// cannot be read is left out; a folder that cannot be read lists none.

abstract class _$SavedSignatures extends $AsyncNotifier<List<SavedSignature>> {
  FutureOr<List<SavedSignature>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<SavedSignature>>, List<SavedSignature>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<SavedSignature>>,
                List<SavedSignature>
              >,
              AsyncValue<List<SavedSignature>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// What a click on the page places in Fill & Sign (a5-3d), as
/// `signaturePlacementProvider`: null while nothing is to be placed.

@ProviderFor(SignaturePlacement)
final signaturePlacementProvider = SignaturePlacementProvider._();

/// What a click on the page places in Fill & Sign (a5-3d), as
/// `signaturePlacementProvider`: null while nothing is to be placed.
final class SignaturePlacementProvider
    extends $NotifierProvider<SignaturePlacement, SavedSignature?> {
  /// What a click on the page places in Fill & Sign (a5-3d), as
  /// `signaturePlacementProvider`: null while nothing is to be placed.
  SignaturePlacementProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signaturePlacementProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signaturePlacementHash();

  @$internal
  @override
  SignaturePlacement create() => SignaturePlacement();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedSignature? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedSignature?>(value),
    );
  }
}

String _$signaturePlacementHash() =>
    r'5da02b6dc21ff10212c0402e31d0167718c82145';

/// What a click on the page places in Fill & Sign (a5-3d), as
/// `signaturePlacementProvider`: null while nothing is to be placed.

abstract class _$SignaturePlacement extends $Notifier<SavedSignature?> {
  SavedSignature? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SavedSignature?, SavedSignature?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SavedSignature?, SavedSignature?>,
              SavedSignature?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
