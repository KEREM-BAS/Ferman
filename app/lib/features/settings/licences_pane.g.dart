// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'licences_pane.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every licence the app ships, by component, sorted by name, as
/// `licencesProvider`: what Flutter's build collects (the engine and the
/// Dart packages), the texts `registerLicenses()` adds (PDFium and its
/// packager, the fonts, the icons, the Rust crates), less the Dart packages
/// that only build and test the app ([ships]).

@ProviderFor(licences)
final licencesProvider = LicencesProvider._();

/// Every licence the app ships, by component, sorted by name, as
/// `licencesProvider`: what Flutter's build collects (the engine and the
/// Dart packages), the texts `registerLicenses()` adds (PDFium and its
/// packager, the fonts, the icons, the Rust crates), less the Dart packages
/// that only build and test the app ([ships]).

final class LicencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Licensed>>,
          List<Licensed>,
          FutureOr<List<Licensed>>
        >
    with $FutureModifier<List<Licensed>>, $FutureProvider<List<Licensed>> {
  /// Every licence the app ships, by component, sorted by name, as
  /// `licencesProvider`: what Flutter's build collects (the engine and the
  /// Dart packages), the texts `registerLicenses()` adds (PDFium and its
  /// packager, the fonts, the icons, the Rust crates), less the Dart packages
  /// that only build and test the app ([ships]).
  LicencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'licencesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$licencesHash();

  @$internal
  @override
  $FutureProviderElement<List<Licensed>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Licensed>> create(Ref ref) {
    return licences(ref);
  }
}

String _$licencesHash() => r'0a7ebf731bf47db04d9fd130cf912ee786529e38';
