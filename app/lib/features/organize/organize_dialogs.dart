import 'dart:async';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'organize_dialogs.g.dart';

/// The smallest and largest side of a page the engine takes, in points.
const double smallestPageSide = 3;

/// See [smallestPageSide].
const double largestPageSide = 14400;

/// The dialog Organize shows now (G45, a6-5), one at a time: each of its files
/// has the function that asks for it.
@Riverpod(keepAlive: true)
class OrganizeDialog extends _$OrganizeDialog {
  @override
  Widget? build() => null;

  /// Shows [dialog].
  // ignore: use_setters_to_change_properties
  void show(Widget dialog) => state = dialog;

  /// Closes it.
  void close() => state = null;
}

/// Organize's dialog over the editor.
class OrganizeDialogs extends ConsumerWidget {
  /// The dialog, when one shows.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(organizeDialogProvider) ?? const SizedBox.shrink();
}

/// The pages Organize's commands act on, as indices.
///
/// shortcut: the reader's page alone, until the page grid's selection joins.
List<int> organizeSelection(WidgetRef ref) =>
    switch (ref.read(viewerProvider)) {
      final view? => [view.currentPage],
      null => const [],
    };

/// The name of the open tab of [document].
String _nameOf(WidgetRef ref, int document) =>
    ref
        .read(shellDocumentsProvider)
        .documents
        .where((tab) => tab.document?.id == document)
        .firstOrNull
        ?.name ??
    '';

/// Runs [then] once the change to [document] may go on: at once, or after
/// a3-16a's "Edit anyway" on a signed document. Asked first, since a job's
/// change comes long after the dialog.
void afterSigned(WidgetRef ref, OpenedDocument document, VoidCallback then) {
  final saver = ref.read(documentSaverProvider.notifier);
  final tab = ref
      .read(shellDocumentsProvider)
      .documents
      .where((tab) => tab.document?.id == document.id)
      .firstOrNull;
  if (tab != null && saver.needsConfirmation(document)) {
    saver.askSigned(tab, then);
  } else {
    then();
  }
}

/// Takes [change] as one step of [document], or says why not in a toast. Reads
/// what it needs before it waits, so a dialog can close at once.
void commitPageChange(
  WidgetRef ref,
  int document,
  Future<RevisionInfo> Function() change,
) {
  final toasts = ref.read(toastNoticesProvider.notifier);
  final name = _nameOf(ref, document);
  unawaited(
    ref.read(documentEditorProvider.notifier).pageChange(document, change).then(
      (error) {
        if (error != null) showPageChangeFailure(toasts, error, name);
      },
    ),
  );
}

/// The toast of a page change the engine refused.
void showPageChangeFailure(
  ToastNotices toasts,
  EngineException error,
  String name,
) => toasts.show(
  tone: ToastTone.danger,
  title: (l10n) => l10n.organizeFailedTitle,
  message: (l10n) => engineMessage(l10n, error, name),
);
