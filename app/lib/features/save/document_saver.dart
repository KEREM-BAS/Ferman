import 'dart:async';

import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/save/file_exists.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'document_saver.g.dart';

/// A save that failed: the document's [name], what the engine reported,
/// and the two ways out the failure dialog offers (a11-7, a11-7d).
@immutable
final class SaveFailure {
  /// The failure of [name]'s save with [error].
  const new({
    required this.document,
    required this.name,
    required this.error,
    required this.retry,
    required this.saveAs,
  });

  /// The engine document that failed to save.
  final int? document;

  /// The document's file name.
  final String name;

  /// What the engine reported.
  final EngineException error;

  /// Tries the same save again ("Try again").
  final Future<void> Function() retry;

  /// Saves somewhere else ("Save as…", "Save somewhere else…").
  final Future<void> Function() saveAs;
}

/// a3-16a asked for: the signed [document], and what [then] goes on with
/// after "Edit anyway".
@immutable
final class SignedRequest {
  /// The question for [document].
  const new({required this.document, required this.then});

  /// The signed document's tab.
  final ShellDocument document;

  /// Goes on with what asked: opening the block, the save.
  final VoidCallback then;
}

/// The a1-11 sheet asked for: [document]'s tab, as Save as or, with
/// [copy], as Save a copy (⌥⌘S).
@immutable
final class SaveSheetRequest {
  /// The sheet for [document].
  const new({required this.document, this.copy = false});

  /// The document's tab; it has a path and an engine document.
  final ShellDocument document;

  /// Whether "Save as a copy" starts checked.
  final bool copy;
}

/// What the save flow shows, as `documentSaverProvider`.
@immutable
final class SaveFlow {
  /// The flow showing [sheet], [failure] (as the dialog, or as the f4
  /// toast once [toast]), [optimizing]'s warning, [signed]'s question and
  /// the a11-7b bar of the documents in [changed].
  const new({
    this.sheet,
    this.failure,
    this.toast = false,
    this.optimizing,
    this.signed,
    this.changed = const {},
  });

  /// The Save as sheet (a1-11), or null.
  final SaveSheetRequest? sheet;

  /// The save that failed, or null.
  final SaveFailure? failure;

  /// Whether [failure] shows as the f4 toast, after its dialog closed.
  final bool toast;

  /// The signed document whose Optimize and clean waits for the person to
  /// accept that its signatures break (G35).
  final ShellDocument? optimizing;

  /// The question before the first change to a signed document (a3-16a).
  final SignedRequest? signed;

  /// The engine documents whose file changed on disk (a11-7b).
  final Set<int> changed;
}

/// Saving the open documents, as `documentSaverProvider`: Save (⌘S), Save
/// as and Save a copy through the a1-11 sheet, Optimize and clean, the
/// repaired copy (B103), and what each failure shows: a11-7's and
/// a11-7d's dialog, then the f4 toast, or a11-7b's bar for a file that
/// changed on disk, which the window regaining focus checks too
/// ([checkExternalChanges]). A failed save leaves the file and the edits
/// as they were (ADR 0008).
@Riverpod(keepAlive: true)
class DocumentSaver extends _$DocumentSaver {
  @override
  SaveFlow build() => const SaveFlow();

  EngineService get _engine => ref.read(engineServiceProvider);

  DocumentEditor get _editor => ref.read(documentEditorProvider.notifier);

  ShellDocument? get _active => ref.read(shellDocumentsProvider).active;

  /// The signed documents the person said to edit anyway (a3-16a); the
  /// engine holds the same until they close.
  final Set<int> _confirmed = {};

  /// Saves the active document to its file.
  Future<void> save() async {
    final tab = _active;
    if (tab?.document == null) return;
    await saveTab(tab!);
  }

  /// Saves [tab]'s document to its file: whether it saved. When not, the
  /// failure shows as for Save; closing and quitting stop there.
  Future<bool> saveTab(ShellDocument tab) => _guard(
    tab,
    () => _editor.save(document: tab.document?.id),
    saveAs: () async => _openSheet(tab),
  );

