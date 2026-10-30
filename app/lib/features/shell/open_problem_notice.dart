import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sentence for the engine's [error] about the file [name] (already
/// isolated, ADR 0014): the ARB string named by its message key, or the
/// generic one for a key the app does not know.
String engineMessage(
  AppLocalizations l10n,
  EngineException error,
  String name,
) => switch (error.messageKey) {
  'errorFileNotFound' => l10n.errorFileNotFound,
  'errorFilePermissionDenied' => l10n.errorFilePermissionDenied,
  'errorFileRead' => l10n.errorFileRead,
  'errorNotPdf' => l10n.errorNotPdf(name),
  'errorPasswordRequired' => l10n.errorPasswordRequired,
  'errorWrongPassword' => l10n.errorWrongPassword,
  'errorDamaged' => l10n.errorDamaged,
  'errorDamagedTruncated' => l10n.errorDamagedTruncated,
  'errorDamagedEmpty' => l10n.errorDamagedEmpty,
  'errorUnsupported' => l10n.errorUnsupported,
  'errorTooComplex' => l10n.errorTooComplex,
  'errorOutOfMemory' => l10n.errorOutOfMemory,
  _ => l10n.errorInternal,
};

/// The start screen's danger banner for a file that ran out of memory or
/// past a limit while opening, so it got no tab (a1-9f's toast, as a
/// banner where no editor shows): its title and message, Try again and
/// Dismiss.
class OpenProblemBanner extends ConsumerWidget {
  /// The banner of [problem].
  const new(this.problem, {super.key});

  /// The file that did not open.
  final OpenProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final opener = ref.read(documentOpenerProvider.notifier);
    final name = bidiIsolate(problem.name);
    return Banner(
      tone: BannerTone.danger,
      title: l10n.openClosedTitle(name),
      onDismiss: opener.dismiss,
      dismissLabel: l10n.openFailedDismiss,
      actions: [
        if (problem.path != null)
          Button(
            size: ButtonSize.sm,
            onPressed: opener.retry,
            child: Text(l10n.openTryAgain),
          ),
      ],
      child: Text(engineMessage(l10n, problem.error, name)),
    );
  }
}

/// a1-9f's toast at the bottom end of the editor's canvas: the file that
/// ran out of memory or past a limit while opening, Try again (opens it
/// again) and Dismiss; it stays, as errors do (a11-6).
class OpenProblemToast extends ConsumerWidget {
  /// The toast of [problem].
  const new(this.problem, {super.key});

  /// The file that did not open.
  final OpenProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final opener = ref.read(documentOpenerProvider.notifier);
    final name = bidiIsolate(problem.name);
    return Toast(
      tone: ToastTone.danger,
      icon: IconName.circleAlert,
      title: l10n.openClosedTitle(name),
      message: engineMessage(l10n, problem.error, name),
      action: problem.path == null
          ? null
          : (label: l10n.openTryAgain, onPressed: opener.retry),
      onClose: opener.dismiss,
      closeLabel: l10n.openFailedDismiss,
    );
  }
}
