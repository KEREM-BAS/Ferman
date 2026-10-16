// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_window.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app window. `bootstrap()` overrides it with the desktop window; the
/// default draws no title bar of its own.

@ProviderFor(desktopWindow)
final desktopWindowProvider = DesktopWindowProvider._();

/// The app window. `bootstrap()` overrides it with the desktop window; the
/// default draws no title bar of its own.

final class DesktopWindowProvider
    extends $FunctionalProvider<DesktopWindow, DesktopWindow, DesktopWindow>
    with $Provider<DesktopWindow> {
  /// The app window. `bootstrap()` overrides it with the desktop window; the
  /// default draws no title bar of its own.
  DesktopWindowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'desktopWindowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$desktopWindowHash();

  @$internal
  @override
  $ProviderElement<DesktopWindow> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DesktopWindow create(Ref ref) {
    return desktopWindow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DesktopWindow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DesktopWindow>(value),
    );
  }
}

String _$desktopWindowHash() => r'f8ba976a78de2b3caa94c3046e8c46ed71af0bad';
