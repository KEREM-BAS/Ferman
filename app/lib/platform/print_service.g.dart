// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'print_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The system's printing, as `printServiceProvider`; `bootstrap()` gives the
/// runner's.

@ProviderFor(printService)
final printServiceProvider = PrintServiceProvider._();

/// The system's printing, as `printServiceProvider`; `bootstrap()` gives the
/// runner's.

final class PrintServiceProvider
    extends $FunctionalProvider<PrintService, PrintService, PrintService>
    with $Provider<PrintService> {
  /// The system's printing, as `printServiceProvider`; `bootstrap()` gives the
  /// runner's.
  PrintServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'printServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$printServiceHash();

  @$internal
  @override
  $ProviderElement<PrintService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PrintService create(Ref ref) {
    return printService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrintService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrintService>(value),
    );
  }
}

String _$printServiceHash() => r'a5b72bca901e064c1d688bfe56e5bdda62a4baad';
