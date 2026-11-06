// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_recovery.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Crash recovery at launch, as `documentRecoveryProvider`: [check] asks the
/// engine once what a session that ended without cleaning up left (a1-12).
/// [open] restores the checked documents, each as unsaved in a tab of its own
/// (under a new name when its original changed, a11-7f), and deletes the
/// copies of the others; [discard] deletes them all. An encrypted one asks for
/// its password first. A copy that was not opened, by Cancel or a failure,
/// stays for the next launch.

@ProviderFor(DocumentRecovery)
final documentRecoveryProvider = DocumentRecoveryProvider._();

/// Crash recovery at launch, as `documentRecoveryProvider`: [check] asks the
/// engine once what a session that ended without cleaning up left (a1-12).
/// [open] restores the checked documents, each as unsaved in a tab of its own
/// (under a new name when its original changed, a11-7f), and deletes the
/// copies of the others; [discard] deletes them all. An encrypted one asks for
/// its password first. A copy that was not opened, by Cancel or a failure,
/// stays for the next launch.
final class DocumentRecoveryProvider
    extends $NotifierProvider<DocumentRecovery, RecoveryFlow> {
  /// Crash recovery at launch, as `documentRecoveryProvider`: [check] asks the
  /// engine once what a session that ended without cleaning up left (a1-12).
  /// [open] restores the checked documents, each as unsaved in a tab of its own
  /// (under a new name when its original changed, a11-7f), and deletes the
  /// copies of the others; [discard] deletes them all. An encrypted one asks for
  /// its password first. A copy that was not opened, by Cancel or a failure,
  /// stays for the next launch.
  DocumentRecoveryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentRecoveryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentRecoveryHash();

  @$internal
  @override
  DocumentRecovery create() => DocumentRecovery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecoveryFlow value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecoveryFlow>(value),
    );
  }
}

String _$documentRecoveryHash() => r'88ec75deb489c14723ebc466cd3f7197eaf0fe06';

/// Crash recovery at launch, as `documentRecoveryProvider`: [check] asks the
/// engine once what a session that ended without cleaning up left (a1-12).
/// [open] restores the checked documents, each as unsaved in a tab of its own
/// (under a new name when its original changed, a11-7f), and deletes the
/// copies of the others; [discard] deletes them all. An encrypted one asks for
/// its password first. A copy that was not opened, by Cancel or a failure,
/// stays for the next launch.

abstract class _$DocumentRecovery extends $Notifier<RecoveryFlow> {
  RecoveryFlow build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RecoveryFlow, RecoveryFlow>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RecoveryFlow, RecoveryFlow>,
              RecoveryFlow,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
