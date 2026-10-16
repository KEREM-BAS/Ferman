import 'dart:io';

import 'package:checks/src/bundle_scan.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A temporary folder with `repo/design/` and a `build/` folder to scan,
/// deleted when the test ends.
final class Tree {
  new() : dir = Directory.systemTemp.createTempSync('scan_bundle_test_') {
    addTearDown(() => dir.deleteSync(recursive: true));
  }

  /// The temporary folder.
  final Directory dir;

  /// The absolute path of the `/`-separated [relative].
  String path(String relative) => p.joinAll([dir.path, ...relative.split('/')]);

  /// Writes [content] (a string or bytes) to [relative].
  void write(String relative, Object content) {
    final file = File(path(relative))..parent.createSync(recursive: true);
    switch (content) {
      case final String text:
        file.writeAsStringSync(text);
      case final List<int> bytes:
        file.writeAsBytesSync(bytes);
    }
  }

  /// The index of `repo/design/`.
  DesignIndex design() => DesignIndex.load(Directory(path('repo/design')));

  /// The findings in [folder].
  List<BundleFinding> scan([String folder = 'build']) =>
      scanBuild(Directory(path(folder)), design()).findings;
}

/// [length] bytes that differ from every other call's [seed].
List<int> bytes(int length, {int seed = 1}) => [
  for (var i = 0; i < length; i++) (i * 37 + seed * 101) & 0xff,
];

/// A stand-in for `design/support.js`.
final supportJs =
    '${'// The design export runtime: loads React and Babel from unpkg.\n' * 4}'
    'var REACT_URL = "https://unpkg.com/react@18.3.1/umd/react.js";\n';

/// A design folder shaped like the export.
Tree designTree() => Tree()
  ..write('repo/design/support.js', supportJs)
  ..write('repo/design/01 First run.dc.html', '<html>${'board ' * 40}</html>')
  ..write('repo/design/_ds/ds/assets/logo.png', bytes(4000, seed: 2))
  ..write('repo/design/_ds/ds/assets/logo-copy.png', bytes(4000, seed: 2))
  ..write(
    'repo/design/_ds/ds/assets/fonts/plex-sans-latin-400-normal.woff2',
    bytes(9000, seed: 3),
  )
  ..write('repo/design/tiny.css', 'a{}\n');

/// Matches a finding for [path] with a reason that contains [reason].
Matcher finding(String path, [String reason = '']) => isA<BundleFinding>()
    .having((f) => f.path, 'path', path)
    .having((f) => f.reasons, 'reasons', contains(contains(reason)));

