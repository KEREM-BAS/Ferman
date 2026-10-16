import 'package:l10n/l10n.dart';
import 'package:test/test.dart';

void main() {
  group('MaskedSource', () {
    test('keeps every view the length of the source', () {
      const source = "a /* x */ b // y\n'c' \"d\" r'e'";
      final masked = MaskedSource.parse(source);
      expect(masked.code.length, source.length);
      expect(masked.mask.length, source.length);
    });

    test('blanks line, doc and nested block comments in code and mask', () {
      final masked = MaskedSource.parse(
        'a; // String get x;\n/// String get y;\n/* 1 /* 2 */ 3; */ b;',
      );
      expect(masked.code.replaceAll(RegExp(r'\s+'), ' ').trim(), 'a; b;');
      expect(masked.mask, masked.code);
    });

    test('masks string literals and keeps them in code', () {
      final masked = MaskedSource.parse(
        "x = 'a;{'; y = \"}\"; z = r'\\'; w = '''a\n;''';",
      );
      expect(masked.code, contains("'a;{'"));
      expect(masked.mask, isNot(contains(';{')));
      expect(masked.mask, isNot(contains('}')));
      expect(';'.allMatches(masked.mask).length, 4);
      expect(masked.mask, contains('\n'), reason: 'line breaks are kept');
    });

    test('a comment marker inside a string is not a comment', () {
      final masked = MaskedSource.parse("a = '// no'; b = '/* no */';");
      expect(masked.code, "a = '// no'; b = '/* no */';");
    });

    test('masks interpolations with nested strings and braces', () {
      final masked = MaskedSource.parse(
        r"a = '${f('}')} and ${{1: 2}[1]}'; b;",
      );
      expect(masked.mask, startsWith('a = _'));
      expect(masked.mask, endsWith('; b;'));
      expect(masked.mask, isNot(contains('}')));
    });

    test('a backslash escapes the quote, but not in a raw string', () {
      expect(MaskedSource.parse(r"a = 'it\'s'; b;").mask, endsWith('; b;'));
      expect(MaskedSource.parse(r"a = r'\'; b;").mask, endsWith('; b;'));
    });

    test('an r ending an identifier is not a raw prefix', () {
      final masked = MaskedSource.parse(r"for'\''; b;");
      expect(masked.mask, startsWith('for_'));
      expect(masked.mask, endsWith('; b;'));
    });

    test('counts lines', () {
      final masked = MaskedSource.parse('a\nb\nc');
      expect(masked.lineOf(0), 1);
      expect(masked.lineOf(2), 2);
      expect(masked.lineOf(4), 3);
    });

    test('fails on an unterminated string, comment or interpolation', () {
      expect(
        () => MaskedSource.parse("a = 'b\n';"),
        throwsA(isA<L10nException>()),
      );
      expect(() => MaskedSource.parse('a /* b'), throwsA(isA<L10nException>()));
      expect(
        () => MaskedSource.parse(r"a = '${b"),
        throwsA(isA<L10nException>()),
      );
    });
  });

  group('matchingBracket', () {
    test('finds the closing bracket of the same kind', () {
      expect(matchingBracket('(a[b]{c}) d', 0, what: 'x'), 8);
      expect(matchingBracket('a {b (c)}', 2, what: 'x'), 8);
    });

    test('fails on mismatched or unclosed brackets', () {
      expect(
        () => matchingBracket('(a]', 0, what: 'x'),
        throwsA(isA<L10nException>()),
      );
      expect(
        () => matchingBracket('(a', 0, what: 'x'),
        throwsA(isA<L10nException>()),
      );
    });
  });
}
