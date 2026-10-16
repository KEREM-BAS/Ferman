/// Groups the resolved tokens into the generated Dart classes.
///
/// Placement rules, in order (first match wins):
///
/// 1. `--focus-*` → `FermanFocusTokens` (light and dark).
/// 2. Shadows → `FermanElevationTokens` (light and dark).
/// 3. Colours: ramp steps and `--annot-*` → `FermanRampTokens`;
///    theme-dependent colours → `FermanColorTokens` (light and dark); every
///    other colour is an on-page mark → `FermanPageColorTokens`. A colour is
///    theme-dependent if and only if a theme environment other than light
///    (today only `[data-theme="dark"]`) redeclares it, even to the same
///    value, or it resolves differently there, as an alias of a redeclared
///    colour does. Because the design defines the page marks by name (ADR
///    0012), a colour that is not theme-dependent must also have a page-mark
///    name ([pageMarkColorPrefixes] or `--page-bg`); otherwise the run stops,
///    so a new UI colour that happens to match in both themes is never filed
///    as a page mark without notice.
/// 4. Filters → `FermanPageFilterTokens` (standard and dim).
/// 5. Durations and easings → `FermanMotionTokens` (standard and reduced).
/// 6. Integers (z-index) → `FermanZTokens`.
/// 7. `font` shorthands → `FermanTypeRoleTokens` (standard and CJK), named
///    without the `type-` prefix.
/// 8. Font stacks, features, weights and tracking → `FermanTypeTokens`.
/// 9. Lengths: `--text-<size>` → `FermanTypeTokens.size<Size>` (so the size
///    never shares a name with the `--text-*` colours), `--leading-<size>` →
///    `FermanTypeTokens`, `--space-*` → `FermanSpaceTokens`, radii →
///    `FermanRadiusTokens`, `--border-width*` → `FermanBorderTokens`, lengths
///    that touch density overrides and `--icon-<size>` →
///    `FermanDensityTokens` (desktop and touch), every other length →
///    `FermanSizeTokens`.
///
/// Every other field name is the CSS name in lowerCamelCase. A token that
/// varies in an environment its class has no instance for stops the run.
library;

import 'package:tokens/src/cascade.dart';
import 'package:tokens/src/classifier.dart';
import 'package:tokens/src/css.dart';
import 'package:tokens/src/dart_model.dart';
import 'package:tokens/src/errors.dart';
import 'package:tokens/src/mappers.dart';
import 'package:tokens/src/naming.dart';
import 'package:tokens/src/resolver.dart';
import 'package:tokens/src/supplement.dart';
import 'package:tokens/src/values.dart';

/// Which environments a token class has constant instances for.
enum TokenAxis {
  /// Static constants: the value is the same everywhere.
  none,

  /// `light` and `dark`.
  theme,

  /// `desktop` and `touch`.
  density,

  /// `standard` and `reduced`.
  motion,

  /// `standard` and `cjk`.
  script,

  /// `standard` and `dim`.
  page,
}

