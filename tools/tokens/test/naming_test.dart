import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

void main() {
  group('camelCase', () {
    for (final (css, dart) in [
      ('ink-600', 'ink600'),
      ('space-1-5', 'space1_5'),
      ('space-0-5', 'space0_5'),
      ('space-px', 'spacePx'),
      ('control-h-xs', 'controlHXs'),
      ('text-2xs', 'text2xs'),
      ('surface-selected-strong', 'surfaceSelectedStrong'),
      ('z-canvas', 'zCanvas'),
    ]) {
      test('--$css → $dart', () => expect(camelCase(css), dart));
    }

    test('rejects names that give no Dart identifier', () {
      expect(() => camelCase('2xl'), throwsA(isA<TokenException>()));
      expect(() => camelCase('switch'), throwsA(isA<TokenException>()));
    });
  });

  test('naturalCompare orders digit runs by value', () {
    final names = [
      'space2',
      'ink100',
      'spacePx',
      'space0_5',
      'ink50',
      'space1_5',
      'space1',
      'space0',
      'space10',
    ]..sort(naturalCompare);
    expect(names, [
      'ink50',
      'ink100',
      'space0',
      'space0_5',
      'space1',
      'space1_5',
      'space2',
      'space10',
      'spacePx',
    ]);
  });
}
