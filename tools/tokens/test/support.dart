import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tokens/tokens.dart';

/// The repository root: the nearest parent of the working directory that
/// holds `design/` and `tools/tokens/`.
final String repoRoot = () {
  var directory = Directory.current.absolute.path;
  while (true) {
    if (Directory(p.join(directory, 'design')).existsSync() &&
        File(p.join(directory, 'tools', 'tokens', 'pubspec.yaml'))
            .existsSync()) {
      return directory;
    }
    final parent = p.dirname(directory);
    if (parent == directory) {
      throw StateError('run the tests inside the Ferman repository');
    }
    directory = parent;
  }
}();

/// The token model built from the real design files, built once.
final TokenModel designModel = loadModel(repoRoot);

/// Builds a model from in-memory stylesheets, in cascade order.
TokenModel modelFromCss(Map<String, String> sheets) => TokenModel.build(
  TokenCascade.fromSheets([
    for (final MapEntry(key: file, value: css) in sheets.entries)
      parseStylesheet(css, file: file),
  ]),
  const Supplement([]),
);

/// [expression] without whitespace or trailing commas, for comparisons that
/// do not depend on spacing.
String compact(String expression) => expression
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(',)', ')')
    .replaceAll(',]', ']');

/// The compacted value of [className].[fieldName] for [instance] (`''` for a
/// class of static constants).
String valueOf(
  TokenModel model,
  String className,
  String fieldName, [
  String instance = '',
]) {
  final value = model.classNamed(className).field(fieldName).values[instance];
  if (value == null) {
    throw StateError('$className.$fieldName has no "$instance" value');
  }
  return compact(value);
}

/// Copies the files the generator reads into a fresh temporary root and
/// returns its path.
Directory copyGeneratorInputs() {
  final temp = Directory.systemTemp.createTempSync('ferman_tokens_');
  final supplement = Supplement.load(repoRoot);
  final paths = [
    for (final source in tokenSources) source.path,
    'tools/tokens/supplement.yaml',
    for (final hatch in supplement.hatches) hatch.source.split(':').first,
  ];
  for (final path in paths) {
    final target = File(p.joinAll([temp.path, ...path.split('/')]));
    target.parent.createSync(recursive: true);
    File(p.joinAll([repoRoot, ...path.split('/')])).copySync(target.path);
  }
  return temp;
}
