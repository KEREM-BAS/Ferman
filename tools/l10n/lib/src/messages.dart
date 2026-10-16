/// Reads the messages of the gen-l10n localizations class: its abstract
/// `String` getters and methods, with their exact parameter lists.
library;

import 'package:l10n/src/errors.dart';
import 'package:l10n/src/masked_source.dart';

/// How a method parameter is passed.
enum ParameterKind {
  /// A required positional parameter: `String count`.
  positional,

  /// An optional positional parameter, inside `[…]`.
  optionalPositional,

  /// A named parameter, inside `{…}`, required or not.
  named,
}

/// One parameter of a message method.
final class Parameter {
  /// A parameter called [name], declared as [source].
  const new({required this.name, required this.kind, required this.source});

  /// The parameter's name.
  final String name;

  /// How it is passed.
  final ParameterKind kind;

  /// Its declaration as written, trimmed: type, name, `required` and any
  /// default value (`int count`, `required String name`, `int n = 1`).
  final String source;

  /// The argument that passes this parameter on: `count` or `name: name`.
  String get argument => kind == ParameterKind.named ? '$name: $name' : name;

  @override
  String toString() => source;
}

/// One message of the localizations class: an abstract getter
/// (`String get shellHome;`) or method (`String shellPageOf(String page,
/// String count);`) that returns `String`.
final class Message {
  /// A getter when [parameters] is null, otherwise a method.
  const new({required this.name, required this.line, this.parameters});

  /// The member's name.
  final String name;

  /// The 1-based line of its declaration in the source.
  final int line;

  /// The method's parameters in order, or null for a getter.
  final List<Parameter>? parameters;

  /// Whether the message is a getter.
  bool get isGetter => parameters == null;

  /// The parameter list as declared, without its parentheses:
  /// `String a, [int b = 1]` or `String a, {required int b}`.
  String get parameterList {
    final all = parameters ?? const <Parameter>[];
    final required = [
      for (final p in all)
        if (p.kind == ParameterKind.positional) p.source,
    ];
    final optional = [
      for (final p in all)
        if (p.kind != ParameterKind.positional) p.source,
    ];
    if (optional.isEmpty) return required.join(', ');
    final named = all.any((p) => p.kind == ParameterKind.named);
    final section = named
        ? '{${optional.join(', ')}}'
        : '[${optional.join(', ')}]';
    return [...required, section].join(', ');
  }

  /// The arguments that pass every parameter on, in order: `a, b, c: c`.
  String get argumentList =>
      (parameters ?? const <Parameter>[]).map((p) => p.argument).join(', ');

  /// The declaration without its semicolon: `String get shellHome` or
  /// `String shellPageOf(String page, String count)`.
  String get signature =>
      isGetter ? 'String get $name' : 'String $name($parameterList)';

  @override
  String toString() => signature;
}

/// The messages of the abstract class [className] in [source] (the
/// gen-l10n output file), in source order.
///
/// Skipped: the constructor, static members (`of`, `delegate`,
/// `localizationsDelegates`, `supportedLocales`) and fields (`final String
/// localeName`). Everything else must be an abstract getter or method that
/// returns `String`; any other member (a concrete one, a setter, an
/// operator, another return type, a generic method, an old-style function
/// parameter) throws an [L10nException] naming it, because the generator
/// could not wrap it faithfully.
List<Message> parseMessages(String source, {required String className}) {
  final masked = MaskedSource.parse(source);
  final mask = masked.mask;
  final header = RegExp(
    r'\babstract\s+class\s+' + RegExp.escape(className) + r'\b',
  ).firstMatch(mask);
  if (header == null) {
    throw L10nException('no abstract class $className in the source');
  }
  final open = mask.indexOf('{', header.end);
  if (open == -1) throw L10nException('class $className has no body');
  final close = matchingBracket(mask, open, what: 'class $className');

  final messages = <Message>[];
  final names = <String, int>{};
  for (final (start, end) in _members(mask, open + 1, close)) {
    final line = masked.lineOf(start);
    final message = _classify(
      masked.code.substring(start, end),
      mask.substring(start, end),
      className: className,
      line: line,
    );
    if (message == null) continue;
    final previous = names[message.name];
    if (previous != null) {
      throw L10nException(
        'line $line: ${message.name} is declared twice (first at line '
        '$previous)',
      );
    }
    names[message.name] = line;
    messages.add(message);
  }
  return messages;
}

/// The trimmed ranges of the member declarations between [start] and
/// [end]: each ends at a `;` or at the `}` of a block body, outside
/// brackets.
Iterable<(int, int)> _members(String mask, int start, int end) sync* {
  var depth = 0;
  var from = start;
  for (var i = start; i < end; i++) {
    final c = mask[i];
    var ends = false;
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth < 0) throw L10nException('unbalanced brackets in the class');
      // A block body ends the member; a literal before `;`, `,`, `)` or a
      // member access does not.
      ends =
          depth == 0 &&
          c == '}' &&
          !const {';', ',', ')', '.', '?'}.contains(_nextVisible(mask, i, end));
    } else if (c == ';' && depth == 0) {
      ends = true;
    }
    if (ends) {
      final range = _trim(mask, from, i + 1);
      if (range != null) yield range;
      from = i + 1;
    }
  }
  if (_trim(mask, from, end) case (final s, _)) {
    throw L10nException('unexpected text in the class at offset $s');
  }
}

