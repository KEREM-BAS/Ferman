// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_app_prompt.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether a1-3 was answered in this run, so the start screen does not ask
/// again when it shows again.

@ProviderFor(DefaultAppAsked)
final defaultAppAskedProvider = DefaultAppAskedProvider._();

/// Whether a1-3 was answered in this run, so the start screen does not ask
/// again when it shows again.
final class DefaultAppAskedProvider
    extends $NotifierProvider<DefaultAppAsked, bool> {
  /// Whether a1-3 was answered in this run, so the start screen does not ask
  /// again when it shows again.
  DefaultAppAskedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultAppAskedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultAppAskedHash();

  @$internal
  @override
  DefaultAppAsked create() => DefaultAppAsked();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$defaultAppAskedHash() => r'5ca4dd02c95e90b1c9c24aea3dfb7a487acac5c1';

/// Whether a1-3 was answered in this run, so the start screen does not ask
/// again when it shows again.

abstract class _$DefaultAppAsked extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
