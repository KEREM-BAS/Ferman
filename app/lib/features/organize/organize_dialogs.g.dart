// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organize_dialogs.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The dialog Organize shows now (G45, a6-5), one at a time: each of its files
/// has the function that asks for it.

@ProviderFor(OrganizeDialog)
final organizeDialogProvider = OrganizeDialogProvider._();

/// The dialog Organize shows now (G45, a6-5), one at a time: each of its files
/// has the function that asks for it.
final class OrganizeDialogProvider
    extends $NotifierProvider<OrganizeDialog, Widget?> {
  /// The dialog Organize shows now (G45, a6-5), one at a time: each of its files
  /// has the function that asks for it.
  OrganizeDialogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'organizeDialogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$organizeDialogHash();

  @$internal
  @override
  OrganizeDialog create() => OrganizeDialog();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Widget? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Widget?>(value),
    );
  }
}

String _$organizeDialogHash() => r'202c78171b65f3765479c3e3744e41717e6f1485';

/// The dialog Organize shows now (G45, a6-5), one at a time: each of its files
/// has the function that asks for it.

abstract class _$OrganizeDialog extends $Notifier<Widget?> {
  Widget? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Widget?, Widget?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Widget?, Widget?>,
              Widget?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
