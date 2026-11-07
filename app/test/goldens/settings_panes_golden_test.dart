import 'package:ferman/app/licenses.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _folder = '/data/Signatures';

const AnnotationColor _blue = AnnotationColor(0.102, 0.192, 0.439);

/// a11-1e's three cards.
const List<SavedSignature> _saved = [
  SavedSignature(
    name: 'signature-1.json',
    ink: TypedInk(text: 'Ayşe Yılmaz', family: 'Caveat'),
    color: _blue,
  ),
  SavedSignature(
    name: 'signature-2.json',
    ink: DrawnInk(
      strokes: [
        [Offset(36, 92), Offset(80, 60), Offset(120, 96), Offset(180, 70)],
        [Offset(40, 122), Offset(340, 126)],
      ],
      width: 2.2,
    ),
    color: _blue,
  ),
  SavedSignature(
    name: 'initials-1.json',
    ink: TypedInk(text: 'AY', family: 'Dancing Script'),
    color: _blue,
    initials: true,
  ),
];

/// a11-1d's rows, with fonts the golden host has or falls back from.
const List<InstalledFont> _fonts = [
  InstalledFont(
    family: 'IBM Plex Serif',
    origin: FontOrigin.bundled,
    scripts: {
      FontScript.turkish,
      FontScript.latinExtended,
      FontScript.cyrillic,
      FontScript.greek,
    },
  ),
  InstalledFont(
    family: 'IBM Plex Sans Arabic',
    origin: FontOrigin.bundled,
    scripts: {FontScript.latinExtended, FontScript.arabic},
  ),
  InstalledFont(
    family: 'Georgia',
    origin: FontOrigin.installed,
    scripts: {
      FontScript.turkish,
      FontScript.latinExtended,
      FontScript.cyrillic,
      FontScript.greek,
    },
  ),
  InstalledFont(
    family: 'Noto Serif JP',
    origin: FontOrigin.installed,
    scripts: {
      FontScript.turkish,
      FontScript.latinExtended,
      FontScript.cyrillic,
      FontScript.cjk,
    },
  ),
];

/// Settings › Fonts (a11-1d), Signatures and certificates (a11-1e),
/// Advanced (a11-1k) with its reset confirmation, and Licences (no board),
/// in light and dark × en, tr and ar with macOS chrome. Goldens run on
/// Linux CI only.
Future<void> main() async {
  const screens = {
    'settings_fonts': (SettingsPane.fonts, 'a11-1d'),
    'settings_signatures': (SettingsPane.signatures, 'a11-1e'),
    'settings_advanced': (SettingsPane.advanced, 'a11-1k'),
    'settings_reset': (SettingsPane.advanced, null),
    'settings_licences': (SettingsPane.licences, null),
  };
  for (final MapEntry(key: screen, value: (pane, board)) in screens.entries) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        final engine = FakeEngineService()..installed = _fonts;
        engine.savedSignatureFiles[_folder] = {
          for (final each in _saved) each.name: each.toFile(),
        };
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? board
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          engine: engine,
          initialLocation: Routes.settingsPane(pane.path),
          overrides: [
            signatureDirectoryProvider.overrideWith((ref) async => _folder),
          ],
          // The reset confirmation is a Dialog, which hides while tickers
          // are muted.
          muteTickers: screen != 'settings_reset',
          open: (tester) async {
            if (screen == 'settings_licences') {
              LicenseRegistry.reset();
              registerLicenses();
            }
            await tester.pumpAndSettle();
            if (screen == 'settings_reset') {
              await tester.tap(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is Button &&
                      widget.variant == ButtonVariant.danger,
                ),
              );
              await tester.pumpAndSettle();
            }
          },
          cleanUp: (_) async => LicenseRegistry.reset(),
        );
      }
    }
  }
}
