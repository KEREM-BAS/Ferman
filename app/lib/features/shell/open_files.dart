import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/additions/save_indicator.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'open_files.g.dart';

/// A file that did not open: its name and the engine's reason.
@immutable
final class OpenProblem {
  /// [name] did not open because of [error].
  const new({required this.name, required this.error});

  /// The file name.
  final String name;

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
/// Its state is the last file of the latest request that did not open,
/// which the start screen and the editor show until dismissed (G116).
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
      if (documents.focus(path)) {
        opened = true;
        _remember(path);
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

  /// Opens [path] in a new active tab of [documents], or reports why it did
  /// not open (into [missing] when it is not found and [missing] is given);
  /// whether it opened.
  Future<bool> _add(
    String path,
    ShellDocuments documents,
    Set<String>? missing,
  ) async {
    final name = fileName(path);
    try {
      final document = await ref.read(engineServiceProvider).open(path);
      documents.add(
        ShellDocument(
          name: name,
          path: path,
          document: document,
          pageCount: document.pages.length,
          saveState: document.readOnly == null
              ? SaveState.saved
              : SaveState.readOnly,
        ),
      );
      _remember(
        path,
        pages: document.pages.length,
        signed: document.signatures.isNotEmpty,
      );
      return true;
    } on EngineException catch (error) {
      if (missing != null && error.kind == EngineErrorKind.notFound) {
        missing.add(path);
      } else {
        state = OpenProblem(name: name, error: error);
      }
    } on EngineUnavailableException catch (error) {
      // Picked while the engine was still starting, before its problem
      // disabled opening (G101).
      state = OpenProblem(
        name: name,
        error: EngineException(
          messageKey: 'errorInternal',
          details: 'engine unavailable: ${error.reason.name}',
        ),
      );
    }
    return false;
  }

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
