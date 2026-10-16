import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/features/shell/shell_state.dart';

import '../helpers/window_golden.dart';

/// The shell in [mode] from the start, as when a document opens in it.
class _ShellModeIn extends ShellMode {
  new(this.mode);

  final FermanMode mode;

  @override
  FermanMode build() => mode;
}

/// The `<screen>` part of the file name for [mode].
String _screen(FermanMode mode) => switch (mode) {
  FermanMode.view => 'shell_view',
  FermanMode.edit => 'shell_edit',
  FermanMode.comment => 'shell_comment',
  FermanMode.sign => 'shell_fill_sign',
  FermanMode.organize => 'shell_organize',
  FermanMode.convert => 'shell_convert',
  FermanMode.protect => 'shell_protect',
  FermanMode.tools => 'shell_tools',
};

/// The boards drawn for a mode and chrome in English and light; the shell
/// is the editor at `/debug/shell` with its placeholder documents, so the
/// boards are the nearest drawn states, not the same document.
String? _board(FermanMode mode, GoldenChrome chrome) =>
    switch ((mode, chrome)) {
      (FermanMode.view, GoldenChrome.mac) => 'a2-1b',
      (FermanMode.edit, GoldenChrome.win) => 'f6a',
      _ => null,
    };

/// The editor shell (`/debug/shell`, the placeholder documents) in each of
/// the eight modes with macOS and Windows chrome, in light and dark × en,
/// tr and ar (ROADMAP §5 step 11). English uses the United Kingdom region.
Future<void> main() async {
  for (final mode in FermanMode.values) {
    for (final chrome in GoldenChrome.values) {
      for (final theme in GoldenTheme.values) {
        for (final language in GoldenLanguage.values) {
          await windowGoldenTest(
            screen: _screen(mode),
            chrome: chrome,
            theme: theme,
            language: language,
            board: theme == GoldenTheme.light && language == GoldenLanguage.en
                ? _board(mode, chrome)
                : null,
            settings: goldenSettings(
              theme: theme,
              language: language,
              onboardingCompleted: true,
            ),
            initialLocation: Routes.debugShell,
            overrides: [
              shellModeProvider.overrideWith(() => _ShellModeIn(mode)),
            ],
          );
        }
      }
    }
  }
}
