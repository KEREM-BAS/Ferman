import 'dart:convert';
import 'dart:io';

import 'package:ferman/design/theme/typography.dart';
import 'package:flutter/services.dart';

/// The Noto Sans CJK collection that Debian and Ubuntu install with
/// `fonts-noto-cjk`. It is not bundled (ADR 0013: CJK comes from the
/// system); tests load it when it is there.
const String notoSansCjkPath =
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';

/// The family name the CJK fallback is registered under.
///
/// Flutter loads only the first face of a font collection, which in
/// `NotoSansCJK-Regular.ttc` is Noto Sans CJK JP, so that is its name: the
/// Linux family ADR 0013 names for Japanese. Korean, Simplified and
/// Traditional Chinese forms are not available in tests.
const String notoSansCjkFamily = 'Noto Sans CJK JP';

/// DejaVu Sans Mono as Debian and Ubuntu install it with
/// `fonts-dejavu-core` (2.37 on Ubuntu 24.04, the CI runner, and in the
/// development container). Not bundled: tests load it for the macOS key
/// symbols ([loadKeySymbolFallbackFont]).
const String dejaVuSansMonoPath =
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf';

/// The family name the key-symbol fallback is registered under.
const String keySymbolFamily = 'DejaVu Sans Mono';

/// The macOS key symbols that shortcut caps use and the bundled IBM Plex
/// files lack (G87): ⌘ ⌥ ⇧ ⌃ ⌫ ⌦ ↵.
const String macKeySymbols = '\u2318\u2325\u21E7\u2303\u232B\u2326\u21B5';

/// The families of the app's `FontManifest.json`, filled by [loadAppFonts].
final Set<String> loadedAppFontFamilies = {};

/// Whether [loadCjkFallbackFont] found and loaded [notoSansCjkPath].
bool cjkFallbackLoaded = false;

/// Whether [loadKeySymbolFallbackFont] found and loaded
/// [dejaVuSansMonoPath].
bool keySymbolFallbackLoaded = false;

/// Loads every font family the app bundles (`flutter.fonts` in
/// `pubspec.yaml`, as listed in the generated `FontManifest.json`), so
/// tests and goldens render with the real IBM Plex files instead of the
/// test font, which draws every glyph as a box.
///
/// Runs once per test file from `flutter_test_config.dart`.
Future<void> loadAppFonts() async {
  final manifest = await rootBundle.loadString('FontManifest.json');
  final families = (jsonDecode(manifest) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  for (final family in families) {
    final name = family['family'] as String;
    if (loadedAppFontFamilies.contains(name)) continue;
    final loader = FontLoader(name);
    for (final font
        in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
    loadedAppFontFamilies.add(name);
  }
}

/// Loads the system Noto Sans CJK font as [notoSansCjkFamily] when
/// [notoSansCjkPath] exists (Linux with `fonts-noto-cjk`), so CJK text in
/// widget tests shows real glyphs when a style lists that family, and in
/// goldens through [useSystemFallbackFonts].
///
/// The only CJK text in a golden is the language picker's own names of
/// Japanese, Korean and Chinese (a1-1), which the app draws from the
/// system's fallback (ADR 0013). On macOS and Windows the file does not
/// exist.
Future<void> loadCjkFallbackFont() async {
  if (cjkFallbackLoaded) return;
  final file = File(notoSansCjkPath);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(notoSansCjkFamily)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
  cjkFallbackLoaded = true;
}

/// Loads the system DejaVu Sans Mono as [keySymbolFamily] when
/// [dejaVuSansMonoPath] exists (Linux with `fonts-dejavu-core`), for the
/// macOS key symbols ⌘ ⌥ ⇧ ⌃ ⌫ ⌦ ↵ ([macKeySymbols], G87) through
/// [useSystemFallbackFonts].
Future<void> loadKeySymbolFallbackFont() async {
  if (keySymbolFallbackLoaded) return;
  final file = File(dejaVuSansMonoPath);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(keySymbolFamily)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
  keySymbolFallbackLoaded = true;
}

/// The system families the tests append to every UI font chain: DejaVu
/// Sans Mono and then Noto Sans CJK JP, each when it was loaded.
List<String> get systemFallbackFamilies => [
  if (keySymbolFallbackLoaded) keySymbolFamily,
  if (cjkFallbackLoaded) notoSansCjkFamily,
];

/// Appends the loaded system fonts ([systemFallbackFamilies]) to every UI
/// font chain through [FermanFontFamilies.debugExtraFallback], so goldens
/// draw what the app takes from the system's font fallback, which
/// `flutter test` does not have: the macOS key symbols (G87) and the
/// language picker's CJK names (ADR 0013). The app never sets the hook.
///
/// Nothing else in a golden reaches these families: the bundled Plex files
/// cover every other character the goldens show (checked by rendering the
/// Windows goldens, which show neither, with and without them: the same
/// pixels). Runs from `flutter_test_config.dart` after the fonts are loaded
/// and before any test, so no typography is built before the chain has
/// them. When a file is missing its family stays out, and a window golden
/// that shows such a character fails instead of recording boxes
/// (`window_golden.dart`).
void useSystemFallbackFonts() {
  FermanFontFamilies.debugExtraFallback = systemFallbackFamilies;
}
