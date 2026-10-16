/// Checks the token font families against the fonts the app declares in
/// `app/pubspec.yaml` (ADR 0012 and ADR 0013).
///
/// Every family that a token font stack or `font` shorthand names must be
/// either declared under `flutter: fonts:` and kept by the generator (it is
/// in [bundledFontFamilies]), or deliberately dropped: not declared and not
/// in [bundledFontFamilies], listed in the field's doc comment instead.
library;

import 'package:tokens/src/errors.dart';
import 'package:tokens/src/mappers.dart';
import 'package:tokens/src/model.dart';
import 'package:tokens/src/values.dart';
import 'package:yaml/yaml.dart';

/// The app's pubspec, relative to the repository root.
const String appPubspecPath = 'app/pubspec.yaml';

/// The families declared under `flutter: fonts:` in [pubspecYaml], or null
/// when the pubspec has no fonts section.
///
/// Throws a [TokenException] when the fonts section is not a list of entries
/// that each name a `family`.
Set<String>? declaredFontFamilies(String pubspecYaml) {
  final pubspec = loadYaml(pubspecYaml);
  final flutter = pubspec is YamlMap ? pubspec['flutter'] : null;
  final fonts = flutter is YamlMap ? flutter['fonts'] : null;
  if (fonts == null) return null;
  if (fonts is! YamlList) {
    throw TokenException('$appPubspecPath: flutter: fonts: must be a list');
  }
  return {
    for (final entry in fonts)
      switch (entry) {
        {'family': final String family} => family,
        _ => throw TokenException(
          '$appPubspecPath: every flutter: fonts: entry needs a family, '
          'found $entry',
        ),
      },
  };
}

/// Every font family the tokens name, in any environment, with the CSS
/// names of the tokens that name it.
Map<String, Set<String>> referencedFontFamilies(TokenModel model) {
  final byFamily = <String, Set<String>>{};
  for (final token in model.tokens.values) {
    for (final value in token.values.values) {
      final names = switch (value) {
        FontStackValue(:final families) => families,
        FontShorthandValue(:final families) => families,
        _ => const <String>[],
      };
      for (final family in names) {
        (byFamily[family] ??= <String>{}).add('--${token.name}');
      }
    }
  }
  return byFamily;
}

/// The mismatches between the token font families and the families
/// [declared] in the app's pubspec; empty when they agree.
List<String> fontFamilyProblems(TokenModel model, Set<String> declared) {
  final problems = <String>[];
  for (final MapEntry(key: family, value: tokens) in referencedFontFamilies(
    model,
  ).entries) {
    final kept = bundledFontFamilies.contains(family);
    if (kept && !declared.contains(family)) {
      problems.add(
        '"$family" is kept in tokens.g.dart (${tokens.join(', ')}) but '
        '$appPubspecPath does not declare it under flutter: fonts:',
      );
    } else if (!kept && declared.contains(family)) {
      problems.add(
        '"$family" is declared in $appPubspecPath but the generator drops it '
        'from ${tokens.join(', ')}; add it to bundledFontFamilies in '
        'tools/tokens/lib/src/mappers.dart',
      );
    }
  }
  return problems;
}
