// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_closer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Closing documents with unsaved changes and quitting, as
/// `documentCloserProvider`: a tab asks a1-10b, and quitting asks once, a1-10b
/// for one document and a11-7e for several. Save goes through the saving flow
/// (`documentSaverProvider`); any failure keeps the tab, stops the quit and
/// shows its error. "Don't save" deletes the recovery files. A quit leaves the
/// tabs in place, so they stay in the list to reopen next time.

@ProviderFor(DocumentCloser)
final documentCloserProvider = DocumentCloserProvider._();

/// Closing documents with unsaved changes and quitting, as
/// `documentCloserProvider`: a tab asks a1-10b, and quitting asks once, a1-10b
/// for one document and a11-7e for several. Save goes through the saving flow
/// (`documentSaverProvider`); any failure keeps the tab, stops the quit and
/// shows its error. "Don't save" deletes the recovery files. A quit leaves the
/// tabs in place, so they stay in the list to reopen next time.
final class DocumentCloserProvider
    extends $NotifierProvider<DocumentCloser, CloseFlow> {
  /// Closing documents with unsaved changes and quitting, as
  /// `documentCloserProvider`: a tab asks a1-10b, and quitting asks once, a1-10b
  /// for one document and a11-7e for several. Save goes through the saving flow
  /// (`documentSaverProvider`); any failure keeps the tab, stops the quit and
  /// shows its error. "Don't save" deletes the recovery files. A quit leaves the
  /// tabs in place, so they stay in the list to reopen next time.
  DocumentCloserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentCloserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentCloserHash();

  @$internal
  @override
  DocumentCloser create() => DocumentCloser();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloseFlow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloseFlow>(value),
    );
  }
}

String _$documentCloserHash() => r'ef697db654ce37cebb8d2c5c96a0a2f6b11aa2c1';

/// Closing documents with unsaved changes and quitting, as
/// `documentCloserProvider`: a tab asks a1-10b, and quitting asks once, a1-10b
/// for one document and a11-7e for several. Save goes through the saving flow
/// (`documentSaverProvider`); any failure keeps the tab, stops the quit and
/// shows its error. "Don't save" deletes the recovery files. A quit leaves the
/// tabs in place, so they stay in the list to reopen next time.

abstract class _$DocumentCloser extends $Notifier<CloseFlow> {
  CloseFlow build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CloseFlow, CloseFlow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CloseFlow, CloseFlow>,
              CloseFlow,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
