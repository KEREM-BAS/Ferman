import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/onboarding/onboarding_link.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The end column of the first-run privacy step, board a1-2b: the privacy
/// facts as a list of rows (an icon tile, a title and a line each), then
/// the four times Ferman uses the network and a link to Settings ›
/// Privacy.
///
/// G24: the design names only the update check; the list follows the
/// brief's four uses instead (the update check, which can be turned off,
/// and language packs, the AI assistant and signature timestamps, each off
/// until used), with a11-1h's payload wording ("the version number and
/// platform"). Revocation lookups are not listed (G51).
class PrivacyFacts extends StatelessWidget {
  /// The facts; [onOpenPrivacySettings] follows the link.
  const new({required this.onOpenPrivacySettings, super.key});

  /// Opens Settings › Privacy.
  final VoidCallback onOpenPrivacySettings;

  /// A row's padding (`padding: 16px 18px`): vertical …
  static const double rowPaddingY = 16;

  /// … and horizontal.
  static const double rowPaddingX = 18;

  /// The icon tile (`width: 32px; height: 32px`).
  static const double tileSize = 32;

  /// The icon in the tile (`size={18}`).
  static const double tileIconSize = 18;

  /// The gap between the tile and the text (`gap: 14px`).
  static const double rowGap = 14;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final rows = [
      (
        IconName.hardDrive,
        l10n.onboardingPrivacyFilesTitle,
        l10n.onboardingPrivacyFilesBody,
      ),
      (
        IconName.wifiOff,
        l10n.onboardingPrivacyOfflineTitle,
        l10n.onboardingPrivacyOfflineBody,
      ),
      (
        IconName.user,
        l10n.onboardingPrivacyAccountTitle,
        l10n.onboardingPrivacyAccountBody,
      ),
      (
        IconName.eyeOff,
        l10n.onboardingPrivacyTelemetryTitle,
        l10n.onboardingPrivacyTelemetryBody,
      ),
      (
        IconName.globe,
        l10n.onboardingPrivacyUpdatesTitle,
        l10n.onboardingPrivacyUpdatesBody,
      ),
      (
        IconName.download,
        l10n.onboardingPrivacyPacksTitle,
        l10n.onboardingPrivacyPacksBody,
      ),
      (
        IconName.sparkles,
        l10n.onboardingPrivacyAiTitle,
        l10n.onboardingPrivacyAiBody,
      ),
      (
        IconName.clock,
        l10n.onboardingPrivacyTimestampsTitle,
        l10n.onboardingPrivacyTimestampsBody,
      ),
    ];
    final titleStyle = theme.typography.prose.copyWith(
      fontWeight: theme.typeScale.weightSemibold,
    );
    final bodyStyle = theme.typography.caption.copyWith(
      color: colors.textSecondary,
    );
    final border = BorderSide(
      color: colors.borderSubtle,
      width: theme.border.borderWidth,
    );

    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.fromBorderSide(border),
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusLg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Every row has its line below, the last one too, as the board's
          // list draws it; a Container adds the line to the padding, as
          // `box-sizing: border-box` with no height does.
          for (final (icon, title, body) in rows)
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: rowPaddingX,
                vertical: rowPaddingY,
              ),
              decoration: BoxDecoration(border: Border(bottom: border)),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: rowGap,
                  children: [
                    Container(
                      width: tileSize,
                      height: tileSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceSunken,
                        borderRadius: BorderRadius.all(
                          Radius.circular(theme.radius.radiusSm),
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: tileIconSize,
                        color: colors.iconPrimary,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: theme.space.space0_5,
                        children: [
                          Text(title, style: titleStyle),
                          Text(body, style: bodyStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space3,
      children: [
        card,
        // a1-2b: `font: var(--type-body-strong)`, an arrow after the text.
        OnboardingLink(
          label: l10n.onboardingPrivacySettingsLink,
          style: theme.typography.bodyStrong,
          onPressed: onOpenPrivacySettings,
          trailingIcon: IconName.arrowRight,
        ),
      ],
    );
  }
}
