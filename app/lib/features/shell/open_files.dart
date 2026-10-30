import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/additions/save_indicator.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'open_files.g.dart';

/// A file that ran out of memory or past a resource limit while opening
/// (a1-9f): its tab closed, so the start screen or the editor reports it.
@immutable
final class OpenProblem {
  /// The file at [path], named [name], did not open because of [error].
  const new({required this.name, required this.error, this.path});

  /// The file name.
  final String name;

  /// Where the file is, for Try again; null when it cannot be retried.
  final String? path;

  /// What the engine said.
  final EngineException error;

  /// The facts for a bug report, in English (as a1-9b's link).
  String get technicalDetails =>
      'open: ${error.kind.name} ${error.messageKey}'
      '${error.details == null ? '' : ': ${error.details}'}';
}

/// The file name at the end of [path]: after the last `/`, or on Windows
/// after the last `/` or `\`, since a macOS or Linux name may hold a `\`.
String fileName(String path) => path
    .split(
      defaultTargetPlatform == TargetPlatform.windows
          ? RegExp(r'[/\\]')
          : RegExp('/'),
    )
    .last;

/// Opens PDFs, as `documentOpenerProvider` (a1-13): the files chosen in the
/// system open panel, dropped on the window (a1-6), sent by the system (ADR
/// 0021) or picked from the recent files, each in a new active tab, or the
/// tab of a file already open. Each file that opens goes first in the
/// recent files ([RecentFiles.opened]).
///
/// A file that needs its password opens as a locked tab with the unlock
/// dialog (a1-8, [unlock]); one that does not open shows why in its own
/// error tab (a1-9b, a1-9c). One that runs out of memory or past a limit
/// gets no tab: the state is the last such file of the latest request,
/// which the start screen and the editor show until dismissed (a1-9f).
@Riverpod(keepAlive: true)
class DocumentOpener extends _$DocumentOpener {
  bool _picking = false;

  /// The engine opens under way, by path: a file asked for again while it
  /// opens (two double-clicks, a drop during a pick) waits for that open
  /// and shows its tab instead of opening twice.
  final Map<String, Future<bool>> _opening = {};

  @override
  OpenProblem? build() => null;

  /// Shows the open panel, its filter named [filterLabel], and opens the
  /// chosen files (⌘O, Open file…, Open a PDF, "+"). A second call while
  /// the panel shows does nothing.
  Future<void> pick({required String filterLabel}) async {
    if (_picking) return;
    _picking = true;
    try {
      final paths = await ref
          .read(filePickerServiceProvider)
          .openPdfs(filterLabel: filterLabel);
      await open(paths);
    } finally {
      _picking = false;
    }
  }

  /// Opens the recent file [entry] (a1-4): through its bookmark on macOS,
  /// which reaches it after a restart under the App Sandbox and follows it
  /// when it moved (Q18), then as [open] does. Returns false, reporting
  /// nothing, when the file is gone, so the start screen asks what to do
  /// (a1-9e).
  Future<bool> openRecent(RecentEntry entry) async {
    var path = entry.path;
    if (entry.bookmark case final bookmark?) {
      final access = await ref.read(fileAccessProvider).access(bookmark);
      if (access != null && (access.path != path || access.renewed != null)) {
        path = access.path;
        await ref
            .read(recentFilesProvider.notifier)
            .relocate(
              entry.path,
              to: path,
              name: fileName(path),
              bookmark: access.renewed,
            )
            .catchError((Object _) {});
      }
    }
    final missing = <String>{};
    await open([path], missing: missing);
    return missing.isEmpty;
  }

  /// Opens [paths] one after another, each in a new active tab; a file
  /// already open, or opening for another request, shows its tab. From the
  /// start screen it then shows the editor; anywhere else (the editor, first
  /// run, or Settings opened meanwhile) it stays. Requests for different
  /// files do not wait for each other, so a slow file holds up only its own.
  /// With [missing], a file the engine does not find is added to it instead
  /// of being reported.
  Future<void> open(List<String> paths, {Set<String>? missing}) async {
    if (paths.isEmpty) return;
    state = null;
    final documents = ref.read(shellDocumentsProvider.notifier);
    var opened = false;
    for (final path in paths) {
      if (_opening[path] case final pending?) await pending;
      // A file that did not open is tried again in its tab: it may have
      // been fixed.
      final tab = _tab(path);
      if (tab != null && tab.error == null && documents.focus(path)) {
        opened = true;
        // A locked file is remembered only once it opens.
        if (!tab.locked) _remember(path);
        continue;
      }
      final opening = _add(path, documents, missing);
      _opening[path] = opening;
      try {
        opened = await opening || opened;
      } finally {
        _opening.removeWhere((_, pending) => identical(pending, opening));
      }
    }
    final router = ref.read(routerProvider);
    if (opened && router.state.uri.path == Routes.start) {
      router.go(Routes.editor);
    }
  }

