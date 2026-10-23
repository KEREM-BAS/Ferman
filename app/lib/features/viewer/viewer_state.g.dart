// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The document the canvas shows, as `openDocumentProvider`, or null.
///
/// Set by whatever opens a document: the tests in W2, the open picker,
/// drag and drop and the OS from W3 (ROADMAP §6 step 6).

@ProviderFor(OpenDocument)
final openDocumentProvider = OpenDocumentProvider._();

/// The document the canvas shows, as `openDocumentProvider`, or null.
///
/// Set by whatever opens a document: the tests in W2, the open picker,
/// drag and drop and the OS from W3 (ROADMAP §6 step 6).
final class OpenDocumentProvider
    extends $NotifierProvider<OpenDocument, OpenedDocument?> {
  /// The document the canvas shows, as `openDocumentProvider`, or null.
  ///
  /// Set by whatever opens a document: the tests in W2, the open picker,
  /// drag and drop and the OS from W3 (ROADMAP §6 step 6).
  OpenDocumentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openDocumentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openDocumentHash();

  @$internal
  @override
  OpenDocument create() => OpenDocument();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenedDocument? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenedDocument?>(value),
    );
  }
}

String _$openDocumentHash() => r'929cd058c1b1793cbef4f57c57342fcb7b2d3581';

/// The document the canvas shows, as `openDocumentProvider`, or null.
///
/// Set by whatever opens a document: the tests in W2, the open picker,
/// drag and drop and the OS from W3 (ROADMAP §6 step 6).

abstract class _$OpenDocument extends $Notifier<OpenedDocument?> {
  OpenedDocument? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<OpenedDocument?, OpenedDocument?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OpenedDocument?, OpenedDocument?>,
              OpenedDocument?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Asks the status bar's page field for focus (⌘G or Ctrl+G, a2-13): the
/// count of requests, as `pageFieldRequestProvider`.

@ProviderFor(PageFieldRequest)
final pageFieldRequestProvider = PageFieldRequestProvider._();

/// Asks the status bar's page field for focus (⌘G or Ctrl+G, a2-13): the
/// count of requests, as `pageFieldRequestProvider`.
final class PageFieldRequestProvider
    extends $NotifierProvider<PageFieldRequest, int> {
  /// Asks the status bar's page field for focus (⌘G or Ctrl+G, a2-13): the
  /// count of requests, as `pageFieldRequestProvider`.
  PageFieldRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pageFieldRequestProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pageFieldRequestHash();

  @$internal
  @override
  PageFieldRequest create() => PageFieldRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$pageFieldRequestHash() => r'4c30dcfe1d7d0faf93a2c8cc17359d0c5f21c798';

/// Asks the status bar's page field for focus (⌘G or Ctrl+G, a2-13): the
/// count of requests, as `pageFieldRequestProvider`.

abstract class _$PageFieldRequest extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The canvas's view of the open document, as `viewerProvider`: null when
/// no document is open. The View row, the status bar and the canvas read
/// and change it.

@ProviderFor(Viewer)
final viewerProvider = ViewerProvider._();

/// The canvas's view of the open document, as `viewerProvider`: null when
/// no document is open. The View row, the status bar and the canvas read
/// and change it.
final class ViewerProvider extends $NotifierProvider<Viewer, ViewerState?> {
  /// The canvas's view of the open document, as `viewerProvider`: null when
  /// no document is open. The View row, the status bar and the canvas read
  /// and change it.
  ViewerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewerHash();

  @$internal
  @override
  Viewer create() => Viewer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewerState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewerState?>(value),
    );
  }
}

String _$viewerHash() => r'5035f23893dc59d6eb080c342c59e0e4a30cfeee';

/// The canvas's view of the open document, as `viewerProvider`: null when
/// no document is open. The View row, the status bar and the canvas read
/// and change it.

abstract class _$Viewer extends $Notifier<ViewerState?> {
  ViewerState? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ViewerState?, ViewerState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ViewerState?, ViewerState?>,
              ViewerState?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
