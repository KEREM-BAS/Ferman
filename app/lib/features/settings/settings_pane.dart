import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';

/// The 11 panes of Settings, in the order of a11-1's pane list
/// (`FmSettings.dc.html` `NAV`).
///
/// M1 builds General, Language and region and a Privacy skeleton
/// ([available]); the other panes are listed and disabled with "Available
/// in a future version" until their milestone (G10).
enum SettingsPane {
  /// General (a11-1): theme and viewing defaults.
  general('general', IconName.settings, available: true),

  /// Language and region (a11-1b).
  language('language', IconName.languages, available: true),

  /// Editing (a11-1c): M3.
  editing('editing', IconName.filePenLine),

  /// Fonts (a11-1d): M4 (coverage and system fonts arrive in M3).
  fonts('fonts', IconName.type),

  /// Signatures and certificates (a11-1e): M4 (simple signatures) and P3
  /// (certificates, e-imza).
  signatures('signatures', IconName.signature),

  /// Text recognition (OCR) (a11-1f): P3.
  ocr('ocr', IconName.scanText),

  /// AI assistant (a11-1g): P4.
  ai('ai', IconName.sparkles),

  /// Privacy (a11-1h): a skeleton in M1.
  privacy('privacy', IconName.eyeOff, available: true),

  /// Updates (a11-1i): M5.
  updates('updates', IconName.refreshCw),

  /// Keyboard shortcuts (a11-1j): M4.
  shortcuts('shortcuts', IconName.keyboard),

  /// Advanced (a11-1k): M4.
  advanced('advanced', IconName.wrench);

  new(this.path, this.icon, {this.available = false});

  /// The pane's path segment: `/settings/<path>`.
  final String path;

  /// The pane's icon in the list.
  final IconName icon;

  /// Whether the pane is built in this version.
  final bool available;

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
