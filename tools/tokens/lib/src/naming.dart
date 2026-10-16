/// Dart names for CSS token names, and a stable natural sort.
library;

import 'package:tokens/src/errors.dart';

final _digits = RegExp(r'^\d+$');
final _dartIdentifier = RegExp(r'^[a-z][A-Za-z0-9_]*$');

/// Dart's reserved words, which can never be field names.
const Set<String> _reservedWords = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', //
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
};

/// Converts a kebab-case token name (without `--`) to lowerCamelCase.
///
/// Two numeric segments in a row are joined with `_`, so half steps stay
/// readable: `space-1-5` becomes `space1_5`, `ink-600` becomes `ink600` and
/// `control-h-xs` becomes `controlHXs`. Throws a [TokenException] when the
/// result is not a valid Dart identifier.
String camelCase(String kebab) {
  final parts = kebab.split('-').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) throw TokenException('cannot name the token "--$kebab"');
  final out = StringBuffer(parts.first);
  for (var i = 1; i < parts.length; i++) {
    final part = parts[i];
    if (_digits.hasMatch(parts[i - 1]) && _digits.hasMatch(part)) {
      out.write('_$part');
    } else {
      out
        ..write(part[0].toUpperCase())
        ..write(part.substring(1));
    }
  }
  final name = out.toString();
  if (!_dartIdentifier.hasMatch(name) || _reservedWords.contains(name)) {
    throw TokenException('"--$kebab" does not give a Dart name ("$name")');
  }
  return name;
}

/// Compares strings so that digit runs compare by value: `ink50` sorts
/// before `ink100`, and `space0_5` before `space1`.
int naturalCompare(String a, String b) {
  final left = _chunks(a);
  final right = _chunks(b);
  for (var i = 0; i < left.length && i < right.length; i++) {
    final x = left[i];
    final y = right[i];
    final xNumber = int.tryParse(x);
    final yNumber = int.tryParse(y);
    final order = xNumber != null && yNumber != null
        ? xNumber.compareTo(yNumber)
        : x.compareTo(y);
    if (order != 0) return order;
  }
  final byLength = left.length.compareTo(right.length);
  return byLength != 0 ? byLength : a.compareTo(b);
}

List<String> _chunks(String value) =>
    RegExp(r'\d+|\D+')
        .allMatches(value)
        .map((match) => match.group(0)!)
        .toList();
