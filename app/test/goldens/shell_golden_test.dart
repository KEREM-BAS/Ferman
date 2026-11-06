import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/features/shell/shell_state.dart';

import '../helpers/sample_documents.dart';
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

/// The boards `tools/design-refs/compare-map.json` scores a golden against;
/// the shell is the editor at `/editor` with the sample tabs
/// ([sampleDocuments]), so the boards are the nearest drawn states, not the
/// same document.
String? _board(
  FermanMode mode,
  GoldenChrome chrome,
  GoldenTheme theme,
  GoldenLanguage language,
) => switch ((mode, chrome, theme, language)) {
  (FermanMode.view, GoldenChrome.mac, GoldenTheme.light, GoldenLanguage.en) =>
    'a2-1b',
  (FermanMode.edit, GoldenChrome.mac, GoldenTheme.light, GoldenLanguage.en) =>
    'f6',
  (FermanMode.edit, GoldenChrome.win, GoldenTheme.light, GoldenLanguage.en) =>
    'f6',
  _ => null,
};

/// The editor shell (`/editor`, the [sampleDocuments]) in each of
/// the eight modes with macOS and Windows chrome, in light and dark × en,
/// tr and ar (ROADMAP §5 step 11). English uses the United Kingdom region.
Future<void> main() async {
  for (final mode in FermanMode.values) {
    for (final chrome in GoldenChrome.values) {
      for (final theme in GoldenTheme.values) {
        for (final language in GoldenLanguage.matrix) {
          await windowGoldenTest(
            screen: _screen(mode),
            chrome: chrome,
            theme: theme,
            language: language,
            board: _board(mode, chrome, theme, language),
            settings: goldenSettings(
              theme: theme,
              language: language,
              onboardingCompleted: true,
            ),
            initialLocation: Routes.editor,
            overrides: [
              shellModeProvider.overrideWith(() => _ShellModeIn(mode)),
              sampleDocumentsOverride(),
            ],
          );
        }
      }
    }
  }
}
