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
///   installed, for CJK text in widget tests; goldens never contain CJK
///   ([loadCjkFallbackFont]).
/// - Runs the tests under [fermanAlchemistConfig]: goldens on Linux only.
///   They carry alchemist's `golden` tag, declared in `dart_test.yaml`, so
///   `flutter test --exclude-tags golden` skips them and
///   `flutter test --tags golden` runs only them.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();
  await loadCjkFallbackFont();
  return await AlchemistConfig.runWithConfig<FutureOr<void>>(
    config: fermanAlchemistConfig,
    run: testMain,
  );
}
