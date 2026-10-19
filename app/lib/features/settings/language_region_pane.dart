import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/l10n/region_names.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Language and region pane of Settings, board a11-1b (right to left
/// a12-2c).
///
/// - **App language:** the 21 languages by their own names; those without
///   a translation say "Not translated yet" and show English (G20). The
///   interface switches at once; Arabic, Persian and Hebrew to right to
///   left. Choosing the system's language stores no choice, so the app
///   follows the system again.
/// - **Document languages:** drawn and disabled until spell-check and
///   hyphenation (M3) and text recognition (P3) use them; the badges show the
///   defaults they will start from: the region's language when the app has
///   its name (Turkish for Türkiye, as a11-1b and a12-2c draw it), then
///   English.
/// - **Region formats:** the region (its name in the interface language
///   and its own name, in the interface language's alphabetical order),
///   paper size, units and first day of the week, with live examples of a
///   date, a time, a number and a font size: with Türkiye "13.10.2026",
///   "14:32", "18.500,50" and "10,5 pt", whatever the interface language
///   (G34). The system's region is always offered, and choosing it stores
///   no choice, so the formats follow the system again. Choosing the
///   region's own default for paper, units or week stores no override, so
///   it follows the region.
///
/// A change that cannot be stored still applies; Settings says so
/// (`settingsSaveFailedProvider`).
class LanguageRegionPane extends ConsumerWidget {
  /// The pane.
  const new({super.key});

  /// The app language's largest width (`max-width: 380px`).
  static const double appLanguageMaxWidth = 380;

  /// The examples box's width (`260px`).
  static const double examplesWidth = 260;

  /// The gap between the groups (`gap: 18px`).
  static const double sectionGap = 18;

  /// The examples box's padding (`padding: 12px 14px`): horizontal …
  static const double examplesPaddingX = 14;

  /// … and vertical.
  static const double examplesPaddingY = 12;

  /// The moment the examples show: the boards' 13 October 2026, 14:32.
  static final DateTime exampleMoment = DateTime(2026, 10, 13, 14, 32);

  /// The number the examples show (`18.500,50`).
  static const double exampleNumber = 18500.5;

  /// The font size the examples show (`10,5 pt`).
  static const double examplePointSize = 10.5;

  Future<void> _change(
    WidgetRef ref,
    AppSettings Function(AppSettings settings) update,
  ) => changeSetting(ref, update);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final uiLanguage = Localizations.localeOf(context).languageCode;
    final language = ref.watch(appLanguageProvider);
    final systemLanguage = ref.watch(systemLanguageProvider);
    final regionSettings = ref.watch(regionProvider);
    final region = regionSettings.region;
    final systemRegion = Region.fromLocale(ref.watch(systemLocaleProvider));
    final hint = typography.caption.copyWith(color: colors.textSecondary);

    // App language.
    final appLanguage = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: appLanguageMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space1_5,
        children: [
          Select<AppLanguage>(
            label: l10n.languageAppLanguage,
            icon: IconName.languages,
            value: language,
            options: [
              for (final option in AppLanguage.values)
                SelectOption(
                  value: option,
                  label: option.translated
                      ? option.endonym
                      : l10n.languageOptionNotTranslated(option.endonym),
                  // The endonym's Han characters take its own regional forms.
                  locale: option.locale,
                ),
            ],
            onChanged: (choice) => unawaited(
              _change(
                ref,
                (settings) => settings.copyWith(
                  languageCode: () =>
                      choice == systemLanguage ? null : choice.tag,
                ),
              ),
            ),
          ),
          Text(l10n.settingsAppLanguageHint, style: hint),
        ],
      ),
    );

    // Document languages: the region's language, then English.
    final documentLanguages = {
      switch (region.formatLocale.split('_').first) {
        'tr' => l10n.languageNameTurkish,
        'ar' => l10n.languageNameArabic,
        _ => l10n.languageNameEnglish,
      },
      l10n.languageNameEnglish,
    };
    final documents = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2,
      children: [
        Field.labelOf(context, l10n.settingsDocumentLanguages),
        Wrap(
          spacing: theme.space.space1_5,
          runSpacing: theme.space.space1_5,
          // The fixed-height badges stay at the top of the line, as the
          // board's flex row leaves them (a11-1b).
          children: [
            for (final name in documentLanguages)
              Badge(label: name, tone: BadgeTone.accent),
            Button(
              size: ButtonSize.sm,
              variant: ButtonVariant.ghost,
              icon: IconName.plus,
              disabledReason: Feature.documentLanguages.disabledReason(context),
              child: Text(l10n.settingsAddDocumentLanguage),
            ),
          ],
        ),
        Text(l10n.settingsDocumentLanguagesHint, style: hint),
      ],
    );

    // Region formats.
    final regionCodes = sortRegionCodes({
      for (final known in Region.all) known.code,
      systemRegion.code,
      region.code,
    }, uiLanguage);
    final regionOptions = [
      for (final code in regionCodes)
        SelectOption(
          value: code,
          label: regionDisplayName(code, uiLanguage),
          // The own name of a region that writes Han (中国, 香港, 台灣, 日本)
          // takes its regional forms.
          locale: hanLocaleOf(code),
        ),
    ];
    final week = [
      (FirstDayOfWeek.monday, l10n.regionMonday),
      (FirstDayOfWeek.sunday, l10n.regionSunday),
      (FirstDayOfWeek.saturday, l10n.regionSaturday),
      if (region.defaultFirstDayOfWeek == FirstDayOfWeek.friday ||
          regionSettings.firstDayOfWeek == FirstDayOfWeek.friday)
        (FirstDayOfWeek.friday, l10n.regionFriday),
    ];
    final formats = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space3,
      children: [
        Select<String>(
          label: l10n.regionFormats,
          size: FieldSize.sm,
          value: region.code,
          options: regionOptions,
          onChanged: (code) => unawaited(
            _change(
              ref,
              (settings) => settings.copyWith(
                regionCode: () => code == systemRegion.code ? null : code,
              ),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space3,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: theme.space.space1_5,
                children: [
                  Field.labelOf(context, l10n.regionPaperSize),
                  SegmentedControl<PaperSize>(
                    semanticLabel: l10n.regionPaperSize,
                    value: regionSettings.paperSize,
                    options: [
                      SegmentOption(
                        value: PaperSize.a4,
                        label: l10n.regionPaperA4,
                      ),
                      SegmentOption(
                        value: PaperSize.letter,
                        label: l10n.regionPaperLetter,
                      ),
                    ],
                    onChanged: (size) => unawaited(
                      _change(
                        ref,
                        (settings) => settings.copyWith(
                          paperSize: () =>
                              size == region.defaultPaperSize ? null : size,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: theme.space.space1_5,
                children: [
                  Field.labelOf(context, l10n.regionUnits),
                  SegmentedControl<LengthUnit>(
                    semanticLabel: l10n.regionUnits,
                    value: regionSettings.lengthUnit,
                    options: [
                      for (final unit in LengthUnit.values)
                        SegmentOption(value: unit, label: unit.symbol),
                    ],
                    onChanged: (unit) => unawaited(
                      _change(
                        ref,
                        (settings) => settings.copyWith(
                          lengthUnit: () =>
                              unit == region.defaultLengthUnit ? null : unit,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Select<FirstDayOfWeek>(
          label: l10n.regionFirstDay,
          size: FieldSize.sm,
          value: regionSettings.firstDayOfWeek,
          options: [
            for (final (day, label) in week)
              SelectOption(value: day, label: label),
          ],
          onChanged: (day) => unawaited(
            _change(
              ref,
              (settings) => settings.copyWith(
                firstDayOfWeek: () =>
                    day == region.defaultFirstDayOfWeek ? null : day,
              ),
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: sectionGap,
      children: [
        Align(alignment: AlignmentDirectional.centerStart, child: appLanguage),
        documents,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: sectionGap,
          children: [
            Expanded(child: formats),
            SizedBox(
              width: examplesWidth,
              child: RegionExamples(format: regionSettings.format),
            ),
          ],
        ),
      ],
    );
  }
}

/// The locale of the own name of a region that writes it in Han
/// characters (中国, 台灣, 香港, 澳門, 日本), so it takes that region's
/// glyph forms; null for every other region.
Locale? hanLocaleOf(String regionCode) => switch (regionCode) {
  'CN' ||
  'TW' ||
  'HK' ||
  'MO' => Locale.fromSubtags(languageCode: 'zh', countryCode: regionCode),
  'JP' => const Locale('ja', 'JP'),
  _ => null,
};

/// The examples box of a11-1b: a date, a time, a number and a font size,
/// formatted for the region (G34). Each value keeps its own direction in a
/// right-to-left UI (a12-2c: "13.10.2026", "10,5 pt"), through
/// [bidiIsolate].
class RegionExamples extends StatelessWidget {
  /// The examples formatted by [format].
  const new({required this.format, super.key});

  /// The region's formatter.
  final RegionFormat format;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final moment = LanguageRegionPane.exampleMoment;
    final rows = [
      (l10n.regionExampleDate, format.date(moment)),
      (l10n.regionExampleTime, format.time(moment)),
      (
        l10n.regionExampleNumber,
        format.decimal(LanguageRegionPane.exampleNumber, minFractionDigits: 2),
      ),
      (
        l10n.regionExampleFontSize,
        format.pointSize(LanguageRegionPane.examplePointSize),
      ),
    ];
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: LanguageRegionPane.examplesPaddingX,
        vertical: LanguageRegionPane.examplesPaddingY,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space2,
        children: [
          Text(
            LocaleCasing.of(context).upper(l10n.regionExamples),
            style: typography.label.copyWith(color: colors.textTertiary),
          ),
          for (final (name, value) in rows)
            MergeSemantics(
              child: Row(
                spacing: theme.space.space2_5,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: typography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    bidiIsolate(value),
                    style: typography.body.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
