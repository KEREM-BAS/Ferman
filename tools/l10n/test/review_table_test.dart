import 'dart:io';

import 'package:l10n/l10n.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// A small set of ARB files: English with descriptions, Turkish missing one
/// message, Arabic complete, and a Persian file with one message.
Map<String, Map<String, Object?>> sampleArbs() => {
  'en': {
    '@@locale': 'en',
    'save': 'Save',
    '@save': {'description': 'Mode bar: the Save button.'},
    'pages': '{count, plural, =1{1 page} other{{count} pages}}',
    '@pages': {
      'description': 'Status bar: the page count.',
      'placeholders': {
        'count': {'type': 'int'},
      },
    },
    'open': 'Open',
    '@open': {'description': 'Start screen: opens a file.'},
  },
  'tr': {'@@locale': 'tr', 'save': 'Kaydet', 'open': 'Aç'},
  'ar': {
    '@@locale': 'ar',
    'save': 'حفظ',
    'pages': '{count, plural, =1{صفحة واحدة} other{{count} صفحات}}',
    'open': 'فتح',
  },
  'fa': {'@@locale': 'fa', 'save': 'ذخیره'},
};

List<ArbFile> parsed(Map<String, Map<String, Object?>> arbs) {
  final root = reviewRoot(arbs: arbs);
  try {
    return loadArbFiles(root.path);
  } finally {
    root.deleteSync(recursive: true);
  }
}

