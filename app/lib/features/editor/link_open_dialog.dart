import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// G145's prompt before a web or e-mail link leaves the document: all of the
/// target, as the file has it, left to right in every language, since a
/// document's link text can say anything. Opening goes through the system, so
/// Ferman itself connects to nothing.
class LinkOpenDialog extends ConsumerWidget {
  /// The prompt for [link].
  const new({required this.link, super.key});

  /// The link.
  final LinkInfo link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final dialogs = ref.read(organizeDialogProvider.notifier);
    final mail = link.kind == LinkKind.mail;
    return Dialog(
      tone: DialogTone.warning,
      size: DialogSize.sm,
      icon: mail ? IconName.mail : IconName.externalLink,
      title: mail ? l10n.linkOpenMailTitle : l10n.linkOpenWebTitle,
      description: l10n.linkOpenDescription,
      onClose: dialogs.close,
      closeLabel: l10n.saveAsClose,
      cancelAction: Button(
        onPressed: dialogs.close,
        child: Text(l10n.findCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: () {
            dialogs.close();
            unawaited(ref.read(linkToolProvider.notifier).open(link));
          },
          child: Text(l10n.linkOpenAction),
        ),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          link.target,
          style: theme.typography.mono.copyWith(
            color: theme.colors.textPrimary,
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LinkInfo>('link', link));
  }
}
