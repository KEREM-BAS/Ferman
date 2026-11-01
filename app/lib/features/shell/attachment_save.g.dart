// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_save.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Saves attachments where the person says (Sidebar › Attachments › Save
/// attachment as…, a2-3b, B110); its state is the last one that failed,
/// which the editor's toast shows until dismissed. The file is never opened.

@ProviderFor(AttachmentSaver)
final attachmentSaverProvider = AttachmentSaverProvider._();

/// Saves attachments where the person says (Sidebar › Attachments › Save
/// attachment as…, a2-3b, B110); its state is the last one that failed,
/// which the editor's toast shows until dismissed. The file is never opened.
final class AttachmentSaverProvider
    extends $NotifierProvider<AttachmentSaver, AttachmentSaveProblem?> {
  /// Saves attachments where the person says (Sidebar › Attachments › Save
  /// attachment as…, a2-3b, B110); its state is the last one that failed,
  /// which the editor's toast shows until dismissed. The file is never opened.
  AttachmentSaverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'attachmentSaverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$attachmentSaverHash();

  @$internal
  @override
  AttachmentSaver create() => AttachmentSaver();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AttachmentSaveProblem? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AttachmentSaveProblem?>(value),
    );
  }
}

String _$attachmentSaverHash() => r'aacbb59a076f90b17bed672b16a477c1e79ef01a';

/// Saves attachments where the person says (Sidebar › Attachments › Save
/// attachment as…, a2-3b, B110); its state is the last one that failed,
/// which the editor's toast shows until dismissed. The file is never opened.

abstract class _$AttachmentSaver extends $Notifier<AttachmentSaveProblem?> {
  AttachmentSaveProblem? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AttachmentSaveProblem?, AttachmentSaveProblem?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AttachmentSaveProblem?, AttachmentSaveProblem?>,
              AttachmentSaveProblem?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
