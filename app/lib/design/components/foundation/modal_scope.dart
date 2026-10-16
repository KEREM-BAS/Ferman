import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// How many Ferman modal surfaces are open: the signal the window frame
/// listens to while a modal covers it.
///
/// A modal `Dialog` and a modal `CommandPalette` open in the root overlay,
/// over the title bar too, and register here while they show. The title
/// bar reads [openCount] to stand down while a modal is open (on Windows
/// it gives the maximize button's snap-layout area back to Flutter, so the
/// scrim takes the pointer there as everywhere else).
///
/// A surface calls [open] when it shows and closes the returned
/// [ModalHandle] when it hides or goes away. Changes that happen while a
/// frame is being built, laid out or painted (a modal disposed with its
/// screen) reach the listeners after that frame, so a listener may call
/// `setState`.
abstract final class ModalScope {
  static final ValueNotifier<int> _count = ValueNotifier<int>(0);

  /// The count the listeners have not seen yet.
  static int _pending = 0;
  static bool _flushScheduled = false;

  /// Bumped by [debugReset]: a handle opened before it no longer counts.
  static int _generation = 0;

  /// The number of modals open now; 0 when none is.
  static ValueListenable<int> get openCount => _count;

  /// Whether a modal is open.
  static bool get isOpen => _count.value > 0;

  /// Records that a modal surface opened. Close the handle once it hides
  /// or is disposed; closing it again does nothing.
  static ModalHandle open({String? debugLabel}) {
    _change(1);
    return ModalHandle._(debugLabel, _generation);
  }

  static void _change(int delta) {
    _pending += delta;
    final binding = SchedulerBinding.instance;
    final phase = binding.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _flush();
      return;
    }
    if (_flushScheduled) return;
    _flushScheduled = true;
    binding
      ..addPostFrameCallback((_) {
        _flushScheduled = false;
        _flush();
      }, debugLabel: 'ModalScope')
      ..ensureVisualUpdate();
  }

  static void _flush() {
    _count.value = _pending < 0 ? 0 : _pending;
  }

  /// Forgets every open modal, for tests that end with one still open.
  /// Closing a handle opened before the reset then does nothing, so it
  /// cannot take a later modal off the count.
  @visibleForTesting
  static void debugReset() {
    _generation++;
    _pending = 0;
    _flushScheduled = false;
    _count.value = 0;
  }
}

/// One open modal surface, from [ModalScope.open].
final class ModalHandle {
  new _(this.debugLabel, this._generation);

  /// A name for debugging (the surface that opened it).
  final String? debugLabel;

  /// The [ModalScope] generation the handle was opened in.
  final int _generation;

  bool _closed = false;

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// Records that the modal hid or went away; only the first call counts.
  void close() {
    if (_closed) return;
    _closed = true;
    if (_generation == ModalScope._generation) ModalScope._change(-1);
  }

  @override
  String toString() =>
      'ModalHandle(${debugLabel ?? 'modal'}${_closed ? ', closed' : ''})';
}
