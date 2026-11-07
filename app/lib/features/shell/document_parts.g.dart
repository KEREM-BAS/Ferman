// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_parts.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What the open document's permissions say about changing its information
/// and attachments (a2-7, a2-3b); null until the engine answers.

@ProviderFor(modifyGate)
final modifyGateProvider = ModifyGateProvider._();

/// What the open document's permissions say about changing its information
/// and attachments (a2-7, a2-3b); null until the engine answers.

final class ModifyGateProvider
    extends $FunctionalProvider<AsyncValue<OpGate?>, OpGate?, FutureOr<OpGate?>>
    with $FutureModifier<OpGate?>, $FutureProvider<OpGate?> {
  /// What the open document's permissions say about changing its information
  /// and attachments (a2-7, a2-3b); null until the engine answers.
  ModifyGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modifyGateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modifyGateHash();

  @$internal
  @override
  $FutureProviderElement<OpGate?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OpGate?> create(Ref ref) {
    return modifyGate(ref);
  }
}

String _$modifyGateHash() => r'1495700eba3ac54ec1db5a9c4e33f73c91d3e5ff';

/// Why the open document's information and attachments cannot change, in
/// the language given, or null when they can.

@ProviderFor(modifyRefusal)
final modifyRefusalProvider = ModifyRefusalProvider._();

/// Why the open document's information and attachments cannot change, in
/// the language given, or null when they can.

final class ModifyRefusalProvider
    extends
        $FunctionalProvider<
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?
        >
    with $Provider<String Function(AppLocalizations)?> {
  /// Why the open document's information and attachments cannot change, in
  /// the language given, or null when they can.
  ModifyRefusalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modifyRefusalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modifyRefusalHash();

  @$internal
  @override
  $ProviderElement<String Function(AppLocalizations)?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  String Function(AppLocalizations)? create(Ref ref) {
    return modifyRefusal(ref);
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

String _$modifyRefusalHash() => r'31f80a36d5e1a77e6ef7e57f51f0533109dff0c9';

/// The bookmark the Outline tab renames in place (a2-3a), by its index in
/// the open document's outline; null for none.

@ProviderFor(OutlineRenaming)
final outlineRenamingProvider = OutlineRenamingProvider._();

/// The bookmark the Outline tab renames in place (a2-3a), by its index in
/// the open document's outline; null for none.
final class OutlineRenamingProvider
    extends $NotifierProvider<OutlineRenaming, int?> {
  /// The bookmark the Outline tab renames in place (a2-3a), by its index in
  /// the open document's outline; null for none.
  OutlineRenamingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outlineRenamingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outlineRenamingHash();

  @$internal
  @override
  OutlineRenaming create() => OutlineRenaming();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$outlineRenamingHash() => r'bf2148b2629a4d2b19afa40a5813b5fa021f9df6';

/// The bookmark the Outline tab renames in place (a2-3a), by its index in
/// the open document's outline; null for none.

abstract class _$OutlineRenaming extends $Notifier<int?> {
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

/// The bookmark the Outline tab's More menu, F2 and Delete act on, by its
/// index in the open document's outline: the one last clicked or focused;
/// null for the reader's section.

@ProviderFor(OutlineSelected)
final outlineSelectedProvider = OutlineSelectedProvider._();

/// The bookmark the Outline tab's More menu, F2 and Delete act on, by its
/// index in the open document's outline: the one last clicked or focused;
/// null for the reader's section.
final class OutlineSelectedProvider
    extends $NotifierProvider<OutlineSelected, int?> {
  /// The bookmark the Outline tab's More menu, F2 and Delete act on, by its
  /// index in the open document's outline: the one last clicked or focused;
  /// null for the reader's section.
  OutlineSelectedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outlineSelectedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outlineSelectedHash();

  @$internal
  @override
  OutlineSelected create() => OutlineSelected();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$outlineSelectedHash() => r'b7821c9931019125af54477ceb42dd829fa23f88';

/// The bookmark the Outline tab's More menu, F2 and Delete act on, by its
/// index in the open document's outline: the one last clicked or focused;
/// null for the reader's section.

abstract class _$OutlineSelected extends $Notifier<int?> {
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
