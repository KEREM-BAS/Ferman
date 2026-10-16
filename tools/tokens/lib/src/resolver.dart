/// Resolves `var()` references within one environment.
library;

import 'package:tokens/src/cascade.dart';
import 'package:tokens/src/css.dart';
import 'package:tokens/src/errors.dart';
import 'package:tokens/src/text.dart';

/// Resolves `var(--name)` and `var(--name, fallback)` against the
/// declarations in effect in one [environment].
///
/// Environments are merged first and resolved afterwards, so a chain such as
/// `--focus-ring` → `--surface-raised` → `--soot-100` picks up dark values
/// even though `--focus-ring` itself is declared only on `:root`.
final class VarResolver {
  /// Creates a resolver over [declarations], the tokens in effect in
  /// [environment].
  new(this.declarations, {required this.environment});

  /// The declarations in effect, by name.
  final Map<String, CssDeclaration> declarations;

  /// The environment these declarations belong to, for error messages.
  final TokenEnvironment environment;

  final Map<String, String> _cache = {};

  /// Returns the value of the token [name] with every `var()` replaced.
  ///
  /// Throws a [TokenException] on an unknown name, an unresolved reference
  /// without a fallback, or a reference cycle.
  String resolve(String name) => _resolveName(name, const []);

  /// Returns [value] with every `var()` replaced.
  String resolveValue(String value, {String context = 'value'}) =>
      _substitute(value, const [], context);

  String _resolveName(String name, List<String> chain) {
    final cached = _cache[name];
    if (cached != null) return cached;
    if (chain.contains(name)) {
      final cycle = [...chain, name].map((n) => '--$n').join(' -> ');
      throw TokenException('var() cycle in ${environment.name}: $cycle');
    }
    final declaration = declarations[name];
    if (declaration == null) {
      throw TokenException('unknown token --$name in ${environment.name}');
    }
    final resolved = _substitute(declaration.value, [
      ...chain,
      name,
    ], '--$name (${declaration.location})');
    return _cache[name] = resolved;
  }

  String _substitute(String value, List<String> chain, String context) {
    final out = StringBuffer();
    var index = 0;
    while (true) {
      final start = _findVar(value, index);
      if (start < 0) {
        out.write(value.substring(index));
        break;
      }
      out.write(value.substring(index, start));
      final open = start + 3;
      final close = matchingParen(value, open);
      if (close < 0) {
        throw TokenException('unclosed var( in $context: $value');
      }
      final arguments = splitTopLevel(value.substring(open + 1, close), ',');
      final reference = arguments.first;
      if (!reference.startsWith('--')) {
        throw TokenException('malformed var($reference) in $context');
      }
      final name = reference.substring(2);
      if (declarations.containsKey(name)) {
        out.write(_resolveName(name, chain));
      } else if (arguments.length > 1) {
        final fallback = arguments.sublist(1).join(', ');
        out.write(_substitute(fallback, chain, context));
      } else {
        throw TokenException(
          'unresolved var(--$name) in $context (${environment.name})',
        );
      }
      index = close + 1;
    }
    return collapseWhitespace(out.toString());
  }

  /// Finds the next `var(` that starts a function call, not the tail of a
  /// longer identifier.
  static int _findVar(String value, int from) {
    var start = value.indexOf('var(', from);
    while (start > 0 && RegExp(r'[\w-]').hasMatch(value[start - 1])) {
      start = value.indexOf('var(', start + 4);
    }
    return start;
  }
}
