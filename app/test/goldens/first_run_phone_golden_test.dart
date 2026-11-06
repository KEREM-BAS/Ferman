import '../helpers/m1_screens.dart';
import '../helpers/phone_golden.dart';
import '../helpers/window_golden.dart';

/// First run at phone width (G129), each step in light and dark × en, tr and
/// ar: the language picker (a13-1b) and the three welcome steps, in the
/// language of a13-1.
Future<void> main() async {
  for (final (name, screen) in const [
    ('language_picker', M1Screen.languagePicker),
    ('welcome_edit', M1Screen.editStep),
    ('welcome_privacy', M1Screen.privacyStep),
    ('welcome_free', M1Screen.freeStep),
  ]) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.values) {
        await phoneGoldenTest(
          screen: name,
          theme: theme,
          language: language,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: false,
          ),
          board:
              screen == M1Screen.languagePicker &&
                  theme == GoldenTheme.light &&
                  language == GoldenLanguage.en
              ? 'a13-1b'
              : null,
          open: screen.open,
        );
      }
    }
  }
}
