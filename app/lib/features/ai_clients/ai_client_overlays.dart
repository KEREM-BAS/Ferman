import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/ai_clients/ai_clients.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What AI clients show over every screen (ADR 0019, G94): the notice while
/// one is connected, and the first request waiting for an answer.
class AiClientOverlays extends ConsumerWidget {
  /// The overlays.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(aiClientsProvider);
    final request = clients.requests.firstOrNull;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (clients.clients.isNotEmpty)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                bottom: context.ferman.space.space10,
              ),
              child: AiClientNotice(clients.clients),
            ),
          ),
        if (request != null)
          ClientRequestDialog(request, key: ValueKey(request.id)),
      ],
    );
  }
}

/// The quiet notice while AI clients are connected: their names and Stop,
/// which turns the server off and disconnects them all (G94). It takes the
/// a4-5 notice's look: a raised pill above the window's foot.
class AiClientNotice extends ConsumerWidget {
  /// The notice for [clients].
  const new(this.clients, {super.key});

  /// The connected clients.
  final List<McpClient> clients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final names = clients
        .map((client) => bidiIsolate(client.name))
        .join(l10n.aiClientsSeparator);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          theme.space.space3,
          theme.space.space1_5,
          theme.space.space1_5,
          theme.space.space1_5,
        ),
        decoration: BoxDecoration(
          color: theme.colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusMd),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.space.space2_5,
          children: [
            Icon(
              IconName.plug,
              size: theme.density.iconMd,
              color: theme.colors.iconSecondary,
            ),
            Flexible(
              child: Text(
                l10n.aiClientsNotice(names),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
            Button(
              size: ButtonSize.sm,
              onPressed: () => unawaited(
                changeSetting(ref, (s) => s.copyWith(aiClients: false)),
              ),
              child: Text(l10n.aiClientsStop),
            ),
          ],
        ),
      ),
    );
  }
}

/// A client's request (ADR 0019): what it asks, about which document or
/// file, with Allow and "Don't allow" (also Esc and the close button).
class ClientRequestDialog extends ConsumerWidget {
  /// The dialog of [request].
  const new(this.request, {super.key});

  /// The request.
  final ClientRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(aiClientsProvider.notifier);
    final client = bidiIsolate(request.clientName);
    final name = bidiIsolate(notifier.tabOf(request)?.name ?? '');
    final path = bidiIsolate(request.path ?? '');
    final signer = bidiIsolate(request.signer ?? '');
    final page = RegionFormat.forRegion(ref.watch(regionProvider).region)
        .integer(request.page ?? 0);
    final (icon, title, description) = switch (request.kind) {
      ClientRequestKind.editSigned => (
        IconName.signature,
        l10n.clientRequestEditSigned(client),
        l10n.clientRequestEditSignedBody(name),
      ),
      ClientRequestKind.save => (
        IconName.save,
        l10n.clientRequestSave(client, name),
        l10n.clientRequestSaveBody,
      ),
      ClientRequestKind.writeFile => (
        IconName.fileOutput,
        l10n.clientRequestWriteFile(client),
        path,
      ),
      ClientRequestKind.readFile => (
        IconName.folderOpen,
        l10n.clientRequestReadFile(client),
        path,
      ),
      ClientRequestKind.sign => (
        IconName.signature,
        l10n.clientRequestSign(client, name),
        switch (request.field) {
          final field? => l10n.clientRequestSignFieldBody(
            signer,
            bidiIsolate(field),
            page,
          ),
          null => l10n.clientRequestSignBody(signer, page),
        },
      ),
      ClientRequestKind.restoreVersion => (
        IconName.rotateCcw,
        l10n.clientRequestRestore(client, name),
        l10n.clientRequestRestoreBody,
      ),
    };
    void deny() => unawaited(notifier.answer(request, allow: false));
    return Dialog(
      icon: icon,
      title: title,
      description: description,
      tone: request.kind == ClientRequestKind.editSigned
          ? DialogTone.warning
          : DialogTone.standard,
      onClose: deny,
      closeLabel: l10n.clientRequestDeny,
      // The request comes unasked, maybe while the person types: focus on
      // "Don't allow", so a keystroke already under way cannot allow it.
      cancelAction: Button(
        autofocus: true,
        onPressed: deny,
        child: Text(l10n.clientRequestDeny),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: () => unawaited(notifier.answer(request, allow: true)),
          child: Text(l10n.clientRequestAllow),
        ),
      ],
    );
  }
}
