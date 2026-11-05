import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'document_closer.g.dart';

/// What closing shows, as `documentCloserProvider`.
@immutable
final class CloseFlow {
  /// The flow asking about [asking] (a1-10b) or [reviewing] (a11-7e).
  const new({this.asking, this.reviewing = const []});

  /// The one document a1-10b asks about, or null.
  final ShellDocument? asking;

  /// The documents a11-7e lists; empty when it does not show.
  final List<ShellDocument> reviewing;
}

/// Closing documents with unsaved changes and quitting, as
/// `documentCloserProvider`: a tab asks a1-10b, and quitting asks once, a1-10b
/// for one document and a11-7e for several. Save goes through the saving flow
/// (`documentSaverProvider`); any failure keeps the tab, stops the quit and
/// shows its error. "Don't save" deletes the recovery files. A quit leaves the
/// tabs in place, so they stay in the list to reopen next time.
@Riverpod(keepAlive: true)
class DocumentCloser extends _$DocumentCloser {
  /// The tabs "Close other documents…" still asks about, after the one
  /// [CloseFlow.asking] names.
  List<ShellDocument> _queue = const [];

  /// The quit waiting for an answer.
  Completer<bool>? _quit;

  /// Whether the quit was allowed: closing the window on macOS comes back as
  /// the system's quit, which must not ask again.
  bool _allowed = false;

  @override
  CloseFlow build() => const CloseFlow();

  DocumentEditor get _editor => ref.read(documentEditorProvider.notifier);

  DocumentOpener get _opener => ref.read(documentOpenerProvider.notifier);

  DocumentSaver get _saver => ref.read(documentSaverProvider.notifier);

  /// Commits the typing, which counts as unsaved until then, and waits for a
  /// save under way, so each tab says how it ended. It never throws: a quit
  /// waits on what follows.
  Future<void> _settle() async {
    try {
      await _editor.finish();
    } on Object {
      // The tabs then say what they said.
    }
  }

  /// [DocumentSaver.saveTab], where anything unexpected counts as not saved.
  Future<bool> _save(ShellDocument tab) async {
    try {
      return await _saver.saveTab(tab);
    } on Object {
      return false;
    }
  }

  ShellDocument? _tab(String path) => ref
      .read(shellDocumentsProvider)
      .documents
      .where((tab) => tab.path == path)
      .firstOrNull;

  /// Closes the tab of [path], after asking when it has unsaved changes
  /// (its close button, ⌘W or Ctrl+W).
  Future<void> close(String path) async {
    if (state.asking != null || _quit != null) return;
    await _settle();
    if (state.asking != null || _quit != null) return;
    final tab = _tab(path);
    if (tab == null) return;
    if (tab.unsaved) {
      state = CloseFlow(asking: tab);
    } else {
      _opener.close(path);
    }
  }

  /// Closes every tab but the one of [path] (a1-10's "Close other
  /// documents…"), asking about each with unsaved changes in turn.
  Future<void> closeOthers(String path) async {
    if (state.asking != null || _quit != null) return;
    await _settle();
    if (state.asking != null || _quit != null) return;
    _opener.closeOthers(path);
    _queue = [
      for (final tab in ref.read(shellDocumentsProvider).documents)
        if (tab.path != path && tab.unsaved) tab,
    ];
    _next();
  }

  void _next() {
    if (_queue.isEmpty) {
      state = const CloseFlow();
      return;
    }
    state = CloseFlow(asking: _queue.first);
    _queue = _queue.sublist(1);
  }

  /// a1-10b's Save. A save that fails keeps the tab and asks nothing more. A
  /// quit that came while it ran asks about its own list, and this answers
  /// only for the tab.
  Future<void> save() async {
    final tab = state.asking;
    final quitting = _quit != null;
    state = const CloseFlow();
    if (tab == null) return;
    if (!await _save(tab)) {
      _queue = const [];
      if (quitting || _quit == null) _stop(tab);
      return;
    }
    if (quitting) {
      _endQuit(allowed: true);
      return;
    }
    if (tab.path case final path?) _opener.close(path);
    if (_quit == null) _next();
  }

  /// a1-10b's "Don't save".
  Future<void> discard() async {
    final tab = state.asking;
    if (tab == null) return;
    if (_quit != null) {
      state = const CloseFlow();
      await _discard(tab);
      _endQuit(allowed: true);
      return;
    }
    if (tab.path case final path?) _opener.close(path, discard: true);
    _next();
  }

  /// Cancel and Esc, in a1-10b and a11-7e: nothing closes.
  void cancel() {
    _queue = const [];
    state = const CloseFlow();
    _endQuit(allowed: false);
  }

  /// Whether the app may quit, after asking about unsaved documents; the
  /// answer may wait for the person. Every way of quitting comes through
  /// here, once.
  Future<bool> quit() async {
    if (_allowed) return true;
    if (_quit case final waiting?) return await waiting.future;
    final answer = _quit = Completer<bool>();
    _queue = const [];
    // A question from closing a tab goes now: its answer must not end a quit
    // that has not asked about the other tabs yet.
    state = const CloseFlow();
    await _settle();
    final unsaved = [
      for (final tab in ref.read(shellDocumentsProvider).documents)
        if (tab.unsaved) tab,
    ];
    switch (unsaved) {
      case []:
        state = const CloseFlow();
        _endQuit(allowed: true);
      case [final tab]:
        state = CloseFlow(asking: tab);
      default:
        state = CloseFlow(reviewing: unsaved);
    }
    return await answer.future;
  }

  /// a11-7e's "Save and quit": saves [checked] in turn, discards the rest and
  /// quits. Any failure stops there and shows its error.
  Future<void> saveAndQuit(Set<ShellDocument> checked) async {
    final listed = state.reviewing;
    state = const CloseFlow();
    for (final tab in listed) {
      if (checked.contains(tab) && !await _save(tab)) {
        _stop(tab);
        return;
      }
    }
    for (final tab in listed) {
      if (!checked.contains(tab)) await _discard(tab);
    }
    _endQuit(allowed: true);
  }

  /// a11-7e's "Quit without saving": discards everything and quits.
  Future<void> quitWithoutSaving() async {
    final listed = state.reviewing;
    state = const CloseFlow();
    for (final tab in listed) {
      await _discard(tab);
    }
    _endQuit(allowed: true);
  }

  /// Deletes the recovery files of [tab], whose window goes next.
  Future<void> _discard(ShellDocument tab) async {
    if (tab.document?.id case final id?) {
      await ref
          .read(engineServiceProvider)
          .closeDiscarding(id)
          .catchError((Object _) {});
    }
  }

  /// After a failed save of [tab]: its tab shows, with the error or a11-7b's
  /// bar, and a quit waiting stops.
  void _stop(ShellDocument tab) {
    if (tab.path case final path?) {
      ref.read(shellDocumentsProvider.notifier).focus(path);
      ref.read(routerProvider).go(Routes.editor);
    }
    _endQuit(allowed: false);
  }

  void _endQuit({required bool allowed}) {
    _allowed = allowed;
    final answer = _quit;
    _quit = null;
    answer?.complete(allowed);
  }
}
