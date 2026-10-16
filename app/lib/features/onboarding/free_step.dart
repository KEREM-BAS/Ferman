import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/onboarding/onboarding_link.dart';
import 'package:ferman/features/onboarding/welcome_step.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A feature tile of the last first-run step (a1-2c), and whether this
/// version has the feature.
///
/// G12: only features that have shipped keep the green check and its
/// "Included" label; the others are neutral and say "Available in a future
/// version" instead. In M1 only the interface languages have shipped.
enum WelcomeFeature {
  /// Edit text and images: M3 (text), P2 (images).
  editing(IconName.filePenLine),

  /// Text recognition (OCR): P3.
  ocr(IconName.scanText),

  /// Fill and sign forms: M4.
  fillSign(IconName.signature),

  /// e-imza and digital signatures: P3.
  signatures(IconName.usb),

  /// Redaction: P2.
  redaction(IconName.eyeOff),

  /// Convert to and from Office: P3.
  convert(IconName.refreshCw),

  /// Compare documents: P3.
  compare(IconName.gitCompare),

  /// Batch actions: P4.
  batch(IconName.workflow),

  /// Accessibility checker: P4.
  accessibility(IconName.accessibility),

  /// The interface languages: as many as have a translation (G20).
  languages(IconName.languages, shipped: true);

  new(this.icon, {this.shipped = false});

  /// The tile's icon (a1-2c `features`).
  final IconName icon;

  /// Whether this version has the feature.
  final bool shipped;
}

/// The feature grid of the last first-run step, board a1-2c: ten tiles in
/// two columns, each with an icon, the feature and its state (G12).
class FeatureGrid extends ConsumerWidget {
  /// The grid.
  const new({super.key});

  /// A tile's height (`height: 44px`).
  static const double tileHeight = 44;

  /// A tile's side padding (`padding: 0 14px`).
  static const double tilePaddingX = 14;

  /// The check's stroke (`stroke-width="2"`).
  static const double checkStroke = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = ref.watch(regionProvider).format;
    final languages = AppLanguage.values.where((l) => l.translated).length;

    String label(WelcomeFeature feature) => switch (feature) {
      WelcomeFeature.editing => l10n.onboardingFeatureEditing,
      WelcomeFeature.ocr => l10n.onboardingFeatureOcr,
      WelcomeFeature.fillSign => l10n.onboardingFeatureFillSign,
      WelcomeFeature.signatures => l10n.onboardingFeatureSignatures,
      WelcomeFeature.redaction => l10n.onboardingFeatureRedaction,
      WelcomeFeature.convert => l10n.onboardingFeatureConvert,
      WelcomeFeature.compare => l10n.onboardingFeatureCompare,
      WelcomeFeature.batch => l10n.onboardingFeatureBatch,
      WelcomeFeature.accessibility => l10n.onboardingFeatureAccessibility,
      WelcomeFeature.languages => l10n.onboardingFeatureLanguages(
        languages,
        format.integer(languages),
      ),
    };

    const features = WelcomeFeature.values;
    final gap = theme.space.space2_5;
    return Column(
      spacing: gap,
      children: [
        for (var i = 0; i < features.length; i += 2)
          Row(
            spacing: gap,
            children: [
              for (final feature in features.skip(i).take(2))
                Expanded(child: _FeatureTile(feature, label(feature))),
            ],
          ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const new(this.feature, this.label);

  final WelcomeFeature feature;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final shipped = feature.shipped;
    final state = shipped
        ? l10n.onboardingFeatureIncluded
        : futureVersionReason(context);
    final tile = Container(
      height: FeatureGrid.tileHeight,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: FeatureGrid.tilePaddingX,
      ),
      decoration: BoxDecoration(
        color: shipped ? colors.surfaceRaised : colors.surfaceSunken,
        border: Border.all(
          color: colors.borderSubtle,
          width: theme.border.borderWidth,
        ),
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
      ),
      child: Row(
        spacing: theme.space.space2_5,
        children: [
          Icon(
            feature.icon,
            color: shipped ? colors.iconSecondary : colors.iconDisabled,
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.copyWith(
                color: shipped ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
          if (shipped)
            Icon(
              IconName.check,
              color: colors.successSolid,
              strokeWidth: FeatureGrid.checkStroke,
            )
          else
            Icon(IconName.clock, color: colors.iconDisabled),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: '$label, $state',
      child: ExcludeSemantics(
        child: shipped ? tile : Tooltip(message: state, child: tile),
      ),
    );
  }
}

/// The licence line of the last first-run step (a1-2c): "Licence:
/// Apache-2.0" (G13) and the Source code and Support the project links,
/// disabled in M1 because the app opens no web pages yet.
class LicenceNote extends StatelessWidget {
  /// The line.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = WelcomeStep.noteStyle(context);
    final reason = futureVersionReason(context);
    const separator = ' · ';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${l10n.onboardingFreeLicence}$separator', style: style),
        OnboardingLink(
          label: l10n.onboardingFreeSourceCode,
          style: style,
          disabledReason: reason,
        ),
        Text(separator, style: style),
        OnboardingLink(
          label: l10n.onboardingFreeSupport,
          style: style,
          disabledReason: reason,
        ),
      ],
    );
  }
}
