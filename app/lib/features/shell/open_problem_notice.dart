import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The start screen's danger banner for a file that did not open (G116),
/// until the error tabs of a1-9b to a1-9f and the unlock dialog of a1-8
/// (B115): a1-9b's title, a line for a password, "Copy technical details"
/// and Dismiss.
class OpenProblemBanner extends ConsumerWidget {
  /// The banner of [problem].
  const new(this.problem, {super.key});

  /// The file that did not open.
  final OpenProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Banner(
      tone: BannerTone.danger,
      title: l10n.openFailedTitle(bidiIsolate(problem.name)),
      onDismiss: ref.read(documentOpenerProvider.notifier).dismiss,
      dismissLabel: l10n.openFailedDismiss,
      actions: [
        Button(
          size: ButtonSize.sm,
          icon: IconName.copy,
          onPressed: () => copyDetails(problem),
          child: Text(l10n.startCopyTechnicalDetails),
        ),
      ],
      child: _needsPassword(problem) ? Text(l10n.openFailedPassword) : null,
    );
  }
}

/// The editor's toast for a file of a pick that did not open while others
/// did (G116), at the bottom end of the canvas where a1-9f puts its toast;
/// it stays until dismissed, as errors do (a11-6).
class OpenProblemToast extends ConsumerWidget {
  /// The toast of [problem].
  const new(this.problem, {super.key});

  /// The file that did not open.
  final OpenProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = bidiIsolate(problem.name);
    return Toast(
      tone: ToastTone.danger,
      title: l10n.openFailedToastTitle,
      message: _needsPassword(problem)
          ? l10n.openFailedToastPassword(name)
          : l10n.openFailedTitle(name),
      action: (
        label: l10n.startCopyTechnicalDetails,
        onPressed: () => copyDetails(problem),
      ),
      onClose: ref.read(documentOpenerProvider.notifier).dismiss,
      closeLabel: l10n.openFailedDismiss,
    );
  }
}

bool _needsPassword(OpenProblem problem) =>
    problem.error.kind == EngineErrorKind.passwordRequired;

/// Copies [problem]'s technical details (G63).
void copyDetails(OpenProblem problem) =>
    Clipboard.setData(ClipboardData(text: problem.technicalDetails));
