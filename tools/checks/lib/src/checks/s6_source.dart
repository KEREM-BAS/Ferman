/// Shared parts of the S6 checks (ADR 0011, ADR 0012, ADR 0014): finding
/// the app's hand-written Dart files, blanking comments and strings,
/// reading calls and their arguments, and applying the allow-list.
///
/// The checks read the source text, not a resolved syntax tree, so they
/// stay a pure-Dart script with no analyzer dependency. To keep false
/// positives low they only match code: comments and the contents of string
/// literals are blanked first (string interpolations stay code).
library;

import 'dart:io';

import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_allowlist.dart';
import 'package:checks/src/text.dart';
import 'package:path/path.dart' as p;

/// The folder the S6 checks scan, relative to the repository root.
const String s6Root = 'app/lib';

/// Folders under [s6Root] that hold generated code only: the
/// flutter_rust_bridge bindings and the gen-l10n output.
const List<String> generatedDirs = ['app/lib/bridge/', 'app/lib/l10n/gen/'];

/// File suffixes of generated Dart code (build_runner, freezed).
const List<String> generatedSuffixes = ['.g.dart', '.freezed.dart'];

/// Whether [path], `/`-separated from the root, is generated code, which
/// the S6 checks never read: `*.g.dart`, `*.freezed.dart` and everything
/// under [generatedDirs].
bool isGenerated(String path) =>
    generatedSuffixes.any(path.endsWith) || generatedDirs.any(path.startsWith);

/// One finding of an S6 check, before the allow-list is applied.
final class S6Finding {
  /// A finding of [rule] at [line] (1-based) of [path], with a [message]
  /// saying what is wrong and what to use instead.
  const new({
    required this.path,
    required this.line,
    required this.rule,
    required this.message,
    required this.source,
  });

  /// The file, `/`-separated from the repository root.
  final String path;

  /// The 1-based line number.
  final int line;

  /// The rule that matched, such as `color` or `insets`.
  final String rule;

  /// What is wrong and what to use instead.
  final String message;

  /// The trimmed source line, for the report and for
  /// [S6Allowance.contains].
  final String source;

  @override
  String toString() => '$path:$line: $message [$rule]: ${_short(source)}';

  static String _short(String text) =>
      text.length <= 100 ? text : '${text.substring(0, 97)}...';
}

/// A Dart file prepared for matching.
final class DartSource {
  /// Prepares [text], the contents of [path] (`/`-separated from the root).
  new(this.path, this.text) : code = maskDart(text) {
    _lineStarts.add(0);
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) _lineStarts.add(i + 1);
    }
  }

  /// The file, `/`-separated from the repository root.
  final String path;

  /// The file's text.
  final String text;

  /// [text] with comments and string contents replaced by spaces; same
  /// length and line breaks, so offsets and line numbers agree.
  final String code;

  final List<int> _lineStarts = [];

  /// The 1-based line of [offset].
  int lineOf(int offset) {
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + 1;
  }

  /// The trimmed text of the 1-based [line].
  String lineText(int line) {
    final start = _lineStarts[line - 1];
    final end = line < _lineStarts.length ? _lineStarts[line] - 1 : text.length;
    return text.substring(start, end).trim();
  }

  /// A finding of [rule] at [offset].
  S6Finding finding(int offset, String rule, String message) {
    final line = lineOf(offset);
    return S6Finding(
      path: path,
      line: line,
      rule: rule,
      message: message,
      source: lineText(line),
    );
  }

  /// Every call in [code] matched by [callee], a pattern for the name up to
  /// and including the opening parenthesis (for example
  /// `\bSizedBox\s*\(`), with its parsed arguments. Calls whose closing
  /// parenthesis is missing are skipped.
  Iterable<DartCall> calls(String callee) sync* {
    for (final match in RegExp(callee).allMatches(code)) {
      final open = match.end - 1;
      if (code.codeUnitAt(open) != 0x28) continue;
      final close = matchingParen(code, open);
      if (close == null) continue;
      yield DartCall(
        offset: match.start,
        name: match.group(0)!,
        groups: [for (var i = 1; i <= match.groupCount; i++) match.group(i)],
        arguments: splitArguments(code.substring(open + 1, close)),
      );
    }
  }

  /// The import and export directives of the file.
  List<DartDirective> get directives {
    final result = <DartDirective>[];
    final keyword = RegExp(r'(^|;)\s*(import|export)\b', multiLine: true);
    for (final match in keyword.allMatches(code)) {
      final start = match.end - match.group(2)!.length;
      final end = code.indexOf(';', match.end);
      if (end < 0) break;
      // Quotes stay in [code]; their contents come from [text].
      final uris = <String>[];
      for (var i = match.end; i < end; i++) {
        final quote = code[i];
        if (quote != "'" && quote != '"') continue;
        final close = code.indexOf(quote, i + 1);
        if (close < 0 || close > end) break;
        uris.add(text.substring(i + 1, close));
        i = close;
      }
      if (uris.isEmpty) continue;
      result.add(
        DartDirective(
          offset: start,
          isExport: match.group(2) == 'export',
          uris: uris,
          clauses: code.substring(match.end, end),
        ),
      );
    }
    return result;
  }
}

