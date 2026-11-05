import 'dart:async';
import 'dart:ui' show Rect;

import 'package:ferman/design/components/components.dart' show SaveState;
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
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

/// Lines "Keep and warn" left hidden past a committed block's frame
/// (a3-4, a3-18): the page's margin status and its thumbnail's warning.
@immutable
final class HiddenLines {
  /// [lines] hidden past [frame] of [page]'s block [block].
  const new({
    required this.page,
    required this.block,
    required this.frame,
    required this.direction,
    required this.lines,
  });

  /// The page, from 0.
  final int page;

  /// The block's id.
  final int block;

  /// The block's frame, in the page's displayed points.
  final Rect frame;

  /// The direction its text runs in: the status sits at its end.
  final BlockDirection direction;

  /// How many lines are hidden.
  final int lines;
}

/// The open document's editing: the block being edited, its history
/// (a3-10) and the render key of its last revision.
@immutable
final class EditorState {
  /// The state with [active] open over [history].
  const new({
    this.active,
    this.history = const EditHistory(),
    this.renderKey,
    this.preview,
    this.settled = false,
    this.hidden = const [],
    this.fontSettled = false,
    this.picking = false,
    this.toast,
  });

  /// The block being edited, or null.
  final ActiveEdit? active;

  /// The engine's preview of the newest text applied to the block being
  /// edited or last committed: its overflow choices (a3-4) and the table
  /// cells that depend on it (a3-9); null before any text applies and
  /// after another block opens.
  final EditPreview? preview;

  /// Whether one of the [preview]'s overflow choices was picked, so the
  /// panel no longer asks.
  final bool settled;

  /// The lines "Keep and warn" left hidden in the steps that apply, the
  /// newest step of each block.
  final List<HiddenLines> hidden;

  /// Whether step 3's question was answered with "Keep as is" while no
  /// font could draw the characters, so the panel no longer asks.
  final bool fontSettled;

  /// Whether the a3-3b picker is open over the block being edited.
  final bool picking;

  /// The "Font substituted" toast of the last commit (a11-6), or null.
  final FontSubstitution? toast;

  /// Missing-glyph step 3 waiting for "Choose a font…" or "Keep as is"
  /// (a3-3a, a3-17), or null.
  MissingGlyphs? get glyphs => fontSettled ? null : preview?.glyphs;

  /// Step 2's substitution the panel says once (a3-17: "Character added
  /// from this computer"), or null.
  FontSubstitution? get notice => preview?.substitutions
      .where((s) => s.kind == SubstitutionKind.sameFont && !s.announced)
      .firstOrNull;

  /// The overflow choices waiting for an answer, or null.
  OverflowPlan? get asking => settled ? null : preview?.overflow;

  /// The lines the open block's "Keep and warn" hides now; 0 for none.
  int get keptHidden => active != null && preview?.chosen == OverflowChoice.keep
      ? preview?.overflow?.keepHidden ?? 0
      : 0;

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

  /// This state with the fields given replaced; [clearActive] and
  /// [clearPreview] drop the block and the preview.
  EditorState copy({
    ActiveEdit? active,
    bool clearActive = false,
    EditHistory? history,
    int? renderKey,
    EditPreview? preview,
    bool clearPreview = false,
    bool? settled,
    List<HiddenLines>? hidden,
    bool? fontSettled,
    bool? picking,
    FontSubstitution? toast,
    bool clearToast = false,
  }) => EditorState(
    active: clearActive ? null : active ?? this.active,
    history: history ?? this.history,
    renderKey: renderKey ?? this.renderKey,
    preview: clearPreview ? null : preview ?? this.preview,
    settled: settled ?? (!clearPreview && this.settled),
    hidden: hidden ?? this.hidden,
    fontSettled: fontSettled ?? (!clearPreview && this.fontSettled),
    picking: picking ?? (!clearPreview && this.picking),
    toast: clearToast ? null : toast ?? this.toast,
  );
}

