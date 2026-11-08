// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'form_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The open document's form as its committed steps leave it, in tab order,
/// read again after each step, undo and redo (a5-1); null without a
/// document. Reading generates
/// nothing (M4 decision 19). Kept, as the commands read it.

@ProviderFor(documentForm)
final documentFormProvider = DocumentFormProvider._();

/// The open document's form as its committed steps leave it, in tab order,
/// read again after each step, undo and redo (a5-1); null without a
/// document. Reading generates
/// nothing (M4 decision 19). Kept, as the commands read it.

final class DocumentFormProvider
    extends
        $FunctionalProvider<
          AsyncValue<FormInfo?>,
          FormInfo?,
          FutureOr<FormInfo?>
        >
    with $FutureModifier<FormInfo?>, $FutureProvider<FormInfo?> {
  /// The open document's form as its committed steps leave it, in tab order,
  /// read again after each step, undo and redo (a5-1); null without a
  /// document. Reading generates
  /// nothing (M4 decision 19). Kept, as the commands read it.
  DocumentFormProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentFormProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentFormHash();

  @$internal
  @override
  $FutureProviderElement<FormInfo?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FormInfo?> create(Ref ref) {
    return documentForm(ref);
  }
}

String _$documentFormHash() => r'a6d855e5f1b90891414de7a9a794371f852939c0';

/// What the open document's permissions and signatures say about filling it;
/// null until the engine answers (G35, G47's signed-form notice).

@ProviderFor(fillGate)
final fillGateProvider = FillGateProvider._();

/// What the open document's permissions and signatures say about filling it;
/// null until the engine answers (G35, G47's signed-form notice).

final class FillGateProvider
    extends $FunctionalProvider<AsyncValue<OpGate?>, OpGate?, FutureOr<OpGate?>>
    with $FutureModifier<OpGate?>, $FutureProvider<OpGate?> {
  /// What the open document's permissions and signatures say about filling it;
  /// null until the engine answers (G35, G47's signed-form notice).
  FillGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fillGateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fillGateHash();

  @$internal
  @override
  $FutureProviderElement<OpGate?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OpGate?> create(Ref ref) {
    return fillGate(ref);
  }
}

String _$fillGateHash() => r'c4ff6645620247385f8abac8f9f7161f1898a178';

/// Why the open document cannot be filled, in the language given, or null
/// when it can.

@ProviderFor(fillRefusal)
final fillRefusalProvider = FillRefusalProvider._();

/// Why the open document cannot be filled, in the language given, or null
/// when it can.

final class FillRefusalProvider
    extends
        $FunctionalProvider<
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?
        >
    with $Provider<String Function(AppLocalizations)?> {
  /// Why the open document cannot be filled, in the language given, or null
  /// when it can.
  FillRefusalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fillRefusalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fillRefusalHash();

  @$internal
  @override
  $ProviderElement<String Function(AppLocalizations)?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  String Function(AppLocalizations)? create(Ref ref) {
    return fillRefusal(ref);
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

String _$fillRefusalHash() => r'1e4a61af964694bb3ed63291a4c06c96add65003';

/// Fill & Sign's choices, as `fillToolsProvider`.

@ProviderFor(FillToolsState)
final fillToolsStateProvider = FillToolsStateProvider._();

/// Fill & Sign's choices, as `fillToolsProvider`.
final class FillToolsStateProvider
    extends $NotifierProvider<FillToolsState, FillTools> {
  /// Fill & Sign's choices, as `fillToolsProvider`.
  FillToolsStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fillToolsStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fillToolsStateHash();

  @$internal
  @override
  FillToolsState create() => FillToolsState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FillTools value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FillTools>(value),
    );
  }
}

String _$fillToolsStateHash() => r'f7928d4eb2822b02aaa6ea9ae56043bedbf88e97';

/// Fill & Sign's choices, as `fillToolsProvider`.

