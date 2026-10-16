import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The static token classes of `tokens.g.dart` and their views in
/// `theme/static_tokens.dart`.
const Map<String, String> _views = {
  'FermanRampTokens': 'FermanRamps',
  'FermanPageColorTokens': 'FermanPageColors',
  'FermanTypeTokens': 'FermanTypeScale',
  'FermanSpaceTokens': 'FermanSpacing',
  'FermanSizeTokens': 'FermanSizes',
  'FermanRadiusTokens': 'FermanRadii',
  'FermanBorderTokens': 'FermanBorders',
  'FermanZTokens': 'FermanLayers',
  'FermanHatchTokens': 'FermanHatches',
};

/// The body of the class [name] declared in [source] (`class Name {` to the
/// first `}` at the start of a line).
String _classBody(String source, String name) {
  final match = RegExp(
    'class $name'
    r' \{\n(.*?)\n\}\n',
    dotAll: true,
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'class $name not found');
  return match!.group(1)!;
}

void main() {
  // flutter test runs in app/.
  final tokens = File('lib/design/tokens.g.dart').readAsStringSync();
  final views = File('lib/design/theme/static_tokens.dart').readAsStringSync();

  test('every static token class has a view', () {
    final staticClasses = RegExp(
      r'^abstract final class (Ferman\w+Tokens) \{',
      multiLine: true,
    ).allMatches(tokens).map((m) => m.group(1)).toSet();
    expect(staticClasses, _views.keys.toSet());
  });

  for (final MapEntry(key: tokenClass, value: view) in _views.entries) {
    test('$view mirrors every token of $tokenClass, with its type', () {
      final declared = {
        for (final m in RegExp(
          r'^  static const ([\w<>?, ]+?) (\w+) =',
          multiLine: true,
        ).allMatches(_classBody(tokens, tokenClass)))
          m.group(2)!: m.group(1)!,
      };
      final mirrored = {
        for (final m in RegExp(
          r'^  ([\w<>?, ]+?) get (\w+) =>\s*' + tokenClass + r'\.(\w+);',
          multiLine: true,
        ).allMatches(_classBody(views, view)))
          m.group(2)!: (m.group(1)!, m.group(3)!),
      };
      expect(declared, isNotEmpty);
      expect(mirrored.keys.toSet(), declared.keys.toSet());
      mirrored.forEach((name, typeAndTarget) {
        final (type, target) = typeAndTarget;
        expect(target, name, reason: '$view.$name reads $tokenClass.$target');
        expect(type, declared[name], reason: '$view.$name type');
      });
    });
  }
}