  /// Whether a change to [document] waits for a3-16a's answer.
  bool needsConfirmation(OpenedDocument document) =>
      document.signed && !_confirmed.contains(document.id);

  /// Shows a3-16a for [tab]; [then] goes on after "Edit anyway".
  void askSigned(ShellDocument tab, VoidCallback then) => state = SaveFlow(
    signed: SignedRequest(document: tab, then: then),
    changed: state.changed,
  );

  /// Closes a3-16a (Cancel, Esc): nothing changes.
  void cancelSigned() => state = SaveFlow(changed: state.changed);

  /// "Edit anyway": the engine's confirmation, then what asked goes on.
  /// When the engine refuses, nothing goes on.
  Future<void> editAnyway() async {
    final request = state.signed;
    cancelSigned();
    final id = request?.document.document?.id;
    if (id == null) return;
    try {
      await _engine.confirmEditSigned(id);
    } on EngineException {
      return;
    }
    _confirmed.add(id);
    request!.then();
  }

  /// "Edit a copy": the signed document without its signatures as the first
  /// free name beside it ([name], from 1), which opens in a new tab; the
  /// original stays as it is. When it cannot be written there, the failure's
  /// Save as… asks where.
  Future<void> editCopy(String Function(int number) name) async {
    final tab = state.signed?.document;
    cancelSigned();
    final id = tab?.document?.id;
    final from = tab?.path;
    if (tab == null || id == null || from == null) return;
    Future<void> copyTo(String path) async {
      await _guard(
        tab,
        () async {
          if (openInAnotherTab(path, tab)) {
            return const EngineException(
              kind: EngineErrorKind.io,
              messageKey: 'errorFileWrite',
              offersSaveAs: true,
            );
          }
          try {
            await _engine.saveUnsignedCopy(id, path);
          } on EngineException catch (error) {
            return error;
          }
          unawaited(ref.read(documentOpenerProvider.notifier).open([path]));
          return null;
        },
        saveAs: () async {
          final chosen = await ref
              .read(filePickerServiceProvider)
              .saveFile(suggestedName: name(1));
          if (chosen != null) await copyTo(chosen);
        },
      );
    }

    var number = 1;
    final folder = folderOf(from);
    while (await fileExists(pathIn(folder, name(number)))) {
      number++;
    }
    await copyTo(pathIn(folder, name(number)));
  }

  /// Shows the a1-11 sheet for the active document, "Save as a copy"
  /// checked with [copy].
  void openSheet({bool copy = false}) {
    final tab = _active;
    if (tab != null) _openSheet(tab, copy: copy);
  }

  void _openSheet(ShellDocument tab, {bool copy = false}) {
    if (tab.document == null || tab.path == null) return;
    state = SaveFlow(
      sheet: SaveSheetRequest(document: tab, copy: copy),
      changed: state.changed,
    );
  }

  /// Whether the file at [path] is the file of an open tab other than
  /// [tab]'s: writing there would pull it from under that document.
  bool openInAnotherTab(String path, ShellDocument tab) => ref
      .read(shellDocumentsProvider)
      .documents
      .any(
        (other) => other.path == path && other.document?.id != tab.document?.id,
      );

  /// Hides the sheet (Cancel, Escape).
  void closeSheet() => state = SaveFlow(changed: state.changed);

  /// Writes the sheet's document to [path]: Save as, after which the tab
  /// shows the new file, or with [copy] a copy that leaves it as it was.
  Future<void> saveTo(String path, {required bool copy}) async {
    final tab = state.sheet?.document;
    closeSheet();
    final from = tab?.path;
    final id = tab?.document?.id;
    if (tab == null || from == null || id == null) return;
    Future<EngineException?> write() async {
      // A copy onto the document's own file is a save (the engine treats
      // it as one), so the tab shows it saved.
      if (path == from) return await _editor.save(document: id);
      if (copy) {
        return await _editor.write(
          id,
          () => _engine.saveCopy(id, path),
          copy: true,
        );
      }
      final error = await _editor.write(id, () => _engine.saveAs(id, path));
      if (error == null) {
        ref.read(documentOpenerProvider.notifier).savedAs(from, path);
        // The tab's file is another one now.
        _markChanged(id, changed: false);
      }
      return error;
    }

    await _guard(tab, write, saveAs: () async => _openSheet(tab, copy: copy));
  }

