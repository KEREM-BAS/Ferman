import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/save/save_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_tab.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// That the scripts bar of a document was dismissed, in its
/// `documentMemoryProvider` entry: it stays away until the file reopens.
final class _ScriptsDismissed;

/// The bars above a document's pages (the banner slot of a1-9 and a2-10a):
/// why it opened read-only (a1-9's repaired bar, a11-7c's XFA bar, G102's
/// parsers bar or a1-9d's bar of a file no one may write), a11-7b's bar while
/// its file changed on disk, a3-16b's bar while its changes break its
/// signatures, a2-10a's restricted bar while the author's restrictions
/// apply, and the scripts bar of G100 until it is dismissed.
/// [onUnlock] opens the owner password dialog.
class DocumentBanners extends ConsumerStatefulWidget {
  /// The bars of [document].
  const new({required this.document, required this.onUnlock, super.key});

  /// The document's tab.
  final ShellDocument document;

  /// Opens the owner-password dialog (G106).
  final VoidCallback onUnlock;

  @override
  ConsumerState<DocumentBanners> createState() => _DocumentBannersState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ShellDocument>('document', document))
      ..add(ObjectFlagProperty<VoidCallback>.has('onUnlock', onUnlock));
  }
}

class _DocumentBannersState extends ConsumerState<DocumentBanners> {
  @override
  Widget build(BuildContext context) {
    final opened = widget.document.document;
    if (opened == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final memory = ref.watch(documentMemoryProvider(opened.id));
    final security = opened.security;
    final scripts = opened.scripts;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final changed = ref.watch(
      documentSaverProvider.select((s) => s.changed.contains(opened.id)),
    );
    final invalidated = ref.watch(
      documentEditorProvider.select((s) => s.history.signatureInvalidated),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?switch (opened.readOnly) {
          // a1-9d, until an edit asks for a11-7d at Save.
          null when widget.document.saveState == SaveState.readOnly => Banner(
            variant: BannerVariant.bar,
            icon: IconName.lock,
            title: l10n.readOnlyFileTitle(bidiIsolate(widget.document.name)),
            actions: [
              Button(
                size: ButtonSize.sm,
                onPressed: () => ref
                    .read(documentSaverProvider.notifier)
                    .openSheet(copy: true),
                child: Text(l10n.readOnlyFileSaveCopy),
              ),
            ],
            child: Text(l10n.readOnlyFileBody),
          ),
          null => null,
          ReadOnlyReason.repaired => _RepairedBar(widget.document),
          ReadOnlyReason.xfaOnly => Banner(
            variant: BannerVariant.bar,
            tone: BannerTone.warning,
            icon: IconName.fileX,
            title: l10n.xfaTitle,
            actions: [
              Button(
                size: ButtonSize.sm,
                onPressed: switch (widget.document.path) {
                  final path? => () => unawaited(
                    ref.read(fileAccessProvider).show(path),
                  ),
                  null => null,
                },
                child: Text(switch (ref.watch(shortcutPlatformProvider)) {
                  ShortcutPlatform.mac => l10n.openShowInFinder,
                  ShortcutPlatform.windows => l10n.openShowInExplorer,
                  ShortcutPlatform.linux => l10n.openShowInFolder,
                }),
              ),
            ],
            child: Text(l10n.xfaBody),
          ),
          ReadOnlyReason.parsersDisagree => Banner(
            variant: BannerVariant.bar,
            icon: IconName.lock,
            title: l10n.disagreeTitle(bidiIsolate(widget.document.name)),
            child: Text(l10n.disagreeBody),
          ),
        },
        if (changed) FileChangedBar(widget.document),
        if (invalidated) SignatureInvalidBar(opened),
        if (security != null && security.restricted)
          Banner(
            variant: BannerVariant.bar,
            icon: IconName.shield,
            title: l10n.restrictedTitle,
            actions: [
              Button(
                size: ButtonSize.sm,
                onPressed: widget.onUnlock,
                child: Text(l10n.restrictedUnlock),
              ),
            ],
            child: Text(
              _boardSentence(security.permissions)
                  ? l10n.restrictedBody
                  : l10n.restrictedBodyOther,
            ),
          ),
        if (scripts > 0 && memory.recall<_ScriptsDismissed>() == null)
          Banner(
            variant: BannerVariant.bar,
            icon: IconName.shieldCheck,
            title: l10n.scriptsTitle(scripts, format.integer(scripts)),
            onDismiss: () =>
                setState(() => memory.remember(_ScriptsDismissed())),
            dismissLabel: l10n.scriptsDismiss,
            child: Text(l10n.scriptsBody),
          ),
      ],
    );
  }

  /// Whether a2-10a's sentence is true of [permissions]: printing allowed,
  /// changes, comments and form filling not. Any other set gets the
  /// neutral sentence, so the bar never claims what the file does not say.
  static bool _boardSentence(DocumentPermissions permissions) =>
      permissions.print &&
      !permissions.modify &&
      !permissions.annotate &&
      !permissions.fillForms;
}

/// a1-9's repaired bar: how many problems repair fixed, Details with the
/// popover "What Ferman repaired" and its Copy details, and "Save repaired
/// copy…", which writes the repaired document where the system save panel
/// says (B103, `DocumentSaver.saveRepairedCopy`).
class _RepairedBar extends ConsumerStatefulWidget {
  const new(this.tab);

  final ShellDocument tab;

  /// a1-9's repair details (`width: 420px`) …
  static const double detailsWidth = 420;

