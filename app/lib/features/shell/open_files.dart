import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/additions/save_indicator.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/save/file_exists.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/recent/recent_previews.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
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

  /// The closes under way, by path: a recent file reopened meanwhile waits,
  /// so the access its bookmark starts is not ended by the late release.
  final Map<String, Future<void>> _releasing = {};

  /// How long, in milliseconds, an open runs before its tab shows loading
  /// (a1-7, G104).
  static const int slowOpenMs = 500;

  /// [slowOpenMs] as a duration.
  static const Duration slowOpen = Duration(milliseconds: slowOpenMs);

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
    await _releasing[entry.path];
    final path = await _reach(entry);
    final missing = <String>{};
    await open([path], missing: missing);
    return missing.isEmpty;
  }

  /// Starts access to the file of [entry] through its bookmark, if it has
  /// one, keeping the recent file up to date; where the file is now.
  Future<String> _reach(RecentEntry entry) async {
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
    return path;
  }

  /// Starts access to those of [paths] that are recent files with a
  /// bookmark (crash recovery's originals): whether any was.
  Future<bool> reachRecent(Iterable<String> paths) async {
    var reached = false;
    final recent = ref.read(recentFilesProvider);
    for (final path in paths.toSet()) {
      final entry = recent.where((entry) => entry.path == path).firstOrNull;
      if (entry?.bookmark == null) continue;
      await _reach(entry!);
      reached = true;
    }
    return reached;
  }

  /// Opens the files open when the app last ran, in their tab order, when
  /// Settings › General › Reopen documents from last time is on (B079).
  /// Each opens as a recent file ([openRecent]), whose bookmark reaches it
  /// after a restart under the App Sandbox; one that is gone or off the
  /// recent list is skipped without a report.
  Future<void> reopenLast() async {
    final settings = ref.read(settingsProvider);
    if (!settings.reopenDocuments) return;
    final recent = ref.read(recentFilesProvider);
    for (final path in settings.lastDocuments) {
      final entry = recent.where((entry) => entry.path == path).firstOrNull;
      if (entry != null) await openRecent(entry);
    }
  }

  /// Stores the paths of the files open in [documents] for [reopenLast];
  /// error tabs are left out. A failed save keeps the old list.
  Future<void> recordOpen(ShellDocumentList documents) async {
    final paths = [
      for (final document in documents.documents)
        if (document.path case final path? when document.error == null) path,
    ];
    try {
      await ref
          .read(settingsProvider.notifier)
          .change((settings) => settings.copyWith(lastDocuments: paths));
    } on SettingsStoreException {
      // Kept for this session: the next change tries again.
    }
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
    // a1-7: an open that takes a moment shows its tab with a spinner and
    // the progress card; a fast one shows none, so no tab flashes.
    var loading = false;
    final slow = Timer(slowOpen, () {
      if (_tab(path) != null) return;
      loading = true;
      documents.add(ShellDocument(name: fileName(path), path: path));
      final router = ref.read(routerProvider);
      if (router.state.uri.path == Routes.start) router.go(Routes.editor);
    });
    final opened = await _engineOpen(path);
    slow.cancel();
    if (loading && _tab(path)?.loading != true) {
      // Cancelled (a1-7's Cancel or Esc, or the tab closed): the document
      // is not wanted any more.
      if (opened case ShellDocument(:final document?)) {
        unawaited(
          ref
              .read(engineServiceProvider)
              .close(document.id)
              .catchError((Object _) {}),
        );
      }
      return false;
    }
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
        if (document.document case final engine?) {
          _rememberOpened(path, engine);
        } else if (document.locked) {
          // It needs a password now: no image of its page stays (G109).
          _keepPreview(path, null);
        }
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

  /// Lifts the restrictions of the tab of [path]'s document with its owner
  /// [password] for the session (a2-10a, G106): the banner and the shield
  /// go. False when the password is wrong, so the dialog asks again.
  Future<bool> unlockOwner(String path, String password) async {
    final document = _tab(path)?.document;
    if (document == null) return true;
    final Security? security;
    try {
      security = await ref
          .read(engineServiceProvider)
          .unlockOwner(document.id, password);
    } on EngineException catch (error) {
      // Closed meanwhile, or the engine failed: nothing to ask again.
      return error.kind != EngineErrorKind.wrongPassword;
    }
    final tab = _tab(path);
    if (tab?.document?.id != document.id) return true;
    ref
        .read(shellDocumentsProvider.notifier)
        .replace(
          path,
          ShellDocument(
            name: tab!.name,
            path: path,
            document: document.withSecurity(security),
            pageCount: tab.pageCount,
            saveState: tab.saveState,
            savedAt: tab.savedAt,
            editCount: tab.editCount,
          ),
        );
    return true;
  }

  /// Closes the tab of [path] (its close button, ⌘W or Ctrl+W, the unlock
  /// dialog's Cancel): the tab after it shows, or the one before when it
  /// was the last, and the start screen when no tab is left and the editor
  /// shows (not Settings opened meanwhile). Its engine document closes,
  /// what its views kept goes, and on macOS the access its recent file
  /// started ends (B029). It does not ask about unsaved changes:
  /// `documentCloserProvider` does (a1-10b); with [discard] ("Don't save")
  /// its recovery files go too.
  void close(String path, {bool discard = false}) {
    final tab = _tab(path);
    if (tab == null) return;
    final documents = ref.read(shellDocumentsProvider.notifier)..remove(path);
    final releasing = _release(path, tab.document, discard: discard);
    _releasing[path] = releasing;
    unawaited(
      releasing.whenComplete(
        () => _releasing.removeWhere((_, pending) => pending == releasing),
      ),
    );
    final router = ref.read(routerProvider);
    if (documents.state.documents.isEmpty &&
        router.state.uri.path == Routes.editor) {
      router.go(Routes.start);
    }
  }

  /// Closes every clean tab but the one of [path] and shows it (a1-10's
  /// "Close other documents…"); `documentCloserProvider` asks about the rest.
  void closeOthers(String path) {
    for (final document in ref.read(shellDocumentsProvider).documents) {
      if (document.path case final other?
          when other != path && !document.unsaved) {
        close(other);
      }
    }
    ref.read(shellDocumentsProvider.notifier).focus(path);
  }

  /// Lets go of [document], closed with its tab, and then of the file at
  /// [path]: the file is read until the engine closes it.
  Future<void> _release(
    String path,
    OpenedDocument? document, {
    bool discard = false,
  }) async {
    if (document != null) {
      ref.invalidate(documentMemoryProvider(document.id));
      final engine = ref.read(engineServiceProvider);
      await (discard
              ? engine.closeDiscarding(document.id)
              : engine.close(document.id))
          .catchError((Object _) {});
    }
    await ref.read(fileAccessProvider).release(path).catchError((Object _) {});
  }

  /// Moves the tab of [from] to the file at [to], where Save as wrote its
  /// document (a1-11): later saves write there, and [to] goes first in the
  /// recent files.
  void savedAs(String from, String to) {
    final tab = _tab(from);
    if (tab == null || from == to) return;
    ref
        .read(shellDocumentsProvider.notifier)
        .replace(
          from,
          ShellDocument(
            name: fileName(to),
            path: to,
            // a1-9d's lock said the old file could not be written.
            icon: tab.icon == IconName.lock && tab.document?.readOnly == null
                ? IconName.fileText
                : tab.icon,
            saveState: tab.saveState,
            savedAt: tab.savedAt,
            pageCount: tab.pageCount,
            editCount: tab.editCount,
            document: tab.document,
          ),
        );
    _remember(
      to,
      pages: tab.pageCount,
      edited: tab.editCount > 0 ? true : null,
    );
  }

  /// Shows the document crash recovery opened in a tab of its own, unsaved
  /// with its [changes] (a1-12), in place of the tab the file reopened in;
  /// one under a new name (a11-7f) is no recent file until it is saved.
  void restored(RestoredDocument restored, {required int changes}) {
    final path = restored.path;
    final documents = ref.read(shellDocumentsProvider.notifier);
    final tab = ShellDocument(
      name: fileName(path),
      path: path,
      document: restored.opened,
      pageCount: restored.opened.pages.length,
      saveState: SaveState.unsaved,
      editCount: changes,
    );
    if (_tab(path) case final old?) {
      documents
        ..replace(path, tab)
        ..focus(path);
      if (old.document case final document?) {
        ref.invalidate(documentMemoryProvider(document.id));
        unawaited(
          ref
              .read(engineServiceProvider)
              .close(document.id)
              .catchError((Object _) {}),
        );
      }
    } else {
      documents.add(tab);
    }
    if (!restored.originalChanged) _rememberOpened(path, restored.opened);
    final router = ref.read(routerProvider);
    if (router.state.uri.path == Routes.start) router.go(Routes.editor);
  }

  /// Shows the toast of a document that recovery could not open; its files
  /// stay for the next launch.
  void reportRestoreFailed(String path, EngineException error) =>
      state = OpenProblem(name: fileName(path), error: error);

  /// Shows the toast of a file that is gone, whose tab stays (a11-7b's
  /// Reload).
  void reportMissing(String path) => state = OpenProblem(
    name: fileName(path),
    error: const EngineException(
      kind: EngineErrorKind.notFound,
      messageKey: 'errorFileNotFound',
    ),
    path: path,
  );

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
      // a1-9d: a file no one may write opens read-only too.
      final readOnlyFile = document.readOnly == null && fileReadOnly(path);
      return ShellDocument(
        name: name,
        path: path,
        document: document,
        // Why it is read-only (a1-9's wrench, a11-7c's file-x, G102's and
        // a1-9d's lock), else a2-10a's shield while the author's restrictions
        // apply.
        icon: switch (document.readOnly) {
          ReadOnlyReason.repaired => IconName.wrench,
          ReadOnlyReason.xfaOnly => IconName.fileX,
          ReadOnlyReason.parsersDisagree => IconName.lock,
          null =>
            readOnlyFile
                ? IconName.lock
                : document.security?.restricted ?? false
                ? IconName.shield
                : IconName.fileText,
        },
        pageCount: document.pages.length,
        saveState: document.readOnly == null && !readOnlyFile
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

  /// Remembers the file at [path], opened as [document], with its facts and
  /// the preview of its first page, none for a file that needs a password
  /// (G109).
  void _rememberOpened(String path, OpenedDocument document) {
    final locked = document.security?.userPasswordRequired ?? false;
    _remember(
      path,
      pages: document.pages.length,
      signed: document.signatures.isNotEmpty,
      locked: locked,
      form: document.formFields > 0,
      scanned: document.scanned,
    );
    _keepPreview(path, locked ? null : document);
  }

  /// Renders and keeps the preview of [document] as the file at [path]'s,
  /// or deletes the file's preview when [document] is null. A preview that
  /// cannot be made or kept leaves the card's placeholder page.
  void _keepPreview(String path, OpenedDocument? document) {
    final store = ref.read(recentPreviewStoreProvider);
    final engine = ref.read(engineServiceProvider);
    Future<void> keep() async {
      if (document == null) {
        await store.remove(path);
        return;
      }
      final png = await renderRecentPreview(engine, document.id);
      if (png != null) await store.save(path, png);
    }

    unawaited(
      keep()
          .then((_) => ref.invalidate(recentPreviewProvider(path)))
          .catchError((Object _) {}),
    );
  }

  /// Puts the file at [path] first in the recent files, with a bookmark
  /// that reaches it again after a restart (macOS, Q18). The list is kept
  /// for this session when it cannot be stored.
  void _remember(
    String path, {
    int? pages,
    bool? signed,
    bool? locked,
    bool? form,
    bool? scanned,
    bool? edited,
  }) {
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
                  locked: locked,
                  form: form,
                  scanned: scanned,
                  edited: edited,
                  bookmark: bookmark,
                ),
          )
          .catchError((Object _) {}),
    );
  }

  /// Hides the problem.
  void dismiss() => state = null;
}
