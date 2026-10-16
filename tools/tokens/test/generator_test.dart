import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

import 'support.dart';

void main() {
  group('generateTokens', () {
    late String first;

    setUpAll(() async {
      first = await generateTokens(repoRoot);
    });

    test('is deterministic: two runs are byte-identical', () async {
      expect(await generateTokens(repoRoot), first);
    });

    test('starts with the generated header and has no timestamp', () {
      expect(first.split('\n').first, generatedHeader);
      expect(first, isNot(matches(RegExp(r'\b20\d\d-\d\d-\d\d'))));
    });

    test('imports only Flutter painting and animation', () {
      final imports = RegExp(
        "^import '([^']+)';",
        multiLine: true,
      ).allMatches(first).map((m) => m.group(1)).toList();
      expect(imports, [
        'package:flutter/animation.dart',
        'package:flutter/painting.dart',
      ]);
    });

    test('is already formatted', () async {
      final formatted = await formatDart(
        first,
        stdinName: p.join(repoRoot, outputPath),
      );
      expect(formatted, first);
    });

    test('documents every token by its CSS name', () {
      for (final name in designModel.cascade.names) {
        expect(first, contains('`--$name`'), reason: name);
      }
    });

    test('matches the committed app/lib/design/tokens.g.dart', () {
      final committed = File(p.join(repoRoot, outputPath));
      expect(
        committed.existsSync() && committed.readAsStringSync() == first,
        isTrue,
        reason: '$outputPath is stale or missing; run $writeCommand',
      );
    });
  });

  group('runTokensCli', () {
    late Directory root;
    late StringBuffer out;
    late StringBuffer err;

    setUp(() {
      root = copyGeneratorInputs();
      out = StringBuffer();
      err = StringBuffer();
    });

    tearDown(() => root.deleteSync(recursive: true));

    Future<int> run(List<String> arguments) =>
        runTokensCli(arguments, out: out, err: err);

    File output() => File(p.joinAll([root.path, ...outputPath.split('/')]));

    test('--check fails while the file is missing', () async {
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(err.toString(), contains('missing'));
      expect(output().existsSync(), isFalse);
    });

    test('writes the file, then --check passes', () async {
      expect(await run(['--root', root.path]), 0);
      expect(output().readAsStringSync(), startsWith(generatedHeader));
      expect(await run(['--root', root.path, '--check']), 0);
      expect(out.toString(), contains('up to date'));
    });

    test('--check fails on a stale file and leaves it alone', () async {
      expect(await run(['--root', root.path]), 0);
      final stale = '${output().readAsStringSync()}// edited\n';
      output().writeAsStringSync(stale);
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(err.toString(), contains('stale'));
      expect(output().readAsStringSync(), stale);
    });

    test('finds the root from a working directory inside it', () async {
      final nested = Directory(p.join(root.path, 'tools', 'tokens'));
      File(p.join(nested.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');
      final code = await runTokensCli(
        const ['--check'],
        out: out,
        err: err,
        workingDirectory: nested.path,
      );
      expect(code, exitStale, reason: 'nothing generated yet in the copy');
      expect(err.toString(), contains('missing'));
    });

    test('reports token errors with exit code $exitError', () async {
      final colors = File(
        p.joinAll([
          root.path,
          ...tokenSources
              .firstWhere((s) => s.label == 'colors.css')
              .path
              .split('/'),
        ]),
      );
      colors.writeAsStringSync(
        '${colors.readAsStringSync()}\n:root { --broken: var(--nowhere); }\n',
      );
      expect(await run(['--root', root.path]), exitError);
      expect(err.toString(), contains('unresolved var(--nowhere)'));
    });

    test('rejects unknown options', () async {
      expect(await run(['--nope']), exitUsage);
      expect(await run(['--help']), 0);
      expect(out.toString(), contains('--check'));
    });

    test('help and messages give a command that works', () async {
      // `dart run --check` fails: `dart run` reads the flag as its own.
      expect(await run(['--help']), 0);
      expect(
        out.toString(),
        contains('dart run bin/tokens.dart [--root <dir>] [--check]'),
      );
      expect(out.toString(), isNot(contains('dart run [')));
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(err.toString(), contains(writeCommand));
      expect(writeCommand, '(cd tools/tokens && dart run bin/tokens.dart)');
    });
  });
}
