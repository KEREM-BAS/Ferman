// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Review edits (a3-12, a3-12b), as `reviewListProvider`: reverts go through
/// `DocumentEditor`, the list itself comes from its history, so it follows
/// every edit, undo and revert and clears with the document (G42).

@ProviderFor(ReviewList)
final reviewListProvider = ReviewListProvider._();

/// Review edits (a3-12, a3-12b), as `reviewListProvider`: reverts go through
/// `DocumentEditor`, the list itself comes from its history, so it follows
/// every edit, undo and revert and clears with the document (G42).
final class ReviewListProvider
    extends $NotifierProvider<ReviewList, ReviewListState> {
  /// Review edits (a3-12, a3-12b), as `reviewListProvider`: reverts go through
  /// `DocumentEditor`, the list itself comes from its history, so it follows
  /// every edit, undo and revert and clears with the document (G42).
  ReviewListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewListHash();

  @$internal
  @override
  ReviewList create() => ReviewList();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReviewListState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReviewListState>(value),
    );
  }
}

String _$reviewListHash() => r'f6f7801963048519a84f4c66e6737800aa4a171f';

/// Review edits (a3-12, a3-12b), as `reviewListProvider`: reverts go through
/// `DocumentEditor`, the list itself comes from its history, so it follows
/// every edit, undo and revert and clears with the document (G42).

abstract class _$ReviewList extends $Notifier<ReviewListState> {
  ReviewListState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReviewListState, ReviewListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReviewListState, ReviewListState>,
              ReviewListState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
