// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tools_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Tools row's open panel, or null, as `toolsPanelProvider`.

@ProviderFor(ToolsPanelNotifier)
final toolsPanelProvider = ToolsPanelNotifierProvider._();

/// The Tools row's open panel, or null, as `toolsPanelProvider`.
final class ToolsPanelNotifierProvider
    extends $NotifierProvider<ToolsPanelNotifier, ToolsPanel?> {
  /// The Tools row's open panel, or null, as `toolsPanelProvider`.
  ToolsPanelNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toolsPanelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toolsPanelNotifierHash();

  @$internal
  @override
  ToolsPanelNotifier create() => ToolsPanelNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ToolsPanel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ToolsPanel?>(value),
    );
  }
}

String _$toolsPanelNotifierHash() =>
    r'19542dba84dcb1d9100f9884831d6b25c5574326';

/// The Tools row's open panel, or null, as `toolsPanelProvider`.

abstract class _$ToolsPanelNotifier extends $Notifier<ToolsPanel?> {
  ToolsPanel? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ToolsPanel?, ToolsPanel?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ToolsPanel?, ToolsPanel?>,
              ToolsPanel?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The preset a9-1 shows chosen: Balanced, as drawn.

@ProviderFor(CompressChoice)
final compressChoiceProvider = CompressChoiceProvider._();

/// The preset a9-1 shows chosen: Balanced, as drawn.
final class CompressChoiceProvider
    extends $NotifierProvider<CompressChoice, CompressPreset> {
  /// The preset a9-1 shows chosen: Balanced, as drawn.
  CompressChoiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'compressChoiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$compressChoiceHash();

  @$internal
  @override
  CompressChoice create() => CompressChoice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CompressPreset value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CompressPreset>(value),
    );
  }
}

String _$compressChoiceHash() => r'dc23d6d3ae9d61003b5d6f609fad6575ebdd227e';

/// The preset a9-1 shows chosen: Balanced, as drawn.

abstract class _$CompressChoice extends $Notifier<CompressPreset> {
  CompressPreset build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CompressPreset, CompressPreset>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CompressPreset, CompressPreset>,
              CompressPreset,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// What Compress would do to the open document as its steps stand (a9-1).

@ProviderFor(compressAnalysis)
final compressAnalysisProvider = CompressAnalysisProvider._();

/// What Compress would do to the open document as its steps stand (a9-1).

final class CompressAnalysisProvider
    extends
        $FunctionalProvider<
          AsyncValue<CompressAnalysis?>,
          CompressAnalysis?,
          FutureOr<CompressAnalysis?>
        >
    with
        $FutureModifier<CompressAnalysis?>,
        $FutureProvider<CompressAnalysis?> {
  /// What Compress would do to the open document as its steps stand (a9-1).
  CompressAnalysisProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'compressAnalysisProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$compressAnalysisHash();

  @$internal
  @override
  $FutureProviderElement<CompressAnalysis?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CompressAnalysis?> create(Ref ref) {
    return compressAnalysis(ref);
  }
}

String _$compressAnalysisHash() => r'eee55f6069b20e32eb3938b293b874dde0a09fa0';

/// What the open document's permissions say about printing (B121); null
/// until the engine answers.

@ProviderFor(printGate)
final printGateProvider = PrintGateProvider._();

/// What the open document's permissions say about printing (B121); null
/// until the engine answers.

final class PrintGateProvider
    extends $FunctionalProvider<AsyncValue<OpGate?>, OpGate?, FutureOr<OpGate?>>
    with $FutureModifier<OpGate?>, $FutureProvider<OpGate?> {
  /// What the open document's permissions say about printing (B121); null
  /// until the engine answers.
  PrintGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'printGateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$printGateHash();

  @$internal
  @override
  $FutureProviderElement<OpGate?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OpGate?> create(Ref ref) {
    return printGate(ref);
  }
}

String _$printGateHash() => r'0ffcbde04e661a13ecbfab34603e05564fa33406';

/// Why the open document cannot be printed, in the language given, or null
/// when it can (B121, G27).

@ProviderFor(printRefusal)
final printRefusalProvider = PrintRefusalProvider._();

/// Why the open document cannot be printed, in the language given, or null
/// when it can (B121, G27).

final class PrintRefusalProvider
    extends
        $FunctionalProvider<
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?
        >
    with $Provider<String Function(AppLocalizations)?> {
  /// Why the open document cannot be printed, in the language given, or null
  /// when it can (B121, G27).
  PrintRefusalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'printRefusalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$printRefusalHash();

  @$internal
  @override
  $ProviderElement<String Function(AppLocalizations)?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  String Function(AppLocalizations)? create(Ref ref) {
    return printRefusal(ref);
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

String _$printRefusalHash() => r'edf6c37ac7c470a47367bca6b95fc3c0fdefb983';

/// The versions of the open document's file, newest first (a9-8), read again
/// after each save.

@ProviderFor(documentVersions)
final documentVersionsProvider = DocumentVersionsProvider._();

/// The versions of the open document's file, newest first (a9-8), read again
/// after each save.

final class DocumentVersionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VersionInfo>>,
          List<VersionInfo>,
          FutureOr<List<VersionInfo>>
        >
    with
        $FutureModifier<List<VersionInfo>>,
        $FutureProvider<List<VersionInfo>> {
  /// The versions of the open document's file, newest first (a9-8), read again
  /// after each save.
  DocumentVersionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentVersionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentVersionsHash();

  @$internal
  @override
  $FutureProviderElement<List<VersionInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VersionInfo>> create(Ref ref) {
    return documentVersions(ref);
  }
}

String _$documentVersionsHash() => r'17f981242d8b50179ee34d435ac6add3c04ea510';

/// The version a9-8 shows instead of the current document, as
/// `versionPreviewProvider`; the preview's document closes when another is
/// chosen, when the view goes and when another document shows.

@ProviderFor(VersionPreviewNotifier)
final versionPreviewProvider = VersionPreviewNotifierProvider._();

/// The version a9-8 shows instead of the current document, as
/// `versionPreviewProvider`; the preview's document closes when another is
/// chosen, when the view goes and when another document shows.
final class VersionPreviewNotifierProvider
    extends $NotifierProvider<VersionPreviewNotifier, VersionPreview?> {
  /// The version a9-8 shows instead of the current document, as
  /// `versionPreviewProvider`; the preview's document closes when another is
  /// chosen, when the view goes and when another document shows.
  VersionPreviewNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'versionPreviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$versionPreviewNotifierHash();

  @$internal
  @override
  VersionPreviewNotifier create() => VersionPreviewNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VersionPreview? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VersionPreview?>(value),
    );
  }
}

String _$versionPreviewNotifierHash() =>
    r'658712dbb62deb6cae87f2b7b820977be34eacf0';

/// The version a9-8 shows instead of the current document, as
/// `versionPreviewProvider`; the preview's document closes when another is
/// chosen, when the view goes and when another document shows.

abstract class _$VersionPreviewNotifier extends $Notifier<VersionPreview?> {
  VersionPreview? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VersionPreview?, VersionPreview?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VersionPreview?, VersionPreview?>,
              VersionPreview?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
