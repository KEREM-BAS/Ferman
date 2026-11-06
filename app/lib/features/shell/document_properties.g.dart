// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_properties.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// What [document]'s fonts need said beyond their status, by font name.

@ProviderFor(fontCoverage)
final fontCoverageProvider = FontCoverageFamily._();

/// What [document]'s fonts need said beyond their status, by font name.

final class FontCoverageProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, FontCoverage>>,
          Map<String, FontCoverage>,
          FutureOr<Map<String, FontCoverage>>
        >
    with
        $FutureModifier<Map<String, FontCoverage>>,
        $FutureProvider<Map<String, FontCoverage>> {
  /// What [document]'s fonts need said beyond their status, by font name.
  FontCoverageProvider._({
    required FontCoverageFamily super.from,
    required (int, String) super.argument,
  }) : super(
         retry: _never,
         name: r'fontCoverageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fontCoverageHash();

  @override
  String toString() {
    return r'fontCoverageProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, FontCoverage>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, FontCoverage>> create(Ref ref) {
    final argument = this.argument as (int, String);
    return fontCoverage(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is FontCoverageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fontCoverageHash() => r'10809d1452c648a181d2575c56f6736165fff3c8';

/// What [document]'s fonts need said beyond their status, by font name.

final class FontCoverageFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<String, FontCoverage>>,
          (int, String)
        > {
  FontCoverageFamily._()
    : super(
        retry: _never,
        name: r'fontCoverageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What [document]'s fonts need said beyond their status, by font name.

  FontCoverageProvider call(int document, String letters) =>
      FontCoverageProvider._(argument: (document, letters), from: this);

  @override
  String toString() => r'fontCoverageProvider';
}
