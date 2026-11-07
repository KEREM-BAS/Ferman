// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stamp_clock.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The time a stamp is filled with, so tests and goldens can hold it still.

@ProviderFor(stampClock)
final stampClockProvider = StampClockProvider._();

/// The time a stamp is filled with, so tests and goldens can hold it still.

final class StampClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The time a stamp is filled with, so tests and goldens can hold it still.
  StampClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stampClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stampClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return stampClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$stampClockHash() => r'940af7a48293c75a857c99a8767e3351ae9f4f18';
