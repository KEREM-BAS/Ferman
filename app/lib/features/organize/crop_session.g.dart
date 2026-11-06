// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crop_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the crop tool shows: in Organize, on its own document.

@ProviderFor(cropShowing)
final cropShowingProvider = CropShowingProvider._();

/// Whether the crop tool shows: in Organize, on its own document.

final class CropShowingProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the crop tool shows: in Organize, on its own document.
  CropShowingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cropShowingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cropShowingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return cropShowing(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$cropShowingHash() => r'd246e452ae0040a843f260c945522a6bee20c383';

/// The crop tool, as `organizeCropProvider`: null while it is closed. It works
/// on the reader's page in the canvas, with its panel in the right panel's
/// place.

@ProviderFor(OrganizeCrop)
final organizeCropProvider = OrganizeCropProvider._();

/// The crop tool, as `organizeCropProvider`: null while it is closed. It works
/// on the reader's page in the canvas, with its panel in the right panel's
/// place.
final class OrganizeCropProvider
    extends $NotifierProvider<OrganizeCrop, CropSession?> {
  /// The crop tool, as `organizeCropProvider`: null while it is closed. It works
  /// on the reader's page in the canvas, with its panel in the right panel's
  /// place.
  OrganizeCropProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'organizeCropProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$organizeCropHash();

  @$internal
  @override
  OrganizeCrop create() => OrganizeCrop();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CropSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CropSession?>(value),
    );
  }
}

String _$organizeCropHash() => r'565a50c6a71943ddae431cca909acd27c4245565';

/// The crop tool, as `organizeCropProvider`: null while it is closed. It works
/// on the reader's page in the canvas, with its panel in the right panel's
/// place.

abstract class _$OrganizeCrop extends $Notifier<CropSession?> {
  CropSession? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CropSession?, CropSession?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CropSession?, CropSession?>,
              CropSession?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
