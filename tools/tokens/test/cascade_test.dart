import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

import 'support.dart';

void main() {
  group('the design token files', () {
    final cascade = designModel.cascade;

    test('hold the declarations ROADMAP step 4 and ADR 0012 list', () {
      // Counted by parsing; these are the numbers the CSS really holds.
      const light = TokenEnvironment.light;
      const dark = TokenEnvironment.dark;
      const expected = {
        'fonts.css': <TokenEnvironment, int>{},
        'colors.css': {light: 132, dark: 48, TokenEnvironment.dim: 1},
        'typography.css': {light: 41},
        'spacing.css': {light: 34, TokenEnvironment.touch: 12},
        'effects.css': {light: 31, dark: 5, TokenEnvironment.reducedMotion: 4},
        'base.css': <TokenEnvironment, int>{},
        'fm-additions.css': {light: 34, TokenEnvironment.cjk: 5, dark: 1},
      };
      expect(cascade.counts.keys, expected.keys);
      for (final MapEntry(key: file, value: perEnv) in expected.entries) {
        for (final env in TokenEnvironment.values) {
          expect(
            cascade.counts[file]![env],
            perEnv[env] ?? 0,
            reason: '$file, ${env.name}',
          );
        }
      }
      expect(cascade.declarationCount, 348);
    });

    test('define 269 unique names: 238 in the design system and 31 new in '
        'the additions, which also override 3', () {
      final designSystem = <String>{};
      final additions = <String>{};
      for (final sheet in cascade.sheets) {
        final names = sheet.customProperties.map((d) => d.name);
        (sheet.file == 'fm-additions.css' ? additions : designSystem).addAll(
          names,
        );
      }
      expect(cascade.names, hasLength(269));
      expect(designSystem, hasLength(238));
      expect(additions.difference(designSystem), hasLength(31));
      expect(
        cascade.replaced[TokenEnvironment.light]!.keys,
        unorderedEquals(['edit-changed', 'edit-changed-bg', 'font-ui']),
      );
    });

    test('fonts.css and base.css only hold rules without tokens', () {
      final fonts = cascade.sheets.firstWhere((s) => s.file == 'fonts.css');
      final base = cascade.sheets.firstWhere((s) => s.file == 'base.css');
      expect(
        fonts.rules.where((r) => r.selectors.single == '@font-face'),
        hasLength(33),
      );
      expect(
        base.rules.map((r) => r.atRule).whereType<String>().toSet(),
        hasLength(5),
        reason: 'five @keyframes',
      );
    });

    test('the additions load last and win', () {
      final light = cascade.effective(TokenEnvironment.light);
      expect(light['edit-changed']!.value, 'var(--ink-600)');
      expect(light['edit-changed']!.location.file, 'fm-additions.css');
      expect(light['font-ui']!.value, contains("'IBM Plex Sans Hebrew'"));
    });

    test('an environment inherits :root and applies its own overrides', () {
      final dark = cascade.effective(TokenEnvironment.dark);
      expect(dark['surface-canvas']!.value, 'var(--soot-0)');
      expect(dark['ink-600']!.value, '#2A4DAF');
      final touch = cascade.effective(TokenEnvironment.touch);
      expect(touch['control-h-sm']!.value, '44px');
      expect(touch['icon-sm']!.value, '14px');
    });
  });

  group('TokenCascade.fromSheets', () {
    TokenCascade cascadeOf(String css) =>
        TokenCascade.fromSheets([parseStylesheet(css, file: 't.css')]);

    test('maps every token selector to its environment', () {
      final cascade = cascadeOf('''
:root { --a: 1px; }
[data-theme="dark"] { --a: 2px; }
[data-page="dim"] { --a: 3px; }
[data-density="touch"] { --a: 4px; }
[lang|="ja"], [lang|="zh"], [lang|="ko"] { --a: 5px; }
@media (prefers-reduced-motion: reduce) { :root { --a: 6px; } }
''');
      for (final (env, value) in [
        (TokenEnvironment.light, '1px'),
        (TokenEnvironment.dark, '2px'),
        (TokenEnvironment.dim, '3px'),
        (TokenEnvironment.touch, '4px'),
        (TokenEnvironment.cjk, '5px'),
        (TokenEnvironment.reducedMotion, '6px'),
      ]) {
        expect(cascade.effective(env)['a']!.value, value, reason: env.name);
      }
    });

    test('the last declaration wins and the earlier one is recorded', () {
      final cascade = cascadeOf(':root { --a: 1px; } :root { --a: 2px; }');
      expect(cascade.effective(TokenEnvironment.light)['a']!.value, '2px');
      expect(
        cascade.replaced[TokenEnvironment.light]!['a']!.single.value,
        '1px',
      );
    });

    test('ignores rules without custom properties', () {
      final cascade = cascadeOf('.fm-x { color: red; } :root { --a: 1px; }');
      expect(cascade.names, ['a']);
    });

    test('rejects custom properties under any other selector', () {
      expect(
        () => cascadeOf('.fm-x { --a: 1px; }'),
        throwsA(
          isA<TokenException>().having(
            (e) => e.message,
            'message',
            contains('not a token environment'),
          ),
        ),
      );
    });

    test('rejects an override without a :root default', () {
      expect(
        () =>
            cascadeOf(':root { --a: 1px; } [data-theme="dark"] { --b: 1px; }'),
        throwsA(
          isA<TokenException>().having(
            (e) => e.message,
            'message',
            contains('no :root default'),
          ),
        ),
      );
    });
  });
}
