import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// The panes of Settings: a11-1's 11 in the order of its pane list
/// (`FmSettings.dc.html` `NAV`), then Licences (question 7 of the M4 plan).
///
/// M1 builds General, Language and region and a Privacy skeleton, M3 Editing,
/// M4 Fonts, Signatures and certificates, Advanced, AI clients (G94) and
/// Licences; the other
/// panes name their [feature] in the feature registry and are listed and
/// disabled with "Available in a future version" while it is there (G10).
enum SettingsPane {
  /// General (a11-1): theme and viewing defaults.
  general('general', IconName.settings),

  /// Language and region (a11-1b).
  language('language', IconName.languages),

  /// Editing (a11-1c).
  editing('editing', IconName.filePenLine),

  /// Fonts (a11-1d): the fonts bundled and installed, with their scripts.
  fonts('fonts', IconName.type),

  /// Signatures and certificates (a11-1e): the saved signatures; the
  /// certificates, e-imza and timestamps are P3.
  signatures('signatures', IconName.signature),

  /// Text recognition (OCR) (a11-1f): P3.
  ocr('ocr', IconName.scanText, feature: Feature.ocr),

  /// AI assistant (a11-1g): P4.
  ai('ai', IconName.sparkles, feature: Feature.aiAssistant),

  /// AI clients: outside AI apps working in Ferman through MCP (ADR 0019).
  /// No board draws it (G94); it sits after Ferman's own assistant.
  aiClients(
    'ai-clients',
    IconName.plug,
    feature: kIsWeb ? Feature.aiClientsOnWeb : null,
  ),

  /// Privacy (a11-1h).
  privacy('privacy', IconName.eyeOff),

  /// Updates (a11-1i): M5.
  updates('updates', IconName.refreshCw, feature: Feature.updateCheck),

  /// Keyboard shortcuts (a11-1j).
  shortcuts('shortcuts', IconName.keyboard),

  /// Advanced (a11-1k).
  advanced('advanced', IconName.wrench),

  /// Licences: the third-party notices (question 7 of the M4 plan, G14),
  /// the last row; no board draws it. a11-5's Licences button opens it from
  /// M5.
  licences('licences', IconName.fileText);

  new(this.path, this.icon, {this.feature});

  /// The pane's path segment: `/settings/<path>`.
  final String path;

  /// The pane's icon in the list.
  final IconName icon;

  /// The feature of the registry that builds the pane; null for the panes
  /// that are built.
  final Feature? feature;

  /// Whether the pane is built in this version.
  bool get available => feature == null;

  /// The pane's name, in the list and as its heading.
  String label(AppLocalizations l10n) => switch (this) {
    general => l10n.settingsPaneGeneral,
    language => l10n.settingsPaneLanguage,
    editing => l10n.settingsPaneEditing,
    fonts => l10n.settingsPaneFonts,
    signatures => l10n.settingsPaneSignatures,
    ocr => l10n.settingsPaneOcr,
    ai => l10n.settingsPaneAi,
    aiClients => l10n.settingsPaneAiClients,
    privacy => l10n.settingsPanePrivacy,
    updates => l10n.settingsPaneUpdates,
    shortcuts => l10n.settingsPaneShortcuts,
    advanced => l10n.settingsPaneAdvanced,
    licences => l10n.settingsPaneLicences,
  };

  /// What the settings search finds the pane by: its name and the names of
  /// its settings (a11-1: "Search filters every pane"). A pane not built
  /// yet is found by its name alone.
  List<String> searchTerms(AppLocalizations l10n) => [
    label(l10n),
    ...switch (this) {
      general => [
        l10n.settingsTheme,
        l10n.settingsThemeSystem,
        l10n.settingsThemeLight,
        l10n.settingsThemeDark,
        l10n.settingsPageTheme,
        l10n.settingsPagePaper,
        l10n.settingsPageDimmed,
        l10n.settingsPageDark,
        l10n.settingsPageLayout,
        l10n.settingsZoom,
        l10n.settingsReopen,
        l10n.settingsMakeDefault,
        l10n.settingsCommenterName,
      ],
      language => [
        l10n.languageAppLanguage,
        l10n.settingsDocumentLanguages,
        l10n.regionFormats,
        l10n.regionPaperSize,
        l10n.regionUnits,
        l10n.regionFirstDay,
      ],
      editing => [
        l10n.settingsEditMarks,
        l10n.settingsMissingGlyphs,
        l10n.settingsFontForNewText,
        l10n.settingsKeepVersions,
        l10n.settingsReflow,
        l10n.settingsRecoveryCopies,
        l10n.settingsSaving,
        l10n.settingsOptimize,
        l10n.settingsRecoveryFolder,
      ],
      fonts => [l10n.settingsFontsSearchLabel, l10n.settingsFontsFilterTurkish],
      signatures => [
        l10n.settingsSavedSignatures,
        l10n.settingsCertificates,
        l10n.settingsCardDriver,
        l10n.settingsTimestampServer,
        l10n.settingsCheckRevocation,
      ],
      privacy => [
        l10n.settingsPrivacyStatement,
        l10n.settingsNetUpdates,
        l10n.settingsNetSignatureChecks,
        l10n.settingsNetTimestamps,
        l10n.settingsNetDownloads,
        l10n.settingsNetAiProvider,
        l10n.settingsNetAiClients,
        l10n.settingsNetworkActivity,
      ],
      advanced => [
        l10n.settingsGpu,
        l10n.settingsPageCache,
        l10n.settingsThumbnails,
        l10n.settingsObjectInspector,
        l10n.settingsExport,
        l10n.settingsImport,
        l10n.settingsShowLogs,
        l10n.settingsResetButton,
      ],
      aiClients => [
        l10n.aiClientsServer,
        l10n.aiClientsConnected,
        l10n.aiClientsSetUpHeading,
        l10n.aiClientsCopy,
      ],
      licences => [l10n.licencesIntro],
      ocr || ai || updates || shortcuts => const <String>[],
    },
  ];

  /// The available pane with the path segment [path]; General for any
  /// other path, a pane not built yet included.
  static SettingsPane fromPath(String? path) {
    for (final pane in values) {
      if (pane.path == path && pane.available) return pane;
    }
    return general;
  }
}
