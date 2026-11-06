// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_commands.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The pages selected in Organize by handle, never by index, so a selection
/// holds through any change around it (a6-1), as `pageSelectionProvider`. A
/// deleted page stays in the set and is selected again when undo brings it
/// back; read the pages through `selectedPagesProvider`.

@ProviderFor(PageSelection)
final pageSelectionProvider = PageSelectionProvider._();

/// The pages selected in Organize by handle, never by index, so a selection
/// holds through any change around it (a6-1), as `pageSelectionProvider`. A
/// deleted page stays in the set and is selected again when undo brings it
/// back; read the pages through `selectedPagesProvider`.
final class PageSelectionProvider
    extends $NotifierProvider<PageSelection, Set<int>> {
  /// The pages selected in Organize by handle, never by index, so a selection
  /// holds through any change around it (a6-1), as `pageSelectionProvider`. A
  /// deleted page stays in the set and is selected again when undo brings it
  /// back; read the pages through `selectedPagesProvider`.
  PageSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pageSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pageSelectionHash();

  @$internal
  @override
  PageSelection create() => PageSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>>(value),
    );
  }
}

String _$pageSelectionHash() => r'df17b9e5fe219e75b68130bfea4b96de523cc3e3';

/// The pages selected in Organize by handle, never by index, so a selection
/// holds through any change around it (a6-1), as `pageSelectionProvider`. A
/// deleted page stays in the set and is selected again when undo brings it
/// back; read the pages through `selectedPagesProvider`.

abstract class _$PageSelection extends $Notifier<Set<int>> {
  Set<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<int>, Set<int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<int>, Set<int>>,
              Set<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The handles of the pages selected in the open document, in its order.

@ProviderFor(selectedPages)
final selectedPagesProvider = SelectedPagesProvider._();

/// The handles of the pages selected in the open document, in its order.

final class SelectedPagesProvider
    extends $FunctionalProvider<List<int>, List<int>, List<int>>
    with $Provider<List<int>> {
  /// The handles of the pages selected in the open document, in its order.
  SelectedPagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedPagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedPagesHash();

  @$internal
  @override
  $ProviderElement<List<int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<int> create(Ref ref) {
    return selectedPages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<int>>(value),
    );
  }
}

String _$selectedPagesHash() => r'eab9648bda8b250c3d2127f147c6432f53b61d38';

/// What the open document's permissions say about changing its pages; null
/// until the engine answers, and without a document.

@ProviderFor(organizeGate)
final organizeGateProvider = OrganizeGateProvider._();

/// What the open document's permissions say about changing its pages; null
/// until the engine answers, and without a document.

final class OrganizeGateProvider
    extends $FunctionalProvider<AsyncValue<OpGate?>, OpGate?, FutureOr<OpGate?>>
    with $FutureModifier<OpGate?>, $FutureProvider<OpGate?> {
  /// What the open document's permissions say about changing its pages; null
  /// until the engine answers, and without a document.
  OrganizeGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'organizeGateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$organizeGateHash();

  @$internal
  @override
  $FutureProviderElement<OpGate?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OpGate?> create(Ref ref) {
    return organizeGate(ref);
  }
}

String _$organizeGateHash() => r'04274e01ade7a3bddd191371bfebdbbd5bf75fcf';

/// Why the open document's pages cannot change, in the language given, or null
/// when they can.

@ProviderFor(organizeRefusal)
final organizeRefusalProvider = OrganizeRefusalProvider._();

/// Why the open document's pages cannot change, in the language given, or null
/// when they can.

final class OrganizeRefusalProvider
    extends
        $FunctionalProvider<
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?
        >
    with $Provider<String Function(AppLocalizations)?> {
  /// Why the open document's pages cannot change, in the language given, or null
  /// when they can.
  OrganizeRefusalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'organizeRefusalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$organizeRefusalHash();

  @$internal
  @override
  $ProviderElement<String Function(AppLocalizations)?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  String Function(AppLocalizations)? create(Ref ref) {
    return organizeRefusal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String Function(AppLocalizations)? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String Function(AppLocalizations)?>(
        value,
      ),
    );
  }
}

String _$organizeRefusalHash() => r'4a114a7b665f28b500bf2500aee768874e59a657';