  /// Runs [write] for [tab]: success takes away the toast of an earlier
  /// failure of [tab], a file changed on disk shows a11-7b's bar, and any
  /// other failure the dialog, whose Try again runs it again and whose Save
  /// as… runs [saveAs]. A change to a signed document not confirmed in this
  /// session (a restored one) asks a3-16a and goes on after "Edit anyway".
  /// Whether it wrote.
  Future<bool> _guard(
    ShellDocument tab,
    Future<EngineException?> Function() write, {
    required Future<void> Function() saveAs,
  }) async {
    final error = await write();
    if (error == null) {
      if (state.failure case final failure?
          when failure.document == tab.document?.id) {
        dismissFailure();
      }
      return true;
    }
    if (error.kind == EngineErrorKind.fileChangedOnDisk) {
      if (tab.document?.id case final id?) _markChanged(id, changed: true);
      return false;
    }
    if (error.kind == EngineErrorKind.confirmationRequired) {
      askSigned(tab, () => unawaited(_guard(tab, write, saveAs: saveAs)));
      return false;
    }
    state = SaveFlow(
      failure: SaveFailure(
        document: tab.document?.id,
        name: tab.name,
        error: error,
        retry: () async {
          dismissFailure();
          await _guard(tab, write, saveAs: saveAs);
        },
        saveAs: () async {
          dismissFailure();
          await saveAs();
        },
      ),
      changed: state.changed,
    );
    return false;
  }

  /// Closes the failure dialog and leaves the f4 toast.
  void closeFailureDialog() {
    if (state.failure == null) return;
    state = SaveFlow(
      failure: state.failure,
      toast: true,
      changed: state.changed,
    );
  }

  /// Hides the failure, dialog or toast.
  void dismissFailure() => state = SaveFlow(changed: state.changed);

  void _markChanged(int document, {required bool changed}) {
    if (state.changed.contains(document) == changed) return;
    state = SaveFlow(
      sheet: state.sheet,
      failure: state.failure,
      toast: state.toast,
      optimizing: state.optimizing,
      signed: state.signed,
      changed: changed
          ? {...state.changed, document}
          : ({...state.changed}..remove(document)),
    );
  }

  /// Asks the engine whether the file of each open document changed on
  /// disk since it was opened or saved, when the window regains focus
  /// (a11-7b, decision 9).
  Future<void> checkExternalChanges() async {
    for (final tab in ref.read(shellDocumentsProvider).documents) {
      final id = tab.document?.id;
      if (id == null || state.changed.contains(id)) continue;
      try {
        if (await _engine.checkExternalChange(id)) {
          _markChanged(id, changed: true);
        }
      } on Object {
        // Asked again on the next focus or save.
      }
    }
  }

  /// "Keep mine" (a11-7b): saves the active document over the change.
  Future<void> keepMine() async {
    final tab = _active;
    final id = tab?.document?.id;
    if (id == null) return;
    _markChanged(id, changed: false);
    await _guard(
      tab!,
      () => _editor.save(document: id, overChange: true),
      saveAs: () async => _openSheet(tab),
    );
  }

  /// "Reload" (a11-7b): closes the active document, dropping its edits,
  /// and opens its file again. A file that is gone cannot come back, so the
  /// document and its edits stay, and the toast of a missing file says why.
  Future<void> reload() async {
    final tab = _active;
    final id = tab?.document?.id;
    final path = tab?.path;
    if (id == null || path == null) return;
    final opener = ref.read(documentOpenerProvider.notifier);
    if (!await fileExists(path)) {
      opener.reportMissing(path);
      return;
    }
    _markChanged(id, changed: false);
    opener.close(path, discard: true);
    await opener.open([path]);
  }