/// The constant instances generated for [axis].
List<DartInstance> instancesFor(TokenAxis axis) => switch (axis) {
  TokenAxis.none => const [],
  TokenAxis.theme => const [
    DartInstance(
      name: 'light',
      label: 'Light',
      environment: TokenEnvironment.light,
      doc: 'The light theme (`:root`), the default.',
    ),
    DartInstance(
      name: 'dark',
      label: 'Dark',
      environment: TokenEnvironment.dark,
      doc: 'The dark theme (`[data-theme="dark"]`).',
    ),
  ],
  TokenAxis.density => const [
    DartInstance(
      name: 'desktop',
      label: 'Desktop',
      environment: TokenEnvironment.light,
      doc: 'Compact desktop density (`:root`), the default.',
    ),
    DartInstance(
      name: 'touch',
      label: 'Touch',
      environment: TokenEnvironment.touch,
      doc:
          'Touch density (`[data-density="touch"]`) for tablets and phones: '
          'every target is at least 44 px.',
    ),
  ],
  TokenAxis.motion => const [
    DartInstance(
      name: 'standard',
      label: 'Standard',
      environment: TokenEnvironment.light,
      doc: 'Standard motion (`:root`).',
    ),
    DartInstance(
      name: 'reduced',
      label: 'Reduced motion',
      environment: TokenEnvironment.reducedMotion,
      doc:
          'Reduced motion (`@media (prefers-reduced-motion: reduce)`): every '
          'duration is zero. Use it when `MediaQuery.disableAnimationsOf` is '
          'true.',
    ),
  ],
  TokenAxis.script => const [
    DartInstance(
      name: 'standard',
      label: 'Standard',
      environment: TokenEnvironment.light,
      doc: 'The default type roles (`:root`).',
    ),
    DartInstance(
      name: 'cjk',
      label: 'CJK',
      environment: TokenEnvironment.cjk,
      doc:
          'Japanese, Chinese and Korean text (`[lang|="ja"]`, `zh`, `ko`): '
          'taller leading on five roles. The design also sets '
          '`font-synthesis: none` here, so never synthesise bold or italic '
          'for CJK text.',
    ),
  ],
  TokenAxis.page => const [
    DartInstance(
      name: 'standard',
      label: 'Standard',
      environment: TokenEnvironment.light,
      doc: 'No page filter (`--page-filter: none`), the default.',
    ),
    DartInstance(
      name: 'dim',
      label: 'Dim',
      environment: TokenEnvironment.dim,
      doc:
          'The dimmed page (`[data-page="dim"]`), a per-user reading-comfort '
          'option meant for the dark theme.',
    ),
  ],
};

final class _ClassSpec {
  const new(this.name, this.axis, this.doc);

  final String name;
  final TokenAxis axis;

  /// Documentation; paragraphs are separated by a blank line.
  final String doc;
}