/// Why the selection cannot be deleted, as [organizeRefusal]: a document keeps
/// at least one page, and the engine refuses to delete them all (a6-1 draws no
/// such state).

@ProviderFor(deleteRefusal)
final deleteRefusalProvider = DeleteRefusalProvider._();

/// Why the selection cannot be deleted, as [organizeRefusal]: a document keeps
/// at least one page, and the engine refuses to delete them all (a6-1 draws no
/// such state).

final class DeleteRefusalProvider
    extends
        $FunctionalProvider<
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?
        >
    with $Provider<String Function(AppLocalizations)?> {
  /// Why the selection cannot be deleted, as [organizeRefusal]: a document keeps
  /// at least one page, and the engine refuses to delete them all (a6-1 draws no
  /// such state).
  DeleteRefusalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteRefusalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteRefusalHash();

  @$internal
  @override
  $ProviderElement<String Function(AppLocalizations)?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  String Function(AppLocalizations)? create(Ref ref) {
    return deleteRefusal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String Function(AppLocalizations)? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String Function(AppLocalizations)?>(
        value,
      ),
    );
  }
}

String _$deleteRefusalHash() => r'7d8e7f64777936deeedb7624e02593bb656ef45d';

/// How many pages are being dragged in the page grid, for the tool row's hint
/// ("Moving 3 pages", a6-1b); null without a drag.

@ProviderFor(PagesDragged)
final pagesDraggedProvider = PagesDraggedProvider._();

/// How many pages are being dragged in the page grid, for the tool row's hint
/// ("Moving 3 pages", a6-1b); null without a drag.
final class PagesDraggedProvider extends $NotifierProvider<PagesDragged, int?> {
  /// How many pages are being dragged in the page grid, for the tool row's hint
  /// ("Moving 3 pages", a6-1b); null without a drag.
  PagesDraggedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pagesDraggedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pagesDraggedHash();

  @$internal
  @override
  PagesDragged create() => PagesDragged();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$pagesDraggedHash() => r'3abe0b8c0e3534c937d4b850fc916ed52c569084';

/// How many pages are being dragged in the page grid, for the tool row's hint
/// ("Moving 3 pages", a6-1b); null without a drag.

abstract class _$PagesDragged extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The one [PageGridDropSlot].

@ProviderFor(pageGridDropSlot)
final pageGridDropSlotProvider = PageGridDropSlotProvider._();

/// The one [PageGridDropSlot].

final class PageGridDropSlotProvider
    extends
        $FunctionalProvider<
          PageGridDropSlot,
          PageGridDropSlot,
          PageGridDropSlot
        >
    with $Provider<PageGridDropSlot> {
  /// The one [PageGridDropSlot].
  PageGridDropSlotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pageGridDropSlotProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pageGridDropSlotHash();

  @$internal
  @override
  $ProviderElement<PageGridDropSlot> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PageGridDropSlot create(Ref ref) {
    return pageGridDropSlot(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PageGridDropSlot value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PageGridDropSlot>(value),
    );
  }
}

String _$pageGridDropSlotHash() => r'af4a3ef6aeb8c21bf1c5ac66e3056c4de2ab579c';

/// The page commands on the selection (a6-1, a6-1b), as
/// `pageCommandsProvider`: each is one step of the history, offered back by a
/// toast's Undo for as long as it is the newest step (G45).

@ProviderFor(PageCommands)
final pageCommandsProvider = PageCommandsProvider._();

/// The page commands on the selection (a6-1, a6-1b), as
/// `pageCommandsProvider`: each is one step of the history, offered back by a
/// toast's Undo for as long as it is the newest step (G45).
final class PageCommandsProvider extends $NotifierProvider<PageCommands, void> {
  /// The page commands on the selection (a6-1, a6-1b), as
  /// `pageCommandsProvider`: each is one step of the history, offered back by a
  /// toast's Undo for as long as it is the newest step (G45).
  PageCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pageCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pageCommandsHash();

  @$internal
  @override
  PageCommands create() => PageCommands();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$pageCommandsHash() => r'49161bc05e81670aba9cacd530420c971b9699d9';

/// The page commands on the selection (a6-1, a6-1b), as
/// `pageCommandsProvider`: each is one step of the history, offered back by a
/// toast's Undo for as long as it is the newest step (G45).

abstract class _$PageCommands extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
