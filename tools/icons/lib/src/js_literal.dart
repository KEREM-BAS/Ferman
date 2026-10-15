/// Reads string-to-string object literals out of JavaScript source.
///
/// The design keeps its icon geometry in two such literals (`ICON_PATHS` in
/// the bundle and `ADD` in `fm-icons.js`). This reader understands exactly
/// what they need: quoted or bare keys, single- or double-quoted string
/// values with the standard escapes, commas, comments and whitespace.
/// Anything else is an error, so a changed export cannot be misread.
library;

import 'package:icons/src/errors.dart';

/// Returns the entries of the object literal that starts right after
/// [marker] in [source], in source order.
///
/// [marker] must occur exactly once and end with the literal's opening `{`.
/// [sourceName] names the file in error messages.
Map<String, String> readStringMap(
  String source,
  String marker, {
  required String sourceName,
}) {
  if (!marker.endsWith('{')) {
    throw ArgumentError.value(marker, 'marker', 'must end with "{"');
  }
  final start = source.indexOf(marker);
  if (start < 0) {
    throw IconsException('$sourceName: cannot find "$marker".');
  }
  if (source.indexOf(marker, start + 1) >= 0) {
    throw IconsException('$sourceName: "$marker" occurs more than once.');
  }
  return _Reader(source, start + marker.length, sourceName).readEntries();
}

class _Reader {
  new(this._source, this._pos, this._sourceName);

  final String _source;
  final String _sourceName;
  int _pos;

  Map<String, String> readEntries() {
    final entries = <String, String>{};
    while (true) {
      _skipBlank();
      if (_peek() == '}') return entries;
      final keyAt = _pos;
      final key = _readKey();
      _skipBlank();
      _expect(':');
      _skipBlank();
      final value = _readString();
      if (entries.containsKey(key)) {
        _fail('duplicate key "$key"', at: keyAt);
      }
      entries[key] = value;
      _skipBlank();
      final next = _peek();
      if (next == ',') {
        _pos++;
      } else if (next != '}') {
        _fail('expected "," or "}" after the value of "$key"');
      }
    }
  }

  String _readKey() {
    final c = _peek();
    if (c == '"' || c == "'") return _readString();
    final match = RegExp(r'[A-Za-z_$][\w$]*').matchAsPrefix(_source, _pos);
    if (match == null) _fail('expected a key');
    _pos = match.end;
    return match.group(0)!;
  }

  String _readString() {
    final quote = _peek();
    if (quote != '"' && quote != "'") _fail('expected a quoted string');
    final opening = _pos;
    _pos++;
    final out = StringBuffer();
    while (true) {
      if (_pos >= _source.length) {
        _fail('unterminated string', at: opening);
      }
      final c = _source[_pos];
      if (c == quote) {
        _pos++;
        return out.toString();
      }
      if (c == '\n' || c == '\r') {
        _fail('line break inside a string', at: opening);
      }
      if (c == r'\') {
        _readEscape(out);
      } else {
        out.write(c);
        _pos++;
      }
    }
  }

  void _readEscape(StringBuffer out) {
    final escapeAt = _pos;
    _pos++;
    if (_pos >= _source.length) _fail('unterminated escape', at: escapeAt);
    final c = _source[_pos];
    _pos++;
    switch (c) {
      case 'n':
        out.write('\n');
      case 'r':
        out.write('\r');
      case 't':
        out.write('\t');
      case 'b':
        out.write('\b');
      case 'f':
        out.write('\f');
      case 'v':
        out.write('\v');
      case '0' when !_isDigit(_peekOrEmpty()):
        out.write('\x00');
      case 'x':
        out.writeCharCode(_readHex(2, escapeAt));
      case 'u':
        if (_peekOrEmpty() == '{') {
          _pos++;
          final close = _source.indexOf('}', _pos);
          if (close < 0) _fail(r'unterminated \u{...} escape', at: escapeAt);
          final digits = _source.substring(_pos, close);
          final code = int.tryParse(digits, radix: 16);
          if (code == null || code > 0x10FFFF) {
            _fail(r'bad \u{...} escape', at: escapeAt);
          }
          _pos = close + 1;
          out.writeCharCode(code);
        } else {
          out.writeCharCode(_readHex(4, escapeAt));
        }
      case '\r':
        if (_peekOrEmpty() == '\n') _pos++;
      case '\n':
        break; // A line continuation adds nothing.
      default:
        if (_isDigit(c)) _fail('octal escapes are not supported', at: escapeAt);
        out.write(c); // \" \' \\ and identity escapes.
    }
  }

  int _readHex(int length, int escapeAt) {
    final end = _pos + length;
    final digits = end <= _source.length ? _source.substring(_pos, end) : '';
    final code = RegExp(r'^[0-9A-Fa-f]+$').hasMatch(digits)
        ? int.parse(digits, radix: 16)
        : null;
    if (code == null || digits.length != length) {
      _fail('bad hexadecimal escape', at: escapeAt);
    }
    _pos = end;
    return code;
  }

  void _skipBlank() {
    while (_pos < _source.length) {
      final c = _source[_pos];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        _pos++;
      } else if (_source.startsWith('//', _pos)) {
        final end = _source.indexOf('\n', _pos);
        _pos = end < 0 ? _source.length : end + 1;
      } else if (_source.startsWith('/*', _pos)) {
        final end = _source.indexOf('*/', _pos + 2);
        if (end < 0) _fail('unterminated comment');
        _pos = end + 2;
      } else {
        return;
      }
    }
  }

  void _expect(String c) {
    if (_peek() != c) _fail('expected "$c"');
    _pos++;
  }

  String _peek() {
    if (_pos >= _source.length) _fail('unexpected end of file');
    return _source[_pos];
  }

  String _peekOrEmpty() => _pos < _source.length ? _source[_pos] : '';

  static bool _isDigit(String c) =>
      c.isNotEmpty && c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

  Never _fail(String message, {int? at}) {
    final offset = at ?? _pos;
    final line = '\n'.allMatches(_source.substring(0, offset)).length + 1;
    throw IconsException('$_sourceName:$line: $message.');
  }
}
