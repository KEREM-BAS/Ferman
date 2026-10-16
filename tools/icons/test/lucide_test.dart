import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('readTarGz', () {
    test('returns the wanted regular files', () {
      final archive = buildTarGz({
        'package/LICENSE': 'ISC',
        'package/icons/x.svg': '<svg/>',
        'package/README.md': 'skip',
      });
      final files = readTarGz(archive, (path) => !path.endsWith('.md'));
      expect(
        files.keys,
        unorderedEquals(['package/LICENSE', 'package/icons/x.svg']),
      );
      expect(utf8.decode(files['package/LICENSE']!), 'ISC');
    });

    test('honours PAX path records', () {
      final archive = buildTarGz({
        'package/icons/long.svg': 'a',
      }, paxNames: true);
      expect(readTarGz(archive, (_) => true).keys, ['package/icons/long.svg']);
    });

    test('rejects data that is not gzip', () {
      expect(
        () => readTarGz([1, 2, 3], (_) => true),
        throwsA(isA<IconsException>()),
      );
    });
  });

  test('sriSha512 matches the npm integrity format', () {
    final bytes = utf8.encode('abc');
    expect(
      sriSha512(bytes),
      'sha512-${base64.encode(sha512.convert(bytes).bytes)}',
    );
    expect(sriSha512(bytes), startsWith('sha512-3a81oZNherrMQXNJriBBMRLm'));
  });

  test('the pins cover the four releases G60 names, in preference order', () {
    expect(
      [for (final r in lucideReleases) r.version],
      ['0.460.0', '1.56.0', '0.500.0', '0.300.0'],
    );
    for (final release in lucideReleases) {
      expect(release.integrity, startsWith('sha512-'));
      expect(release.licenseSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(
        release.url.toString(),
        'https://registry.npmjs.org/lucide-static/-/lucide-static-'
        '${release.version}.tgz',
      );
    }
  });

  test(
    '0.300.0, 0.460.0 and 0.500.0 share one licence file; 1.56.0 has its own',
    () {
      final groups = licenseGroups();
      expect(
        [for (final g in groups) g.fileName],
        ['LICENSE-lucide-0.460.0.txt', 'LICENSE-lucide-1.56.0.txt'],
      );
      expect(
        [for (final r in groups.first.releases) r.version],
        ['0.460.0', '0.500.0', '0.300.0'],
      );
    },
  );

  test('the shipped licence files are the pinned texts with the notices', () {
    for (final group in licenseGroups()) {
      final file = File(
        p.joinAll([repoRoot, ...licensePath(group).split('/')]),
      );
      // Hashed with LF line endings, as the pinned hash was taken, so a
      // CRLF checkout passes too.
      final text = readText(file);
      expect(
        sha256.convert(utf8.encode(text)).toString(),
        group.sha256,
        reason: file.path,
      );
      expect(text, startsWith('ISC License'));
      expect(text, contains('Feather'));
    }
    final newest = readRepoFile('app/assets/icons/LICENSE-lucide-1.56.0.txt');
    expect(newest, contains('The MIT License (MIT)'));
    expect(newest, contains('Cole Bemis'));
  });

  group('loadLucide', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('lucide_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('refuses a tarball that does not match its pin', () async {
      const release = LucideRelease('9.9.9', 'sha512-nope', 'ff');
      File(p.join(dir.path, release.tarballName))
          .writeAsBytesSync(buildTarGz({'package/LICENSE': 'x'}));
      await expectLater(
        loadLucide(dir.path, release, {'x'}, download: false),
        throwsA(isA<IconsException>()),
      );
    });

    test(
      'reads the licence and the requested icons of a pinned tarball',
      () async {
        final archive = buildTarGz({
          'package/LICENSE': 'ISC License',
          'package/icons/check.svg': '<svg><path d="M20 6 9 17l-5-5"/></svg>',
          'package/icons/other.svg': '<svg><path d="M0 0"/></svg>',
        });
        final release = LucideRelease(
          '9.9.9',
          sriSha512(archive),
          sha256.convert(utf8.encode('ISC License')).toString(),
        );
        File(p.join(dir.path, release.tarballName)).writeAsBytesSync(archive);
        final package = await loadLucide(dir.path, release, {
          'check',
          'missing',
        }, download: false);
        expect(package.license, 'ISC License');
        expect(package.icons.keys, ['check']);

        final matches = matchIcons(
          [
            const DesignIcon(
              'check',
              '<path d="M20 6 9 17l-5-5" />',
              IconOrigin.bundle,
            ),
            const DesignIcon(
              'missing',
              '<path d="M1 1"/>',
              IconOrigin.additions,
            ),
          ],
          [package],
        );
        expect(matches, {
          'check': ['9.9.9'],
          'missing': <String>[],
        });
      },
    );

    test('refuses a licence that does not match its pin', () async {
      final archive = buildTarGz({'package/LICENSE': 'changed'});
      final release = LucideRelease('9.9.9', sriSha512(archive), '00');
      File(p.join(dir.path, release.tarballName)).writeAsBytesSync(archive);
      await expectLater(
        loadLucide(dir.path, release, const {}, download: false),
        throwsA(isA<IconsException>()),
      );
    });

    test('does not download when told not to', () async {
      await expectLater(
        loadLucide(dir.path, lucideReleases.first, const {}, download: false),
        throwsA(isA<IconsException>()),
      );
    });
  });
}
