import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_tab.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// That the scripts bar of a document was dismissed, in its
/// `documentMemoryProvider` entry: it stays away until the file reopens.
final class _ScriptsDismissed;

/// The bars above a document's pages (the banner slot of a1-9 and a2-10a):
/// a2-10a's restricted bar while the author's restrictions apply, and the
/// scripts bar of G100 until it is dismissed. [onUnlock] opens the owner
/// password dialog.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
