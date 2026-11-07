// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_tool_menus.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The state of the Shapes and Stamp menus, as `commentToolMenusProvider`.

@ProviderFor(CommentToolMenus)
final commentToolMenusProvider = CommentToolMenusProvider._();

/// The state of the Shapes and Stamp menus, as `commentToolMenusProvider`.
final class CommentToolMenusProvider
    extends $NotifierProvider<CommentToolMenus, CommentToolMenuState> {
  /// The state of the Shapes and Stamp menus, as `commentToolMenusProvider`.
  CommentToolMenusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentToolMenusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentToolMenusHash();

  @$internal
  @override
  CommentToolMenus create() => CommentToolMenus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentToolMenuState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentToolMenuState>(value),
    );
  }
}

String _$commentToolMenusHash() => r'c2f87e284223a712a360f5b1e0847236b9803e27';

/// The state of the Shapes and Stamp menus, as `commentToolMenusProvider`.

abstract class _$CommentToolMenus extends $Notifier<CommentToolMenuState> {
  CommentToolMenuState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CommentToolMenuState, CommentToolMenuState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CommentToolMenuState, CommentToolMenuState>,
              CommentToolMenuState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The stamps saved on this device, oldest first (a4-3's MY STAMPS), as
/// `myStampsProvider`. Settings hold each as JSON; what cannot be read is left
/// out here, and goes from the file once the list changes.

@ProviderFor(MyStamps)
final myStampsProvider = MyStampsProvider._();

/// The stamps saved on this device, oldest first (a4-3's MY STAMPS), as
/// `myStampsProvider`. Settings hold each as JSON; what cannot be read is left
/// out here, and goes from the file once the list changes.
final class MyStampsProvider
    extends $NotifierProvider<MyStamps, List<StampDesign>> {
  /// The stamps saved on this device, oldest first (a4-3's MY STAMPS), as
  /// `myStampsProvider`. Settings hold each as JSON; what cannot be read is left
  /// out here, and goes from the file once the list changes.
  MyStampsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'myStampsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myStampsHash();

  @$internal
  @override
  MyStamps create() => MyStamps();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<StampDesign> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<StampDesign>>(value),
    );
  }
}

String _$myStampsHash() => r'8c0e4852ae4d56ab104c5521accaf0524975d01c';

/// The stamps saved on this device, oldest first (a4-3's MY STAMPS), as
/// `myStampsProvider`. Settings hold each as JSON; what cannot be read is left
/// out here, and goes from the file once the list changes.

abstract class _$MyStamps extends $Notifier<List<StampDesign>> {
  List<StampDesign> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<StampDesign>, List<StampDesign>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<StampDesign>, List<StampDesign>>,
              List<StampDesign>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
