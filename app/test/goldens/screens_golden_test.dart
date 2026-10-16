import '../helpers/m1_screens.dart';
import '../helpers/window_golden.dart';

/// A screen of the golden matrix (ROADMAP §5 step 11): its golden name, the
/// M1 screen it shows, and the board it is compared with in English.
final class _Screen {
  const new(this.name, this.screen, this.board, {this.region});

  /// The `<screen>` part of the file name.
  final String name;

  final M1Screen screen;

  /// The board of the English light golden.
  final String board;

  /// The region of every language's goldens when the boards show one;
  /// null keeps each language's own ([GoldenLanguage.regionCode]).
  final String? region;
}

/// First run's three steps, the empty start screen and Settings' General,
/// Language and region and Privacy panes, each in light and dark × en, tr
/// and ar with macOS chrome, as their boards draw them.
const List<_Screen> _screens = [
  _Screen('language_picker', M1Screen.languagePicker, 'a1-1'),
  _Screen('welcome_privacy', M1Screen.privacyStep, 'a1-2b'),
  _Screen('welcome_free', M1Screen.freeStep, 'a1-2c'),
  _Screen('start', M1Screen.start, 'a1-5'),
  _Screen('settings_general', M1Screen.settingsGeneral, 'a11-1'),
  // a11-1b (English) and a12-2c (Arabic) both show the Türkiye region
  // ("13.10.2026", "18.500,50", "10,5 pt", Latin digits), as the rule a11-1b
  // states (G34); every language takes it.
  _Screen(
    'settings_language',
    M1Screen.settingsLanguage,
    'a11-1b',
    region: 'TR',
  ),
  _Screen('settings_privacy', M1Screen.settingsPrivacy, 'a11-1h'),
];

/// The boards of the other languages and chromes where one exists.
String? _board(_Screen screen, GoldenChrome chrome, GoldenLanguage language) =>
    switch ((screen.name, chrome, language)) {
      (_, GoldenChrome.mac, GoldenLanguage.en) => screen.board,
      ('settings_general', GoldenChrome.win, GoldenLanguage.en) => 'a11-1w',
      ('start', GoldenChrome.mac, GoldenLanguage.ar) => 'a12-2a',
      ('settings_language', GoldenChrome.mac, GoldenLanguage.ar) => 'a12-2c',
      _ => null,
    };

Future<void> _golden(
  _Screen screen,
  GoldenChrome chrome,
  GoldenTheme theme,
  GoldenLanguage language,
) => windowGoldenTest(
  screen: screen.name,
  chrome: chrome,
  theme: theme,
  language: language,
  board: theme == GoldenTheme.light ? _board(screen, chrome, language) : null,
  settings: goldenSettings(
    theme: theme,
    language: language,
    onboardingCompleted: !screen.screen.firstRun,
    regionCode: screen.region,
  ),
  open: screen.screen.open,
);

Future<void> main() async {
  for (final screen in _screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.values) {
        await _golden(screen, GoldenChrome.mac, theme, language);
      }
    }
  }
  // Settings › General with Windows chrome (a11-1w): caption buttons and
  // Ctrl shortcuts.
  final general = _screens.firstWhere((s) => s.name == 'settings_general');
  for (final theme in GoldenTheme.values) {
    for (final language in GoldenLanguage.values) {
      await _golden(general, GoldenChrome.win, theme, language);
    }
  }
}
