import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The Privacy pane of Settings, board a11-1h: a skeleton in M1.
///
/// The no-telemetry statement, then every network use with its own switch
/// (ADR 0015): the update check (M5), signature checks, timestamps,
/// downloads you start (OCR language packs, P3; the assistant's model, P4)
/// and your AI provider (P4). These are the brief's four uses (the update
/// check, language packs, AI and timestamp servers) plus the drawn
/// "Signature checks" row, which stays visible but disabled until the
/// owner decides on revocation lookups (G51, Q06).
///
/// Nothing connects in M1, so every switch is off and disabled with
/// "Available in a future version" (the design draws four of them on, as
/// they will be once their features ship), and so is "Show network
/// activity…" (M5, with the network gateway).
class PrivacyPane extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final reason = futureVersionReason(context);
    final uses = [
      (l10n.settingsNetUpdates, l10n.settingsNetUpdatesDescription),
      (
        l10n.settingsNetSignatureChecks,
        l10n.settingsNetSignatureChecksDescription,
      ),
      (l10n.settingsNetTimestamps, l10n.settingsNetTimestampsDescription),
      (l10n.settingsNetDownloads, l10n.settingsNetDownloadsDescription),
      (l10n.settingsNetAiProvider, l10n.settingsNetAiProviderDescription),
    ];

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
        for (final (title, description) in uses)
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
              Switch(
                value: false,
                semanticLabel: '$title. $description',
                disabled: true,
                disabledReason: reason,
              ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Button(
            size: ButtonSize.sm,
            icon: IconName.list,
            disabledReason: reason,
            child: Text(l10n.settingsNetworkActivity),
          ),
        ),
      ],
    );
  }
}
