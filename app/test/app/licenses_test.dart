import 'dart:io';

import 'package:ferman/app/licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `flutter.assets` entries of `app/pubspec.yaml`.
///
/// A small line reader instead of a YAML parser: the list is a flat block
/// of `    - path` lines under `  assets:`, which is how the pubspec writes
/// it, and the app has no direct YAML dependency.
List<String> _pubspecAssets() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final start = lines.indexOf('  assets:');
  expect(start, isNot(-1), reason: 'pubspec.yaml has no flutter.assets');
  final assets = <String>[];
  for (final line in lines.skip(start + 1)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (!line.startsWith('    - ')) break;
    assets.add(trimmed.substring(2).trim());
  }
  return assets;
}

/// Whether [asset] is a licence text by its place in `app/assets/`.
bool _isLicenseAsset(String asset) =>
    asset.startsWith('assets/licenses/') ||
    RegExp(r'^assets/fonts/[^/]+/LICENSE\.txt$').hasMatch(asset) ||
    RegExp(r'^assets/icons/LICENSE-[^/]+\.txt$').hasMatch(asset);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundledLicenses', () {
    test('lists every licence asset of pubspec.yaml, once', () {
      final listed = [for (final license in bundledLicenses) license.asset];
      final declared = _pubspecAssets().where(_isLicenseAsset).toList();
      expect(listed.toSet(), hasLength(listed.length), reason: 'duplicates');
      expect(listed.toSet(), declared.toSet());
    });

    test('covers the PDFium archive, the six Plex families and Lucide', () {
      List<String> under(String prefix) => [
        for (final license in bundledLicenses)
          if (license.asset.startsWith(prefix)) license.asset,
      ];
      expect(under('assets/licenses/pdfium/'), hasLength(16));
      expect(under('assets/fonts/'), hasLength(6));
      expect(under('assets/icons/'), hasLength(2));
    });

    test('points at files that exist and are not empty', () {
      for (final license in bundledLicenses) {
        final file = File(license.asset);
        expect(file.existsSync(), isTrue, reason: license.asset);
        expect(file.lengthSync(), greaterThan(0), reason: license.asset);
        expect(license.packages, isNotEmpty, reason: license.asset);
      }
    });

    test('names the packages the notices screen groups them under', () {
      Set<String> packagesOf(String asset) => bundledLicenses
          .singleWhere((license) => license.asset == asset)
          .packages
          .toSet();
      expect(packagesOf('assets/licenses/pdfium/pdfium.txt'), {'PDFium'});
      expect(packagesOf('assets/licenses/pdfium/freetype.txt'), {
        'FreeType',
        'PDFium',
      });
      expect(packagesOf('assets/licenses/pdfium/LICENSE'), {
        'pdfium-binaries',
        'PDFium',
      });
      expect(packagesOf('assets/fonts/ibm-plex-sans/LICENSE.txt'), {
        'IBM Plex Sans',
      });
      expect(packagesOf('assets/icons/LICENSE-lucide-1.56.0.txt'), {'Lucide'});
      // Every PDFium archive text appears under PDFium.
      for (final license in bundledLicenses) {
        if (license.asset.startsWith('assets/licenses/pdfium/')) {
          expect(license.packages, contains('PDFium'), reason: license.asset);
        }
      }
    });
  });

  test('decodeLicenseText reads UTF-8 and falls back to Latin-1', () {
    expect(
      decodeLicenseText([0xC2, 0xA9, 0x20, 0x49, 0x42, 0x4D]),
      '\u00A9 IBM',
    );
    expect(decodeLicenseText([0xA9, 0x20, 0x46, 0x54]), '\u00A9 FT');
  });

  group('registerLicenses', () {
    setUp(LicenseRegistry.reset);
    tearDown(LicenseRegistry.reset);

    test('makes LicenseRegistry yield every bundled licence text', () async {
      registerLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      expect(entries, hasLength(bundledLicenses.length));
      for (final (index, license) in bundledLicenses.indexed) {
        final entry = entries[index];
        expect(entry.packages, license.packages, reason: license.asset);
        final text = entry.paragraphs
            .map((p) => p.text)
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ');
        final firstWords =
            decodeLicenseText(File(license.asset).readAsBytesSync())
                .split(RegExp(r'\s+'))
                .where((word) => word.isNotEmpty)
                .take(3)
                .join(' ');
        expect(text, contains(firstWords), reason: license.asset);
      }
    });

    test('shows the OFL, ISC and MIT texts by name', () async {
      registerLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      String textOf(String package) => entries
          .where((entry) => entry.packages.contains(package))
          .expand((entry) => entry.paragraphs)
          .map((paragraph) => paragraph.text)
          .join('\n');
      expect(textOf('IBM Plex Sans'), contains('SIL Open Font License'));
      expect(textOf('IBM Plex Sans'), contains('Reserved Font Name'));
      expect(textOf('Lucide'), contains('ISC License'));
      expect(textOf('Lucide'), contains('Feather'));
      expect(textOf('PDFium'), contains('The PDFium Authors'));
      // The Latin-1 FreeType text keeps its copyright sign.
      expect(textOf('FreeType'), contains('copyright \u00A9 <year>'));
    });
  });
}