/// The generated token classes in output order.
const List<_ClassSpec> _classSpecs = [
  _ClassSpec(
    'FermanRampTokens',
    TokenAxis.none,
    'Colour ramps and the annotation palette (colors.css).\n\n'
        'They are the same in the light and dark themes; the semantic colour '
        'tokens alias them.',
  ),
  _ClassSpec(
    'FermanColorTokens',
    TokenAxis.theme,
    'Semantic UI colours with a light and a dark instance: surfaces, text, '
        'icons, borders, accent and status colours, the page border and the '
        'Windows close-button hover.\n\n'
        'Translucent values such as `surfaceHover`, `surfacePressed` and the '
        'dark selected colours are overlays: paint them over the surface '
        'beneath (for example with `Color.alphaBlend`), not as opaque fills.',
  ),
  _ClassSpec(
    'FermanPageColorTokens',
    TokenAxis.none,
    'Marks drawn on the PDF page, tuned against white paper: editing states, '
        'missing glyphs, redaction, search, form fields, compare, OCR, '
        'translation, overflow and the page background.\n\n'
        'The page stays paper-white in both themes, so these do not change in '
        'dark mode.',
  ),
  _ClassSpec(
    'FermanTypeTokens',
    TokenAxis.none,
    'The type scale, line heights, weights, tracking, numeral features and '
        'font stacks (typography.css; fm-additions.css extends `--font-ui` '
        'and adds the CJK document and handwriting stacks).\n\n'
        'Sizes are named `size<Step>` so they never share a name with the '
        '`--text-*` colours. Heights are `leading / size`, ready for '
        '`TextStyle.height`. Tracking values are `em` factors: '
        '`letterSpacing = tracking × fontSize`.\n\n'
        'Font stacks keep only the bundled families (IBM Plex Sans, Sans '
        'Arabic, Sans Hebrew, Sans Devanagari, Mono and Serif). CSS generic '
        'and system keywords, the CJK families (system fonts cover CJK, '
        'ADR 0013) and the handwriting faces (waiting for Q08) are dropped; '
        'each stack lists what was dropped.',
  ),
  _ClassSpec(
    'FermanTypeRoleTokens',
    TokenAxis.script,
    'The semantic text styles, from the `--type-*` font shorthands.\n\n'
        '`height` is the CSS line height divided by the size, with even '
        'leading distribution to match CSS half-leading. A shorthand without '
        'a line height leaves `height` null, so the font metrics set the line '
        'height, as CSS `normal` does. Font stacks keep only the bundled '
        'families, as in [FermanTypeTokens]. Colour is not part of a role; '
        'take it from '
        '[FermanColorTokens].',
  ),
  _ClassSpec(
    'FermanSpaceTokens',
    TokenAxis.none,
    'The spacing scale (spacing.css): a 4 px base with 2 px and 6 px half '
        'steps. `space1_5` is `--space-1-5`.',
  ),
  _ClassSpec(
    'FermanDensityTokens',
    TokenAxis.density,
    'Control, icon and bar sizes that change with density (spacing.css).\n\n'
        'Choose the instance by platform (desktop or touch), not by '
        '`VisualDensity`.',
  ),
  _ClassSpec(
    'FermanSizeTokens',
    TokenAxis.none,
    'Fixed sizes that do not change with density: app layout widths, dialog '
        'and palette widths, document tabs, the Windows caption button, '
        'edit-mark geometry and the mobile bars.',
  ),
  _ClassSpec(
    'FermanRadiusTokens',
    TokenAxis.none,
    'Corner radii (effects.css; `sheetRadius` from fm-additions.css). '
        '`radiusFull` (999 px) draws a pill.',
  ),
  _ClassSpec(
    'FermanBorderTokens',
    TokenAxis.none,
    'Border widths (effects.css).',
  ),
  _ClassSpec(
    'FermanElevationTokens',
    TokenAxis.theme,
    'Shadows for things that float above the document, with light and dark '
        'instances.\n\n'
        'Converted for Flutter: the layers are reversed (CSS paints the first '
        'layer on top, Flutter the last), a `0 0 0 1px` ring becomes a 1 px '
        'spread with no blur, negative spreads are kept, and the CSS blur '
        'becomes `blurRadius = (blur / 2 - 0.5) / 0.57735` so that the '
        'Gaussian sigma matches.',
  ),
  _ClassSpec(
    'FermanFocusTokens',
    TokenAxis.theme,
    'Keyboard focus indicators, with light and dark instances (their colours '
        'come from `--surface-raised` and `--border-focus`).\n\n'
        '`focusRing` is a 2 px gap in the raised-surface colour inside a 4 px '
        'ring, as shadow layers. `focusRingInset` cannot be a `BoxShadow`, so '
        'it is a 2 px inside border. `focusOutline` is drawn outside the box, '
        '`focusOffset` away from it.',
  ),
  _ClassSpec(
    'FermanMotionTokens',
    TokenAxis.motion,
    'Durations and easing curves (effects.css). Motion is short and eases '
        'out, never bouncy.',
  ),
  _ClassSpec(
    'FermanZTokens',
    TokenAxis.none,
    'Stacking order (effects.css). Flutter has no z-index: use these to order '
        'overlays and stack children.',
  ),
  _ClassSpec(
    'FermanPageFilterTokens',
    TokenAxis.page,
    'The reading-comfort page filter.\n\n'
        'Apply `ColorFilter.matrix(pageFilter)` to the rendered page only, '
        'never to chrome, and never when printing or saving.',
  ),
  _ClassSpec(
    'FermanHatchTokens',
    TokenAxis.none,
    'Stripe patterns that the design draws in component CSS rather than as '
        'tokens.\n\n'
        'They come from `tools/tokens/supplement.yaml`, where each entry cites '
        'the design file and line it was copied from.',
  ),
];

final _rampName = RegExp(r'^(ink|seal|paper|soot|green|amber|red)-\d+$');

/// The name prefixes of the on-page mark colours (ADR 0012, DESIGN_INVENTORY
/// §6): edit marks, missing glyphs, redaction, search, form fields, compare,
/// OCR, translation and overflow. `--page-bg` is the one other page mark.
const List<String> pageMarkColorPrefixes = [
  'edit-',
  'glyph-',
  'redact-',
  'search-',
  'form-field-',
  'diff-',
  'ocr-',
  'translated-',
  'overflow-',
];

/// The environments that make a colour theme-dependent: those of every
/// [TokenAxis.theme] instance except the light default.
final Set<TokenEnvironment> _themeEnvironments = {
  for (final instance in instancesFor(TokenAxis.theme))
    if (instance.environment != TokenEnvironment.light) instance.environment,
};
final _sizeStep = RegExp(r'^(?:\dx[sl]|xs|sm|md|lg|xl)$');

