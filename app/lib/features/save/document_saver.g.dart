// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_saver.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Saving the open documents, as `documentSaverProvider`: Save (⌘S), Save
/// as and Save a copy through the a1-11 sheet, Optimize and clean, the
/// repaired copy (B103), and what each failure shows: a11-7's and
/// a11-7d's dialog, then the f4 toast, or a11-7b's bar for a file that
/// changed on disk, which the window regaining focus checks too
/// ([checkExternalChanges]). A failed save leaves the file and the edits
/// as they were (ADR 0008).

@ProviderFor(DocumentSaver)
final documentSaverProvider = DocumentSaverProvider._();

/// Saving the open documents, as `documentSaverProvider`: Save (⌘S), Save
/// as and Save a copy through the a1-11 sheet, Optimize and clean, the
/// repaired copy (B103), and what each failure shows: a11-7's and
/// a11-7d's dialog, then the f4 toast, or a11-7b's bar for a file that
/// changed on disk, which the window regaining focus checks too
/// ([checkExternalChanges]). A failed save leaves the file and the edits
/// as they were (ADR 0008).
final class DocumentSaverProvider
    extends $NotifierProvider<DocumentSaver, SaveFlow> {
  /// Saving the open documents, as `documentSaverProvider`: Save (⌘S), Save
  /// as and Save a copy through the a1-11 sheet, Optimize and clean, the
  /// repaired copy (B103), and what each failure shows: a11-7's and
  /// a11-7d's dialog, then the f4 toast, or a11-7b's bar for a file that
  /// changed on disk, which the window regaining focus checks too
  /// ([checkExternalChanges]). A failed save leaves the file and the edits
  /// as they were (ADR 0008).
  DocumentSaverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentSaverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentSaverHash();

  @$internal
  @override
  DocumentSaver create() => DocumentSaver();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveFlow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveFlow>(value),
    );
  }
}

String _$documentSaverHash() => r'5e7538bcab80ef681969164c2b9fd84b3c88155a';

/// Saving the open documents, as `documentSaverProvider`: Save (⌘S), Save
/// as and Save a copy through the a1-11 sheet, Optimize and clean, the
/// repaired copy (B103), and what each failure shows: a11-7's and
/// a11-7d's dialog, then the f4 toast, or a11-7b's bar for a file that
/// changed on disk, which the window regaining focus checks too
/// ([checkExternalChanges]). A failed save leaves the file and the edits
/// as they were (ADR 0008).

abstract class _$DocumentSaver extends $Notifier<SaveFlow> {
  SaveFlow build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SaveFlow, SaveFlow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SaveFlow, SaveFlow>,
              SaveFlow,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
