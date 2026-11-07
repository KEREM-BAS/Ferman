// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fonts_pane.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The font families bundled with Ferman and installed on this computer,
/// read by the engine off the UI isolate each time the pane opens, as
/// `installedFontsProvider`. None when the engine cannot read them.

@ProviderFor(installedFonts)
final installedFontsProvider = InstalledFontsProvider._();

/// The font families bundled with Ferman and installed on this computer,
/// read by the engine off the UI isolate each time the pane opens, as
/// `installedFontsProvider`. None when the engine cannot read them.

final class InstalledFontsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InstalledFont>>,
          List<InstalledFont>,
          FutureOr<List<InstalledFont>>
        >
    with
        $FutureModifier<List<InstalledFont>>,
        $FutureProvider<List<InstalledFont>> {
  /// The font families bundled with Ferman and installed on this computer,
  /// read by the engine off the UI isolate each time the pane opens, as
  /// `installedFontsProvider`. None when the engine cannot read them.
  InstalledFontsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedFontsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedFontsHash();

  @$internal
  @override
  $FutureProviderElement<List<InstalledFont>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<InstalledFont>> create(Ref ref) {
    return installedFonts(ref);
  }
}

String _$installedFontsHash() => r'7af7d0331ac2d401009deb0be2714f14ff945902';
