import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'text_state.g.dart';

/// The text the Select tool has selected on the canvas (B106), for ⌘C or
/// Ctrl+C and the context menu's Copy; null with nothing selected. It
/// starts empty for each document.
@Riverpod(keepAlive: true)
class CanvasSelection extends _$CanvasSelection {
  @override
  PageSelection? build() {
    ref.watch(viewerProvider.select((view) => view?.document.id));
    return null;
  }

  /// Selects [selection]; null or an empty one clears it.
  void select(PageSelection? selection) =>
      state = selection == null || selection.text.isEmpty ? null : selection;
}

/// Why the text the pointer last pointed at in Edit mode cannot be edited,
/// for the Edit panel's callout (a3-19, G39); null after it pointed at
/// editable text. It starts empty for each document.
@Riverpod(keepAlive: true)
class EditCallout extends _$EditCallout {
  @override
  NotEditableReason? build() {
    ref.watch(viewerProvider.select((view) => view?.document.id));
    return null;
  }

  /// Shows the callout of [reason], or none.
  // ignore: use_setters_to_change_properties
  void show(NotEditableReason? reason) => state = reason;
}
