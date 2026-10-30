// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The document the canvas shows, as `openDocumentProvider`, or null: the
/// active tab's (`shellDocumentsProvider`), or one a test shows.

@ProviderFor(OpenDocument)
final openDocumentProvider = OpenDocumentProvider._();

/// The document the canvas shows, as `openDocumentProvider`, or null: the
/// active tab's (`shellDocumentsProvider`), or one a test shows.
final class OpenDocumentProvider
    extends $NotifierProvider<OpenDocument, OpenedDocument?> {
  /// The document the canvas shows, as `openDocumentProvider`, or null: the
  /// active tab's (`shellDocumentsProvider`), or one a test shows.
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

String _$openDocumentHash() => r'4ac8d6efc7c11f4be44ce0d6004fc6104e5b5d32';

/// The document the canvas shows, as `openDocumentProvider`, or null: the
/// active tab's (`shellDocumentsProvider`), or one a test shows.

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

/// What one open document's views showed when its tab was left, by the
/// view's state type, so switching back restores its layers, view and
/// search (a1-10): per-document state in a family keyed by the document's
/// id (ADR 0011), as `documentMemoryProvider(id)`.
// shortcut: an entry stays until the app quits; invalidate it when closing
// documents ships (B029).

@ProviderFor(documentMemory)
final documentMemoryProvider = DocumentMemoryFamily._();

/// What one open document's views showed when its tab was left, by the
/// view's state type, so switching back restores its layers, view and
/// search (a1-10): per-document state in a family keyed by the document's
/// id (ADR 0011), as `documentMemoryProvider(id)`.
// shortcut: an entry stays until the app quits; invalidate it when closing
// documents ships (B029).

final class DocumentMemoryProvider
    extends $FunctionalProvider<DocumentMemory, DocumentMemory, DocumentMemory>
    with $Provider<DocumentMemory> {
  /// What one open document's views showed when its tab was left, by the
  /// view's state type, so switching back restores its layers, view and
  /// search (a1-10): per-document state in a family keyed by the document's
  /// id (ADR 0011), as `documentMemoryProvider(id)`.
  // shortcut: an entry stays until the app quits; invalidate it when closing
  // documents ships (B029).
  DocumentMemoryProvider._({
    required DocumentMemoryFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'documentMemoryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$documentMemoryHash();

  @override
  String toString() {
    return r'documentMemoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<DocumentMemory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DocumentMemory create(Ref ref) {
    final argument = this.argument as int;
    return documentMemory(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DocumentMemory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DocumentMemory>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentMemoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$documentMemoryHash() => r'af8a3ad8963b12e905376342311131761c3a3297';

/// What one open document's views showed when its tab was left, by the
/// view's state type, so switching back restores its layers, view and
/// search (a1-10): per-document state in a family keyed by the document's
/// id (ADR 0011), as `documentMemoryProvider(id)`.
// shortcut: an entry stays until the app quits; invalidate it when closing
// documents ships (B029).

final class DocumentMemoryFamily extends $Family
    with $FunctionalFamilyOverride<DocumentMemory, int> {
  DocumentMemoryFamily._()
    : super(
        retry: null,
        name: r'documentMemoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// What one open document's views showed when its tab was left, by the
  /// view's state type, so switching back restores its layers, view and
  /// search (a1-10): per-document state in a family keyed by the document's
  /// id (ADR 0011), as `documentMemoryProvider(id)`.
  // shortcut: an entry stays until the app quits; invalidate it when closing
  // documents ships (B029).

  DocumentMemoryProvider call(int document) =>
      DocumentMemoryProvider._(argument: document, from: this);

  @override
  String toString() => r'documentMemoryProvider';
}

/// Shows and hides the open document's layers (a2-3c) in every view, as
/// `layerVisibilityProvider`; null without a document.

@ProviderFor(LayerVisibility)
final layerVisibilityProvider = LayerVisibilityProvider._();

/// Shows and hides the open document's layers (a2-3c) in every view, as
/// `layerVisibilityProvider`; null without a document.
final class LayerVisibilityProvider
    extends $NotifierProvider<LayerVisibility, LayerState?> {
  /// Shows and hides the open document's layers (a2-3c) in every view, as
  /// `layerVisibilityProvider`; null without a document.
  LayerVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'layerVisibilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$layerVisibilityHash();

  @$internal
  @override
  LayerVisibility create() => LayerVisibility();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LayerState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LayerState?>(value),
    );
  }
}

String _$layerVisibilityHash() => r'8583196ba64e4764ad1eacf68629d069622e7242';

/// Shows and hides the open document's layers (a2-3c) in every view, as
/// `layerVisibilityProvider`; null without a document.

abstract class _$LayerVisibility extends $Notifier<LayerState?> {
  LayerState? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LayerState?, LayerState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LayerState?, LayerState?>,
              LayerState?,
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

String _$viewerHash() => r'ab50e9b3050c17d0c13689b1ff489054cee4bc64';

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