  /// Optimize and clean (ARCHITECTURE §7.3): rewrites the active
  /// document's file whole, after the warning when that breaks its
  /// signatures (G35); never the default.
  Future<void> optimizeAndClean() async {
    final tab = _active;
    final id = tab?.document?.id;
    if (id == null) return;
    bool signed;
    try {
      signed = await _engine.wouldBreakSignatures(id);
    } on Object {
      // Unknown counts as signed: the warning shows.
      signed = true;
    }
    if (signed) {
      state = SaveFlow(optimizing: tab, changed: state.changed);
      return;
    }
    await _optimize(tab!);
  }

  /// Rewrites the document the warning asked about.
  Future<void> confirmOptimize() async {
    final tab = state.optimizing;
    cancelOptimize();
    if (tab == null) return;
    // Accepting that the signatures break is the first-change confirmation.
    if (tab.document?.id case final id?) {
      try {
        await _engine.confirmEditSigned(id);
        _confirmed.add(id);
      } on EngineException {
        // The write below then asks a3-16a.
      }
    }
    await _optimize(tab);
  }

  /// Closes the warning without rewriting.
  void cancelOptimize() => state = SaveFlow(changed: state.changed);

  Future<void> _optimize(ShellDocument tab) {
    final id = tab.document?.id;
    if (id == null) return Future.value();
    return _guard(
      tab,
      () => _editor.write(id, () => _engine.optimizeAndClean(id)),
      saveAs: () async => _openSheet(tab),
    );
  }

  /// "Save repaired copy…" (a1-9, B103): the system save panel, then the
  /// repaired [document] rewritten whole where it says, which then opens
  /// in a tab of its own. Choosing the damaged file itself replaces it: the
  /// panel has asked before replacing it, the confirmation ADR 0008 needs.
  Future<void> saveRepairedCopy(ShellDocument document) async {
    final id = document.document?.id;
    if (id == null) return;
    final path = await ref
        .read(filePickerServiceProvider)
        .saveFile(suggestedName: document.name);
    if (path == null) return;
    final replace = path == document.path;
    await _guard(document, () async {
      // Not over another open document (a failure the system panel cannot
      // know of); its own file only as above.
      if (openInAnotherTab(path, document)) {
        return const EngineException(
          kind: EngineErrorKind.io,
          messageKey: 'errorFileWrite',
          offersSaveAs: true,
        );
      }
      try {
        await _engine.saveRepairedCopy(id, path, replaceOriginal: replace);
      } on EngineException catch (error) {
        return error;
      }
      if (!replace) {
        unawaited(ref.read(documentOpenerProvider.notifier).open([path]));
      }
      return null;
    }, saveAs: () => saveRepairedCopy(document));
  }
}

/// The folder of [path]: everything before the separator ahead of its
/// file name ([fileName]); empty for a file at the root.
String folderOf(String path) {
  final end = path.length - fileName(path).length;
  return end > 0 ? path.substring(0, end - 1) : '';
}

/// The separator the system puts between folders.
String get pathSeparator =>
    defaultTargetPlatform == TargetPlatform.windows ? r'\' : '/';

/// The file [name] in [folder].
String pathIn(String folder, String name) => '$folder$pathSeparator$name';

/// [folder] as the sheet's Where names it: its last two folders, as
/// a1-11 draws "Belgeler › Ev".
String folderLabel(String folder) {
  final parts = folder
      .split(RegExp(r'[/\\]'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return pathSeparator;
  return parts.skip(parts.length < 2 ? 0 : parts.length - 2).join(' › ');
}

/// Whether [name] can be a file name in the sheet: not empty, not `.` or
/// `..`, no folder separator or control character and, on Windows, none of
/// the characters it reserves (`:` would name a stream of another file)
/// (brief §6: validators return a bool and check null and empty values).
bool validFileName(String? name) {
  if (name == null) return false;
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') return false;
  if (trimmed.contains(RegExp(r'[/\\\x00-\x1f\x7f]'))) return false;
  return defaultTargetPlatform != TargetPlatform.windows ||
      !trimmed.contains(RegExp('[<>:"|?*]'));
}

/// [name] trimmed, with `.pdf` added unless it ends with it already.
String pdfFileName(String name) {
  final trimmed = name.trim();
  return RegExp(r'\.pdf$', caseSensitive: false).hasMatch(trimmed)
      ? trimmed
      : '$trimmed.pdf';
}
