import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';

/// The 11 panes of Settings, in the order of a11-1's pane list
/// (`FmSettings.dc.html` `NAV`).
///
/// M1 builds General, Language and region and a Privacy skeleton; the
/// other panes name their [feature] in the feature registry and are listed
/// and disabled with "Available in a future version" while it is there
/// (G10).
enum SettingsPane {
  /// General (a11-1): theme and viewing defaults.
  general('general', IconName.settings),

  /// Language and region (a11-1b).
  language('language', IconName.languages),

  /// Editing (a11-1c): M3.
  editing('editing', IconName.filePenLine, feature: Feature.settingsEditing),

  /// Fonts (a11-1d): M4 (coverage and system fonts arrive in M3).
  fonts('fonts', IconName.type, feature: Feature.settingsFonts),

  /// Signatures and certificates (a11-1e): M4 (simple signatures) and P3
  /// (certificates, e-imza).
  signatures(
    'signatures',
    IconName.signature,
    feature: Feature.simpleSignatures,
  ),

  /// Text recognition (OCR) (a11-1f): P3.
  ocr('ocr', IconName.scanText, feature: Feature.ocr),

  /// AI assistant (a11-1g): P4.
  ai('ai', IconName.sparkles, feature: Feature.aiAssistant),

  /// Privacy (a11-1h): a skeleton in M1.
  privacy('privacy', IconName.eyeOff),

  /// Updates (a11-1i): M5.
  updates('updates', IconName.refreshCw, feature: Feature.updateCheck),

  /// Keyboard shortcuts (a11-1j): M4.
  shortcuts('shortcuts', IconName.keyboard, feature: Feature.keyboardShortcuts),

  /// Advanced (a11-1k): M4.
  advanced('advanced', IconName.wrench, feature: Feature.settingsAdvanced);

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
    privacy => l10n.settingsPanePrivacy,
    updates => l10n.settingsPaneUpdates,
    shortcuts => l10n.settingsPaneShortcuts,
    advanced => l10n.settingsPaneAdvanced,
  };

  /// The available pane with the path segment [path]; General for any
  /// other path, a pane not built yet included.
  static SettingsPane fromPath(String? path) {
    for (final pane in values) {
      if (pane.path == path && pane.available) return pane;
    }
    return general;
  }
}
