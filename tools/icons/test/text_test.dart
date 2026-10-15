import 'dart:io';

import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('normalizeNewlines turns CRLF and lone CR into LF', () {
    expect(normalizeNewlines('a\r\nb\rc\nd'), 'a\nb\nc\nd');
    expect(normalizeNewlines('no breaks'), 'no breaks');
    expect(normalizeNewlines('\r\n\r\n'), '\n\n');
  });

  test('readText reads a CRLF file as LF', () {
    final dir = Directory.systemTemp.createTempSync('icons_text_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'crlf.txt'))
      ..writeAsStringSync('one\r\ntwo\r\n');
    expect(readText(file), 'one\ntwo\n');
  });
}
