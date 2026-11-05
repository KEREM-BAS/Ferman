import 'dart:async';

import 'package:ferman/design/components/components.dart' show SaveState;
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'edit_session.g.dart';

/// The text block an inline editor is open on (a3-1b).
@immutable
final class ActiveEdit {
  /// The editor on [block] of [page] of [document], its caret at [caret].
  const new({
    required this.document,
    required this.page,
    required this.block,
    required this.caret,
  });

  /// The engine's document.
  final int document;

  /// The block's page, from 0.
  final int page;

  /// The block as the engine laid it out when the editor opened.
  final TextBlock block;

  /// Where the click put the caret: an index in the block's text, in code
  /// points.
  final int caret;
}

/// The open document's editing: the block being edited, its history
/// (a3-10) and the render key of its last revision.
@immutable
final class EditorState {
  /// The state with [active] open over [history].
  const new({this.active, this.history = const EditHistory(), this.renderKey});

  /// The block being edited, or null.
  final ActiveEdit? active;

  /// The document's committed steps.
  final EditHistory history;

  /// Every page's render key after the last commit, undo or redo; null
  /// before any. Bitmaps with an older one show an older revision.
  final int? renderKey;

  /// Whether ⌘Z or Ctrl+Z has something to undo: a step, or the typing
  /// open in a block, which commits first.
  bool get canUndo => history.current > 0 || active != null;

  /// Whether a step undone can be redone.
  bool get canRedo => history.current < history.steps.length;
}

/// Edits the open document's text through the engine's transactions, as
/// `documentEditorProvider` (ARCHITECTURE §3.6).
///
/// A click on an editable block opens its editor ([open]) and begins a
/// transaction; typing replaces the block's text in it ([type]). The
/// typing commits as one history step, named as [open] says, on blur,
/// Esc, a mode switch (the canvas calls [finish]), a tab switch or save
/// ([finish], which also closes
/// the editor), and after [idle] without input ([commit], which keeps the
/// editor open; typing on begins a new transaction). Undo and redo commit
/// the typing first, so ⌘Z undoes a typing burst. Every engine call runs
/// one after another, in the order they were asked for.
///
/// Each commit, undo and redo marks the shell's document unsaved; [save]
/// writes the committed steps to the file (an incremental update) and
/// marks it saved, or "Couldn't save" when it fails.
@Riverpod(keepAlive: true)
class DocumentEditor extends _$DocumentEditor {
  /// The coalescing rule's pause in milliseconds (PROGRESS, M3 decision
  /// 4): not motion, so not a token.
  static const int idleMs = 1500;

  /// [idleMs] as a duration.
  static const Duration idle = Duration(milliseconds: idleMs);

  Future<void> _queue = Future.value();
  int? _document;
  int? _transaction;
  String _name = '';
  String? _pending;
  Timer? _idle;

  EngineService get _engine => ref.read(engineServiceProvider);

  @override
  EditorState build() {
    _document = ref.read(openDocumentProvider)?.id;
    ref
      ..onDispose(() => _idle?.cancel())
      ..listen(openDocumentProvider.select((document) => document?.id), (
        _,
        next,
      ) {
        _idle?.cancel();
        unawaited(
          _run(() async {
            await _commit();
            _document = next;
            state = const EditorState();
            if (next != null) await _refresh(next, null);
          }),
        );
      });
    if (_document case final document?) {
      unawaited(_run(() => _refresh(document, null)));
    }
    return const EditorState();
  }