void main() {
  test('passes a clean build', () {
    final tree = designTree()
      ..write('build/ferman', bytes(5000, seed: 4))
      ..write('build/lib/libapp.so', bytes(7000, seed: 5))
      ..write('build/lib/libpdfium.so', bytes(6000, seed: 6))
      ..write(
        'build/data/flutter_assets/assets/fonts/ibm-plex-sans/'
        'IBMPlexSans-Regular.ttf',
        bytes(9000, seed: 7),
      )
      ..write('build/data/flutter_assets/AssetManifest.bin', bytes(300))
      ..write('build/main.dart.js', '(function dartProgram(){${'x' * 2000}})')
      // The same size as logo.png, other bytes.
      ..write('build/data/flutter_assets/assets/other.png', bytes(4000))
      // A copy of a design file too small to count, and an empty file.
      ..write('build/data/flutter_assets/tiny.css', 'a{}\n')
      ..write('build/data/empty', '');
    final result = scanBuild(Directory(tree.path('build')), tree.design());
    expect(result.findings, isEmpty);
    expect(result.files, 9);
  });

  test('finds the file names of the design export and its runtime', () {
    final tree = designTree();
    const names = [
      'web/boards/01 First run.DC.HTML',
      'web/_ds_bundle.js',
      'web/support.js',
      'web/css/fm-additions.css',
      'web/FM-Icons.js',
      'web/vendor/react.production.min.js',
      'web/vendor/react.development.js',
      'web/vendor/react-dom.production.min.js',
      'web/vendor/react-dom.development.js',
      'web/vendor/babel.min.js',
      'web/vendor/babel.js',
    ];
    for (final name in names) {
      tree.write('build/$name', 'console.log(1);');
    }
    final findings = tree.scan();
    expect(findings.map((f) => f.path), unorderedEquals(names));
    expect(findings, contains(finding('web/support.js', 'design export')));
    expect(
      findings,
      contains(finding('web/vendor/babel.min.js', 'Babel standalone')),
    );
  });

  test('finds React and Babel scripts under other names', () {
    final tree = designTree()
      ..write(
        'build/web/vendor.js',
        '/**\n * @license React\n * react.production.min.js\n */\n(function(){',
      )
      ..write(
        'build/web/compiler.mjs',
        '!function(e,t){t((e=globalThis||self).Babel={})}(this,function(e){',
      )
      ..write(
        'build/web/compiler2.js',
        '(function (global, factory) {\n  factory(global.Babel = {});\n',
      )
      // Only scripts are read: a licence text may name React.
      ..write('build/NOTICES', '@license React\n.Babel={}\n');
    expect(tree.scan(), [
      finding('web/compiler.mjs', 'Babel standalone under another name'),
      finding('web/compiler2.js', 'Babel standalone'),
      finding('web/vendor.js', 'React script under another name'),
    ]);
  });

  test('finds web fonts and @fontsource files, not the bundled TTFs', () {
    final tree = designTree()
      ..write('build/assets/fonts/caveat-latin-400-normal.woff2', bytes(900))
      ..write('build/assets/fonts/Old.WOFF', bytes(800))
      ..write('build/node_modules/@fontsource/caveat/index.css', '@font-face')
      ..write('build/assets/fonts/IBMPlexSans-Regular.ttf', bytes(700));
    expect(tree.scan(), [
      finding('assets/fonts/Old.WOFF', 'web font'),
      finding('assets/fonts/caveat-latin-400-normal.woff2', 'web font'),
      finding('node_modules/@fontsource/caveat/index.css', '@fontsource'),
    ]);
  });

  test('finds a copy of a design file under any name', () {
    final tree = designTree()
      ..write(
        'build/data/flutter_assets/assets/brand.png',
        bytes(4000, seed: 2),
      )
      ..write('build/runtime.txt', supportJs)
      ..write('build/font.bin', bytes(9000, seed: 3));
    final findings = tree.scan();
    expect(findings.map((f) => f.path), [
      'data/flutter_assets/assets/brand.png',
      'font.bin',
      'runtime.txt',
    ]);
    // Both design files with these bytes are named.
    expect(findings[0].reasons, [
      'identical to design/_ds/ds/assets/logo-copy.png',
      'identical to design/_ds/ds/assets/logo.png',
    ]);
    expect(findings[2].reasons, ['identical to design/support.js']);
  });

  test('lists every reason a file must not ship', () {
    final tree = designTree()..write('build/assets/support.js', supportJs);
    expect(tree.scan().single.reasons, [
      contains('runtime script of the design export'),
      'identical to design/support.js',
    ]);
  });

  test(
    'checks a link to a file like the file and does not follow folder links',
    () {
      final tree = designTree()
        ..write('build/real/app.png', bytes(4000, seed: 2));
      Link(tree.path('build/brand.png'))
          .createSync(tree.path('build/real/app.png'));
      Link(tree.path('build/loop')).createSync(tree.path('build'));
      final result = scanBuild(Directory(tree.path('build')), tree.design());
      expect(result.files, 3);
      expect(result.findings.map((f) => f.path), ['brand.png', 'real/app.png']);
    },
    skip: Platform.isWindows ? 'symbolic links need privileges' : false,
  );

  test('compares with the real design export', () {
    final design = DesignIndex.load(Directory(p.join('..', '..', 'design')));
    expect(design.fileCount, greaterThan(100));
    final tree = Tree()
      ..write(
        'build/x.bin',
        File(p.join('..', '..', 'design', 'support.js')).readAsBytesSync(),
      )
      ..write('build/ok.bin', bytes(5000));
    final result = scanBuild(Directory(tree.path('build')), design);
    expect(result.findings, [
      finding('x.bin', 'identical to design/support.js'),
    ]);
  });

  group('runScanBundle', () {
    late Tree tree;
    setUp(() {
      tree = designTree()
        ..write('clean/ferman', bytes(5000, seed: 4))
        ..write('dirty/ferman', bytes(5000, seed: 4))
        ..write('dirty/data/support.js', 'var x;');
    });

    (int, String) run(List<String> arguments) {
      final out = StringBuffer();
      final status = runScanBundle(arguments, out: out);
      return (status, out.toString());
    }

    test('passes clean folders', () {
      final (status, out) = run([
        '--root',
        tree.path('repo'),
        tree.path('clean'),
      ]);
      expect(status, scanOk);
      expect(out, contains('PASS  ${tree.path('clean')}: 1 files'));
    });

    test('fails when any folder holds a design file and names it', () {
      final (status, out) = run([
        '--root',
        tree.path('repo'),
        tree.path('clean'),
        tree.path('dirty'),
      ]);
      expect(status, scanFound);
      expect(out, contains('PASS  ${tree.path('clean')}'));
      expect(out, contains('FAIL  ${tree.path('dirty')}: 1 of 2 files'));
      expect(out, contains('data/support.js: the runtime script'));
      expect(out, contains('2 folders scanned'));
    });

    test('lists at most 50 files of a folder', () {
      for (var i = 0; i < 60; i++) {
        tree.write('dirty/fonts/f$i.woff2', 'font');
      }
      final (status, out) = run([
        '--root',
        tree.path('repo'),
        tree.path('dirty'),
      ]);
      expect(status, scanFound);
      expect(out, contains('61 of 62 files must not ship'));
      expect(out, contains('... and 11 more'));
    });

    test('rejects a missing folder, a missing design/ and no folder', () {
      expect(run(['--root', tree.path('repo')]).$1, scanUsage);
      final missing = run(['--root', tree.path('repo'), tree.path('nope')]);
      expect(missing.$1, scanUsage);
      expect(missing.$2, contains('build folder not found'));
      final noDesign = run(['--root', tree.path('clean'), tree.path('clean')]);
      expect(noDesign.$1, scanUsage);
      expect(noDesign.$2, contains('design/ not found'));
      expect(run(['--nope']).$1, scanUsage);
    });

    test('prints its usage', () {
      final (status, out) = run(['--help']);
      expect(status, scanOk);
      expect(out, contains('Usage: dart run bin/scan_bundle.dart'));
    });
  });

  test('the bin script runs and fails on a design file', () async {
    final tree = designTree()..write('build/a.dc.html', '<html></html>');
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      p.join('bin', 'scan_bundle.dart'),
      '--root',
      tree.path('repo'),
      tree.path('build'),
    ]);
    expect(result.exitCode, scanFound, reason: '${result.stdout}');
    expect(result.stdout, contains('a.dc.html: a design board'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('lists every design export file name in lowercase', () {
    for (final name in designFileNames.keys) {
      expect(name, name.toLowerCase());
    }
  });
}
