/// Small text helpers shared by the checks.
library;

/// Removes `//` line comments (including `///` and `//!` doc comments).
///
/// Good enough for attribute checks on Rust sources: a `//` inside a string
/// literal also ends the line early, and block comments are kept, which can
/// only make a check stricter.
String stripLineComments(String source) => source
    .split('\n')
    .map((line) {
      final index = line.indexOf('//');
      return index < 0 ? line : line.substring(0, index);
    })
    .join('\n');

final _tomlHeader = RegExp(r'^\s*\[{1,2}\s*([^\[\]]+?)\s*\]{1,2}');

/// The value of `key = "value"` in the TOML table [table] of [source].
///
/// Reads only plain `key = "string"` lines, which is all the checks need
/// from `Cargo.toml`. Returns `null` when the table or the key is missing.
String? tomlString(
  String source, {
  required String table,
  required String key,
}) {
  String? current;
  final keyLine = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=\s*"([^"]*)"');
  for (final line in source.split('\n')) {
    final header = _tomlHeader.firstMatch(line);
    if (header != null) {
      current = header.group(1);
    } else if (current == table) {
      final match = keyLine.firstMatch(line);
      if (match != null) return match.group(1);
    }
  }
  return null;
}

/// The versions of package [name] in a `Cargo.lock` file, in file order.
///
/// A lock file can hold several versions of one crate.
List<String> cargoLockVersions(String lockFile, String name) {
  final field = RegExp('^(name|version) = "([^"]*)"');
  final versions = <String>[];
  var inPackage = false;
  String? currentName;
  for (final line in lockFile.split('\n')) {
    if (line.startsWith('[')) {
      inPackage = line.trim() == '[[package]]';
      currentName = null;
      continue;
    }
    final match = inPackage ? field.firstMatch(line) : null;
    if (match == null) continue;
    if (match.group(1) == 'name') {
      currentName = match.group(2);
    } else if (currentName == name) {
      versions.add(match.group(2)!);
    }
  }
  return versions;
}

/// Lists at most [limit] items, then says how many more there are.
List<String> capped(List<String> items, {int limit = 20}) =>
    items.length <= limit
    ? items
    : [...items.take(limit), '... and ${items.length - limit} more'];
