import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/save/save_as_sheet.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The save flow's dialogs over the editor (`documentSaverProvider`): the
/// Save as sheet (a1-11), a failed save's dialog (a11-7, a11-7d), the
/// warning before Optimize and clean breaks signatures (G35) and the
/// question before the first change to a signed document (a3-16a). It also asks
/// the engine whether the open files changed on disk each time the window
/// regains focus (a11-7b, decision 9).
class SaveOverlays extends ConsumerStatefulWidget {
  /// The dialogs.
  const new({super.key});

  @override
  ConsumerState<SaveOverlays> createState() => _SaveOverlaysState();
}

class _SaveOverlaysState extends ConsumerState<SaveOverlays> {
  late final AppLifecycleListener _focus;

  @override
  void initState() {
    super.initState();
    _focus = AppLifecycleListener(
      onResume: () => unawaited(
        ref.read(documentSaverProvider.notifier).checkExternalChanges(),
      ),
    );
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(documentSaverProvider);
    return Stack(
      children: [
        if (flow.sheet case final sheet?)
          SaveAsSheet(sheet, key: ObjectKey(sheet)),
        if (flow.failure case final failure? when !flow.toast)
          SaveFailureDialog(failure),
        if (flow.optimizing case final tab?) OptimizeWarningDialog(tab),
        if (flow.signed case final request?) SignedEditDialog(request.document),
      ],
    );
  }
}

/// A failed save (a11-7, a11-7d): the a11-7 layout with the failure's
/// glyph, what happened and that the edits are kept, then Try again and,
/// for a failure another file avoids, Save as… (Save somewhere else… when
/// the disk is full). Closing it leaves the f4 toast ([SaveFailureToast]).
class SaveFailureDialog extends ConsumerWidget {
  /// The dialog of [failure].
  const new(this.failure, {super.key});

  /// The save that failed.
  final SaveFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final error = failure.error;
    final (icon, message) = switch (error.kind) {
      EngineErrorKind.diskFull => (IconName.hardDrive, l10n.saveFailedDiskFull),
      EngineErrorKind.permissionDenied => (
        IconName.lock,
        l10n.saveFailedPermission,
      ),
      EngineErrorKind.fileLocked => (
        IconName.circleAlert,
        l10n.saveFailedLocked,
      ),
      EngineErrorKind.renameFailed => (
        IconName.refreshCw,
        l10n.saveFailedRename,
      ),
      EngineErrorKind.volumeGone => (IconName.hardDrive, l10n.saveFailedVolume),
      EngineErrorKind.hardLinked => (IconName.link, l10n.saveFailedHardLinked),
      EngineErrorKind.notOwner => (IconName.lock, l10n.saveFailedNotOwner),
      _ => (IconName.circleAlert, l10n.saveFailedOther),
    };
    return Dialog(
      icon: icon,
      title: l10n.saveFailedTitle(bidiIsolate(failure.name)),
      description: error.noRecoveryCopy
          ? '$message ${l10n.saveFailedNoRecoveryCopy}'
          : message,
      onClose: ref.read(documentSaverProvider.notifier).closeFailureDialog,
      closeLabel: l10n.saveAsClose,
      actions: [
        Button(
          variant: error.offersSaveAs
              ? ButtonVariant.secondary
              : ButtonVariant.primary,
          onPressed: () => unawaited(failure.retry()),
          child: Text(l10n.saveTryAgain),
        ),
        if (error.offersSaveAs)
          Button(
            variant: ButtonVariant.primary,
            onPressed: () => unawaited(failure.saveAs()),
            child: Text(
              error.kind == EngineErrorKind.diskFull
                  ? l10n.saveSomewhereElse
                  : l10n.saveAsEllipsis,
            ),
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SaveFailure>('failure', failure));
  }
}

/// The f4 toast of a save whose dialog was closed: "Couldn't save", what
/// to do, and Save as…; it stays until dismissed, as errors do (a11-6).
class SaveFailureToast extends ConsumerWidget {
  /// The toast of [failure].
  const new(this.failure, {super.key});

  /// The save that failed.
  final SaveFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final error = failure.error;
    return Toast(
      tone: ToastTone.danger,
      icon: IconName.circleAlert,
      title: l10n.shellSaveError,
      message: error.kind == EngineErrorKind.diskFull
          ? l10n.saveToastDiskFull
          : l10n.saveToastOther,
      action: error.offersSaveAs
          ? (
              label: l10n.saveAsEllipsis,
              onPressed: () => unawaited(failure.saveAs()),
            )
          : null,
      onClose: ref.read(documentSaverProvider.notifier).dismissFailure,
      closeLabel: l10n.saveToastDismiss,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SaveFailure>('failure', failure));
  }
}

/// The warning before Optimize and clean rewrites a signed document (G35):
/// its signatures will no longer be valid; Cancel or Optimize and clean.
class OptimizeWarningDialog extends ConsumerWidget {
  /// The warning for [document].
  const new(this.document, {super.key});

