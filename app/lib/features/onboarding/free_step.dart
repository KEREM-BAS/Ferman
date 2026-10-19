import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/onboarding/onboarding_link.dart';
import 'package:ferman/features/onboarding/welcome_step.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A feature tile of the last first-run step (a1-2c-m1), and whether this
/// version has the feature.
///
/// G12: only features that have shipped keep the green check and its
/// "Included" label; the others are neutral and say "Available in a future
/// version" instead, while any of their [features] is in the feature
/// registry. In M1 only the interface languages have shipped.
enum WelcomeFeature {
  /// Edit text and images: M3 (text), P2 (images).
  editing(
    IconName.filePenLine,
    features: {Feature.editingText, Feature.addingImages},
  ),

  /// Text recognition (OCR): P3.
  ocr(IconName.scanText, features: {Feature.ocr}),

  /// Fill and sign forms: M4.
  fillSign(
    IconName.signature,
    features: {Feature.formFilling, Feature.simpleSignatures},
  ),

  /// e-imza and digital signatures: P3.
  signatures(
    IconName.usb,
    features: {Feature.certificateSignatures, Feature.eImza},
  ),

  /// Redaction: P2.
  redaction(IconName.eyeOff, features: {Feature.redaction}),

  /// Convert to and from Office: P3.
  convert(IconName.refreshCw, features: {Feature.convertFromPdf}),

  /// Compare documents: P3.
  compare(IconName.gitCompare, features: {Feature.compare}),

  /// Batch actions: P4.
  batch(IconName.workflow, features: {Feature.batchActions}),

  /// Accessibility checker: P4.
  accessibility(IconName.accessibility, features: {Feature.accessibilityTools}),

  /// The interface languages: as many as have a translation (G20).
  languages(IconName.languages);

  new(this.icon, {this.features = const {}});

  /// The tile's icon (a1-2c `features`).
  final IconName icon;

  /// The features of the registry the tile covers; the tile says
  /// "Included" only once all of them have shipped and left the registry
  /// (none for the interface languages, which shipped in M1).
  final Set<Feature> features;

  /// Whether this version has the feature.
  bool get shipped => features.isEmpty;
}

/// The feature grid of the last first-run step, board a1-2c-m1: ten tiles in
/// two columns, each with an icon, the feature and its state (G12).
class FeatureGrid extends ConsumerWidget {
  /// The grid.
  const new({super.key});

  /// A tile's height (`height: 44px`), the least height: a label longer
  /// than two lines makes its row taller.
  static const double tileHeight = 44;

  /// A tile's side padding (`padding: 6px 14px` in a1-2c-m1).
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
          // The two tiles of a row stay as tall as each other, as the
          // board's grid row keeps them, when a long label grows one.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                for (final feature in features.skip(i).take(2))
                  Expanded(child: _FeatureTile(feature, label(feature))),
              ],
            ),
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
    final state =
        feature.features.firstOrNull?.disabledReason(context) ??
        l10n.onboardingFeatureIncluded;
    // The label wraps, as the board's `flex: 1` span does: two lines still
    // fit the 44 px tile; a longer label (in a narrow window or a longer
    // language) makes the tile taller instead of being cut off.
    final tile = Container(
      constraints: const BoxConstraints(minHeight: FeatureGrid.tileHeight),
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: FeatureGrid.tilePaddingX,
        vertical: theme.space.space1_5,
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
    // The accessible name is the label and the state as two sentences, as
    // a1-2c-m1's `aria-label` reads ("Text recognition (OCR). Available in a
    // future version").
    return Semantics(
      container: true,
      label: '$label. $state',
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
    final reason = Feature.projectLinks.disabledReason(context);
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
