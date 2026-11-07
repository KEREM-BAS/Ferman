// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'links.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The open document's links as its history stands now (a3-6).

@ProviderFor(documentLinks)
final documentLinksProvider = DocumentLinksProvider._();

/// The open document's links as its history stands now (a3-6).

final class DocumentLinksProvider
    extends
        $FunctionalProvider<AsyncValue<LinkList>, LinkList, FutureOr<LinkList>>
    with $FutureModifier<LinkList>, $FutureProvider<LinkList> {
  /// The open document's links as its history stands now (a3-6).
  DocumentLinksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentLinksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentLinksHash();

  @$internal
  @override
  $FutureProviderElement<LinkList> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<LinkList> create(Ref ref) {
    return documentLinks(ref);
  }
}

String _$documentLinksHash() => r'4eef70baa63cbf53bcf2c468aae61ff871a15b76';

/// What the open document's permissions say about its links; null until the
/// engine answers, and without a document.

@ProviderFor(linkGate)
final linkGateProvider = LinkGateProvider._();

/// What the open document's permissions say about its links; null until the
/// engine answers, and without a document.

final class LinkGateProvider
    extends $FunctionalProvider<AsyncValue<OpGate?>, OpGate?, FutureOr<OpGate?>>
    with $FutureModifier<OpGate?>, $FutureProvider<OpGate?> {
  /// What the open document's permissions say about its links; null until the
  /// engine answers, and without a document.
  LinkGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkGateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkGateHash();

  @$internal
  @override
  $FutureProviderElement<OpGate?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OpGate?> create(Ref ref) {
    return linkGate(ref);
  }
}

String _$linkGateHash() => r'71a8eeacbcdf12a79197961c21ae1fbf079c088e';

/// Why the open document's links cannot change, in the language given, or null
/// when they can.

@ProviderFor(linkRefusal)
final linkRefusalProvider = LinkRefusalProvider._();

/// Why the open document's links cannot change, in the language given, or null
/// when they can.

final class LinkRefusalProvider
    extends
        $FunctionalProvider<
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?
        >
    with $Provider<String Function(AppLocalizations)?> {
  /// Why the open document's links cannot change, in the language given, or null
  /// when they can.
  LinkRefusalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkRefusalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkRefusalHash();

  @$internal
  @override
  $ProviderElement<String Function(AppLocalizations)?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  String Function(AppLocalizations)? create(Ref ref) {
    return linkRefusal(ref);
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

String _$linkRefusalHash() => r'b6c83cb501a941beae218fcf4ccd8b28bdc853c2';

/// Edit's Link tool, and following a link anywhere.

@ProviderFor(LinkTool)
final linkToolProvider = LinkToolProvider._();

/// Edit's Link tool, and following a link anywhere.
final class LinkToolProvider
    extends $NotifierProvider<LinkTool, LinkToolState> {
  /// Edit's Link tool, and following a link anywhere.
  LinkToolProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkToolProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkToolHash();

  @$internal
  @override
  LinkTool create() => LinkTool();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkToolState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkToolState>(value),
    );
  }
}

String _$linkToolHash() => r'3c9a2ae68e669534413d6b26c77639daf2b96951';

/// Edit's Link tool, and following a link anywhere.

abstract class _$LinkTool extends $Notifier<LinkToolState> {
  LinkToolState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LinkToolState, LinkToolState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LinkToolState, LinkToolState>,
              LinkToolState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