/// The block a committed step changed, for [HiddenLines].
typedef _StepTarget = ({int page, int block, Rect frame, BlockDirection dir});

/// The newest commit whose overflow was still unanswered: a choice picked
/// after it replaces that step.
typedef _Unanswered = ({
  int document,
  int page,
  int block,
  String text,
  String name,
  int current,
});

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
/// Text that no longer fits its block comes back with "Keep and warn"
/// applied and the overflow choices in [EditorState.asking]; [resolve]
/// picks another, in the open transaction or, once the typing committed,
/// by undoing that step and writing the text again with the choice, so
/// either way it is one step.
///
/// Text with characters its font lacks comes back with missing-glyph step
/// 3 in [EditorState.glyphs] (ADR 0006): drawn provisionally in the
/// closest candidate, or not at all with "Ask each time" (the
/// [settingsProvider]'s policy, which the engine gets as it changes).
/// [chooseFont] and [keepAsIs] answer it in the open transaction; the idle
/// commit waits for the answer, and closing the editor in any other way
/// answers "Keep as is" first. A commit that set characters in another
/// font shows the "Font substituted" toast once ([EditorState.toast]).
///
/// Each commit, undo and redo marks the shell's document unsaved; [save]
/// writes the committed steps to the file (an incremental update) and
/// marks it saved, or "Couldn't save" when it fails, and returns the
/// failure for `documentSaverProvider` to show; [write] does the same for
/// Save as and Optimize and clean.
@Riverpod(keepAlive: true)
class DocumentEditor extends _$DocumentEditor {
  /// The coalescing rule's pause in milliseconds (PROGRESS, M3 decision
  /// 4): not motion, so not a token.
  static const int idleMs = 1500;

  /// [idleMs] as a duration.
  static const Duration idle = Duration(milliseconds: idleMs);

  /// How long the "Font substituted" toast stays (a11-6: "the rest leave
  /// after six seconds").
  // shortcut: hovering or focusing the toast does not hold it yet; a
  // toast region with that rule comes with the next toast that needs it.
  static const int toastMs = 6000;

  /// [toastMs] as a duration: not motion, so not a token.
  static const Duration toastTime = Duration(milliseconds: toastMs);

  Future<void> _queue = Future.value();
  Timer? _toastTimer;
  int? _document;
  int? _transaction;
  String _name = '';
  String? _pending;
  String? _applied;

  /// The newest text sent to the engine, applied or not.
  String? _requested;
  Timer? _idle;

  /// The block of each committed step, parallel to the history's steps;
  /// null for a step this notifier did not see committed.
  List<_StepTarget?> _targets = const [];
  _Unanswered? _unanswered;

  EngineService get _engine => ref.read(engineServiceProvider);