/// The first non-space character after [i] and before [end], or `''`.
String _nextVisible(String mask, int i, int end) {
  for (var j = i + 1; j < end; j++) {
    if (mask[j].trim().isNotEmpty) return mask[j];
  }
  return '';
}

(int, int)? _trim(String mask, int start, int end) {
  var s = start;
  var e = end;
  while (s < e && mask[s].trim().isEmpty) {
    s++;
  }
  while (e > s && mask[e - 1].trim().isEmpty) {
    e--;
  }
  return s == e ? null : (s, e);
}

final RegExp _leadingWord = RegExp(r'^[A-Za-z_$][\w$]*');
final RegExp _getter = RegExp(
  r'^(.*\S)\s+get\s+([A-Za-z_$][\w$]*)$',
  dotAll: true,
);
final RegExp _methodHead = RegExp(
  r'^(.*\S)\s+([A-Za-z_$][\w$]*)(\s*<.*>)?$',
  dotAll: true,
);
final RegExp _trailingName = RegExp(r'([A-Za-z_$][\w$]*)$');
final RegExp _whitespace = RegExp(r'\s+');

const Set<String> _skippedKeywords = {
  'static',
  'factory',
  'final',
  'late',
  'var',
  'const',
  'covariant',
};

/// The message declared by [text] (with its [mask]), or null for a member
/// that is not a message.
Message? _classify(
  String text,
  String mask, {
  required String className,
  required int line,
}) {
  final skip = _annotationsEnd(mask, line);
  final code = text.substring(skip);
  final structure = mask.substring(skip);
  final word = _leadingWord.firstMatch(structure)?.group(0);
  if (_skippedKeywords.contains(word)) return null;
  final shortened = code.length > 60 ? '${code.substring(0, 57)}…' : code;
  final what = 'line $line: "${shortened.replaceAll(_whitespace, ' ')}"';
  if (word == className &&
      RegExp(r'^\s*[(.]').hasMatch(structure.substring(word!.length))) {
    return null; // The constructor.
  }
  if (word == 'external') throw L10nException('$what: external member');
  if (structure.endsWith('}') || _atDepthZero(structure, '=>') != -1) {
    throw L10nException(
      '$what: concrete member; only abstract members can be wrapped',
    );
  }
  if (!structure.endsWith(';')) {
    throw L10nException('$what: unsupported member');
  }
  final body = code.substring(0, code.length - 1).trimRight();
  final bodyMask = structure.substring(0, body.length);
  if (_assignment(bodyMask) != -1) {
    throw L10nException('$what: field with an initializer');
  }
  final paren = _atDepthZero(bodyMask, '(');
  final headWords = (paren == -1 ? bodyMask : bodyMask.substring(0, paren))
      .trim()
      .split(_whitespace);
  if (headWords.contains('operator') ||
      (headWords.length >= 2 && headWords[headWords.length - 2] == 'set')) {
    throw L10nException('$what: setters and operators are not supported');
  }
  if (paren == -1) {
    final getter = _getter.firstMatch(body);
    if (getter == null) throw L10nException('$what: unsupported member');
    final name = getter.group(2)!;
    _expectString(getter.group(1)!, name, line);
    return Message(name: name, line: line);
  }

  final closeParen = matchingBracket(bodyMask, paren, what: what);
  if (closeParen != bodyMask.length - 1) {
    throw L10nException('$what: unsupported member');
  }
  final head = _methodHead.firstMatch(body.substring(0, paren).trimRight());
  if (head == null) {
    throw L10nException('$what: a method without a return type');
  }
  final name = head.group(2)!;
  if (head.group(3) != null) {
    throw L10nException('$what: generic methods are not supported');
  }
  _expectString(head.group(1)!, name, line);
  return Message(
    name: name,
    line: line,
    parameters: parseParameters(
      body.substring(paren + 1, closeParen),
      bodyMask.substring(paren + 1, closeParen),
      what: what,
    ),
  );
}

/// The offset just after the annotations (`@override`, `@Deprecated('…')`)
/// that start [mask].
int _annotationsEnd(String mask, int line) {
  var i = 0;
  while (i < mask.length && mask[i] == '@') {
    i++;
    while (i < mask.length && RegExp(r'[\w$.]').hasMatch(mask[i])) {
      i++;
    }
    while (i < mask.length && mask[i].trim().isEmpty) {
      i++;
    }
    if (i < mask.length && mask[i] == '(') {
      i = matchingBracket(mask, i, what: 'an annotation at line $line') + 1;
      while (i < mask.length && mask[i].trim().isEmpty) {
        i++;
      }
    }
  }
  return i;
}