  /// … and their padding (`padding: 14px 16px`).
  static const double detailsPaddingY = 14;

  @override
  ConsumerState<_RepairedBar> createState() => _RepairedBarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ShellDocument>('tab', tab));
  }
}

class _RepairedBarState extends ConsumerState<_RepairedBar> {
  bool _details = false;

  /// Details, which gets focus back when the popover closes.
  final FocusNode _detailsButton = FocusNode(debugLabel: 'Repair details');

  @override
  void dispose() {
    _detailsButton.dispose();
    super.dispose();
  }

  void _close() {
    if (!_details) return;
    setState(() => _details = false);
    _detailsButton.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    String count(int value) => format.integer(value);
    final document = widget.tab.document;
    final pages = document?.pages.length ?? 0;
    final fixes = [
      for (final fix in document?.repairs ?? const <RepairFix>[])
        switch (fix.kind) {
          RepairKind.crossReferenceRebuilt => (
            l10n.repairXrefTitle,
            '${l10n.repairXrefBody(fix.count, count(fix.count))} '
                '${l10n.repairPagesPresent(pages, count(pages))}',
            true,
          ),
          RepairKind.trailerRebuilt => (
            l10n.repairTrailerTitle,
            l10n.repairTrailerBody,
            true,
          ),
          RepairKind.streamLengthsCorrected => (
            l10n.repairStreamsTitle(fix.count, count(fix.count)),
            l10n.repairStreamsBody,
            true,
          ),
          // Not fixed: what used them may be incomplete.
          RepairKind.objectsUnreadable => (
            l10n.repairUnreadableTitle(fix.count, count(fix.count)),
            l10n.repairUnreadableBody,
            false,
          ),
        },
    ];
    // An entry not fixed (unreadable objects) is not counted as fixed.
    final fixed = fixes.where((fix) => fix.$3).length;
    final details = Semantics(
      container: true,
      label: l10n.repairDetailsTitle,
      child: SizedBox(
        width: _RepairedBar.detailsWidth,
        child: PopoverSurface(
          radius: theme.radius.radiusLg,
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.space.space4,
              vertical: _RepairedBar.detailsPaddingY,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: theme.space.space3,
              children: [
                Text(
                  l10n.repairDetailsTitle,
                  style: theme.typography.panelTitle,
                ),
                for (final (title, body, fixed) in fixes)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: theme.space.space2_5,
                    children: [
                      Icon(
                        fixed ? IconName.circleCheck : IconName.triangleAlert,
                        size: theme.density.iconMd,
                        color: fixed
                            ? theme.colors.successSolid
                            : theme.colors.warningSolid,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: theme.space.space0_5,
                          children: [
                            Text(title, style: theme.typography.body),
                            Text(
                              body,
                              style: theme.typography.caption.copyWith(
                                color: theme.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: theme.colors.borderSubtle),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: theme.space.space1,
                    ),
                    child: Row(
                      children: [
                        Button(
                          size: ButtonSize.sm,
                          icon: IconName.copy,
                          onPressed: () => Clipboard.setData(
                            ClipboardData(
                              text: [
                                for (final (title, body, _) in fixes)
                                  '$title. $body',
                              ].join('\n'),
                            ),
                          ),
                          child: Text(l10n.repairCopyDetails),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Banner(
      variant: BannerVariant.bar,
      icon: IconName.wrench,
      title: l10n.repairedTitle,
      actions: [
        // Nothing to list, nothing to open.
        if (fixes.isNotEmpty)
          Popover(
            open: _details,
            surface: false,
            onDismiss: _close,
            anchor: Semantics(
              expanded: _details,
              child: Button(
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                focusNode: _detailsButton,
                onPressed: () =>
                    _details ? _close() : setState(() => _details = true),
                child: Text(l10n.repairedDetails),
              ),
            ),
            child: details,
          ),
        Button(
          size: ButtonSize.sm,
          onPressed: () => unawaited(
            ref
                .read(documentSaverProvider.notifier)
                .saveRepairedCopy(widget.tab),
          ),
          child: Text(l10n.repairedSave),
        ),
      ],
      child: Text(l10n.repairedBody(fixed, count(fixed))),
    );
  }
}

/// The owner-password dialog of G106, document-modal over the pages: a1-8's
/// dialog with a2-10b's `key-round`. The right password lifts the
/// restrictions for the session ([DocumentOpener.unlockOwner]) and closes
/// it; [onClose] closes it too.
class OwnerUnlockDialog extends ConsumerWidget {
  /// The dialog for [document].
  const new({required this.document, required this.onClose, super.key});

  /// The restricted document's tab.
  final ShellDocument document;

  /// Closes the dialog.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final path = document.path;
    return Scrim(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(context.ferman.space.space6),
        child: PasswordDialog(
          icon: IconName.keyRound,
          title: l10n.ownerUnlockTitle,
          description: l10n.ownerUnlockDescription(bidiIsolate(document.name)),
          label: l10n.ownerUnlockPassword,
          action: l10n.ownerUnlockAction,
          onSubmit: (password) async {
            final accepted =
                path == null ||
                await ref
                    .read(documentOpenerProvider.notifier)
                    .unlockOwner(path, password);
            if (accepted) onClose();
            return accepted;
          },
          onCancel: onClose,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ShellDocument>('document', document))
      ..add(ObjectFlagProperty<VoidCallback>.has('onClose', onClose));
  }
}