  /// Opens [path] in a new active tab of [documents], or in place of its
  /// error tab: the document, its locked tab, or its error tab. Whether a
  /// tab shows: not for a file that is not found when [missing] is given
  /// (it is added to [missing]), nor for one that ran out of memory or past
  /// a limit (the state); either closes an error tab it had.
  Future<bool> _add(
    String path,
    ShellDocuments documents,
    Set<String>? missing,
  ) async {
    final opened = await _engineOpen(path);
    void show(ShellDocument document) {
      if (_tab(path) == null) {
        documents.add(document);
      } else {
        documents
          ..replace(path, document)
          ..focus(path);
      }
    }

    switch (opened) {
      case final ShellDocument document:
        show(document);
        if (document.document case final engine?) _rememberOpened(path, engine);
        return true;
      case EngineException(kind: EngineErrorKind.notFound) when missing != null:
        missing.add(path);
      case EngineException(kind: EngineErrorKind.resourceLimit):
        state = OpenProblem(name: fileName(path), error: opened, path: path);
      case final EngineException error:
        show(_failed(path, error));
        return true;
    }
    if (_tab(path) != null) close(path);
    return false;
  }

  /// Opens the locked file of the tab of [path] with [password] (a1-8) and
  /// shows the document in its place. False when the password is wrong
  /// (a1-8b), so the dialog asks again; otherwise the tab shows the
  /// document or why it did not open, or closes when memory ran out
  /// (a1-9f).
  Future<bool> unlock(String path, String password) async {
    final opened = await _engineOpen(path, password: password);
    final documents = ref.read(shellDocumentsProvider.notifier);
    if (_tab(path)?.locked != true) {
      // The tab closed meanwhile: the document is not wanted any more.
      if (opened case ShellDocument(:final document?)) {
        unawaited(
          ref
              .read(engineServiceProvider)
              .close(document.id)
              .catchError((Object _) {}),
        );
      }
      return true;
    }
    switch (opened) {
      case final ShellDocument document:
        documents.replace(path, document);
        if (document.document case final engine?) _rememberOpened(path, engine);
      case EngineException(kind: EngineErrorKind.wrongPassword):
        return false;
      case EngineException(kind: EngineErrorKind.resourceLimit):
        state = OpenProblem(name: fileName(path), error: opened, path: path);
        close(path);
      case final EngineException error:
        documents.replace(path, _failed(path, error));
    }
    return true;
  }

  /// Closes the tab of [path], which holds no document (the unlock
  /// dialog's Cancel), and shows the start screen when no tab is left
  /// and the editor shows (not Settings opened meanwhile).
  void close(String path) {
    final documents = ref.read(shellDocumentsProvider.notifier)..remove(path);
    final router = ref.read(routerProvider);
    if (documents.state.documents.isEmpty &&
        router.state.uri.path == Routes.editor) {
      router.go(Routes.start);
    }
  }

  /// Opens the file of the problem again (a1-9f's Try again).
  Future<void> retry() async {
    if (state?.path case final path?) await open([path]);
  }

  /// The tab of [path], if one is open.
  ShellDocument? _tab(String path) {
    for (final document in ref.read(shellDocumentsProvider).documents) {
      if (document.path == path) return document;
    }
    return null;
  }

  /// The engine's document for [path] in a tab of its own, the locked tab
  /// of a file that needs its password, or why it did not open.
  Future<Object> _engineOpen(String path, {String? password}) async {
    final name = fileName(path);
    try {
      final document = await ref
          .read(engineServiceProvider)
          .open(path, password: password);
      return ShellDocument(
        name: name,
        path: path,
        document: document,
        pageCount: document.pages.length,
        saveState: document.readOnly == null
            ? SaveState.saved
            : SaveState.readOnly,
      );
    } on EngineException catch (error) {
      if (error.kind != EngineErrorKind.passwordRequired) return error;
      return ShellDocument(
        name: name,
        path: path,
        icon: IconName.lock,
        saveState: SaveState.readOnly,
        locked: true,
      );
    } on EngineUnavailableException catch (error) {
      // Picked while the engine was still starting, before its problem
      // disabled opening (G101).
      return EngineException(
        messageKey: 'errorInternal',
        details: 'engine unavailable: ${error.reason.name}',
      );
    }
  }

  /// The error tab of [path] (a1-9b, a1-9c).
  ShellDocument _failed(String path, EngineException error) => ShellDocument(
    name: fileName(path),
    path: path,
    icon: IconName.fileX,
    saveState: SaveState.readOnly,
    error: error,
  );

  /// Remembers the file at [path], opened as [document], with its facts.
  void _rememberOpened(String path, OpenedDocument document) => _remember(
    path,
    pages: document.pages.length,
    signed: document.signatures.isNotEmpty,
  );

  /// Puts the file at [path] first in the recent files, with a bookmark
  /// that reaches it again after a restart (macOS, Q18). The list is kept
  /// for this session when it cannot be stored.
  void _remember(String path, {int? pages, bool? signed}) {
    final now = DateTime.now();
    unawaited(
      ref
          .read(fileAccessProvider)
          .bookmark(path)
          .then(
            (bookmark) => ref
                .read(recentFilesProvider.notifier)
                .opened(
                  path,
                  name: fileName(path),
                  now: now,
                  pages: pages,
                  signed: signed,
                  bookmark: bookmark,
                ),
          )
          .catchError((Object _) {}),
    );
  }

  /// Hides the problem.
  void dismiss() => state = null;
}