void _expectString(String type, String name, int line) {
  final normalized = type.replaceAll(_whitespace, ' ');
  if (normalized != 'String') {
    throw L10nException(
      'line $line: $name returns $normalized, not String; only String '
      'messages can be wrapped',
    );
  }
}

/// The parameters in [text] (a method's parameter list without its
/// parentheses), with [mask] its structure.
///
/// Handles required positional parameters, then either optional positional
/// ones in `[…]` or named ones in `{…}`, each with a type, `required` and a
/// default value as written. Throws an [L10nException] naming [what] for
/// anything else (an old-style function-typed parameter, `this.`, text after
/// the optional section).
List<Parameter> parseParameters(
  String text,
  String mask, {
  String what = 'parameters',
}) {
  final optional = [
    _atDepthZero(mask, '['),
    _atDepthZero(mask, '{'),
  ].where((i) => i != -1).toList()..sort();
  final parameters = <Parameter>[];
  final sectionStart = optional.isEmpty ? null : optional.first;
  if (sectionStart == null) {
    parameters.addAll(_split(text, mask, ParameterKind.positional, what));
    return parameters;
  }
  final sectionEnd = matchingBracket(mask, sectionStart, what: what);
  if (mask.substring(sectionEnd + 1).trim().isNotEmpty) {
    throw L10nException('$what: text after the optional parameters');
  }
  final kind = mask[sectionStart] == '['
      ? ParameterKind.optionalPositional
      : ParameterKind.named;
  final before = mask.substring(0, sectionStart).trimRight();
  if (before.isNotEmpty && !before.endsWith(',')) {
    throw L10nException('$what: a comma is missing before the optional ones');
  }
  parameters
    ..addAll(
      _split(
        text.substring(0, sectionStart),
        mask.substring(0, sectionStart),
        ParameterKind.positional,
        what,
      ),
    )
    ..addAll(
      _split(
        text.substring(sectionStart + 1, sectionEnd),
        mask.substring(sectionStart + 1, sectionEnd),
        kind,
        what,
      ),
    );
  return parameters;
}

/// The parameters of one section, split at its top-level commas.
List<Parameter> _split(
  String text,
  String mask,
  ParameterKind kind,
  String what,
) {
  final pieces = <(int, int)>[];
  var depth = 0;
  var from = 0;
  for (var i = 0; i < mask.length; i++) {
    final c = mask[i];
    if ('([{<'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c) ||
        (c == '>' && (i == 0 || mask[i - 1] != '='))) {
      depth--;
      if (depth < 0) throw L10nException('$what: unbalanced brackets');
    } else if (c == ',' && depth == 0) {
      pieces.add((from, i));
      from = i + 1;
    }
  }
  if (depth != 0) throw L10nException('$what: unbalanced brackets');
  pieces.add((from, mask.length));

  final parameters = <Parameter>[];
  for (final (index, (start, end)) in pieces.indexed) {
    final source = text.substring(start, end).trim();
    if (source.isEmpty) {
      // Only a trailing comma leaves an empty piece, and only at the end.
      if (index == pieces.length - 1 && index > 0) continue;
      if (pieces.length == 1) continue; // No parameters at all.
      throw L10nException('$what: an empty parameter');
    }
    final structure = mask.substring(start, end).trim();
    final equals = _assignment(structure);
    final declaration = (equals == -1 ? source : source.substring(0, equals))
        .trimRight();
    if (RegExp(r'\b(this|super)\s*\.').hasMatch(declaration)) {
      throw L10nException('$what: "$source": this. and super. parameters');
    }
    final name = _trailingName.firstMatch(declaration)?.group(1);
    if (name == null) {
      throw L10nException('$what: unsupported parameter "$source"');
    }
    parameters.add(Parameter(name: name, kind: kind, source: source));
  }
  return parameters;
}

/// The offset of the first [token] in [mask] outside brackets, or -1.
int _atDepthZero(String mask, String token) {
  var depth = 0;
  for (var i = 0; i < mask.length; i++) {
    if (depth == 0 && mask.startsWith(token, i)) return i;
    final c = mask[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    }
  }
  return -1;
}

/// The offset of the first assignment `=` in [mask] outside brackets (not
/// part of `==`, `!=`, `<=`, `>=` or `=>`), or -1.
int _assignment(String mask) {
  var depth = 0;
  for (var i = 0; i < mask.length; i++) {
    final c = mask[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (c == '=' && depth == 0) {
      final before = i > 0 ? mask[i - 1] : '';
      final after = i + 1 < mask.length ? mask[i + 1] : '';
      final compound = before.isNotEmpty && '=!<>'.contains(before);
      if (!compound && after != '=' && after != '>') return i;
    }
  }
  return -1;
}
