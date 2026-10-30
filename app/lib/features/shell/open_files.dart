import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/additions/save_indicator.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/platform/file_picker_service.dart';
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

/// Opens PDFs, as `documentOpenerProvider` (a1-13): the system open panel,
/// then each chosen file in a new active tab, or the tab of a file already
/// open. Its state is the last file of the latest pick that did not open,
/// which the start screen and the editor show until dismissed (G116).
@Riverpod(keepAlive: true)
class DocumentOpener extends _$DocumentOpener {
  bool _picking = false;

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

  /// Opens [paths] one after another, each in a new active tab; a file
  /// already open shows its tab. From the start screen it then shows the
  /// editor; anywhere else (the editor, or Settings opened meanwhile) it
  /// stays.
  Future<void> open(List<String> paths) async {
    if (paths.isEmpty) return;
    state = null;
    final documents = ref.read(shellDocumentsProvider.notifier);
    var opened = false;
    for (final path in paths) {
      if (documents.focus(path)) {
        opened = true;
        continue;
      }
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
        opened = true;
      } on EngineException catch (error) {
        state = OpenProblem(name: name, error: error);
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
    }
    final router = ref.read(routerProvider);
    if (opened && router.state.uri.path == Routes.start) {
      router.go(Routes.editor);
    }
  }

  /// Hides the problem.
  void dismiss() => state = null;
}