  @override
  EditorState build() {
    _document = ref.read(openDocumentProvider)?.id;
    ref
      ..onDispose(() {
        _idle?.cancel();
        _toastTimer?.cancel();
      })
      ..listen(
        settingsProvider.select((s) => s.missingGlyphs),
        (_, policy) => unawaited(_fonts(policy)),
        fireImmediately: true,
      )
      ..listen(
        settingsProvider.select((s) => s.recoveryCopies),
        (_, enabled) => unawaited(_recovery(enabled: enabled)),
        fireImmediately: true,
      )
      ..listen(openDocumentProvider.select((document) => document?.id), (
        _,
        next,
      ) {
        _idle?.cancel();
        unawaited(
          _run(() async {
            await _commit();
            _document = next;
            _targets = const [];
            _unanswered = null;
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

  /// Tells the engine where the fonts for missing glyphs come from: this
  /// computer's and Ferman's, and [policy]'s "Ask each time".
  Future<void> _fonts(MissingGlyphPolicy policy) => _run(() async {
    try {
      await _engine.setFontSettings(
        FontSettings(askEachTime: policy == MissingGlyphPolicy.ask),
      );
    } on Object {
      // Missing glyphs then go without installed and bundled fonts; an
      // engine that did not start has no edits either.
    }
  });

  /// Tells the engine a11-1c's "Save a recovery copy every minute".
  Future<void> _recovery({required bool enabled}) async {
    try {
      await _engine.setRecoveryEnabled(enabled: enabled);
    } on Object {
      // An engine that did not start has no edits to recover.
    }
  }

  /// Runs [step] after every step asked for before it.
  Future<void> _run(Future<void> Function() step) {
    final next = _queue.then((_) => step());
    _queue = next.catchError((Object _) {});
    return next;
  }

  /// Opens the editor on [block] of [page] with its caret at [caret],
  /// after committing the one open; its typing becomes the history step
  /// [name]. A block the engine refuses opens nothing. Before the first
  /// change to a signed document it asks first (a3-16a) and opens the block
  /// after "Edit anyway".
  Future<void> open(
    int page,
    TextBlock block, {
    required int caret,
    required String name,
  }) {
    final tab = ref.read(shellDocumentsProvider).active;
    final saver = ref.read(documentSaverProvider.notifier);
    if (tab?.document case final document?
        when document.id == _document && saver.needsConfirmation(document)) {
      saver.askSigned(
        tab!,
        () => unawaited(open(page, block, caret: caret, name: name)),
      );
      return Future.value();
    }
    _idle?.cancel();
    return _run(() async {
      await _close();
      final document = _document;
      // a3-16a waits on the typing just refused: its transaction stays.
      if (document == null || _transaction != null) return;
      try {
        _transaction = await _engine.beginEdit(document, page, block.id);
      } on EngineException {
        return;
      }
      _name = name;
      _applied = null;
      _unanswered = null;
      state = state.copy(
        active: ActiveEdit(
          document: document,
          page: page,
          block: block,
          caret: caret,
        ),
        clearPreview: true,
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
      _requested = text;
      final preview = await _engine.applyEdit(transaction, text);
      // Text with missing characters is not applied: the overflow stays
      // the one of the text applied before it.
      if (preview.missing.isEmpty) _applied = text;
      _unanswered = null;
      state = state.copy(preview: preview, settled: false, fontSettled: false);
      // Typing not yet committed is unsaved too: Save, and closing the tab
      // asks first.
      if (!_unsaved(active.document)) {
        _mark(active.document, SaveState.unsaved);
      }
    } on EngineException {
      // Kept as it was.
    }
  }

  /// Commits the typing so far as a step and keeps the editor open, unless
  /// missing-glyph step 3 waits for an answer: the idle commit.
  Future<void> commit() {
    _idle?.cancel();
    return _run(() => _commit(idle: true));
  }

  /// Commits the typing so far and closes the editor.
  Future<void> finish() {
    _idle?.cancel();
    return _run(_close);
  }

  Future<void> _commit({bool idle = false}) async {
    await _apply();
    final transaction = _transaction;
    if (transaction == null) return;
    if (state.glyphs != null) {
      // Never silent: the question stays until it is answered, and only
      // leaving the editor answers it, with "Keep as is".
      if (idle) return;
      await _keep(transaction);
      state = state.copy(picking: false);
    }
    _transaction = null;
    final active = state.active;
    final document = active?.document ?? _document;
    try {
      final info = await _engine.commitEdit(transaction, _name);
      if (document == null) return;
      _announce(info.substitutions);
      await _refresh(
        document,
        info,
        committed: active == null
            ? null
            : (
                page: active.page,
                block: active.block.id,
                frame: active.block.frame,
                dir: active.block.direction,
              ),
      );
      final text = _applied;
      if (active != null && text != null && state.asking != null) {
        _unanswered = (
          document: document,
          page: active.page,
          block: active.block.id,
          text: text,
          name: _name,
          current: state.history.current,
        );
      }
    } on EngineException catch (error) {
      // The engine dropped the transaction and the history is as it was,
      // unless the signed document waits for a3-16a: it stays open, for the
      // commit after "Edit anyway" or the rollback after Cancel.
      if (error.kind == EngineErrorKind.confirmationRequired) {
        _transaction = transaction;
        final tab = ref
            .read(shellDocumentsProvider)
            .documents
            .where((tab) => tab.document?.id == document)
            .firstOrNull;
        if (tab == null) {
          await _rollbackUnconfirmed();
        } else {
          ref
              .read(documentSaverProvider.notifier)
              .askSigned(
                tab,
                () => unawaited(commit()),
                cancelled: () => unawaited(_run(_rollbackUnconfirmed)),
              );
        }
      }
    }
  }

  /// Drops the typing the person chose not to confirm (a3-16a's Cancel).
  Future<void> _rollbackUnconfirmed() async {
    final transaction = _transaction;
    _transaction = null;
    if (transaction == null) return;
    _pending = null;
    _applied = null;
    state = state.copy(clearActive: true, clearPreview: true);
    try {
      await _engine.rollbackEdit(transaction);
    } on EngineException {
      // Nothing more to drop.
    }
  }

  /// Shows the "Font substituted" toast for the first of [substitutions]
  /// the app was not told of yet (step 3 only: step 2 keeps the same font
  /// and says so in the panel).
  void _announce(List<FontSubstitution> substitutions) {
    final next = substitutions
        .where((s) => s.kind == SubstitutionKind.similar && !s.announced)
        .firstOrNull;
    if (next == null) return;
    _toastTimer?.cancel();
    _toastTimer = Timer(toastTime, dismissToast);
    state = state.copy(toast: next);
  }

  /// Hides the "Font substituted" toast.
  void dismissToast() {
    _toastTimer?.cancel();
    if (state.toast != null) state = state.copy(clearToast: true);
  }

  /// Opens or closes the a3-3b picker for the block being edited.
  void showFontPicker({required bool open}) {
    if (open && state.glyphs == null) return;
    state = state.copy(picking: open);
  }

  /// Draws step 3's characters in [candidate] (a3-3b's "Use …") and closes
  /// the picker.
  Future<void> chooseFont(FontCandidate candidate) {
    _idle?.cancel();
    return _run(() async {
      final transaction = _transaction;
      state = state.copy(picking: false);
      if (transaction == null || state.glyphs == null) return;
      try {
        final preview = await _engine.chooseFont(
          transaction,
          candidate.origin,
          candidate.postscriptName,
        );
        _applied = _requested;
        state = state.copy(preview: preview);
      } on EngineException {
        // The provisional font stays; the question too.
      }
      _restartIdle();
    });
  }

  /// Keeps step 3's characters in the closest candidate (a3-3a's "Keep as
  /// is").
  Future<void> keepAsIs() {
    _idle?.cancel();
    return _run(() async {
      state = state.copy(picking: false);
      if (_transaction case final transaction? when state.glyphs != null) {
        await _keep(transaction);
      }
      _restartIdle();
    });
  }

  /// "Keep as is" in [transaction]. With no font to draw the characters
  /// the engine refuses, and the text last applied stays, kept as is: a
  /// font it drew provisionally would otherwise hold the commit back.
  Future<void> _keep(int transaction) async {
    try {
      final preview = await _engine.keepAsIs(transaction);
      _applied = _requested;
      state = state.copy(preview: preview);
    } on EngineException {
      // shortcut: the characters no font has stay in the field but not in
      // the page, until a11-1c's "Keep the original font and mark the
      // character" (B140).
      state = state.copy(fontSettled: true);
      final drawn = _applied;
      if (drawn == null || drawn == _requested) return;
      try {
        _requested = drawn;
        var preview = await _engine.applyEdit(transaction, drawn);
        if (preview.glyphs != null) {
          preview = await _engine.keepAsIs(transaction);
        }
        state = state.copy(preview: preview);
      } on EngineException {
        // The commit says what the engine keeps.
      }
    }
  }

  void _restartIdle() {
    if (state.active != null) {
      _idle = Timer(idle, () => unawaited(commit()));
    }
  }

  Future<void> _close() async {
    await _commit();
    if (state.active != null) state = state.copy(clearActive: true);
  }

  /// Picks the overflow [choice] for the text that does not fit (a3-4).
  Future<void> resolve(OverflowChoice choice) {
    _idle?.cancel();
    return _run(() async {
      if (state.preview?.overflow?.allows(choice) != true) return;
      try {
        await _apply();
        if (_transaction case final transaction?) {
          final preview = await _engine.resolveOverflow(transaction, choice);
          state = state.copy(preview: preview, settled: true);
          if (state.active != null) {
            _idle = Timer(idle, () => unawaited(commit()));
          }
          return;
        }
        final last = _unanswered;
        _unanswered = null;
        if (last == null ||
            last.document != _document ||
            last.current != state.history.current) {
          return;
        }
        // The typing committed with "Keep and warn" already: that step
        // gives way to the same text with the choice.
        await _refresh(last.document, await _engine.undo(last.document));
        int? transaction;
        try {
          transaction = await _engine.beginEdit(
            last.document,
            last.page,
            last.block,
          );
          await _engine.applyEdit(transaction, last.text);
          final preview = await _engine.resolveOverflow(transaction, choice);
          final info = await _engine.commitEdit(transaction, last.name);
          state = state.copy(preview: preview, settled: true);
          await _refresh(
            last.document,
            info,
            committed: _targets.elementAtOrNull(last.current - 1),
          );
        } on EngineException {
          // The step comes back as it was committed.
          if (transaction != null) {
            try {
              await _engine.rollbackEdit(transaction);
            } on EngineException {
              // A failed commit dropped it already.
            }
          }
          await _refresh(last.document, await _engine.redo(last.document));
        }
      } on EngineException {
        // The text stays as it was applied.
      }
    });
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
      // The choices were for the step the history left.
      state = state.copy(clearPreview: true);
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
        // The choices were for the step the history left.
        state = state.copy(clearPreview: true);
      } on EngineException {
        // Nothing to undo or redo.
      }
    });
  }

  /// Saves the committed steps to the document's file, after committing
  /// the typing (ADR 0008): those of [document], by default the one shown;
  /// [overChange] saves over a change on disk ("Keep mine", a11-7b). The
  /// engine's error, or null when it saved.
  Future<EngineException?> save({int? document, bool overChange = false}) {
    final target = document ?? _document;
    if (target == null) return Future.value();
    return write(
      target,
      () => through(
        target,
        pathOf(target),
        (staging) =>
            _engine.save(target, overChange: overChange, staging: staging),
      ),
    );
  }

  /// The file of [document]'s tab. Read it only when the write's turn came:
  /// a Save as ahead of it in the queue moves the document, and a swap over
  /// the old path would replace the wrong file.
  String? pathOf(int document) => ref
      .read(shellDocumentsProvider)
      .documents
      .where((tab) => tab.document?.id == document)
      .firstOrNull
      ?.path;

  /// Writes [document]'s file at [path] with [write]: under the macOS App
  /// Sandbox [write] gets the staging directory the platform names, the
  /// platform swaps in the file it stages, and the engine then records the
  /// save (ADR 0008); elsewhere it writes the file itself. A failed swap
  /// reads as the engine's failures do, with the file and the edits as they
  /// were.
  Future<void> through(
    int document,
    String? path,
    Future<String?> Function(String? staging) write,
  ) async {
    final access = ref.read(fileAccessProvider);
    final staging = path == null ? null : await access.staging(path);
    final String? staged;
    try {
      staged = await write(staging);
    } on Object {
      if (staging != null) await access.discardStaging(staging);
      rethrow;
    }
    if (staged == null || path == null) return;
    final failure = await access.swapIn(staged, path);
    final noRecoveryCopy = await _engine.finishSave(
      document,
      swapped: failure == null,
    );
    if (failure == null) return;
    throw EngineException(
      kind: switch (failure) {
        SwapFailure.permission => EngineErrorKind.permissionDenied,
        SwapFailure.diskFull => EngineErrorKind.diskFull,
        SwapFailure.locked => EngineErrorKind.fileLocked,
        SwapFailure.volumeGone => EngineErrorKind.volumeGone,
        SwapFailure.other => EngineErrorKind.renameFailed,
      },
      messageKey: 'errorFileWrite',
      offersSaveAs: true,
      noRecoveryCopy: noRecoveryCopy,
    );
  }

  /// Commits the typing, then writes [document] with [write] (a save, Save
  /// as, Optimize and clean). It marks the document saving, then saved (a
  /// document the engine holds read-only stays so). When it fails, unsaved
  /// edits show "Couldn't save", or unsaved when the file changed on disk
  /// (a11-7b), and a document with none keeps the state it had; a [copy]
  /// leaves its state as it is. The engine's error, or null when it wrote.
  Future<EngineException?> write(
    int document,
    Future<void> Function() write, {
    bool copy = false,
  }) async {
    _idle?.cancel();
    EngineException? failed;
    await _run(() async {
      await _close();
      final before = ref
          .read(shellDocumentsProvider)
          .documents
          .where((tab) => tab.document?.id == document)
          .firstOrNull;
      if (!copy) _mark(document, SaveState.saving);
      try {
        await write();
        if (!copy) {
          _mark(
            document,
            before?.document?.readOnly == null
                ? SaveState.saved
                : SaveState.readOnly,
            savedAt: DateTime.now(),
          );
        }
      } on Object catch (error) {
        final engine = error is EngineException
            ? error
            : const EngineException(messageKey: 'errorInternal');
        failed = engine;
        if (!copy) {
          _mark(document, switch (before) {
            ShellDocument(unsaved: false, :final saveState?) => saveState,
            _
                when engine.kind == EngineErrorKind.fileChangedOnDisk ||
                    engine.kind == EngineErrorKind.confirmationRequired =>
              SaveState.unsaved,
            _ => SaveState.error,
          });
        }
      }
    });
    return failed;
  }

  /// Reads [document]'s history after [info] (null: on opening it) and,
  /// when it changed something, marks the document unsaved. [committed]
  /// is the block of the step a commit just added.
  Future<void> _refresh(
    int document,
    RevisionInfo? info, {
    _StepTarget? committed,
  }) async {
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
      final added = committed != null && history.current == before.current + 1;
      _targets = [
        for (var i = 0; i < history.steps.length; i++)
          if (added && i == before.current)
            committed
          else if (added && i > before.current)
            null
          else
            _targets.elementAtOrNull(i),
      ];
      state = state.copy(
        history: history,
        renderKey: info?.renderKey,
        hidden: _hidden(history),
      );
    }
    if (changed) _mark(document, SaveState.unsaved);
  }

  /// The lines hidden by the newest step of each block that applies.
  List<HiddenLines> _hidden(EditHistory history) {
    final newest = <(int, int), int>{};
    for (var i = 0; i < history.current; i++) {
      if (_targets.elementAtOrNull(i) case final target?) {
        newest[(target.page, target.block)] = i;
      }
    }
    return [
      for (final i in newest.values)
        if (_targets[i] case final target?
            when history.steps[i].hiddenLines > 0)
          HiddenLines(
            page: target.page,
            block: target.block,
            frame: target.frame,
            direction: target.dir,
            lines: history.steps[i].hiddenLines,
          ),
    ];
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