/// One token after cascade, resolution and classification.
final class TokenInfo {
  /// Creates a token description.
  new({
    required this.name,
    required this.declarations,
    required this.resolved,
    required this.values,
    required this.declaredIn,
  });

  /// The CSS name without `--`.
  final String name;

  /// The declaration in effect per environment.
  final Map<TokenEnvironment, CssDeclaration> declarations;

  /// The resolved value per environment.
  final Map<TokenEnvironment, String> resolved;

  /// The typed value per environment.
  final Map<TokenEnvironment, TokenValue> values;

  /// The environments other than light that declare the token themselves.
  final Set<TokenEnvironment> declaredIn;

  /// The typed light (default) value.
  TokenValue get value => values[TokenEnvironment.light]!;

  /// The environments in which the token resolves differently from light.
  Set<TokenEnvironment> get variesIn => {
    for (final MapEntry(key: env, value: text) in resolved.entries)
      if (text != resolved[TokenEnvironment.light]) env,
  };

  /// Whether a theme environment other than light redeclares the token or
  /// resolves it differently (see the placement rules in this library).
  bool get isThemeDependent =>
      declaredIn.any(_themeEnvironments.contains) ||
      variesIn.any(_themeEnvironments.contains);
}

/// The resolved tokens and the Dart classes generated from them.
final class TokenModel {
  new _(this.cascade, this.tokens, this.classes);

  /// Resolves, classifies and groups every token in [cascade], and adds the
  /// [supplement] entries.
  ///
  /// Throws a [TokenException] on any value that cannot be resolved, typed
  /// or placed.
  factory build(TokenCascade cascade, Supplement supplement) {
    final resolvers = {
      for (final env in TokenEnvironment.values)
        env: VarResolver(cascade.effective(env), environment: env),
    };
    final tokens = <String, TokenInfo>{};
    for (final name in cascade.names) {
      final declarations = <TokenEnvironment, CssDeclaration>{};
      final resolved = <TokenEnvironment, String>{};
      final values = <TokenEnvironment, TokenValue>{};
      for (final env in TokenEnvironment.values) {
        final declaration = resolvers[env]!.declarations[name]!;
        declarations[env] = declaration;
        resolved[env] = resolvers[env]!.resolve(name);
        try {
          values[env] = classifyToken(
            name,
            resolved[env]!,
            kindHint: declaration.kindHint,
          );
        } on TokenException catch (error) {
          throw TokenException(
            '${declaration.location}: $error (in ${env.name})',
          );
        }
      }
      tokens[name] = TokenInfo(
        name: name,
        declarations: declarations,
        resolved: resolved,
        values: values,
        declaredIn: {
          for (final env in TokenEnvironment.values)
            if (env != TokenEnvironment.light &&
                cascade.declared[env]!.containsKey(name))
              env,
        },
      );
    }

    final fieldsByClass = {
      for (final spec in _classSpecs) spec.name: <DartField>[],
    };
    final specs = {for (final spec in _classSpecs) spec.name: spec};
    for (final token in tokens.values) {
      final (className, fieldName) = _place(token);
      final spec = specs[className]!;
      final instances = instancesFor(spec.axis);
      _checkAxis(token, spec);
      fieldsByClass[className]!.add(
        _field(token, fieldName, instances, cascade),
      );
    }
    fieldsByClass['FermanTypeTokens']!.addAll(_heights(tokens));
    fieldsByClass['FermanHatchTokens']!.addAll(
      supplement.hatchFields(resolvers[TokenEnvironment.light]!),
    );

    final classes = <DartClass>[];
    for (final spec in _classSpecs) {
      final fields = fieldsByClass[spec.name]!
        ..sort((a, b) => naturalCompare(a.name, b.name));
      for (var i = 1; i < fields.length; i++) {
        if (fields[i].name == fields[i - 1].name) {
          final first = fields[i - 1].cssNames.first;
          final second = fields[i].cssNames.first;
          throw TokenException(
            '${spec.name}.${fields[i].name} comes from both --$first and '
            '--$second',
          );
        }
      }
      if (fields.isEmpty) continue;
      classes.add(
        DartClass(
          name: spec.name,
          doc: spec.doc.split('\n\n'),
          instances: instancesFor(spec.axis),
          fields: List.unmodifiable(fields),
        ),
      );
    }
    return TokenModel._(cascade, tokens, List.unmodifiable(classes));
  }

