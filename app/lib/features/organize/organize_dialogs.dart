import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/combine.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'organize_dialogs.g.dart';

/// The smallest and largest side of a page the engine takes, in points.
const double smallestPageSide = 3;

/// See [smallestPageSide].
const double largestPageSide = 14400;

/// The dialog Organize shows now (G45, a6-2, a6-5), one at a time, above every
/// screen, since Create PDF also opens from the start screen: each of its files
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

/// The pages Organize's dialogs start from, as indices: the grid's selection,
/// or the reader's page without one.
List<int> organizeSelection(WidgetRef ref) {
  final view = ref.read(viewerProvider);
  if (view == null) return const [];
  final selected = [
    for (final handle in ref.read(selectedPagesProvider))
      ?view.document.pageIndexOf(handle),
  ];
  return selected.isEmpty ? [view.currentPage] : selected;
}

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

/// Asks where to write and creates a one-page PDF on the region's paper, which
/// opens once written. A new file, since the open path reads a file (B019).
Future<void> createBlankPdf(WidgetRef ref, AppLocalizations l10n) async {
  final output = await ref
      .read(filePickerServiceProvider)
      .saveFile(suggestedName: l10n.createDefaultName);
  if (output == null) return;
  final paper = ref.read(regionProvider).paperSize;
  await ref
      .read(backgroundJobsProvider.notifier)
      .combine(
        [CombineInput.blank(paper.widthPoints, paper.heightPoints)],
        keepForms: true,
        output: output,
        kind: BackgroundJobKind.create,
      );
}

/// Create PDF (B019; no board draws it): a blank page or files, the clipboard
/// disabled (B176). Files go through the Combine tab, where a locked file can
/// be unlocked, and the result opens.
class CreatePdfDialog extends ConsumerWidget {
  /// The dialog.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final dialogs = ref.read(organizeDialogProvider.notifier);
    return Dialog(
      icon: IconName.filePlus2,
      title: l10n.startCreatePdf,
      description: l10n.startCreatePdfDescription,
      onClose: dialogs.close,
      closeLabel: l10n.saveAsClose,
      cancelAction: Button(
        onPressed: dialogs.close,
        child: Text(l10n.findCancel),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space2,
        children: [
          Button(
            autofocus: true,
            icon: IconName.filePlus2,
            fullWidth: true,
            onPressed: () {
              dialogs.close();
              unawaited(createBlankPdf(ref, l10n));
            },
            child: Text(l10n.createBlank),
          ),
          Button(
            icon: IconName.folderOpen,
            fullWidth: true,
            onPressed: () async {
              dialogs.close();
              final picked = await ref
                  .read(filePickerServiceProvider)
                  .openFilesToCombine(filterLabel: l10n.combineFilter);
              if (picked.isEmpty) return;
              ref
                  .read(combineFilesProvider.notifier)
                  .showTab(
                    l10n.shellToolCombineFiles,
                    add: picked,
                    opensResult: true,
                  );
            },
            child: Text(l10n.createFromFiles),
          ),
          Button(
            icon: IconName.copy,
            fullWidth: true,
            disabledReason: Feature.createFromClipboard.disabledReason(context),
            child: Text(l10n.createFromClipboard),
          ),
        ],
      ),
    );
  }
}
