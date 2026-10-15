import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

void main() {
  group('parseStylesheet', () {
    test('reads custom properties with their location', () {
      final sheet = parseStylesheet(
        ':root {\n  --ink-600: #2A4DAF;\n  color-scheme: light;\n}\n',
        file: 'colors.css',
      );
      final rule = sheet.rules.single;
      expect(rule.selectors, [':root']);
      expect(rule.atRule, isNull);
      final declaration = rule.customProperties.single;
      expect(declaration.name, 'ink-600');
      expect(declaration.value, '#2A4DAF');
      expect(declaration.location.toString(), 'colors.css:2');
      expect(rule.properties.single.name, 'color-scheme');
    });

    test('a trailing comment documents every declaration before it on the '
        'line', () {
      final sheet = parseStylesheet(
        ':root {\n'
        '  --text-xs: 11px;   --leading-xs: 14px;    /* section labels */\n'
        '  --text-sm: 12px;\n'
        '}\n',
        file: 't.css',
      );
      final byName = {for (final d in sheet.customProperties) d.name: d};
      expect(byName['text-xs']!.comment, 'section labels');
      expect(byName['leading-xs']!.comment, 'section labels');
      expect(byName['text-sm']!.comment, isNull);
    });

    test('an own-line comment documents nothing', () {
      final sheet = parseStylesheet(
        ':root {\n  /* Ink ramp */\n  --ink-50: #EEF2FC;\n}\n',
        file: 't.css',
      );
      expect(sheet.customProperties.single.comment, isNull);
    });

    test('extracts the @kind hint and strips it from the comment', () {
      final sheet = parseStylesheet(
        ':root {\n'
        '  --dur-fast: 120ms; /* @kind other */\n'
        '  --numeric-tabular: tabular-nums; /* figures @kind font */\n'
        '}\n',
        file: 't.css',
      );
      final [duration, numeric] = sheet.customProperties.toList();
      expect(duration.kindHint, 'other');
      expect(duration.comment, isNull);
      expect(numeric.kindHint, 'font');
      expect(numeric.comment, 'figures');
    });

    test('removes comments inside a value and keeps them as documentation', () {
      final sheet = parseStylesheet(
        ':root { --gap: 4px /* tight */; }',
        file: 't.css',
      );
      final declaration = sheet.customProperties.single;
      expect(declaration.value, '4px');
      expect(declaration.comment, 'tight');
    });

    test('skips @import, even with semicolons inside the quoted URL', () {
      final sheet = parseStylesheet(
        "@import url('https://example.test/css?family=A:wght@400;500;600');\n"
        ':root { --a: 1px; }\n',
        file: 't.css',
      );
      expect(sheet.customProperties.single.name, 'a');
    });

    test('keeps semicolons and commas inside functions and strings', () {
      final sheet = parseStylesheet(
        ":root { --shadow: 0 1px 2px rgba(0, 0, 0, 0.5); --font: 'A;B', x; }",
        file: 't.css',
      );
      final values = sheet.customProperties.map((d) => d.value).toList();
      expect(values, ['0 1px 2px rgba(0, 0, 0, 0.5)', "'A;B', x"]);
    });

    test('records the @media block around nested rules', () {
      final sheet = parseStylesheet(
        '@media (prefers-reduced-motion: reduce) {\n'
        '  :root { --dur-fast: 0ms; }\n'
        '}\n',
        file: 't.css',
      );
      final rule = sheet.rules.single;
      expect(rule.atRule, '@media (prefers-reduced-motion: reduce)');
      expect(rule.selectors, [':root']);
    });

    test('parses @keyframes and @font-face without tokens', () {
      final sheet = parseStylesheet(
        '@keyframes spin { to { transform: rotate(360deg); } }\n'
        "@font-face { font-family: 'X'; src: url('x.woff2'); }\n",
        file: 't.css',
      );
      expect(sheet.customProperties, isEmpty);
      expect(sheet.rules.map((r) => r.selectors.single), ['to', '@font-face']);
      expect(sheet.rules.first.atRule, '@keyframes spin');
    });

    test('splits selector lists and normalises quotes', () {
      final sheet = parseStylesheet(
        "[lang|='ja'],\n[lang|=\"zh\"] { --a: 1px; }",
        file: 't.css',
      );
      expect(sheet.rules.single.selectors, ['[lang|="ja"]', '[lang|="zh"]']);
    });

    test('accepts CRLF line endings', () {
      final sheet = parseStylesheet(
        ':root {\r\n  --a: 1px;\r\n  --b: 2px; /* two */\r\n}\r\n',
        file: 't.css',
      );
      final [a, b] = sheet.customProperties.toList();
      expect(a.location.line, 2);
      expect(b.comment, 'two');
    });

    test('rejects nested style blocks', () {
      expect(
        () => parseStylesheet(':root { .x { --a: 1px; } }', file: 't.css'),
        throwsA(isA<TokenException>()),
      );
    });

    test('names the file and line of an unterminated comment', () {
      expect(
        () => parseStylesheet(':root {\n  /* open\n}', file: 'bad.css'),
        throwsA(
          isA<TokenException>().having(
            (e) => e.message,
            'message',
            contains('bad.css:2: unterminated comment'),
          ),
        ),
      );
    });

    test('rejects a missing closing brace', () {
      expect(
        () => parseStylesheet(':root { --a: 1px;', file: 't.css'),
        throwsA(isA<TokenException>()),
      );
    });
  });
}
