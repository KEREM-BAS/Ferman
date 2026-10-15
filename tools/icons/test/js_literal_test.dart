import 'package:icons/icons.dart';
import 'package:test/test.dart';

void main() {
  Map<String, String> read(String source) =>
      readStringMap(source, 'X = {', sourceName: 'test.js');

  test('reads double- and single-quoted entries in source order', () {
    expect(
      read(r'''
X = {
  "b": "<path d=\"M1 2\" />",
  'a': '<circle r="2"/>',
  bare: "x"
};'''),
      {'b': '<path d="M1 2" />', 'a': '<circle r="2"/>', 'bare': 'x'},
    );
  });

  test('reads CRLF sources like LF sources', () {
    const lf =
        'X = {\n  // icons\n  "a": "<path d=\\"M1 2\\"/>",\n  b: \'x\'\n};\n';
    final crlf = lf.replaceAll('\n', '\r\n');
    expect(crlf, contains('\r\n'));
    expect(read(crlf), read(lf));
    expect(read(crlf), {'a': '<path d="M1 2"/>', 'b': 'x'});
  });

  test('accepts a trailing comma, comments and empty maps', () {
    expect(read('X = { // none\n};'), isEmpty);
    expect(read('X = { "a": "1", /* c */ "b": "2", };'), {'a': '1', 'b': '2'});
  });

  test('decodes escapes', () {
    expect(read(r'''X = { "a": "A\x42\u{43}\n\t\\\'\"" };'''), {
      'a': 'ABC\n\t\\\'"',
    });
  });

  test('rejects what the icon sources never contain', () {
    expect(() => read('X = { "a": 1 };'), throwsA(isA<IconsException>()));
    expect(
      () => read('X = { "a": "1" "b": "2" };'),
      throwsA(isA<IconsException>()),
    );
    expect(
      () => read('X = { "a": "1", "a": "2" };'),
      throwsA(isA<IconsException>()),
    );
    expect(
      () => read('X = { "a": "unterminated };'),
      throwsA(isA<IconsException>()),
    );
    expect(() => read(r'X = { "a": "\101" };'), throwsA(isA<IconsException>()));
  });

  test('needs the marker exactly once', () {
    expect(
      () => readStringMap('Y = {}', 'X = {', sourceName: 't'),
      throwsA(isA<IconsException>()),
    );
    expect(
      () => readStringMap('X = {} X = {}', 'X = {', sourceName: 't'),
      throwsA(isA<IconsException>()),
    );
  });

  test('names the line of an error', () {
    expect(
      () => read('X = {\n "a": "1",\n "b": 2 };'),
      throwsA(
        isA<IconsException>().having(
          (e) => e.message,
          'message',
          contains(':3:'),
        ),
      ),
    );
  });
}