/// A call found by [DartSource.calls].
final class DartCall {
  /// A call at [offset] whose callee text is [name].
  const new({
    required this.offset,
    required this.name,
    required this.groups,
    required this.arguments,
  });

  /// The offset of the callee in the file.
  final int offset;

  /// The matched callee text, up to and including `(`.
  final String name;

  /// The capture groups of the callee pattern.
  final List<String?> groups;

  /// The arguments, split at top-level commas.
  final List<DartArgument> arguments;

  /// The named argument [name], or null.
  DartArgument? named(String name) {
    for (final argument in arguments) {
      if (argument.name == name) return argument;
    }
    return null;
  }

  /// The positional arguments, in order.
  List<DartArgument> get positional => [
    for (final argument in arguments)
      if (argument.name == null) argument,
  ];
}

/// One argument of a [DartCall].
final class DartArgument {
  /// An argument with an optional [name] and its [value] expression.
  const new(this.name, this.value);

  /// The argument name for a named argument, else null.
  final String? name;

  /// The value expression, trimmed.
  final String value;

  /// Whether [value] is a numeric literal.
  bool get isNumber => numberValue(value) != null;

  /// Whether [value] is a numeric literal other than zero.
  bool get isNonZeroNumber {
    final number = numberValue(value);
    return number != null && number != 0;
  }

  /// Whether [value] is the numeric literal zero.
  bool get isZero => numberValue(value) == 0;
}

/// An `import` or `export` directive.
final class DartDirective {
  /// A directive at [offset] with its [uris] (the first is the default; the
  /// others are conditional) and the code after the first URI.
  const new({
    required this.offset,
    required this.isExport,
    required this.uris,
    required this.clauses,
  });

  /// The offset of the `import` or `export` keyword.
  final int offset;

  /// Whether this is an `export`.
  final bool isExport;

  /// Every URI the directive names.
  final List<String> uris;

  /// The directive's code after the keyword: `as`, `show` and `hide`
  /// clauses, with the URIs blanked.
  final String clauses;

  /// The import prefix (`as name`), or null.
  String? get prefix => RegExp(r'\bas\s+(\w+)').firstMatch(clauses)?.group(1);

  /// The names of the `show` clauses, or null when there are none.
  Set<String>? get shown => _names('show');

  /// The names of the `hide` clauses.
  Set<String> get hidden => _names('hide') ?? const {};

  Set<String>? _names(String keyword) {
    final matches = RegExp(
      '\\b$keyword\\s+([\\w\\s,]+?)(?=\\s*(?:\\bshow\\b|\\bhide\\b|\$))',
    ).allMatches(clauses).toList();
    if (matches.isEmpty) return null;
    return {
      for (final match in matches)
        for (final name in match.group(1)!.split(','))
          if (name.trim().isNotEmpty) name.trim(),
    };
  }

  /// Whether this directive makes the identifier [name] visible without a
  /// prefix.
  bool showsUnprefixed(String name) {
    if (prefix != null) return false;
    final show = shown;
    if (show != null) return show.contains(name);
    return !hidden.contains(name);
  }
}

/// [source] with every comment and the contents of every string literal
/// replaced by spaces, keeping line breaks, quotes and the code inside
/// `${...}` interpolations. Handles nested block comments, raw strings and
/// triple-quoted strings.
String maskDart(String source) {
  final out = source.codeUnits.toList();
  final length = source.length;
  void blank(int index) {
    if (index >= length) return;
    final unit = out[index];
    if (unit != 0x0A && unit != 0x0D) out[index] = 0x20;
  }

  final interpolations = <_Interpolation>[];
  _StringState? string;
  var i = 0;
  while (i < length) {
    final char = source[i];
    final inString = string;
    if (inString != null) {
      if (!inString.raw && char == r'\') {
        blank(i);
        blank(i + 1);
        i += 2;
      } else if (source.startsWith(inString.delimiter, i)) {
        i += inString.delimiter.length;
        string = null;
      } else if (!inString.triple && char == '\n') {
        // Unterminated string: recover at the end of the line.
        string = null;
        i++;
      } else if (!inString.raw &&
          char == r'$' &&
          i + 1 < length &&
          source[i + 1] == '{') {
        blank(i);
        blank(i + 1);
        interpolations.add(_Interpolation(inString));
        string = null;
        i += 2;
      } else {
        blank(i);
        i++;
      }
      continue;
    }

    if (source.startsWith('//', i)) {
      while (i < length && source[i] != '\n') {
        blank(i++);
      }
    } else if (source.startsWith('/*', i)) {
      var depth = 0;
      do {
        if (source.startsWith('/*', i)) {
          depth++;
          blank(i);
          blank(i + 1);
          i += 2;
        } else if (source.startsWith('*/', i)) {
          depth--;
          blank(i);
          blank(i + 1);
          i += 2;
        } else {
          blank(i++);
        }
      } while (depth > 0 && i < length);
    } else if (char == "'" || char == '"') {
      final raw =
          i > 0 &&
          (source[i - 1] == 'r' || source[i - 1] == 'R') &&
          (i < 2 || !_identifierChar.hasMatch(source[i - 2]));
      final triple = source.startsWith(char * 3, i);
      final delimiter = triple ? char * 3 : char;
      string = _StringState(delimiter, raw: raw, triple: triple);
      i += delimiter.length;
    } else {
      if (interpolations.isNotEmpty) {
        final current = interpolations.last;
        if (char == '{') {
          current.depth++;
        } else if (char == '}') {
          if (current.depth == 0) {
            blank(i);
            string = interpolations.removeLast().string;
          } else {
            current.depth--;
          }
        }
      }
      i++;
    }
  }
  return String.fromCharCodes(out);
}

