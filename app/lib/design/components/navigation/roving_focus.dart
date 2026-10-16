import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A move of the arrow-key models of the segmented controls (ModeTabs,
/// SegmentedControl, the AnnotationTools colour group and the document
/// tabs) and of Toolbar, in logical order.
enum RovingStep {
  /// To the item before, wrapping to the last.
  previous,

  /// To the item after, wrapping to the first.
  next,

  /// To the first item (Home).
  first,

  /// To the last item (End).
  last,
}

/// The arrow-key handling the navigation components share: which key moves
/// where, in the visual direction, and which item a move lands on.
///
/// The design's handlers (`ModeTabs.jsx`, `SegmentedControl.jsx`,
/// `Toolbar.jsx`) read ArrowLeft and ArrowRight in the visual direction:
/// ArrowRight moves forward in left to right and backward in right to left,
/// and moves wrap. Keys with Control, Alt, Meta or Shift held are left to
/// the app's shortcuts. Not exported from the component library: an
/// implementation detail of the components in `navigation/`,
/// `annotations/` and `additions/`.
abstract final class RovingFocus {
  /// The step [event] asks for in [direction], or null when it is not a
  /// movement key: ArrowLeft and ArrowRight, and with [homeAndEnd] also
  /// Home and End. Only key-down and key-repeat events move.
  static RovingStep? stepFor(
    KeyEvent event,
    TextDirection direction, {
    bool homeAndEnd = false,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return null;
    }
    final rtl = direction == TextDirection.rtl;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      return rtl ? RovingStep.previous : RovingStep.next;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return rtl ? RovingStep.next : RovingStep.previous;
    }
    if (homeAndEnd && key == LogicalKeyboardKey.home) return RovingStep.first;
    if (homeAndEnd && key == LogicalKeyboardKey.end) return RovingStep.last;
    return null;
  }

  /// The index [step] lands on from [from] among [count] items, skipping
  /// the ones [canVisit] rejects; null when none can be visited. [from] is
  /// the current item, or -1 when no item has focus.
  static int? target(
    int from,
    int count,
    RovingStep step,
    bool Function(int index) canVisit,
  ) {
    if (count <= 0) return null;
    switch (step) {
      case RovingStep.first:
        for (var i = 0; i < count; i++) {
          if (canVisit(i)) return i;
        }
        return null;
      case RovingStep.last:
        for (var i = count - 1; i >= 0; i--) {
          if (canVisit(i)) return i;
        }
        return null;
      case RovingStep.previous || RovingStep.next:
        final delta = step == RovingStep.next ? 1 : -1;
        var index = from < 0 && delta < 0 ? count : from;
        for (var visited = 0; visited < count; visited++) {
          index = ((index + delta) % count + count) % count;
          if (canVisit(index)) return index;
        }
        return null;
    }
  }

  /// The scroll alignment that brings the item at [to], moved to from the
  /// item at [from], into view without jumping past it.
  static ScrollPositionAlignmentPolicy alignmentFor(int from, int to) =>
      to >= from
      ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
      : ScrollPositionAlignmentPolicy.keepVisibleAtStart;
}
