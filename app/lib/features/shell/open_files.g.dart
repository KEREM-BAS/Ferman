// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_files.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
/// system open panel, dropped on the window (a1-6), sent by the system (ADR
/// 0021) or picked from the recent files, each in a new active tab, or the
/// tab of a file already open. Each file that opens goes first in the
/// recent files ([RecentFiles.opened]).
///
/// A file that needs its password opens as a locked tab with the unlock
/// dialog (a1-8, [unlock]); one that does not open shows why in its own
/// error tab (a1-9b, a1-9c). One that runs out of memory or past a limit
/// gets no tab: the state is the last such file of the latest request,
/// which the start screen and the editor show until dismissed (a1-9f).

@ProviderFor(DocumentOpener)
final documentOpenerProvider = DocumentOpenerProvider._();

/// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
/// system open panel, dropped on the window (a1-6), sent by the system (ADR
/// 0021) or picked from the recent files, each in a new active tab, or the
/// tab of a file already open. Each file that opens goes first in the
/// recent files ([RecentFiles.opened]).
///
/// A file that needs its password opens as a locked tab with the unlock
/// dialog (a1-8, [unlock]); one that does not open shows why in its own
/// error tab (a1-9b, a1-9c). One that runs out of memory or past a limit
/// gets no tab: the state is the last such file of the latest request,
/// which the start screen and the editor show until dismissed (a1-9f).
final class DocumentOpenerProvider
    extends $NotifierProvider<DocumentOpener, OpenProblem?> {
  /// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
  /// system open panel, dropped on the window (a1-6), sent by the system (ADR
  /// 0021) or picked from the recent files, each in a new active tab, or the
  /// tab of a file already open. Each file that opens goes first in the
  /// recent files ([RecentFiles.opened]).
  ///
  /// A file that needs its password opens as a locked tab with the unlock
  /// dialog (a1-8, [unlock]); one that does not open shows why in its own
  /// error tab (a1-9b, a1-9c). One that runs out of memory or past a limit
  /// gets no tab: the state is the last such file of the latest request,
  /// which the start screen and the editor show until dismissed (a1-9f).
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

String _$documentOpenerHash() => r'd9a9c4e455eb7b9e66e6d3c7a954722ca6daadfd';

/// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
/// system open panel, dropped on the window (a1-6), sent by the system (ADR
/// 0021) or picked from the recent files, each in a new active tab, or the
/// tab of a file already open. Each file that opens goes first in the
/// recent files ([RecentFiles.opened]).
///
/// A file that needs its password opens as a locked tab with the unlock
/// dialog (a1-8, [unlock]); one that does not open shows why in its own
/// error tab (a1-9b, a1-9c). One that runs out of memory or past a limit
/// gets no tab: the state is the last such file of the latest request,
/// which the start screen and the editor show until dismissed (a1-9f).

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
