import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

import 'support.dart';

/// The six bundled families as a pubspec fonts section.
String pubspecWithFonts(Iterable<String> families) => [
  'name: app',
  'flutter:',
  '  fonts:',
  for (final family in families) ...[
    '    - family: $family',
    '      fonts:',
    '        - asset: assets/fonts/x.ttf',
  ],
].join('\n');

void main() {
  group('declaredFontFamilies', () {
    test('reads flutter: fonts: families', () {
      expect(
        declaredFontFamilies(pubspecWithFonts(['IBM Plex Sans', 'Other'])),
        {'IBM Plex Sans', 'Other'},
      );
    });

    test('is null without a fonts section', () {
      expect(declaredFontFamilies('name: app\n'), isNull);
      expect(declaredFontFamilies('flutter:\n  generate: true\n'), isNull);
    });

    test('rejects a malformed fonts section', () {
      expect(
        () => declaredFontFamilies('flutter:\n  fonts: plex\n'),
        throwsA(isA<TokenException>()),
      );
      expect(
        () => declaredFontFamilies('flutter:\n  fonts:\n    - asset: a.ttf\n'),
        throwsA(isA<TokenException>()),
      );
    });
  });

  group('fontFamilyProblems', () {
    test('the design tokens name bundled and dropped families', () {
      final referenced = referencedFontFamilies(designModel);
      expect(
        referenced.keys,
        containsAll(['IBM Plex Sans', 'IBM Plex Mono', 'IBM Plex Serif']),
      );
      expect(referenced.keys, containsAll(['Caveat', 'sans-serif']));
      expect(referenced['IBM Plex Mono'], contains('--font-mono'));
    });

    test('agree when the pubspec declares every bundled family', () {
      expect(
        fontFamilyProblems(
          designModel,
          declaredFontFamilies(pubspecWithFonts(bundledFontFamilies))!,
        ),
        isEmpty,
      );
    });

    test('report a kept family the pubspec does not declare', () {
      final declared = {...bundledFontFamilies}..remove('IBM Plex Mono');
      final problems = fontFamilyProblems(designModel, declared);
      expect(problems, hasLength(1));
      expect(problems.single, contains('"IBM Plex Mono" is kept'));
      expect(problems.single, contains('--font-mono'));
    });

    test('report a declared family that the generator drops', () {
      final declared = {...bundledFontFamilies, 'Caveat'};
      final problems = fontFamilyProblems(designModel, declared);
      expect(problems, hasLength(1));
      expect(problems.single, contains('"Caveat" is declared'));
      expect(problems.single, contains('--font-hand-1'));
    });
  });

  group('app/pubspec.yaml', () {
    final pubspec = File(p.joinAll([repoRoot, ...appPubspecPath.split('/')]));
    final declared = declaredFontFamilies(pubspec.readAsStringSync());

    test(
      'declares every font family the tokens keep, and none they drop',
      () {
        final problems = fontFamilyProblems(designModel, declared!);
        expect(problems, isEmpty, reason: problems.join('\n'));
      },
      skip: declared == null
          ? 'SKIP: $appPubspecPath has no flutter: fonts: section yet, so the '
                'token font families cannot be checked against it'
          : false,
    );
  });
}
