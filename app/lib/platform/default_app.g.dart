// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'default_app.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The system's default-app lookup, as `defaultPdfAppProvider`;
/// `bootstrap()` gives the runner's on macOS.

@ProviderFor(defaultPdfApp)
final defaultPdfAppProvider = DefaultPdfAppProvider._();

/// The system's default-app lookup, as `defaultPdfAppProvider`;
/// `bootstrap()` gives the runner's on macOS.

final class DefaultPdfAppProvider
    extends $FunctionalProvider<DefaultPdfApp, DefaultPdfApp, DefaultPdfApp>
    with $Provider<DefaultPdfApp> {
  /// The system's default-app lookup, as `defaultPdfAppProvider`;
  /// `bootstrap()` gives the runner's on macOS.
  DefaultPdfAppProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultPdfAppProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultPdfAppHash();

  @$internal
  @override
  $ProviderElement<DefaultPdfApp> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DefaultPdfApp create(Ref ref) {
    return defaultPdfApp(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DefaultPdfApp value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DefaultPdfApp>(value),
    );
  }
}

String _$defaultPdfAppHash() => r'e62ecd87f09a19b6876eb65902750548335ce586';

/// The app that opens PDF files now; null when the system does not say.
/// Invalidated after Ferman asks to become it.

@ProviderFor(pdfHandler)
final pdfHandlerProvider = PdfHandlerProvider._();

/// The app that opens PDF files now; null when the system does not say.
/// Invalidated after Ferman asks to become it.

final class PdfHandlerProvider
    extends
        $FunctionalProvider<
          AsyncValue<PdfHandler?>,
          PdfHandler?,
          FutureOr<PdfHandler?>
        >
    with $FutureModifier<PdfHandler?>, $FutureProvider<PdfHandler?> {
  /// The app that opens PDF files now; null when the system does not say.
  /// Invalidated after Ferman asks to become it.
  PdfHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pdfHandlerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pdfHandlerHash();

  @$internal
  @override
  $FutureProviderElement<PdfHandler?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PdfHandler?> create(Ref ref) {
    return pdfHandler(ref);
  }
}

String _$pdfHandlerHash() => r'd156bbe2d00f26fb45ab1bc1f6562e809c318c8d';
