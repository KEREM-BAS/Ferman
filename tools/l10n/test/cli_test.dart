import 'dart:io';

import 'package:l10n/l10n.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('runL10nCli', () {
    late Directory root;
    late StringBuffer out;
    late StringBuffer err;

    setUp(() {
      root = tempRoot();
      out = StringBuffer();
      err = StringBuffer();
    });

    tearDown(() => root.deleteSync(recursive: true));

    Future<int> run(List<String> arguments) =>
        runL10nCli(arguments, out: out, err: err);

    File output() => File(p.joinAll([root.path, ...outputPath.split('/')]));
    File input() => File(p.joinAll([root.path, ...inputPath.split('/')]));

    test('--check fails while the file is missing', () async {
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(err.toString(), contains('missing'));
      expect(output().existsSync(), isFalse);
    });

    test('writes the file, then --check passes (fresh)', () async {
      expect(await run(['--root', root.path]), 0);
      expect(out.toString(), contains('Wrote $outputPath'));
      expect(output().readAsStringSync(), startsWith(generatedHeader));
      expect(await run(['--root', root.path, '--check']), 0);
      expect(out.toString(), contains('up to date'));
    });

    test('a second run writes nothing', () async {
      expect(await run(['--root', root.path]), 0);
      final modified = output().lastModifiedSync();
      expect(await run(['--root', root.path]), 0);
      expect(out.toString(), contains('is up to date'));
      expect(output().lastModifiedSync(), modified);
    });

    test('--check fails on a stale file and leaves it alone', () async {
      expect(await run(['--root', root.path]), 0);
      final stale = '${output().readAsStringSync()}// edited\n';
      output().writeAsStringSync(stale);
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(err.toString(), contains('stale'));
      expect(output().readAsStringSync(), stale);
    });

    test('--check fails when gen-l10n adds a message', () async {
      expect(await run(['--root', root.path]), 0);
      final source = input().readAsStringSync();
      final end = source.indexOf('\n}\n', source.indexOf('abstract class'));
      input().writeAsStringSync(
        '${source.substring(0, end)}\n\n  String get brandNew;'
        '${source.substring(end)}',
      );
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(await run(['--root', root.path]), 0);
      expect(
        output().readAsStringSync(),
        contains('String get brandNew => isolate(super.brandNew);'),
      );
    });

    test('finds the root from a working directory inside it', () async {
      final nested = Directory(p.join(root.path, 'tools', 'l10n'))
        ..createSync(recursive: true);
      File(p.join(nested.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');
      final code = await runL10nCli(
        const ['--check'],
        out: out,
        err: err,
        workingDirectory: nested.path,
      );
      expect(code, exitStale, reason: 'nothing generated yet in the copy');
      expect(err.toString(), contains('missing'));
    });

    test('reports a member it cannot wrap with exit code $exitError', () async {
      input().writeAsStringSync(classWith('  int get count;'));
      expect(await run(['--root', root.path]), exitError);
      expect(err.toString(), contains('count returns int, not String'));
      expect(err.toString(), contains(inputPath));
      expect(output().existsSync(), isFalse);
    });

    test('asks for gen-l10n when its output is missing', () async {
      input().deleteSync();
      expect(await run(['--root', root.path, '--check']), exitError);
      expect(err.toString(), contains('flutter gen-l10n'));
    });

    test('rejects unknown options and arguments', () async {
      expect(await run(['--nope']), exitUsage);
      expect(await run(['--root', root.path, 'extra']), exitUsage);
      expect(err.toString(), contains('Unexpected arguments: extra'));
    });

    test('help and messages give a command that works', () async {
      expect(await run(['--help']), 0);
      expect(
        out.toString(),
        contains('dart run l10n [--root <dir>] [--check]'),
      );
      expect(out.toString(), contains('--check'));
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(err.toString(), contains(writeCommand));
      expect(writeCommand, '(cd tools/l10n && dart run l10n)');
    });
  });
}
