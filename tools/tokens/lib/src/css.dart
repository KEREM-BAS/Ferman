/// A hand-written reader for the regular subset of CSS that holds the design
/// tokens (ADR 0012): plain rules, `@import` and other statement at-rules,
/// `@media` blocks that wrap rules, and declaration-only at-rules such as
/// `@font-face`. Custom properties keep their trailing comment, which carries
/// documentation and the design tooling's `@kind` hint.
library;

import 'package:tokens/src/errors.dart';
import 'package:tokens/src/text.dart';

/// A position in a token file, printed as `file:line`.
final class SourceLocation {
  /// Creates a location in [file] (a short label such as `colors.css`) at
  /// the 1-based [line].
  const new(this.file, this.line);

  /// The short file label.
  final String file;

  /// The 1-based line number.
  final int line;

  @override
  String toString() => '$file:$line';
}

/// One custom-property declaration, `--name: value`.
final class CssDeclaration {
  /// Creates a declaration.
  const new({
    required this.name,
    required this.value,
    required this.location,
    this.comment,
    this.kindHint,
  });

  /// The property name without the leading `--`.
  final String name;

  /// The value with comments removed and whitespace collapsed.
  final String value;

  /// Where the declaration starts.
  final SourceLocation location;

  /// The trailing comment on the same line, without the `@kind` hint, or
  /// null when there is none.
  final String? comment;

  /// The `@kind` hint from the trailing comment (`other`, `font`), if any.
  final String? kindHint;

  @override
  String toString() => '--$name: $value ($location)';
}

/// A declaration of an ordinary property such as `color-scheme: dark`. These
/// are not tokens; they are kept so callers can see what was skipped.
final class CssProperty {
  /// Creates a property declaration.
  const new(this.name, this.value, this.location);

  /// The lower-case property name.
  final String name;

  /// The value with whitespace collapsed.
  final String value;

  /// Where the declaration starts.
  final SourceLocation location;
}

/// A rule: selectors and the declarations of its block.
final class CssRule {
  /// Creates a rule.
  const new({
    required this.selectors,
    required this.atRule,
    required this.customProperties,
    required this.properties,
    required this.location,
  });

  /// The selectors, whitespace collapsed and single quotes normalised to
  /// double quotes. A declaration-only at-rule such as `@font-face` uses its
  /// header as the only selector.
  final List<String> selectors;

  /// The enclosing block at-rule header, such as
  /// `@media (prefers-reduced-motion: reduce)`, or null at top level.
  final String? atRule;

  /// The custom properties declared in the block, in source order.
  final List<CssDeclaration> customProperties;

  /// The other properties declared in the block, in source order.
  final List<CssProperty> properties;

  /// Where the rule starts.
  final SourceLocation location;
}

/// A parsed stylesheet.
final class CssStylesheet {
  /// Creates a stylesheet labelled [file].
  const new(this.file, this.rules);

  /// The short file label used in source locations.
  final String file;

  /// The rules in source order, including rules nested in at-rules.
  final List<CssRule> rules;

  /// Every custom-property declaration in source order.
  Iterable<CssDeclaration> get customProperties =>
      rules.expand((rule) => rule.customProperties);
}

/// Parses [source]. [file] labels source locations and error messages.
///
/// Throws a [TokenException] on syntax the token files do not use, such as
/// nested style blocks or unterminated comments.
CssStylesheet parseStylesheet(String source, {required String file}) =>
    _Parser(source.replaceAll('\r\n', '\n'), file).parse();

final _customPropertyName = RegExp(r'^--[A-Za-z0-9_-]+$');
final _kindHint = RegExp(r'@kind\s+([A-Za-z-]+)');

final class _RawDeclaration {
  new(this.text, this.start, this.end, this.inlineComments);

  final String text;
  final int start;
  final int end;
  final List<String> inlineComments;
}

final class _RawComment {
  new(this.text, this.offset);

  final String text;
  final int offset;
}

final class _Parser {
  new(this.text, this.file) : _lineStarts = _computeLineStarts(text);

  final String text;
  final String file;
  final List<int> _lineStarts;
  final List<CssRule> _rules = [];
  int _pos = 0;

