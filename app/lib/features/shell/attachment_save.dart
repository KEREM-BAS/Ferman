import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attachment_save.g.dart';

/// An attachment that was not saved: its name and why.
@immutable
final class AttachmentSaveProblem {
  /// The attachment [name] was not saved because of [error].
  const new({required this.name, required this.error});

  /// The attachment's file name.
  final String name;

  /// What the engine reported.
  final EngineException error;
}

/// Saves attachments where the person says (Sidebar › Attachments › Save
/// attachment as…, a2-3b, B110); its state is the last one that failed,
/// which the editor's toast shows until dismissed. The file is never opened.
@Riverpod(keepAlive: true)
class AttachmentSaver extends _$AttachmentSaver {
  @override
  AttachmentSaveProblem? build() => null;

  /// Shows the save panel for the attachment [name], the one at [index] of
  /// [document]'s attachments, and writes it where the panel says: the
  /// engine writes, flushes and verifies a temp file and renames it over the
  /// chosen file (ADR 0008); under the macOS App Sandbox the temp file is
  /// written in the system's replacement directory and swapped in there.
  Future<void> save(int document, int index, String name) async {
    // A name from the file never picks the folder.
    final suggested = name.split(RegExp(r'[/\\]')).last;
    final path = await ref
        .read(filePickerServiceProvider)
        .saveFile(suggestedName: suggested);
    if (path == null) return;
    state = null;
    final access = ref.read(fileAccessProvider);
    final staging = await access.staging(path);
    try {
      final staged = await ref
          .read(engineServiceProvider)
          .saveAttachment(document, index, path, staging: staging);
      if (staged != null && !await access.swapIn(staged, path)) {
        throw const EngineException(
          kind: EngineErrorKind.io,
          messageKey: 'errorFileWrite',
        );
      }
    } on EngineException catch (error) {
      state = AttachmentSaveProblem(name: suggested, error: error);
    }
  }

  /// Hides the toast.
  void dismiss() => state = null;
}

/// The editor's danger toast for an attachment that was not saved, with
/// Dismiss; it stays, as errors do (a11-6, G124).
class AttachmentSaveToast extends ConsumerWidget {
  /// The toast of [problem].
  const new(this.problem, {super.key});

  /// The attachment that was not saved.
  final AttachmentSaveProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = bidiIsolate(problem.name);
    final error = problem.error;
    return Toast(
      tone: ToastTone.danger,
      icon: IconName.circleAlert,
      title: l10n.attachmentNotSaved(name),
      // A file error is the write's: the open messages would speak of
      // reading the document.
      message: error.messageKey.startsWith('errorFile')
          ? l10n.attachmentWriteFailed
          : engineMessage(l10n, error, name),
      onClose: ref.read(attachmentSaverProvider.notifier).dismiss,
      closeLabel: l10n.openFailedDismiss,
    );
  }
}
