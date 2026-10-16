import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A licence text that ships as an asset, and the packages it covers.
@immutable
final class BundledLicense {
  /// Creates an entry for the asset at [asset] covering [packages].
  const new(this.asset, this.packages);

  /// The asset key, exactly as `flutter.assets` in `pubspec.yaml` lists it.
  final String asset;

  /// The package names the licences screen lists the text under.
  final List<String> packages;
}

/// Every licence text bundled with the app that Flutter does not collect by
/// itself (Dart packages and the engine are collected by the build).
///
/// Sources (docs/DEPENDENCIES.md §5): PDFium and its third-party
/// components from the bblanchon/pdfium-binaries archive (§5.1), the IBM
/// Plex families (§5.2) and the Lucide icons with the Feather notice (§5.3,
/// ADR 0013). A test checks this list against `pubspec.yaml`.
///
/// Texts from the PDFium archive are listed under their component and under
/// PDFium, so the PDFium entry of the licences screen shows everything the
/// library carries.
const List<BundledLicense> bundledLicenses = [
  // PDFium (docs/DEPENDENCIES.md §5.1): the packager's notice, PDFium's own
  // licence and the 14 component licences of the chromium/7881 archive.
  BundledLicense('assets/licenses/pdfium/LICENSE', [
    'pdfium-binaries',
    'PDFium',
  ]),
  BundledLicense('assets/licenses/pdfium/pdfium.txt', ['PDFium']),
  BundledLicense('assets/licenses/pdfium/abseil.txt', ['Abseil', 'PDFium']),
  BundledLicense('assets/licenses/pdfium/agg23.txt', [
    'Anti-Grain Geometry',
    'PDFium',
  ]),
  BundledLicense('assets/licenses/pdfium/fast_float.txt', [
    'fast_float',
    'PDFium',
  ]),
  BundledLicense('assets/licenses/pdfium/freetype.txt', ['FreeType', 'PDFium']),
  BundledLicense('assets/licenses/pdfium/icu.txt', [
    'ICU',
    'PDFium',
    'Unicode data (UCD and CLDR)',
  ]),
  BundledLicense('assets/licenses/pdfium/lcms.txt', ['Little CMS', 'PDFium']),
  BundledLicense('assets/licenses/pdfium/libjpeg_turbo.ijg', [
    'libjpeg-turbo',
    'PDFium',
  ]),
  BundledLicense('assets/licenses/pdfium/libjpeg_turbo.md', [
    'libjpeg-turbo',
    'PDFium',
  ]),
  BundledLicense('assets/licenses/pdfium/libopenjpeg.txt', [
    'OpenJPEG',
    'PDFium',
  ]),
  BundledLicense('assets/licenses/pdfium/libpng.txt', ['libpng', 'PDFium']),
  BundledLicense('assets/licenses/pdfium/libtiff.txt', ['LibTIFF', 'PDFium']),
  BundledLicense('assets/licenses/pdfium/llvm-libc.txt', [
    'LLVM libc',
    'PDFium',
  ]),
  BundledLicense('assets/licenses/pdfium/simdutf.txt', ['simdutf', 'PDFium']),
  BundledLicense('assets/licenses/pdfium/zlib.txt', ['zlib', 'PDFium']),
  // IBM Plex, OFL-1.1 with the Reserved Font Name "Plex" (§5.2).
  BundledLicense('assets/fonts/ibm-plex-sans/LICENSE.txt', ['IBM Plex Sans']),
  BundledLicense('assets/fonts/ibm-plex-serif/LICENSE.txt', ['IBM Plex Serif']),
  BundledLicense('assets/fonts/ibm-plex-mono/LICENSE.txt', ['IBM Plex Mono']),
  BundledLicense('assets/fonts/ibm-plex-sans-arabic/LICENSE.txt', [
    'IBM Plex Sans Arabic',
  ]),
  BundledLicense('assets/fonts/ibm-plex-sans-hebrew/LICENSE.txt', [
    'IBM Plex Sans Hebrew',
  ]),
  BundledLicense('assets/fonts/ibm-plex-sans-devanagari/LICENSE.txt', [
    'IBM Plex Sans Devanagari',
  ]),
  // Lucide (ISC) with the Feather (MIT) notice, under "Lucide" (ADR 0013).
  BundledLicense('assets/icons/LICENSE-lucide-0.460.0.txt', ['Lucide']),
  BundledLicense('assets/icons/LICENSE-lucide-1.56.0.txt', ['Lucide']),
];

/// Adds every [bundledLicenses] text to Flutter's [LicenseRegistry], so the
/// licences screen shows them next to the licences the build collects.
///
/// Call it once at start-up. The texts are read from [bundle] (the root
/// bundle by default) only when something asks the registry for licences.
void registerLicenses({AssetBundle? bundle}) {
  final source = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() => _bundledLicenseEntries(source));
}

Stream<LicenseEntry> _bundledLicenseEntries(AssetBundle bundle) async* {
  for (final license in bundledLicenses) {
    // load() rather than loadString(): loadString caches the text, decodes
    // large assets on a background isolate and assumes UTF-8.
    final data = await bundle.load(license.asset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    yield LicenseEntryWithLineBreaks(
      license.packages,
      decodeLicenseText(bytes),
    );
  }
}

/// Decodes a licence file as UTF-8, or as Latin-1 when it is not valid
/// UTF-8.
///
/// The texts ship unchanged, and one of them is Latin-1: PDFium's
/// `freetype.txt` writes the © of the FreeType credit line as the single
/// byte 0xA9.
@visibleForTesting
String decodeLicenseText(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}
