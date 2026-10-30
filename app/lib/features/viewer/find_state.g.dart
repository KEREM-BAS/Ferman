// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'find_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Finds text in the open document, as `findProvider`. Each document keeps
/// its own search: switching tabs stops a running one, keeping what it
/// found, and switching back shows it again.

@ProviderFor(Find)
final findProvider = FindProvider._();

/// Finds text in the open document, as `findProvider`. Each document keeps
/// its own search: switching tabs stops a running one, keeping what it
/// found, and switching back shows it again.
final class FindProvider extends $NotifierProvider<Find, FindState> {
  /// Finds text in the open document, as `findProvider`. Each document keeps
  /// its own search: switching tabs stops a running one, keeping what it
  /// found, and switching back shows it again.
  FindProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'findProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$findHash();

  @$internal
  @override
  Find create() => Find();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FindState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FindState>(value),
    );
  }
}

String _$findHash() => r'5fde038267f921dc4b9643f873890f5357f64de0';

/// Finds text in the open document, as `findProvider`. Each document keeps
/// its own search: switching tabs stops a running one, keeping what it
/// found, and switching back shows it again.

abstract class _$Find extends $Notifier<FindState> {
  FindState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FindState, FindState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FindState, FindState>,
              FindState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
