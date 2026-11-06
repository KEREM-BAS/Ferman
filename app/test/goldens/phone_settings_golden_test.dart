import 'package:ferman/app/router.dart';
import 'package:ferman/features/settings/settings_pane.dart';

import '../helpers/phone_golden.dart';
import '../helpers/window_golden.dart';

/// Settings at phone width (G129): the list and the three built panes, in
/// light and dark × en, tr and ar.
Future<void> main() async {
  final screens = <(String, String, String?, GoldenTheme?, String?)>[
    ('settings_list', Routes.settings, null, GoldenTheme.light, 'a13-15'),
    (
      'settings_general',
      Routes.settingsPane(SettingsPane.general.path),
      null,
      null,
      null,
    ),
    // a13-15b shows the Türkiye region, as the desktop's a11-1b does (G34).
    (
      'settings_language',
      Routes.settingsPane(SettingsPane.language.path),
      'TR',
      GoldenTheme.dark,
      'a13-15b',
    ),
    (
      'settings_editing',
      Routes.settingsPane(SettingsPane.editing.path),
      null,
      null,
      null,
    ),
    (
      'settings_privacy',
      Routes.settingsPane(SettingsPane.privacy.path),
      null,
      null,
      null,
    ),
  ];
  for (final (name, location, region, boardTheme, board) in screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.values) {
        await phoneGoldenTest(
          screen: name,
          theme: theme,
          language: language,
          board: theme == boardTheme && language == GoldenLanguage.en
              ? board
              : null,
          initialLocation: location,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
            regionCode: region,
          ),
        );
      }
    }
  }
}
