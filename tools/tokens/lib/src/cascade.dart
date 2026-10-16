/// The token files, their cascade order and the environments they describe.
library;

import 'package:tokens/src/css.dart';
import 'package:tokens/src/errors.dart';

/// The environments the design's token CSS describes (ADR 0012).
enum TokenEnvironment {
  /// The default: light theme, desktop density (`:root`).
  light(':root'),

  /// The dark theme (`[data-theme="dark"]`).
  dark('[data-theme="dark"]'),

  /// The reading-comfort page dimming (`[data-page="dim"]`).
  dim('[data-page="dim"]'),

  /// Touch density for tablets and phones (`[data-density="touch"]`).
  touch('[data-density="touch"]'),

  /// Japanese, Chinese and Korean text (`[lang|="ja"]`, `zh`, `ko`).
  cjk('[lang|="ja"], [lang|="zh"], [lang|="ko"]'),

  /// `@media (prefers-reduced-motion: reduce)`.
  reducedMotion('@media (prefers-reduced-motion: reduce) :root');

  new(this.selector);

  /// The CSS selector (and media query) that introduces the environment.
  final String selector;
}

/// A token stylesheet in cascade order.
final class TokenSource {
  /// Creates a source with a short [label] and a [path] relative to the
  /// repository root, using `/` separators.
  const new(this.label, this.path);

  /// The short label used in source locations, such as `colors.css`.
  final String label;

  /// The path relative to the repository root.
  final String path;
}

/// The design system's token folder, relative to the repository root.
const String designSystemTokensDir =
    'design/_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/'
    'tokens';

/// The token stylesheets in the order the design loads them: the design
/// system's `styles.css` imports order, then the additions, which load last
/// and win (DESIGN_GAPS.md, G05). `fonts.css` and
/// `base.css` declare no tokens; they are read so the counts prove it.
const List<TokenSource> tokenSources = [
  TokenSource('fonts.css', '$designSystemTokensDir/fonts.css'),
  TokenSource('colors.css', '$designSystemTokensDir/colors.css'),
  TokenSource('typography.css', '$designSystemTokensDir/typography.css'),
  TokenSource('spacing.css', '$designSystemTokensDir/spacing.css'),
  TokenSource('effects.css', '$designSystemTokensDir/effects.css'),
  TokenSource('base.css', '$designSystemTokensDir/base.css'),
  TokenSource('fm-additions.css', 'design/ds-additions/fm-additions.css'),
];

/// Returns the environment a rule declares tokens for, or null when the
/// selector is not one of the token environments.
TokenEnvironment? environmentOf(CssRule rule) {
  final selectors = rule.selectors.toSet();
  bool only(Set<String> expected) =>
      selectors.length == expected.length && selectors.containsAll(expected);

  if (rule.atRule == '@media (prefers-reduced-motion: reduce)') {
    return only({':root'}) ? TokenEnvironment.reducedMotion : null;
  }
  if (rule.atRule != null) return null;
  if (only({':root'})) return TokenEnvironment.light;
  if (only({'[data-theme="dark"]'})) return TokenEnvironment.dark;
  if (only({'[data-page="dim"]'})) return TokenEnvironment.dim;
  if (only({'[data-density="touch"]'})) return TokenEnvironment.touch;
  if (only({'[lang|="ja"]', '[lang|="zh"]', '[lang|="ko"]'})) {
    return TokenEnvironment.cjk;
  }
  return null;
}

/// All token declarations merged in cascade order, per environment.
final class TokenCascade {
  new _(this.sheets, this.declared, this.replaced, this.counts);

  /// Merges [sheets], which must be in cascade order. Within an environment
  /// the last declaration of a name wins, as in the browser.
  ///
  /// Throws a [TokenException] when a custom property sits in a rule that is
  /// not a token environment, or when an environment overrides a name that
  /// has no `:root` default.
  factory fromSheets(List<CssStylesheet> sheets) {
    final declared = {
      for (final env in TokenEnvironment.values)
        env: <String, CssDeclaration>{},
    };
    final replaced = {
      for (final env in TokenEnvironment.values)
        env: <String, List<CssDeclaration>>{},
    };
    final counts = <String, Map<TokenEnvironment, int>>{};
    for (final sheet in sheets) {
      final perEnv = counts[sheet.file] = {
        for (final env in TokenEnvironment.values) env: 0,
      };
      for (final rule in sheet.rules) {
        if (rule.customProperties.isEmpty) continue;
        final env = environmentOf(rule);
        if (env == null) {
          final selectors = rule.selectors.join(', ');
          final inside = rule.atRule == null ? '' : ' inside "${rule.atRule}"';
          throw TokenException(
            '${rule.location}: custom properties in "$selectors"$inside, '
            'which is not a token environment',
          );
        }
        for (final declaration in rule.customProperties) {
          perEnv[env] = perEnv[env]! + 1;
          final previous = declared[env]![declaration.name];
          if (previous != null) {
            (replaced[env]![declaration.name] ??= []).add(previous);
          }
          declared[env]![declaration.name] = declaration;
        }
      }
    }
    final light = declared[TokenEnvironment.light]!;
    for (final MapEntry(key: env, value: map) in declared.entries) {
      for (final declaration in map.values) {
        if (!light.containsKey(declaration.name)) {
          throw TokenException(
            '${declaration.location}: --${declaration.name} is declared for '
            '${env.selector} but has no :root default',
          );
        }
      }
    }
    return TokenCascade._(sheets, declared, replaced, counts);
  }

  /// The parsed sheets in cascade order.
  final List<CssStylesheet> sheets;

  /// The winning declaration per environment and name. Environments other
  /// than [TokenEnvironment.light] hold only their own overrides.
  final Map<TokenEnvironment, Map<String, CssDeclaration>> declared;

  /// Declarations that a later declaration of the same name in the same
  /// environment replaced, oldest first.
  final Map<TokenEnvironment, Map<String, List<CssDeclaration>>> replaced;

  /// The number of custom-property declarations per file label and
  /// environment.
  final Map<String, Map<TokenEnvironment, int>> counts;

  /// The total number of custom-property declarations.
  int get declarationCount => counts.values
      .expand((perEnv) => perEnv.values)
      .fold(0, (sum, count) => sum + count);

  /// Every token name, in first-declared order.
  List<String> get names => declared[TokenEnvironment.light]!.keys.toList();

  /// The declarations in effect in [env]: the `:root` tokens with the
  /// environment's own overrides applied on top.
  Map<String, CssDeclaration> effective(TokenEnvironment env) => {
    ...declared[TokenEnvironment.light]!,
    if (env != TokenEnvironment.light) ...declared[env]!,
  };
}
