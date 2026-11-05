// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The text the Select tool has selected on the canvas (B106), for ⌘C or
/// Ctrl+C and the context menu's Copy; null with nothing selected. It
/// starts empty for each document.

@ProviderFor(CanvasSelection)
final canvasSelectionProvider = CanvasSelectionProvider._();

/// The text the Select tool has selected on the canvas (B106), for ⌘C or
/// Ctrl+C and the context menu's Copy; null with nothing selected. It
/// starts empty for each document.
final class CanvasSelectionProvider
    extends $NotifierProvider<CanvasSelection, PageSelection?> {
  /// The text the Select tool has selected on the canvas (B106), for ⌘C or
  /// Ctrl+C and the context menu's Copy; null with nothing selected. It
  /// starts empty for each document.
  CanvasSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'canvasSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$canvasSelectionHash();

  @$internal
  @override
  CanvasSelection create() => CanvasSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PageSelection? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PageSelection?>(value),
    );
  }
}

String _$canvasSelectionHash() => r'9d77047ac86cb086f2c5d7441ffcd87fec972982';

/// The text the Select tool has selected on the canvas (B106), for ⌘C or
/// Ctrl+C and the context menu's Copy; null with nothing selected. It
/// starts empty for each document.

abstract class _$CanvasSelection extends $Notifier<PageSelection?> {
  PageSelection? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PageSelection?, PageSelection?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PageSelection?, PageSelection?>,
              PageSelection?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Why the text the pointer last pointed at in Edit mode cannot be edited,
/// for the Edit panel's callout (a3-19, G39); null after it pointed at
/// editable text. It starts empty for each document.

@ProviderFor(EditCallout)
final editCalloutProvider = EditCalloutProvider._();

/// Why the text the pointer last pointed at in Edit mode cannot be edited,
/// for the Edit panel's callout (a3-19, G39); null after it pointed at
/// editable text. It starts empty for each document.
final class EditCalloutProvider
    extends $NotifierProvider<EditCallout, NotEditableReason?> {
  /// Why the text the pointer last pointed at in Edit mode cannot be edited,
  /// for the Edit panel's callout (a3-19, G39); null after it pointed at
  /// editable text. It starts empty for each document.
  EditCalloutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editCalloutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editCalloutHash();

  @$internal
  @override
  EditCallout create() => EditCallout();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotEditableReason? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotEditableReason?>(value),
    );
  }
}

String _$editCalloutHash() => r'8fb592c89d5388b14315d25ac0e3acae9bb495bc';

/// Why the text the pointer last pointed at in Edit mode cannot be edited,
/// for the Edit panel's callout (a3-19, G39); null after it pointed at
/// editable text. It starts empty for each document.

abstract class _$EditCallout extends $Notifier<NotEditableReason?> {
  NotEditableReason? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<NotEditableReason?, NotEditableReason?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NotEditableReason?, NotEditableReason?>,
              NotEditableReason?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
