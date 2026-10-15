import 'package:test/test.dart';
import 'package:tokens/tokens.dart';

void main() {
  VarResolver resolverFor(
    String css, [
    TokenEnvironment env = TokenEnvironment.light,
  ]) {
    final cascade = TokenCascade.fromSheets([
      parseStylesheet(css, file: 't.css'),
    ]);
    return VarResolver(cascade.effective(env), environment: env);
  }

  group('VarResolver', () {
    test('resolves chains', () {
      final resolver = resolverFor(
        ':root { --a: #111111; --b: var(--a); --c: 0 0 0 2px var(--b); }',
      );
      expect(resolver.resolve('c'), '0 0 0 2px #111111');
    });

    test('resolves after merging, so inherited chains see overrides', () {
      const css =
          ':root { --gap: #FFFFFF; --ring: 0 0 0 2px var(--gap); } '
          '[data-theme="dark"] { --gap: #1D1C1B; }';
      expect(resolverFor(css).resolve('ring'), '0 0 0 2px #FFFFFF');
      expect(
        resolverFor(css, TokenEnvironment.dark).resolve('ring'),
        '0 0 0 2px #1D1C1B',
      );
    });

    test('uses the fallback for an unknown name', () {
      final resolver = resolverFor(':root { --a: var(--missing, 4px); }');
      expect(resolver.resolve('a'), '4px');
    });

    test('ignores identifiers that merely end in "var"', () {
      final resolver = resolverFor(':root { --a: myvar(1); }');
      expect(resolver.resolve('a'), 'myvar(1)');
    });

    test('fails on an unresolved reference', () {
      expect(
        () => resolverFor(':root { --a: var(--nope); }').resolve('a'),
        throwsA(
          isA<TokenException>().having(
            (e) => e.message,
            'message',
            contains('unresolved var(--nope)'),
          ),
        ),
      );
    });

    test('fails on a cycle and names it', () {
      expect(
        () => resolverFor(
          ':root { --a: var(--b); --b: var(--c); --c: var(--a); }',
        ).resolve('a'),
        throwsA(
          isA<TokenException>().having(
            (e) => e.message,
            'message',
            contains('--a -> --b -> --c -> --a'),
          ),
        ),
      );
    });
  });
}
