import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/ai_clients/ai_clients.dart';
import 'package:ferman/features/settings/phone_settings.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Privacy pane of Settings, boards a11-1h and a11-1h-m1.
///
/// The no-telemetry statement, then every network use with its own switch
/// (ADR 0015): the update check (M5), signature checks, timestamps,
/// downloads you start (OCR language packs, P3; the assistant's model, P4)
/// and your AI provider (P4). These are the brief's four uses (the update
/// check, language packs, AI and timestamp servers) plus the drawn
/// "Signature checks" row, which stays visible but disabled until phase 3
/// builds revocation lookups, off until first use (G51, Q06).
///
/// Nothing connects up to M4 (M4 adds no network use: links open through
/// the operating system, decision 13), so every switch is off and disabled
/// with "Available in a future version" (the design draws four of them on,
/// as they will be once their features ship), and so is "Show network
/// activity…" (M5, with the network gateway).
///
/// After them, "AI clients on this computer" (G94, ADR 0019): the local MCP
/// server, which reaches no network itself but lets a client send what it
/// reads to its own provider. Its switch works and is the one of Settings ›
/// AI clients, off by default; the connected clients are named under it.
class PrivacyPane extends ConsumerWidget {
  /// The pane.
  const new({super.key});

  /// The statement's padding (`padding: 16px`).
  static const double statementPadding = 16;

  /// The statement's size (`font: 600 15px/22px`).
  static const double statementSize = 15;

  /// The statement's line height (22 px at 15 px).
  static const double statementHeight = 22 / 15;

  /// The gap between a network use and its switch (`gap: 14px`).
  static const double rowGap = 14;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    // Each use with the feature that will connect: downloads you start
    // are the OCR language packs first (P3).
    final uses = [
      (
        Feature.updateCheck,
        l10n.settingsNetUpdates,
        l10n.settingsNetUpdatesDescription,
      ),
      (
        Feature.signatureChecks,
        l10n.settingsNetSignatureChecks,
        l10n.settingsNetSignatureChecksDescription,
      ),
      (
        Feature.certificateSignatures,
        l10n.settingsNetTimestamps,
        l10n.settingsNetTimestampsDescription,
      ),
      (
        Feature.ocr,
        l10n.settingsNetDownloads,
        l10n.settingsNetDownloadsDescription,
      ),
      (
        Feature.aiAssistant,
        l10n.settingsNetAiProvider,
        l10n.settingsNetAiProviderDescription,
      ),
    ];

    Widget networkSwitch(Feature feature, String title, String description) =>
        Switch(
          value: false,
          semanticLabel: '$title. $description',
          disabled: true,
          disabledReason: feature.disabledReason(context),
        );
    final clientsOn = ref.watch(settingsProvider.select((s) => s.aiClients));
    final clients = ref.watch(aiClientsProvider);
    final names = clients.clients
        .map((client) => bidiIsolate(client.name))
        .join(l10n.aiClientsSeparator);
    final clientsDescription = [
      l10n.settingsNetAiClientsDescription,
      if (clientsOn && clients.failed) l10n.aiClientsStartFailed,
      if (clients.clients.isNotEmpty) l10n.aiClientsNotice(names),
    ].join(' ');
    // The web build has no host (B231).
    final clientsSwitch = kIsWeb
        ? networkSwitch(
            Feature.aiClientsOnWeb,
            l10n.settingsNetAiClients,
            clientsDescription,
          )
        : Switch(
            value: clientsOn,
            semanticLabel: '${l10n.settingsNetAiClients}. $clientsDescription',
            onChanged: (value) => unawaited(
              changeSetting(ref, (s) => s.copyWith(aiClients: value)),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space4,
      children: [
        Container(
          padding: const EdgeInsets.all(statementPadding),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusMd),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space2,
            children: [
              Text(
                l10n.settingsPrivacyStatement,
                style: typography.prose.copyWith(
                  fontSize: statementSize,
                  height: statementHeight,
                  fontWeight: theme.typeScale.weightSemibold,
                ),
              ),
              Text(
                l10n.settingsPrivacyStatementBody,
                style: typography.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        for (final (title, description, toggle) in [
          for (final (feature, title, description) in uses)
            (title, description, networkSwitch(feature, title, description)),
          (l10n.settingsNetAiClients, clientsDescription, clientsSwitch),
        ])
          Row(
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
                      Text(
                        description,
                        style: typography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (WindowMetrics.isPhone(context))
                PhoneHitTarget(child: toggle)
              else
                toggle,
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Button(
            size: ButtonSize.sm,
            icon: IconName.list,
            disabledReason: Feature.networkActivityLog.disabledReason(context),
            child: Text(l10n.settingsNetworkActivity),
          ),
        ),
      ],
    );
  }
}