  /// The merged token declarations.
  final TokenCascade cascade;

  /// Every token by CSS name (without `--`), in first-declared order.
  final Map<String, TokenInfo> tokens;

  /// The generated classes in output order.
  final List<DartClass> classes;

  /// The class called [name]; throws a [StateError] if there is none.
  DartClass classNamed(String name) => classes.firstWhere(
    (c) => c.name == name,
    orElse: () => throw StateError('no generated class $name'),
  );
}

(String, String) _place(TokenInfo token) {
  final name = token.name;
  final segments = name.split('-');
  if (name.startsWith('focus-')) return ('FermanFocusTokens', camelCase(name));
  switch (token.value) {
    case ShadowValue():
      return ('FermanElevationTokens', camelCase(name));
    case ColorValue():
      if (_rampName.hasMatch(name) || name.startsWith('annot-')) {
        return ('FermanRampTokens', camelCase(name));
      }
      if (token.isThemeDependent) {
        return ('FermanColorTokens', camelCase(name));
      }
      if (name == 'page-bg' || pageMarkColorPrefixes.any(name.startsWith)) {
        return ('FermanPageColorTokens', camelCase(name));
      }
      throw TokenException(
        '${token.declarations[TokenEnvironment.light]!.location}: --$name is '
        'the same in every theme, so it would be an on-page mark, but its '
        'name is not a page-mark name. Redeclare it for '
        '${_themeEnvironments.map((env) => env.selector).join(', ')} if it is '
        'a UI colour, or add its prefix to pageMarkColorPrefixes in '
        'tools/tokens/lib/src/model.dart if it is drawn on the page',
      );
    case FilterValue():
      return ('FermanPageFilterTokens', camelCase(name));
    case DurationValue() || CubicValue():
      return ('FermanMotionTokens', camelCase(name));
    case IntegerValue():
      return ('FermanZTokens', camelCase(name));
    case FontShorthandValue():
      final role = name.startsWith('type-') ? name.substring(5) : name;
      return ('FermanTypeRoleTokens', camelCase(role));
    case FontStackValue() ||
        FontFeaturesValue() ||
        FontWeightValue() ||
        EmValue():
      return ('FermanTypeTokens', camelCase(name));
    case LengthValue():
      final step = segments.length == 2 && _sizeStep.hasMatch(segments[1]);
      if (segments.first == 'text' && step) {
        return ('FermanTypeTokens', camelCase('size-${segments[1]}'));
      }
      if (segments.first == 'leading' && step) {
        return ('FermanTypeTokens', camelCase(name));
      }
      if (segments.first == 'space') {
        return ('FermanSpaceTokens', camelCase(name));
      }
      if (segments.contains('radius')) {
        return ('FermanRadiusTokens', camelCase(name));
      }
      if (name.startsWith('border-width')) {
        return ('FermanBorderTokens', camelCase(name));
      }
      if (token.declaredIn.contains(TokenEnvironment.touch) ||
          (segments.first == 'icon' && step)) {
        return ('FermanDensityTokens', camelCase(name));
      }
      return ('FermanSizeTokens', camelCase(name));
    case BorderValue():
      throw TokenException(
        '${token.declarations[TokenEnvironment.light]!.location}: '
        '--$name is a ${token.value.kind} and fits no token class',
      );
  }
}

/// Fails when [token] resolves differently in an environment that its
/// class has no instance for.
void _checkAxis(TokenInfo token, _ClassSpec spec) {
  final covered = {
    TokenEnvironment.light,
    for (final instance in instancesFor(spec.axis)) instance.environment,
  };
  final uncovered = token.variesIn.difference(covered);
  if (uncovered.isNotEmpty) {
    throw TokenException(
      '${token.declarations[TokenEnvironment.light]!.location}: '
      '--${token.name} goes into ${spec.name}, which has no instance for '
      '${uncovered.map((env) => env.selector).join(', ')}, but its value '
      'changes there',
    );
  }
}