abstract class _$FillToolsState extends $Notifier<FillTools> {
  FillTools build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FillTools, FillTools>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FillTools, FillTools>,
              FillTools,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The open document's [FormView], as `formSessionProvider`; each document
/// keeps its own.

@ProviderFor(FormSession)
final formSessionProvider = FormSessionProvider._();

/// The open document's [FormView], as `formSessionProvider`; each document
/// keeps its own.
final class FormSessionProvider
    extends $NotifierProvider<FormSession, FormView> {
  /// The open document's [FormView], as `formSessionProvider`; each document
  /// keeps its own.
  FormSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formSessionHash();

  @$internal
  @override
  FormSession create() => FormSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FormView value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FormView>(value),
    );
  }
}

String _$formSessionHash() => r'86a3cd29839a21c47aa2d34a9ffefc4ea8a62a60';

/// The open document's [FormView], as `formSessionProvider`; each document
/// keeps its own.

abstract class _$FormSession extends $Notifier<FormView> {
  FormView build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FormView, FormView>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FormView, FormView>,
              FormView,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The form's commands, each one step of the history (a5-1, a5-2, G47), as
/// `formCommandsProvider`. A signed document asks first (a3-16a).

@ProviderFor(FormCommands)
final formCommandsProvider = FormCommandsProvider._();

/// The form's commands, each one step of the history (a5-1, a5-2, G47), as
/// `formCommandsProvider`. A signed document asks first (a3-16a).
final class FormCommandsProvider extends $NotifierProvider<FormCommands, void> {
  /// The form's commands, each one step of the history (a5-1, a5-2, G47), as
  /// `formCommandsProvider`. A signed document asks first (a3-16a).
  FormCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formCommandsHash();

  @$internal
  @override
  FormCommands create() => FormCommands();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$formCommandsHash() => r'1eff0aa386f7c8a4b84fc79f845f8dec6f716138';

/// The form's commands, each one step of the history (a5-1, a5-2, G47), as
/// `formCommandsProvider`. A signed document asks first (a3-16a).

abstract class _$FormCommands extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Form widgets on the canvas, as `formWidgetsShownProvider`: drawn in every
/// mode and tool but Fill & Sign's fields, whose overlay draws each field with
/// its value, so no value shows twice. Render-only, never saved; the canvas
/// listens while it shows a document.

@ProviderFor(FormWidgetsShown)
final formWidgetsShownProvider = FormWidgetsShownProvider._();

/// Form widgets on the canvas, as `formWidgetsShownProvider`: drawn in every
/// mode and tool but Fill & Sign's fields, whose overlay draws each field with
/// its value, so no value shows twice. Render-only, never saved; the canvas
/// listens while it shows a document.
final class FormWidgetsShownProvider
    extends $NotifierProvider<FormWidgetsShown, FormWidgetsVisibility> {
  /// Form widgets on the canvas, as `formWidgetsShownProvider`: drawn in every
  /// mode and tool but Fill & Sign's fields, whose overlay draws each field with
  /// its value, so no value shows twice. Render-only, never saved; the canvas
  /// listens while it shows a document.
  FormWidgetsShownProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formWidgetsShownProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formWidgetsShownHash();

  @$internal
  @override
  FormWidgetsShown create() => FormWidgetsShown();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FormWidgetsVisibility value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FormWidgetsVisibility>(value),
    );
  }
}

String _$formWidgetsShownHash() => r'07f6c44b449440f52ed4d3662875d047bc196b53';

/// Form widgets on the canvas, as `formWidgetsShownProvider`: drawn in every
/// mode and tool but Fill & Sign's fields, whose overlay draws each field with
/// its value, so no value shows twice. Render-only, never saved; the canvas
/// listens while it shows a document.

abstract class _$FormWidgetsShown extends $Notifier<FormWidgetsVisibility> {
  FormWidgetsVisibility build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FormWidgetsVisibility, FormWidgetsVisibility>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FormWidgetsVisibility, FormWidgetsVisibility>,
              FormWidgetsVisibility,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