final RegExp _identifierChar = RegExp(r'[\w$]');

final class _StringState {
  const new(this.delimiter, {required this.raw, required this.triple});

  final String delimiter;
  final bool raw;
  final bool triple;
}

final class _Interpolation {
  new(this.string);

  final _StringState string;
  int depth = 0;
}

/// The offset of the `)` that closes the `(` at [open] in [code] (masked),
/// or null when it is missing.
int? matchingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final unit = code.codeUnitAt(i);
    if (unit == 0x28) {
      depth++;
    } else if (unit == 0x29) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

/// The arguments of an argument list's inner text [inner] (masked), split
/// at commas outside brackets, with names split off (`name: value`).
/// Empty arguments (a trailing comma) are dropped.
List<DartArgument> splitArguments(String inner) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < inner.length; i++) {
    final char = inner[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (char == ',' && depth == 0) {
      parts.add(inner.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(inner.substring(start));
  final named = RegExp(r'^\s*([A-Za-z_]\w*)\s*:(?!:)');
  return [
    for (final part in parts)
      if (part.trim().isNotEmpty)
        if (named.firstMatch(part) case final match?)
          DartArgument(match.group(1), part.substring(match.end).trim())
        else
          DartArgument(null, part.trim()),
  ];
}

final RegExp _number = RegExp(
  r'^-?\s*(?:0[xX][0-9a-fA-F_]+|(?:\d[\d_]*)?\.?\d[\d_]*(?:[eE][+-]?\d+)?)$',
);

/// The value of [expression] when it is a numeric literal (decimal,
/// hexadecimal, with digit separators, optionally negative), else null.
num? numberValue(String expression) {
  final text = expression.trim();
  if (!_number.hasMatch(text)) return null;
  final digits = text.replaceAll(RegExp(r'[\s_]'), '');
  final negative = digits.startsWith('-');
  final body = negative ? digits.substring(1) : digits;
  final value = body.startsWith(RegExp('0[xX]'))
      ? int.tryParse(body.substring(2), radix: 16)
      : num.tryParse(body);
  if (value == null) return null;
  return negative ? -value : value;
}

/// The hand-written Dart files under [s6Root] that [include] accepts
/// (`/`-separated paths from the root), sorted; generated files are never
/// returned. Null when [s6Root] does not exist.
List<DartSource>? appSources(
  CheckContext context, {
  bool Function(String path)? include,
}) {
  final root = context.dir(s6Root);
  if (!root.existsSync()) return null;
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => p.extension(file.path) == '.dart')
          .map((file) => (file, context.relative(file.path)))
          .where(
            (entry) =>
                !isGenerated(entry.$2) && (include?.call(entry.$2) ?? true),
          )
          .toList()
        ..sort((a, b) => a.$2.compareTo(b.$2));
  return [
    for (final (file, path) in files) DartSource(path, file.readAsStringSync()),
  ];
}

const String _fixHint =
    'fix the code, or add a reviewed entry with a reason to '
    'tools/checks/lib/src/checks/s6_allowlist.dart';

/// The result of the S6 check [check] for [findings]: allowances of
/// [allowlist] for [check] remove the findings they match; the check fails
/// on any finding left, on an allowance without a reason, and on an
/// allowance that matches nothing (a stale entry). A pass notes how many
/// findings the allow-list accepted.
CheckResult s6Result(
  String check,
  List<S6Finding> findings,
  List<S6Allowance> allowlist,
) {
  final own = [
    for (final allowance in allowlist)
      if (allowance.check == check) allowance,
  ];
  final used = <S6Allowance>{};
  final left = <S6Finding>[];
  for (final finding in findings) {
    final allowance = own.where((a) => a.matches(finding)).firstOrNull;
    if (allowance == null) {
      left.add(finding);
    } else {
      used.add(allowance);
    }
  }
  final problems = [
    ...capped([for (final finding in left) '$finding']),
    for (final allowance in own)
      if (allowance.reason.trim().isEmpty)
        'allow-list entry without a reason: $allowance',
    for (final allowance in own)
      if (!used.contains(allowance))
        'stale allow-list entry (matches nothing): $allowance',
  ];
  if (problems.isNotEmpty) {
    return CheckResult.fail([...problems, if (left.isNotEmpty) _fixHint]);
  }
  final allowed = findings.length;
  return CheckResult.pass([
    if (allowed > 0)
      '$allowed finding${allowed == 1 ? '' : 's'} accepted by the allow-list',
  ]);
}