  /// The signed document's tab.
  final ShellDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saver = ref.read(documentSaverProvider.notifier);
    return Dialog(
      icon: IconName.triangleAlert,
      tone: DialogTone.warning,
      title: l10n.optimizeTitle(bidiIsolate(document.name)),
      description: l10n.optimizeSignedBody,
      onClose: saver.cancelOptimize,
      closeLabel: l10n.saveAsClose,
      cancelAction: Button(
        onPressed: saver.cancelOptimize,
        child: Text(l10n.saveAsCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: () => unawaited(saver.confirmOptimize()),
          child: Text(l10n.optimizeAction),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ShellDocument>('document', document));
  }
}

/// a11-7b's bar: the file of [document] changed on disk. Compare (until a
/// diff view exists, disabled), Keep mine (saves over the change) and
/// Reload (drops the edits and opens the file again); Ferman picks no
/// winner.
class FileChangedBar extends ConsumerWidget {
  /// The bar of [document].
  const new(this.document, {super.key});

  /// The document's tab.
  final ShellDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saver = ref.read(documentSaverProvider.notifier);
    return Banner(
      variant: BannerVariant.bar,
      tone: BannerTone.warning,
      icon: IconName.refreshCw,
      title: l10n.fileChangedTitle(bidiIsolate(document.name)),
      actions: [
        Button(
          size: ButtonSize.sm,
          variant: ButtonVariant.ghost,
          disabled: true,
          disabledReason: Feature.compare.disabledReason(context),
          child: Text(l10n.fileChangedCompare),
        ),
        Button(
          size: ButtonSize.sm,
          onPressed: () => unawaited(saver.keepMine()),
          child: Text(l10n.fileChangedKeepMine),
        ),
        Button(
          size: ButtonSize.sm,
          onPressed: () => unawaited(saver.reload()),
          child: Text(l10n.fileChangedReload),
        ),
      ],
      child: Text(l10n.fileChangedBody),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ShellDocument>('document', document));
  }
}

/// a3-16a, before the first change to a signed document: how many signatures
/// the change invalidates and by whom, Edit a copy (the default, Enter), Edit
/// anyway, and Cancel (Esc). No setting turns it off (G43).
class SignedEditDialog extends ConsumerWidget {
  /// The question for [document].
  const new(this.document, {super.key});

  /// The signed document's tab.
  final ShellDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final saver = ref.read(documentSaverProvider.notifier);
    final name = bidiIsolate(document.name);
    final signed = [
      for (final signature in document.document?.signatures ?? <Signature>[])
        if (signature.signed) signature,
    ];
    final dot = document.name.lastIndexOf('.');
    final stem = dot > 0 ? document.name.substring(0, dot) : document.name;
    // shortcut: says the first name even when "Edit a copy" will take a later
    // free one; the new tab shows the name it took.
    final copyName = l10n.signedCopyName(stem);
    return Dialog(
      icon: IconName.signature,
      title: l10n.signedTitle,
      description: switch (signed) {
        [Signature(:final String signer, :final DateTime signedAt)] =>
          l10n.signedBodyBy(name, bidiIsolate(signer), format.date(signedAt)),
        _ => l10n.signedBody(
          name,
          signed.isEmpty ? 1 : signed.length,
          format.integer(signed.isEmpty ? 1 : signed.length),
        ),
      },
      onClose: saver.cancelSigned,
      closeLabel: l10n.saveAsClose,
      cancelAction: Button(
        onPressed: saver.cancelSigned,
        child: Text(l10n.saveAsCancel),
      ),
      actions: [
        Button(
          onPressed: () => unawaited(saver.editAnyway()),
          child: Text(l10n.signedEditAnyway),
        ),
        Button(
          variant: ButtonVariant.primary,
          autofocus: true,
          onPressed: () => unawaited(
            saver.editCopy(
              (number) => number == 1
                  ? '$copyName.pdf'
                  : '${l10n.signedCopyNameNumbered(stem, number)}.pdf',
            ),
          ),
          child: Text(l10n.signedEditCopy),
        ),
      ],
      child: Text(
        l10n.signedCopyHint(bidiIsolate('$copyName.pdf')),
        style: theme.typography.caption.copyWith(
          color: theme.colors.textSecondary,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ShellDocument>('document', document));
  }
}

/// a3-16b's bar: the signature no longer matches the document; saving keeps
/// it, showing as invalid. Review edits waits for the review list (B049).
class SignatureInvalidBar extends StatelessWidget {
  /// The bar of [document].
  const new(this.document, {super.key});

  /// The signed document.
  final OpenedDocument document;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signed = [
      for (final signature in document.signatures)
        if (signature.signed) signature,
    ];
    return Banner(
      variant: BannerVariant.bar,
      tone: BannerTone.warning,
      icon: IconName.signature,
      title: l10n.signedBannerTitle(signed.isEmpty ? 1 : signed.length),
      actions: [
        Button(
          size: ButtonSize.sm,
          disabled: true,
          disabledReason: Feature.editReview.disabledReason(context),
          child: Text(l10n.signedBannerReview),
        ),
      ],
      child: Text(switch (signed) {
        [Signature(:final String signer)] => l10n.signedBannerBodyBy(
          bidiIsolate(signer),
        ),
        _ => l10n.signedBannerBody,
      }),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<OpenedDocument>('document', document));
  }
}
