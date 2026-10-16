/// A Dart source with its comments and string literals blanked out, so that
/// brackets, commas and semicolons can be found by position.
library;

import 'package:l10n/src/errors.dart';

/// A Dart source in three views of the same length, offset for offset.
///
/// - [source]: the text as written.
/// - [code]: the text with every comment (`//`, `///`, nested `/* */`)
///   replaced by spaces. Slices of it are what the generator copies.
/// - [mask]: [code] with every string literal, its quotes and any raw `r`
///   prefix included, replaced by `_`. Only structure is left: brackets,
///   commas, semicolons, `=` and identifiers outside strings.
///
/// Line breaks are kept in all three, so offsets map to the same lines.
final class MaskedSource {
  /// Scans [source]; throws an [L10nException] on an unterminated string or
  /// comment.
  factory parse(String source) {
    final scanner = _Scanner(source)..scanAll();
    return MaskedSource._(
      source,
      String.fromCharCodes(scanner.code),
      String.fromCharCodes(scanner.mask),
    );
  }

  new _(this.source, this.code, this.mask);

  /// The text as written.
  final String source;

  /// The text with comments blanked.
  final String code;

  /// The text with comments and string literals blanked.
  final String mask;

  /// The 1-based line of [offset].
  int lineOf(int offset) {
    var line = 1;
    for (var i = 0; i < offset && i < source.length; i++) {
      if (source.codeUnitAt(i) == _newline) line++;
    }
    return line;
  }
}

/// The offset of the bracket that closes the one at [open] in [mask]
/// (`(`, `[` or `{`), checking that the kinds pair up; throws an
/// [L10nException] naming [what] when they do not.
int matchingBracket(String mask, int open, {required String what}) {
  final stack = <int>[];
  for (var i = open; i < mask.length; i++) {
    final c = mask.codeUnitAt(i);
    final closer = _closers[c];
    if (closer != null) {
      stack.add(closer);
    } else if (_closers.containsValue(c)) {
      if (stack.isEmpty || stack.removeLast() != c) {
        throw L10nException('unbalanced brackets in $what');
      }
      if (stack.isEmpty) return i;
    }
  }
  throw L10nException('unclosed bracket in $what');
}

const int _newline = 0x0A;
const int _space = 0x20;
const int _underscore = 0x5F;

const Map<int, int> _closers = {
  0x28: 0x29, // ( )
  0x5B: 0x5D, // [ ]
  0x7B: 0x7D, // { }
};

final class _Scanner {
  new(this.source)
    : code = source.codeUnits.toList(),
      mask = source.codeUnits.toList();

  final String source;
  final List<int> code;
  final List<int> mask;

  int get _length => source.length;

  void scanAll() => _scanCode(0, untilBrace: false);

  /// Scans code from [start]; with [untilBrace], stops at the `}` that ends
  /// a string interpolation and returns its offset.
  int _scanCode(int start, {required bool untilBrace}) {
    var depth = 0;
    var i = start;
    while (i < _length) {
      final c = source.codeUnitAt(i);
      if (source.startsWith('//', i)) {
        final end = source.indexOf('\n', i);
        i = _blankComment(i, end == -1 ? _length : end);
      } else if (source.startsWith('/*', i)) {
        i = _blankComment(i, _blockCommentEnd(i));
      } else if (c == 0x27 || c == 0x22) {
        final raw = _isRawPrefix(i - 1);
        final end = _stringEnd(i, raw: raw);
        _fill(mask, raw ? i - 1 : i, end, _underscore);
        i = end;
      } else {
        if (untilBrace) {
          if (c == 0x7B) {
            depth++;
          } else if (c == 0x7D) {
            if (depth == 0) return i;
            depth--;
          }
        }
        i++;
      }
    }
    if (untilBrace) {
      throw L10nException(
        'unterminated string interpolation at line ${_line(start)}',
      );
    }
    return _length;
  }

  /// Whether the character at [i] is the `r` of a raw string literal.
  bool _isRawPrefix(int i) {
    if (i < 0 || source.codeUnitAt(i) != 0x72) return false;
    return i == 0 || !_isIdentifierPart(source.codeUnitAt(i - 1));
  }

  /// The offset just after the string literal whose opening quote is at
  /// [start].
  int _stringEnd(int start, {required bool raw}) {
    final quote = source[start];
    final triple = source.startsWith(quote * 3, start);
    final delimiter = triple ? quote * 3 : quote;
    var i = start + delimiter.length;
    while (i < _length) {
      final c = source.codeUnitAt(i);
      if (!raw && c == 0x5C) {
        i += 2;
      } else if (source.startsWith(delimiter, i)) {
        return i + delimiter.length;
      } else if (!triple && c == _newline) {
        break;
      } else if (!raw && source.startsWith(r'${', i)) {
        i = _scanCode(i + 2, untilBrace: true) + 1;
      } else {
        i++;
      }
    }
    throw L10nException('unterminated string at line ${_line(start)}');
  }

  int _blockCommentEnd(int start) {
    var depth = 0;
    var i = start;
    while (i < _length) {
      if (source.startsWith('/*', i)) {
        depth++;
        i += 2;
      } else if (source.startsWith('*/', i)) {
        depth--;
        i += 2;
        if (depth == 0) return i;
      } else {
        i++;
      }
    }
    throw L10nException('unterminated comment at line ${_line(start)}');
  }

  int _blankComment(int start, int end) {
    _fill(code, start, end, _space);
    _fill(mask, start, end, _space);
    return end;
  }

  void _fill(List<int> target, int start, int end, int fill) {
    for (var i = start; i < end; i++) {
      if (target[i] != _newline) target[i] = fill;
    }
  }

  int _line(int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;
}

/// Whether [c] can be part of a Dart identifier.
bool _isIdentifierPart(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == _underscore ||
    c == 0x24;
