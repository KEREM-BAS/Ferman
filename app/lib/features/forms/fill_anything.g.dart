// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fill_anything.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The lines, boxes, check boxes and combs drawn on page [page] (by
/// [PageInfo.handle]) of the open document (a5-4), read again after each
/// step.

@ProviderFor(pageFillTargets)
final pageFillTargetsProvider = PageFillTargetsFamily._();

/// The lines, boxes, check boxes and combs drawn on page [page] (by
/// [PageInfo.handle]) of the open document (a5-4), read again after each
/// step.

final class PageFillTargetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<FillTargets>,
          FillTargets,
          FutureOr<FillTargets>
        >
    with $FutureModifier<FillTargets>, $FutureProvider<FillTargets> {
  /// The lines, boxes, check boxes and combs drawn on page [page] (by
  /// [PageInfo.handle]) of the open document (a5-4), read again after each
  /// step.
  PageFillTargetsProvider._({
    required PageFillTargetsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'pageFillTargetsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$pageFillTargetsHash();

  @override
  String toString() {
    return r'pageFillTargetsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FillTargets> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FillTargets> create(Ref ref) {
    final argument = this.argument as int;
    return pageFillTargets(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PageFillTargetsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$pageFillTargetsHash() => r'71461ec7c8ebf04cdb9f565f897a256e7898c488';

/// The lines, boxes, check boxes and combs drawn on page [page] (by
/// [PageInfo.handle]) of the open document (a5-4), read again after each
/// step.

final class PageFillTargetsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FillTargets>, int> {
  PageFillTargetsFamily._()
    : super(
        retry: null,
        name: r'pageFillTargetsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The lines, boxes, check boxes and combs drawn on page [page] (by
  /// [PageInfo.handle]) of the open document (a5-4), read again after each
  /// step.

  PageFillTargetsProvider call(int page) =>
      PageFillTargetsProvider._(argument: page, from: this);

  @override
  String toString() => r'pageFillTargetsProvider';
}