  /// Runs [step] after every step asked for before it.
  Future<void> _run(Future<void> Function() step) {
    final next = _queue.then((_) => step());
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Opens the editor on [block] of [page] with its caret at [caret],
  /// after committing the one open; its typing becomes the history step
  /// [name]. A block the engine refuses opens nothing.
  Future<void> open(
    int page,
    TextBlock block, {
    required int caret,
    required String name,
  }) {
    _idle?.cancel();
    return _run(() async {
      await _close();
      final document = _document;
      if (document == null) return;
      try {
        _transaction = await _engine.beginEdit(document, page, block.id);
      } on EngineException {
        return;
      }
      _name = name;
      state = EditorState(
        active: ActiveEdit(
          document: document,
          page: page,
          block: block,
          caret: caret,
        ),
        history: state.history,
        renderKey: state.renderKey,
      );
    });
  }

  /// Gives the open block [text], its lines separated by line feeds.
  void type(String text) {
    if (state.active == null) return;
    _pending = text;
    _idle?.cancel();
    _idle = Timer(idle, () => unawaited(commit()));
    unawaited(_run(_apply));
  }

  /// Sends the newest text typed, if any, in the open transaction or in a
  /// new one after an idle commit.
  Future<void> _apply() async {
    final text = _pending;
    final active = state.active;
    _pending = null;
    if (text == null || active == null) return;
    try {
      final transaction = _transaction ??= await _engine.beginEdit(
        active.document,
        active.page,
        active.block.id,
      );
      // shortcut: text the engine cannot write yet (another number of
      // lines, characters no font has) stays unapplied without a word; the
      // overflow and missing-glyph states come in W2 and W3.
      await _engine.applyEdit(transaction, text);
      // Typing not yet committed is unsaved too: Save, and closing the tab
      // asks first.
      if (!_unsaved(active.document)) {
        _mark(active.document, SaveState.unsaved);
      }
    } on EngineException {
      // Kept as it was.
    }
  }

  /// Commits the typing so far as a step and keeps the editor open.
  Future<void> commit() {
    _idle?.cancel();
    return _run(_commit);
  }

  /// Commits the typing so far and closes the editor.
  Future<void> finish() {
    _idle?.cancel();
    return _run(_close);
  }

  Future<void> _commit() async {
    await _apply();
    final transaction = _transaction;
    if (transaction == null) return;
    _transaction = null;
    final document = state.active?.document ?? _document;
    try {
      final info = await _engine.commitEdit(transaction, _name);
      if (document != null) await _refresh(document, info);
    } on EngineException {
      // The engine dropped the transaction; the history is as it was.
    }
  }

  Future<void> _close() async {
    await _commit();
    if (state.active != null) {
      state = EditorState(history: state.history, renderKey: state.renderKey);
    }
  }

  /// Steps back one step, after committing the typing.
  Future<void> undo() => _step(_engine.undo);

  /// Steps forward one step undone.
  Future<void> redo() => _step(_engine.redo);

  /// Undoes or redoes until [current] steps apply (a3-10's "Click a step
  /// to go back to it").
  Future<void> goTo(int current) {
    _idle?.cancel();
    return _run(() async {
      await _close();
      final document = _document;
      if (document == null) return;
      try {
        final steps = state.history.steps.length;
        for (var i = 0; i < steps && state.history.current != current; i++) {
          final info = await (state.history.current > current
              ? _engine.undo(document)
              : _engine.redo(document));
          await _refresh(document, info);
        }
      } on EngineException {
        // Stops at the step it reached.
      }
    });
  }

  Future<void> _step(Future<RevisionInfo> Function(int) move) {
    _idle?.cancel();
    return _run(() async {
      await _close();
      final document = _document;
      if (document == null) return;
      try {
        await _refresh(document, await move(document));
      } on EngineException {
        // Nothing to undo or redo.
      }
    });
  }

  /// Saves the committed steps to the document's file, after committing
  /// the typing (ADR 0008).
  Future<void> save() {
    _idle?.cancel();
    return _run(() async {
      await _close();
      final document = _document;
      if (document == null) return;
      _mark(document, SaveState.saving);
      try {
        await _engine.save(document);
        _mark(document, SaveState.saved, savedAt: DateTime.now());
      } on Object {
        _mark(document, SaveState.error);
      }
    });
  }

  /// Reads [document]'s history after [info] (null: on opening it) and,
  /// when it changed something, marks the document unsaved.
  Future<void> _refresh(int document, RevisionInfo? info) async {
    final before = state.history;
    final history = await _engine.history(document);
    // A step taken changes the history even when the pages could not be
    // drawn again (no render key).
    final changed =
        info != null &&
        (info.renderKey != null ||
            history.current != before.current ||
            history.steps.length != before.steps.length);
    if (document == _document) {
      state = EditorState(
        active: state.active,
        history: history,
        renderKey: info?.renderKey ?? state.renderKey,
      );
    }
    if (changed) _mark(document, SaveState.unsaved);
  }

  /// Whether the shell's tab of [document] has unsaved changes.
  bool _unsaved(int document) => ref
      .read(shellDocumentsProvider)
      .documents
      .any((tab) => tab.document?.id == document && tab.unsaved);

  /// Gives the shell's tab of [document] [saveState], with [savedAt] when
  /// it saved, and the number of steps that apply as its edits.
  void _mark(int document, SaveState saveState, {DateTime? savedAt}) {
    final documents = ref.read(shellDocumentsProvider.notifier);
    for (final tab in ref.read(shellDocumentsProvider).documents) {
      if (tab.path case final path? when tab.document?.id == document) {
        documents.replace(
          path,
          tab.withSave(
            saveState,
            savedAt: savedAt,
            editCount: document == _document ? state.history.current : null,
          ),
        );
      }
    }
  }
}

/// Whether Edit's Undo history panel (a3-10) shows in place of the right
/// panel, as `editHistoryOpenProvider`.
@Riverpod(keepAlive: true)
class EditHistoryOpen extends _$EditHistoryOpen {
  @override
  bool build() => false;

  /// Shows the panel if [open], the right panel otherwise.
  // ignore: use_setters_to_change_properties
  void show({required bool open}) => state = open;
}
