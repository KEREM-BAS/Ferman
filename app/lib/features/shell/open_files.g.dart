// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_files.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
/// system open panel, dropped on the window (a1-6) or sent by the system
/// (ADR 0021), each in a new active tab, or the tab of a file already open.
/// Its state is the last file of the latest request that did not open,
/// which the start screen and the editor show until dismissed (G116).

@ProviderFor(DocumentOpener)
final documentOpenerProvider = DocumentOpenerProvider._();

/// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
/// system open panel, dropped on the window (a1-6) or sent by the system
/// (ADR 0021), each in a new active tab, or the tab of a file already open.
/// Its state is the last file of the latest request that did not open,
/// which the start screen and the editor show until dismissed (G116).
final class DocumentOpenerProvider
    extends $NotifierProvider<DocumentOpener, OpenProblem?> {
  /// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
  /// system open panel, dropped on the window (a1-6) or sent by the system
  /// (ADR 0021), each in a new active tab, or the tab of a file already open.
  /// Its state is the last file of the latest request that did not open,
  /// which the start screen and the editor show until dismissed (G116).
  DocumentOpenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentOpenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentOpenerHash();

  @$internal
  @override
  DocumentOpener create() => DocumentOpener();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenProblem? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenProblem?>(value),
    );
  }
}

String _$documentOpenerHash() => r'e551d4e2a5f18731a513d899388fe09ede825f63';

/// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
/// system open panel, dropped on the window (a1-6) or sent by the system
/// (ADR 0021), each in a new active tab, or the tab of a file already open.
/// Its state is the last file of the latest request that did not open,
/// which the start screen and the editor show until dismissed (G116).

abstract class _$DocumentOpener extends $Notifier<OpenProblem?> {
  OpenProblem? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<OpenProblem?, OpenProblem?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OpenProblem?, OpenProblem?>,
              OpenProblem?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
