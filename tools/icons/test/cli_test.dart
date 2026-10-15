import 'dart:io';

import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('--check passes on the committed files', () async {
    final result = await runCli(['--check']);
    expect(result.code, 0, reason: result.err);
    expect(result.out, contains('229 SVGs'));
  });

  group('on a copy of the repository', () {
    late String root;
    setUp(() => root = copyRoot());
    tearDown(() => Directory(root).deleteSync(recursive: true));

    File file(String relative) =>
        File(p.joinAll([root, ...relative.split('/')]));

    test('--check passes on an untouched copy', () async {
      final result = await runCli(['--check', '--root', root]);
      expect(result.code, 0, reason: result.err);
    });

    test('--check fails on a changed SVG and a run repairs it', () async {
      file('$assetsDir/x.svg').writeAsStringSync('<svg/>');
      final check = await runCli(['--check', '--root', root]);
      expect(check.code, exitStale);
      expect(check.err, contains('$assetsDir/x.svg (stale)'));
      expect(file('$assetsDir/x.svg').readAsStringSync(), '<svg/>');

      final run = await runCli(['--root', root]);
      expect(run.code, 0, reason: run.err);
      expect((await runCli(['--check', '--root', root])).code, 0);
    });

    test('--check fails on an unexpected SVG and a run deletes it', () async {
      file('$assetsDir/extra.svg').writeAsStringSync('<svg/>');
      final check = await runCli(['--check', '--root', root]);
      expect(check.code, exitStale);
      expect(check.err, contains('extra.svg (unexpected)'));
      expect((await runCli(['--root', root])).code, 0);
      expect(file('$assetsDir/extra.svg').existsSync(), isFalse);
    });

    test('--check fails on a missing SVG, a stale enum or table', () async {
      file('$assetsDir/zap.svg').deleteSync();
      file(enumPath).writeAsStringSync('// stale');
      file(provenancePath).writeAsStringSync('stale');
      final check = await runCli(['--check', '--root', root]);
      expect(check.code, exitStale);
      expect(check.err, contains('zap.svg (missing)'));
      expect(check.err, contains('$enumPath (stale)'));
      expect(check.err, contains('$provenancePath (stale)'));
    });

    test(
      'a changed licence text fails and only --lucide may write it',
      () async {
        file('$assetsDir/LICENSE-lucide-1.56.0.txt').writeAsStringSync('MIT');
        file('$assetsDir/x.svg').writeAsStringSync('<svg/>');
        file('$assetsDir/extra.svg').writeAsStringSync('<svg/>');
        file(dataPath).deleteSync();
        final check = await runCli(['--check', '--root', root]);
        expect(check.code, exitStale);
        expect(check.err, contains('wrong licence text'));
        final run = await runCli(['--root', root]);
        expect(run.code, exitError);
        expect(run.err, contains('--lucide'));
        // The licence check comes first, so nothing was written or deleted.
        expect(file('$assetsDir/x.svg').readAsStringSync(), '<svg/>');
        expect(file('$assetsDir/extra.svg').existsSync(), isTrue);
        expect(file(dataPath).existsSync(), isFalse);
      },
    );

    test('a CRLF checkout gives the same output and passes --check', () async {
      final lf = await generateIcons(root);
      final crlf = copyRoot();
      addTearDown(() => Directory(crlf).deleteSync(recursive: true));
      final converted = <String>[];
      for (final entity in Directory(crlf).listSync(recursive: true)) {
        if (entity is File) {
          convertToCrlf(entity);
          converted.add(entity.path);
        }
      }
      expect(converted.length, greaterThan(229));
      expect(
        File(p.joinAll([crlf, ...bundlePath.split('/')])).readAsStringSync(),
        contains('\r\n'),
      );
      final output = await generateIcons(crlf);
      expect(output.files, lf.files);
      expect(output.requiredLicenses, lf.requiredLicenses);
      final check = await runCli(['--check', '--root', crlf]);
      expect(check.code, 0, reason: check.err);
      final run = await runCli(['--root', crlf]);
      expect(run.code, 0, reason: run.err);
      expect(run.out, contains('Icons are up to date.'));
    });

    test(
      'a changed glyph needs --lucide before its provenance is reused',
      () async {
        final additions = file(additionsPath);
        final source = additions.readAsStringSync();
        final x = loadDesignIcons(root).singleWhere((i) => i.name == 'ellipse');
        final quoted = "'${x.markup}'";
        expect(source, contains(quoted));
        additions.writeAsStringSync(
          source.replaceFirst(
            quoted,
            "'<ellipse cx=\"12\" cy=\"12\" rx=\"10\" ry=\"8\"/>'",
          ),
        );
        final before = file(provenancePath).readAsStringSync();
        final check = await runCli(['--check', '--root', root]);
        expect(check.code, exitError);
        expect(check.err, contains('[ellipse]'));
        expect(check.err, contains('--lucide'));
        final run = await runCli(['--root', root]);
        expect(run.code, exitError);
        expect(file(provenancePath).readAsStringSync(), before);
      },
    );

    test('a missing matches file asks for --lucide', () async {
      file(matchesPath).deleteSync();
      final run = await runCli(['--check', '--root', root]);
      expect(run.code, exitError);
      expect(run.err, contains('--lucide'));
    });
  });

  test('bad usage exits with 64', () async {
    expect((await runCli(['--nope'])).code, exitUsage);
    expect((await runCli(['extra'])).code, exitUsage);
    final temp = Directory.systemTemp.createTempSync('no_root_');
    addTearDown(() => temp.deleteSync(recursive: true));
    expect((await runCli([], workingDirectory: temp.path)).code, exitUsage);
  });

  test('--help prints the usage', () async {
    final result = await runCli(['--help']);
    expect(result.code, 0);
    expect(result.out, contains('--lucide'));
  });
}
