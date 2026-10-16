import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fonts.dart';
import 'helpers/golden_config.dart';

/// Runs before every test file under `test/`.
///
/// - Loads the bundled IBM Plex families from the app's FontManifest, so
///   text renders with the real fonts, not the test font's boxes
///   (alchemist loads them again for its own tests; that is harmless).
/// - Loads the system Noto Sans CJK font when `fonts-noto-cjk` is
///   installed ([loadCjkFallbackFont]) and the system DejaVu Sans Mono when
///   `fonts-dejavu-core` is ([loadKeySymbolFallbackFont]), and appends them
///   to every UI font chain ([useSystemFallbackFonts]), before any test
///   builds a theme: goldens then draw what the app takes from the
///   system's font fallback, the macOS key symbols ⌘ ⌥ ⇧ ⌃ ⌫ ⌦ ↵ (G87) and
///   the language picker's CJK names, instead of boxes.
/// - Runs the tests under [fermanAlchemistConfig]: goldens on Linux only.
///   They carry alchemist's `golden` tag, declared in `dart_test.yaml`, so
///   `flutter test --exclude-tags golden` skips them and
///   `flutter test --tags golden` runs only them.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();
  await loadCjkFallbackFont();
  await loadKeySymbolFallbackFont();
  useSystemFallbackFonts();
  return await AlchemistConfig.runWithConfig<FutureOr<void>>(
    config: fermanAlchemistConfig,
    run: testMain,
  );
}