  static List<int> _computeLineStarts(String text) {
    final starts = <int>[0];
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) starts.add(i + 1);
    }
    return starts;
  }

  CssStylesheet parse() {
    _parseRules(atRule: null, nested: false);
    return CssStylesheet(file, List.unmodifiable(_rules));
  }

  int _lineOf(int offset) {
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + 1;
  }

  SourceLocation _location(int offset) => SourceLocation(file, _lineOf(offset));

  Never _fail(String message, int offset) =>
      throw TokenException('${_location(offset)}: $message');

  bool _startsComment(int i) =>
      i + 1 < text.length && text[i] == '/' && text[i + 1] == '*';

  int _commentEnd(int start) {
    final end = text.indexOf('*/', start + 2);
    if (end < 0) _fail('unterminated comment', start);
    return end + 2;
  }

  int _stringEnd(int start) {
    final quote = text[start];
    for (var i = start + 1; i < text.length; i++) {
      final c = text[i];
      if (c == r'\') {
        i++;
      } else if (c == '\n') {
        break;
      } else if (c == quote) {
        return i + 1;
      }
    }
    _fail('unterminated string', start);
  }

  void _skipSpaceAndComments() {
    while (_pos < text.length) {
      if (_startsComment(_pos)) {
        _pos = _commentEnd(_pos);
      } else if (text[_pos].trim().isEmpty) {
        _pos++;
      } else {
        return;
      }
    }
  }

  void _parseRules({required String? atRule, required bool nested}) {
    while (true) {
      _skipSpaceAndComments();
      if (_pos >= text.length) {
        if (nested) _fail('missing "}"', text.length - 1);
        return;
      }
      final c = text[_pos];
      if (c == '}') {
        if (!nested) _fail('unexpected "}"', _pos);
        _pos++;
        return;
      }
      if (c == '@') {
        _parseAtRule(atRule);
      } else {
        _parseStyleRule(atRule);
      }
    }
  }

  /// Reads from the current position up to the first of [stops] outside
  /// strings, parentheses and comments. Returns the text read (comments
  /// removed) and the stop character, or null at the end of input. The
  /// position moves past the stop character.
  (String, String?) _readUntil(Set<String> stops) {
    final out = StringBuffer();
    var depth = 0;
    while (_pos < text.length) {
      if (_startsComment(_pos)) {
        _pos = _commentEnd(_pos);
        out.write(' ');
        continue;
      }
      final c = text[_pos];
      if (c == '"' || c == "'") {
        final end = _stringEnd(_pos);
        out.write(text.substring(_pos, end));
        _pos = end;
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth == 0 && stops.contains(c)) {
        _pos++;
        return (out.toString(), c);
      }
      out.write(c);
      _pos++;
    }
    return (out.toString(), null);
  }

  void _parseAtRule(String? enclosing) {
    final start = _pos;
    final (prelude, stop) = _readUntil(const {';', '{', '}'});
    final header = collapseWhitespace(prelude);
    final name = RegExp('^@([A-Za-z-]+)').firstMatch(header)?.group(1);
    if (name == null) _fail('malformed at-rule "$header"', start);
    if (stop == ';') return; // A statement at-rule such as @import.
    if (stop != '{') _fail('unterminated at-rule "$header"', start);
    final context = enclosing == null ? header : '$enclosing $header';
    if (name.toLowerCase() == 'media' || _blockHasNestedRules()) {
      _parseRules(atRule: context, nested: true);
    } else {
      _parseDeclarationBlock([header], enclosing, start);
    }
  }

  /// Whether the block that starts at the current position contains rules
  /// (as in `@media` or `@keyframes`) rather than declarations.
  bool _blockHasNestedRules() {
    var i = _pos;
    var depth = 0;
    while (i < text.length) {
      if (_startsComment(i)) {
        i = _commentEnd(i);
        continue;
      }
      final c = text[i];
      if (c == '"' || c == "'") {
        i = _stringEnd(i);
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth == 0 && c == '{') return true;
      if (depth == 0 && c == '}') return false;
      i++;
    }
    return false;
  }

  void _parseStyleRule(String? atRule) {
    final start = _pos;
    final (prelude, stop) = _readUntil(const {'{', '}', ';'});
    if (stop != '{') _fail('expected "{" after "${prelude.trim()}"', start);
    final selectors = [
      for (final selector in splitTopLevel(prelude, ','))
        collapseWhitespace(selector).replaceAll("'", '"'),
    ];
    if (selectors.any((selector) => selector.isEmpty)) {
      _fail('empty selector in "${prelude.trim()}"', start);
    }
    _parseDeclarationBlock(selectors, atRule, start);
  }

  void _parseDeclarationBlock(
    List<String> selectors,
    String? atRule,
    int ruleStart,
  ) {
    final declarations = <_RawDeclaration>[];
    final comments = <_RawComment>[];
    var buffer = StringBuffer();
    int? declarationStart;
    var inlineComments = <String>[];
    var depth = 0;

    while (true) {
      if (_pos >= text.length) _fail('missing "}"', ruleStart);
      if (_startsComment(_pos)) {
        final end = _commentEnd(_pos);
        final body = text.substring(_pos + 2, end - 2);
        if (declarationStart != null) {
          inlineComments.add(body);
          buffer.write(' ');
        } else {
          comments.add(_RawComment(body, _pos));
        }
        _pos = end;
        continue;
      }
      final c = text[_pos];
      if (c == '"' || c == "'") {
        declarationStart ??= _pos;
        final end = _stringEnd(_pos);
        buffer.write(text.substring(_pos, end));
        _pos = end;
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth < 0) _fail('unbalanced ")"', _pos);
      }
      if (depth == 0 && (c == ';' || c == '}')) {
        if (declarationStart != null) {
          declarations.add(
            _RawDeclaration(
              buffer.toString(),
              declarationStart,
              _pos,
              inlineComments,
            ),
          );
        }
        buffer = StringBuffer();
        declarationStart = null;
        inlineComments = <String>[];
        _pos++;
        if (c == '}') break;
        continue;
      }
      if (depth == 0 && c == '{') {
        _fail('nested blocks are not supported in token files', _pos);
      }
      if (declarationStart == null && c.trim().isNotEmpty) {
        declarationStart = _pos;
      }
      buffer.write(c);
      _pos++;
    }

    final customProperties = <CssDeclaration>[];
    final properties = <CssProperty>[];
    for (final raw in declarations) {
      final colon = raw.text.indexOf(':');
      if (colon < 0) _fail('expected "name: value"', raw.start);
      final name = raw.text.substring(0, colon).trim();
      final value = collapseWhitespace(raw.text.substring(colon + 1));
      final location = _location(raw.start);
      if (!name.startsWith('--')) {
        properties.add(CssProperty(name.toLowerCase(), value, location));
        continue;
      }
      if (!_customPropertyName.hasMatch(name)) {
        _fail('invalid custom property name "$name"', raw.start);
      }
      final endLine = _lineOf(raw.end);
      final trailing = [
        for (final comment in comments)
          if (comment.offset > raw.end && _lineOf(comment.offset) == endLine)
            comment.text,
      ];
      final (comment, kindHint) = _splitComment([
        ...raw.inlineComments,
        ...trailing,
      ]);
      customProperties.add(
        CssDeclaration(
          name: name.substring(2),
          value: value,
          location: location,
          comment: comment,
          kindHint: kindHint,
        ),
      );
    }

    _rules.add(
      CssRule(
        selectors: List.unmodifiable(selectors),
        atRule: atRule,
        customProperties: List.unmodifiable(customProperties),
        properties: List.unmodifiable(properties),
        location: _location(ruleStart),
      ),
    );
  }

  /// Joins comment texts, extracts the `@kind` hint and returns the
  /// remaining documentation (null when empty).
  (String?, String?) _splitComment(List<String> texts) {
    if (texts.isEmpty) return (null, null);
    final joined = collapseWhitespace(texts.join(' '));
    final kind = _kindHint.firstMatch(joined)?.group(1);
    final doc = collapseWhitespace(joined.replaceAll(_kindHint, ' '));
    return (doc.isEmpty ? null : doc, kind);
  }
}