DartField _field(
  TokenInfo token,
  String fieldName,
  List<DartInstance> instances,
  TokenCascade cascade,
) {
  final environments = instances.isEmpty
      ? const [TokenEnvironment.light]
      : [for (final instance in instances) instance.environment];
  final values = <String, String>{};
  String? type;
  for (final (index, env) in environments.indexed) {
    final mapped = mapValue(token.values[env]!, name: token.name);
    if (type != null && mapped.type != type) {
      throw TokenException(
        '--${token.name} is a $type in one environment and a ${mapped.type} '
        'in ${env.name}',
      );
    }
    type = mapped.type;
    values[instances.isEmpty ? '' : instances[index].name] = mapped.expression;
  }
  return DartField(
    name: fieldName,
    type: type!,
    doc: _fieldDoc(token, instances, environments, cascade),
    values: values,
    cssNames: [token.name],
  );
}

List<String> _fieldDoc(
  TokenInfo token,
  List<DartInstance> instances,
  List<TokenEnvironment> environments,
  TokenCascade cascade,
) {
  // The first comment in effect; an overriding declaration without one keeps
  // the comment of the declaration it replaced.
  final comment = [
    for (final env in environments) token.declarations[env]!,
    for (final env in environments)
      ...?cascade.replaced[env]![token.name]?.reversed,
  ].map((d) => d.comment).nonNulls.firstOrNull;
  final summary = comment == null
      ? '`--${token.name}`.'
      : '`--${token.name}`: ${_sentence(comment)}';

  // Group the instances by the declaration in effect.
  final groups = <String, List<int>>{};
  for (final (index, env) in environments.indexed) {
    (groups['${token.declarations[env]!.location}'] ??= []).add(index);
  }
  final String source;
  if (groups.length == 1) {
    final declaration = token.declarations[environments.first]!;
    final resolvedDiffer =
        environments.map((env) => token.resolved[env]).toSet().length > 1;
    source =
        'Source: `${declaration.value}` (${declaration.location}).'
        '${resolvedDiffer ? ' Resolved separately for each instance.' : ''}';
  } else {
    final parts = <String>[];
    for (final MapEntry(key: location, value: indices) in groups.entries) {
      final labels = indices.map((i) => instances[i].label).join(' and ');
      final value = token.declarations[environments[indices.first]]!.value;
      parts.add('$labels: `$value` ($location).');
    }
    source = parts.join(' ');
  }

  final overrides = [
    for (final env in environments)
      for (final replaced
          in cascade.replaced[env]![token.name] ?? const <CssDeclaration>[])
        'Overrides `${replaced.value}` (${replaced.location}).',
  ];

  final dropped = switch (token.value) {
    FontStackValue(:final families) => splitFontStack(families).dropped,
    _ => const <String>[],
  };
  final details = [source, ...overrides].join(' ');
  return [
    // Without a comment, the name and its source share one paragraph.
    if (comment == null) '$summary $details' else ...[summary, details],
    if (dropped.isNotEmpty)
      'Dropped (not bundled): ${dropped.map((f) => '`$f`').join(', ')}.',
  ];
}

/// `heightXs = leadingXs / sizeXs` for every size step with both tokens.
List<DartField> _heights(Map<String, TokenInfo> tokens) {
  final fields = <DartField>[];
  for (final token in tokens.values) {
    final segments = token.name.split('-');
    if (segments.length != 2 || segments.first != 'leading') continue;
    final size = tokens['text-${segments[1]}'];
    final leading = token.value;
    if (size == null || leading is! LengthValue) continue;
    final sizeValue = size.value;
    if (sizeValue is! LengthValue || sizeValue.px == 0) continue;
    final bothWhole =
        leading.px == leading.px.roundToDouble() &&
        sizeValue.px == sizeValue.px.roundToDouble();
    final expression = bothWhole
        ? '${leading.px.round()} / ${sizeValue.px.round()}'
        : dartNumber(leading.px / sizeValue.px);
    final doc =
        '`--${token.name}` / `--${size.name}`: the line height as a '
        '`TextStyle.height` ratio ($expression).';
    fields.add(
      DartField(
        name: camelCase('height-${segments[1]}'),
        type: 'double',
        doc: [doc],
        values: {'': expression},
        cssNames: [token.name, size.name],
      ),
    );
  }
  return fields;
}

String _sentence(String text) {
  final trimmed = text.trim();
  return RegExp(r'[.!?]$').hasMatch(trimmed) ? trimmed : '$trimmed.';
}