void main() {
  group('loadArbFiles', () {
    test('reads English, then Turkish, then the others by locale', () {
      final files = parsed(sampleArbs());
      expect([for (final file in files) file.locale], ['en', 'tr', 'ar', 'fa']);
    });

    test('keeps file order and leaves metadata out', () {
      final english = parsed(sampleArbs()).first;
      expect(english.messages.keys, ['save', 'pages', 'open']);
      expect(english.descriptions, {
        'save': 'Mode bar: the Save button.',
        'pages': 'Status bar: the page count.',
        'open': 'Start screen: opens a file.',
      });
    });

    test('ignores other files in the ARB directory', () {
      final root = reviewRoot(arbs: sampleArbs());
      addTearDown(() => root.deleteSync(recursive: true));
      final directory = p.joinAll([root.path, ...arbDirectory.split('/')]);
      File(p.join(directory, 'casing.dart')).writeAsStringSync('// code\n');
      File(p.join(directory, 'notes.arb')).writeAsStringSync('not json');
      Directory(p.join(directory, 'gen')).createSync();
      expect(loadArbFiles(root.path), hasLength(4));
    });

    test('stops when app_en.arb is missing', () {
      final root = reviewRoot(arbs: {'tr': sampleArbs()['tr']!});
      addTearDown(() => root.deleteSync(recursive: true));
      expect(
        () => loadArbFiles(root.path),
        throwsA(
          isA<L10nException>().having(
            (e) => e.message,
            'message',
            contains('$arbDirectory/$templateArbFile is missing'),
          ),
        ),
      );
    });

    test('stops on a file that is not a JSON object', () {
      expect(
        () => parseArb('tr', '{"save": ', name: 'app_tr.arb'),
        throwsA(
          isA<L10nException>().having(
            (e) => e.message,
            'message',
            contains('app_tr.arb is not valid JSON'),
          ),
        ),
      );
      expect(
        () => parseArb('tr', '["Kaydet"]', name: 'app_tr.arb'),
        throwsA(
          isA<L10nException>().having(
            (e) => e.message,
            'message',
            contains('app_tr.arb must hold a JSON object'),
          ),
        ),
      );
    });

    test('stops on a message that is not a string', () {
      expect(
        () => parseArb('tr', '{"save": 3}', name: 'app_tr.arb'),
        throwsA(
          isA<L10nException>().having(
            (e) => e.message,
            'message',
            contains('the message save is 3, not a string'),
          ),
        ),
      );
    });
  });

  group('renderReviewTable', () {
    test('one row per English message, with every language and the '
        'description', () {
      final table = renderReviewTable(parsed(sampleArbs())).split('\n');
      expect(table, [
        '3 messages in `app_en.arb`; translated: Turkish 2, Arabic 3, fa 1.',
        '',
        '| Key | English | Turkish | Arabic | fa | Context |',
        '|---|---|---|---|---|---|',
        '| `save` | Save | Kaydet | حفظ | ذخیره | Mode bar: the Save button. |',
        [
          '| `pages` | {count, plural, =1{1 page} other{{count} pages}} | — ',
          '| {count, plural, =1{صفحة واحدة} other{{count} صفحات}} | — ',
          '| Status bar: the page count. |',
        ].join(),
        '| `open` | Open | Aç | فتح | — | Start screen: opens a file. |',
        '',
      ]);
    });

    test('names the languages it knows and heads the others by code', () {
      expect(languageNames, {'en': 'English', 'tr': 'Turkish', 'ar': 'Arabic'});
    });

    test('English alone gives a table without translations', () {
      final table = renderReviewTable(parsed({'en': sampleArbs()['en']!}));
      expect(table, startsWith('3 messages in `app_en.arb`.\n'));
      expect(table, contains('| Key | English | Context |\n|---|---|---|\n'));
    });

    test('an English message without a description gets an empty context', () {
      final table = renderReviewTable(
        parsed({
          'en': {'save': 'Save'},
        }),
      );
      expect(table, contains('| `save` | Save |  |'));
    });

    test('a message only in a translation is left out', () {
      final arbs = sampleArbs();
      arbs['tr']!['extra'] = 'Fazla';
      expect(renderReviewTable(parsed(arbs)), isNot(contains('extra')));
    });

    test('needs English first', () {
      expect(() => renderReviewTable(const []), throwsA(isA<L10nException>()));
      expect(
        () => renderReviewTable([ArbFile('tr', const {}, const {})]),
        throwsA(isA<L10nException>()),
      );
    });
  });

  group('markdownCell', () {
    test('escapes what Markdown would read as syntax', () {
      expect(markdownCell('a|b'), r'a\|b');
      expect(markdownCell('*bold* _it_ `code`'), r'\*bold\* \_it\_ \`code\`');
      expect(markdownCell('[link](x) ~~gone~~'), r'\[link\](x) \~\~gone\~\~');
      expect(markdownCell(r'$x$ and \n'), r'\$x\$ and \\n');
      expect(
        markdownCell('<b>Fill & Sign</b>'),
        '&lt;b&gt;Fill &amp; Sign&lt;/b&gt;',
      );
    });

    test('turns line breaks into <br>', () {
      expect(
        markdownCell('one\ntwo\r\nthree\rfour'),
        'one<br>two<br>three<br>four',
      );
    });

    test('keeps letters, digits, braces and other scripts', () {
      const text = 'İMZALA {count} • ٤٠٪ — 10,5 pt 😀';
      expect(markdownCell(text), text);
    });
  });

  group('replaceReviewRegion', () {
    test('replaces only the region and keeps the text around it', () {
      const table = '1 messages.\n\n| Key |\n|---|\n';
      final doc = replaceReviewRegion(emptyReviewDoc, table);
      expect(
        doc,
        '# Review\n\nWritten by hand.\n\n'
        '$reviewBeginMarker\n\n$table\n$reviewEndMarker\n\nAfter the table.\n',
      );
      expect(replaceReviewRegion(doc, table), doc, reason: 'idempotent');
    });

    test('needs both markers, once each, in order', () {
      Matcher fails(String text) => throwsA(
        isA<L10nException>().having(
          (e) => e.message,
          'message',
          contains(text),
        ),
      );
      expect(
        () => replaceReviewRegion('# Review\n$reviewEndMarker\n', ''),
        fails('needs the markers'),
      );
      expect(
        () => replaceReviewRegion('# Review\n$reviewBeginMarker\n', ''),
        fails('needs the markers'),
      );
      expect(
        () => replaceReviewRegion(
          '$reviewBeginMarker\n$reviewEndMarker\n$reviewBeginMarker\n',
          '',
        ),
        fails('more than once'),
      );
      expect(
        () => replaceReviewRegion(
          '$reviewBeginMarker\n$reviewEndMarker\n$reviewEndMarker\n',
          '',
        ),
        fails('more than once'),
      );
      expect(
        () => replaceReviewRegion('$reviewEndMarker\n$reviewBeginMarker\n', ''),
        fails('before'),
      );
    });
  });

  group('the repository', () {
    test('the committed $reviewDocPath is current', () {
      // Line endings are compared as the command compares them.
      final committed = File(p.joinAll([repoRoot, ...reviewDocPath.split('/')]))
          .readAsStringSync()
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
      expect(
        generateReviewDoc(repoRoot) == committed,
        isTrue,
        reason: '$reviewDocPath is stale; run $reviewTableCommand',
      );
    });

    test('every message of app_en.arb has a row', () {
      final english = loadArbFiles(repoRoot).first;
      final committed = File(p.joinAll([repoRoot, ...reviewDocPath.split('/')]))
          .readAsStringSync();
      for (final key in english.messages.keys) {
        expect(committed, contains('| `$key` |'));
      }
    });

    test('reads where app/l10n.yaml keeps the ARB files', () {
      final config = File(p.join(repoRoot, 'app', 'l10n.yaml'))
          .readAsLinesSync()
          .where((line) => line.contains(':'))
          .map((line) => line.split(':').map((part) => part.trim()).toList())
          .fold(<String, String>{}, (map, kv) => map..[kv[0]] = kv[1]);
      expect('app/${config['arb-dir']}', arbDirectory);
      expect(config['template-arb-file'], templateArbFile);
    });
  });

  group('runReviewTableCli', () {
    late Directory root;
    late StringBuffer out;
    late StringBuffer err;

    setUp(() {
      root = reviewRoot(arbs: sampleArbs());
      out = StringBuffer();
      err = StringBuffer();
    });

    tearDown(() => root.deleteSync(recursive: true));

    Future<int> run(List<String> arguments) =>
        runReviewTableCli(arguments, out: out, err: err);

    File doc() => File(p.joinAll([root.path, ...reviewDocPath.split('/')]));
    File arb(String locale) => File(
      p.joinAll([root.path, ...arbDirectory.split('/'), 'app_$locale.arb']),
    );

    test('--check fails while the table is not rendered yet', () async {
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(err.toString(), contains('$reviewDocPath is stale'));
      expect(doc().readAsStringSync(), emptyReviewDoc);
    });

    test('renders the table, then --check passes', () async {
      expect(await run(['--root', root.path]), 0);
      expect(out.toString(), contains('Wrote $reviewDocPath'));
      final text = doc().readAsStringSync();
      expect(text, startsWith('# Review\n\nWritten by hand.\n\n'));
      expect(text, endsWith('$reviewEndMarker\n\nAfter the table.\n'));
      expect(text, contains('| `open` | Open | Aç | فتح | — |'));
      expect(await run(['--root', root.path, '--check']), 0);
      expect(out.toString(), contains('is up to date'));
    });

    test('a second run writes nothing', () async {
      expect(await run(['--root', root.path]), 0);
      final modified = doc().lastModifiedSync();
      expect(await run(['--root', root.path]), 0);
      expect(out.toString(), contains('is up to date'));
      expect(doc().lastModifiedSync(), modified);
    });

    test('--check fails when a translation changes, and leaves the doc '
        'alone', () async {
      expect(await run(['--root', root.path]), 0);
      final rendered = doc().readAsStringSync();
      arb('tr').writeAsStringSync(
        arb('tr').readAsStringSync().replaceFirst('Kaydet', 'Kaydet!'),
      );
      expect(await run(['--root', root.path, '--check']), exitStale);
      expect(err.toString(), contains(reviewTableCommand));
      expect(doc().readAsStringSync(), rendered);
      expect(await run(['--root', root.path]), 0);
      expect(doc().readAsStringSync(), contains('| Kaydet! |'));
    });

    test('a Windows checkout with CRLF line endings is current', () async {
      expect(await run(['--root', root.path]), 0);
      doc().writeAsStringSync(
        doc().readAsStringSync().replaceAll('\n', '\r\n'),
      );
      expect(await run(['--root', root.path, '--check']), 0);
    });

    test('finds the root from a working directory inside it', () async {
      final code = await runReviewTableCli(
        const ['--check'],
        out: out,
        err: err,
        workingDirectory: p.join(root.path, 'tools', 'l10n'),
      );
      expect(code, exitStale, reason: 'nothing rendered yet in the copy');
      expect(findRepoRoot(p.join(root.path, 'docs')), root.path);
    });

    test('reports a missing document or broken ARB file with exit code '
        '$exitError', () async {
      doc().deleteSync();
      expect(await run(['--root', root.path]), exitError);
      expect(err.toString(), contains('$reviewDocPath is missing'));
      doc().writeAsStringSync(emptyReviewDoc);
      arb('ar').writeAsStringSync('{"save": ["حفظ"]}');
      expect(await run(['--root', root.path]), exitError);
      expect(err.toString(), contains('app_ar.arb: the message save'));
      arb('ar')
          .writeAsBytesSync([...'{"save": "A'.codeUnits, 0xe7, 0x22, 0x7d]);
      expect(await run(['--root', root.path]), exitError);
      expect(err.toString(), contains('app_ar.arb cannot be read as UTF-8'));
      expect(doc().readAsStringSync(), emptyReviewDoc);
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
        contains('dart run l10n:review_table [--root <dir>] [--check]'),
      );
      expect(
        reviewTableCommand,
        '(cd tools/l10n && dart run l10n:review_table)',
      );
    });
  });
}
