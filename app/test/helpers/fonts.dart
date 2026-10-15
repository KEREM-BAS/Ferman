import 'dart:convert';
import 'dart:io';

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

/// The families of the app's `FontManifest.json`, filled by [loadAppFonts].
final Set<String> loadedAppFontFamilies = {};

/// Whether [loadCjkFallbackFont] found and loaded [notoSansCjkPath].
bool cjkFallbackLoaded = false;

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
/// widget tests shows real glyphs when a style lists that family.
///
/// Goldens never contain CJK text: it depends on the fonts installed on the
/// machine (ADR 0013), and on macOS and Windows the file does not exist.
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
