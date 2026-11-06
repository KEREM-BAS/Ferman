// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'combine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Combine tab's list, as `combineFilesProvider` (a6-3, G45): a preview of
/// the rows after each change, and the job. It empties when the tab closes.

@ProviderFor(CombineFilesNotifier)
final combineFilesProvider = CombineFilesNotifierProvider._();

/// The Combine tab's list, as `combineFilesProvider` (a6-3, G45): a preview of
/// the rows after each change, and the job. It empties when the tab closes.
final class CombineFilesNotifierProvider
    extends $NotifierProvider<CombineFilesNotifier, CombineFiles> {
  /// The Combine tab's list, as `combineFilesProvider` (a6-3, G45): a preview of
  /// the rows after each change, and the job. It empties when the tab closes.
  CombineFilesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'combineFilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$combineFilesNotifierHash();

  @$internal
  @override
  CombineFilesNotifier create() => CombineFilesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CombineFiles value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CombineFiles>(value),
    );
  }
}

String _$combineFilesNotifierHash() =>
    r'ea504d390d84d4a43df0740ac8a8ff40b9c78498';

/// The Combine tab's list, as `combineFilesProvider` (a6-3, G45): a preview of
/// the rows after each change, and the job. It empties when the tab closes.

abstract class _$CombineFilesNotifier extends $Notifier<CombineFiles> {
  CombineFiles build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CombineFiles, CombineFiles>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CombineFiles, CombineFiles>,
              CombineFiles,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
