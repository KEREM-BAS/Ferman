import 'dart:async';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/ai_clients/ai_clients.dart';
import 'package:ferman/features/ai_clients/client_setup.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Claude Desktop's name, a product name left untranslated.
const String claudeDesktop = 'Claude Desktop';

/// Settings › AI clients (ADR 0019). No board draws it (G94), so it is built
/// from the Settings panes' own parts, as Privacy lays out a network use:
///
/// - "Let AI clients connect", off by default: the local MCP server listens
///   while it is on; a warning Banner says when it could not start.
/// - Connected clients, each with "Can change documents", off (read only)
///   until the person turns it on.
/// - Set up a client: Claude Desktop's one-click Set up, which writes Ferman
///   into its configuration, or, where Ferman cannot write it (the macOS App
///   Sandbox, Linux), a note to copy it; other local clients and the
///   configuration to copy; and why ChatGPT cannot connect yet.
class AiClientsPane extends ConsumerWidget {
  /// The pane.
  const new({super.key});

  /// The gap between a setting and its switch (Privacy's `gap: 14px`).
  static const double rowGap = 14;

  /// The configuration box's padding (Privacy's statement, `padding: 16px`).
  static const double codePadding = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(settingsProvider.select((s) => s.aiClients));
    final clients = ref.watch(aiClientsProvider);
    final notifier = ref.read(aiClientsProvider.notifier);
    final toasts = ref.read(toastNoticesProvider.notifier);
    final folder = clients.folder;
    final pump = ref.watch(mcpPumpProvider);
    final entry = folder == null || pump == null
        ? null
        : mcpServerEntry(pump, folder);
    final claudeConfig = ref.watch(claudeDesktopConfigFileProvider);
    final caption = typography.caption.copyWith(color: colors.textSecondary);

    Widget described(String title, String description, Widget end) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: rowGap,
      children: [
        Expanded(
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: theme.space.space0_5,
              children: [
                Text(title, style: typography.bodyStrong),
                Text(description, style: caption),
              ],
            ),
          ),
        ),
        end,
      ],
    );

    Widget heading(String text) => Semantics(
      header: true,
      child: Text(text, style: typography.bodyStrong),
    );

    void copy(Map<String, Object?> entry) {
      unawaited(Clipboard.setData(ClipboardData(text: copyableConfig(entry))));
      toasts.show(
        tone: ToastTone.success,
        title: (l10n) => l10n.aiClientsCopied,
      );
    }

    Future<void> setUpClaude(String path, Map<String, Object?> entry) async {
      final client = bidiIsolate(claudeDesktop);
      if (await addMcpServer(path, entry)) {
        toasts.show(
          tone: ToastTone.success,
          title: (l10n) => l10n.aiClientsSetUpDone(client),
          message: (l10n) => l10n.aiClientsSetUpRestart(client),
        );
      } else {
        toasts.show(
          tone: ToastTone.danger,
          title: (l10n) => l10n.aiClientsSetUpFailed(client),
          message: (l10n) => l10n.aiClientsSetUpFailedBody,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space4,
      children: [
        described(
          l10n.aiClientsServer,
          l10n.aiClientsServerDescription,
          Switch(
            value: on,
            semanticLabel:
                '${l10n.aiClientsServer}. ${l10n.aiClientsServerDescription}',
            onChanged: (value) => unawaited(
              changeSetting(ref, (s) => s.copyWith(aiClients: value)),
            ),
          ),
        ),
        if (on && clients.failed)
          Banner(
            tone: BannerTone.warning,
            child: Text(l10n.aiClientsStartFailed),
          ),
        heading(l10n.aiClientsConnected),
        if (clients.clients.isEmpty)
          Text(l10n.aiClientsNone, style: caption)
        else
          for (final client in clients.clients)
            Row(
              spacing: rowGap,
              children: [
                Icon(IconName.plug, color: colors.iconSecondary),
                Expanded(
                  child: Text(
                    bidiIsolate(client.name),
                    style: typography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  value: client.mayEdit,
                  label: l10n.aiClientsMayEdit,
                  semanticLabel: l10n.aiClientsMayEditFor(
                    bidiIsolate(client.name),
                  ),
                  onChanged: (value) =>
                      unawaited(notifier.grantEdit(client, mayEdit: value)),
                ),
              ],
            ),
        heading(l10n.aiClientsSetUpHeading),
        if (entry == null)
          Text(l10n.aiClientsOffNote, style: caption)
        else ...[
          described(
            claudeDesktop,
            claudeConfig == null
                ? l10n.aiClientsCopyInstead
                : l10n.aiClientsClaudeNote,
            claudeConfig == null
                ? const SizedBox.shrink()
                : Button(
                    size: ButtonSize.sm,
                    icon: IconName.plug,
                    onPressed: () =>
                        unawaited(setUpClaude(claudeConfig, entry)),
                    child: Text(l10n.aiClientsSetUp),
                  ),
          ),
          described(
            l10n.aiClientsOther,
            l10n.aiClientsOtherNote,
            Button(
              size: ButtonSize.sm,
              icon: IconName.copy,
              onPressed: () => copy(entry),
              child: Text(l10n.aiClientsCopy),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(codePadding),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.all(
                Radius.circular(theme.radius.radiusMd),
              ),
            ),
            // The configuration is code: left to right in every language.
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(copyableConfig(entry), style: typography.mono),
            ),
          ),
        ],
        Text(l10n.aiClientsChatGpt, style: caption),
      ],
    );
  }
}
