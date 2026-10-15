# ADR 0012: Design token pipeline

- **Status:** Accepted (brief)
- **Date:** 2026-10-14
- **Approval:** brief §6
- **Supersedes:** none
- **Superseded by:** none

## Context

The brief: "tools/tokens reads the tokens in design/ and generates app/lib/design/tokens.g.dart, exposed
through ThemeExtension. Never hardcode colours, sizes, radii or durations in widgets."
([brief §6](../BRIEF.md)). Visuals must match the artboards ([brief §2](../BRIEF.md)), and design/ is
read-only.

The tokens are CSS custom properties in two places:

- `design/_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/tokens/`: `colors.css`,
  `typography.css`, `spacing.css` and `effects.css` (`fonts.css` and `base.css` declare none).
- `design/ds-additions/fm-additions.css`, loaded **after** the design system. It adds 31 tokens (edit
  marks, editor chrome sizes, on-page marks, mobile sizes, script fonts) and overrides 3: `--edit-changed`
  and `--edit-changed-bg` (teal to ink 600, fix f3) and `--font-ui` (extended script stack). It also
  sets CJK leading overrides. These are not merged into the design-system files
  ([G05](../DESIGN_GAPS.md#g05)), so a generator that reads only `tokens/*.css` would produce wrong values.

Counts from discovery: 348 declarations, 269 unique names (238 design system plus 31 additions).
Environments: light (`:root`), dark (`[data-theme="dark"]`, 48 colour and 5 shadow overrides), page dim
(`[data-page="dim"]`, one filter), touch density (`[data-density="touch"]`, 12 overrides), reduced motion
(`@media (prefers-reduced-motion: reduce)`, all durations 0) and CJK (`[lang|="ja"]`, `[lang|="zh"]`,
`[lang|="ko"]`, taller leading).

Mapping problems the generator must solve: about 40 rgba overlays, multi-layer shadows with hairline
rings, a two-layer focus ring and an inset variant, cubic-bezier easings, the CSS `font` shorthand,
`var()` chains (up to two levels, some only resolving differently in dark), the page dim filter, hatch
patterns drawn in component CSS, em-based letter spacing, unitless values, and name collisions in the
kebab-case namespace (`--text-*`, `--icon-*` and `--border-*` hold both colours and sizes). The
guidelines folder is missing from the export ([G03](../DESIGN_GAPS.md#g03)), and there is no
high-contrast token set ([G23](../DESIGN_GAPS.md#g23)).

## Decision

### The generator

- `tools/tokens` is a small **Dart** command-line program, so contributors need no extra runtime beyond
  Flutter. It is run with `dart run` from the repository and tested with `dart test`.
- It reads, in this order, matching the design's cascade: `colors.css`, `typography.css`, `spacing.css`,
  `effects.css`, then `ds-additions/fm-additions.css`. Last declaration wins per selector.
- It uses a hand-written tokenizer for this regular subset of CSS: strip `@import`, unwrap the
  reduced-motion `@media` block, split declarations at top-level semicolons (rgba and cubic-bezier hold
  commas), keep the trailing comment as documentation and read its `@kind` hint.
- It reads only these CSS files. The app never reads anything from design/ at run time, and nothing from
  design/ ships ([brief §2](../BRIEF.md)).

### Environments and resolution

- Environments are merged first, then `var()` chains are resolved recursively per environment with a
  cycle guard: light; dark = light + dark blocks; touch = light + touch block; dim; CJK type overrides;
  reduced motion. This matters for the focus ring and the page shadow, whose inputs change in dark.
- Output holds resolved constants, with the source alias kept in a doc comment.

### Value mapping

| CSS | Dart |
|---|---|
| `#RRGGBB`, `rgba(…)` | `Color`; alpha is rounded with one documented rule (round half up) and tested |
| `Npx`, unitless 0 | `double` |
| `Nem` letter spacing | a factor applied per text style (`em × fontSize`) |
| `Nms` | `Duration` |
| `cubic-bezier(a, b, c, d)` | `Cubic(a, b, c, d)` |
| weights 400, 500, 600 | `FontWeight.w400`, `w500`, `w600` |
| font stack | `fontFamily` plus `fontFamilyFallback`; generic CSS keywords dropped; families must match `pubspec.yaml` ([ADR 0013](0013-fonts-and-icons.md)) |
| `font` shorthand | `TextStyle` with size, weight, family and `height = lineHeight / size`, `leadingDistribution: even` |
| shadow list | `List<BoxShadow>` in reverse order (CSS paints the first layer on top, Flutter the last); a `0 0 0 1px` ring becomes spread 1, blur 0; negative spreads kept; blur converted to Flutter's sigma |
| focus ring | both layers per theme; the inset variant becomes an inside border, since `BoxShadow` cannot be inset |
| `brightness() contrast() sepia()` (page dim) | one composed `ColorFilter.matrix`, applied to the page widget only, never to chrome |
| z-index | `int` constants for overlay ordering |
| `--radius-full: 999px` | a pill shape |

Hatch patterns (pending redaction stripes, thumbnail text lines) and a few component-level dark tweaks
are not tokens in the design. The generator takes them from a small supplement file in `tools/tokens`,
where each value cites the design file and line it came from. They are emitted with the tokens, so
widgets still never hard-code them.

### Output

`app/lib/design/tokens.g.dart`, deterministic and sorted, with a header saying it is generated and must
not be edited. It imports only `package:flutter/animation.dart` and `package:flutter/painting.dart` and
holds plain `const` value classes named `Ferman*Tokens`, not `ThemeExtension`s. A class whose values
change in some environment has a `const` constructor, one static instance per variant (in brackets
below) and an instance `lerp(other, t)` ready for `ThemeExtension.lerp`; the others are static
constants only. The classes, as built in M1:

- `FermanRampTokens` (static): the colour ramps (ink, seal, paper, soot, status) and the `annot*`
  palette.
- `FermanColorTokens` [`light`, `dark`]: the semantic UI colours, such as `textPrimary`,
  `iconPrimary`, `borderSubtle`, `pageBorder` and `winCloseHover`.
- `FermanPageColorTokens` (static): on-page marks tuned for white paper (edit marks, missing glyph,
  redaction, search, form fields, diff, OCR, translation, overflow, page background). They **do not
  change in dark mode**, so they are a separate constant class, not part of the themed colours; the
  run fails if one of them varies in dark.
- `FermanTypeTokens` (static): `size*`, `leading*`, `height*` (leading divided by size), `weight*`,
  `tracking*` (em factors), `numericTabular`, `featuresUi`, and the `font*` stacks as
  `FermanFontStack(family, fallback)`.
- `FermanTypeRoleTokens` [`standard`, `cjk`]: the 10 type roles as `TextStyle`s with even leading
  distribution.
- `FermanSpaceTokens` (static); `FermanDensityTokens` [`desktop`, `touch`]: control heights, padding,
  icon sizes, the minimum hit size and bar heights, chosen by platform, not by `VisualDensity`.
- `FermanSizeTokens`, `FermanRadiusTokens` and `FermanBorderTokens` (static), including the additions'
  sizes (edit-box label, thumbnail badge, document tab, Windows caption width, mobile bars).
- `FermanElevationTokens` [`light`, `dark`]: `shadow*` as `List<BoxShadow>`.
- `FermanFocusTokens` [`light`, `dark`]: `focusRing` (shadows), `focusRingInset` (an inside
  `BorderSide`), `focusOutline` (an outside `BorderSide`) and `focusOffset`.
- `FermanMotionTokens` [`standard`, `reduced`]: `dur*` durations and `ease*` curves; `reduced` holds
  the design's reduced-motion values.
- `FermanZTokens` (static, `int`).
- `FermanPageFilterTokens` [`standard`, `dim`]: `pageFilter`, a 20-value list for
  `ColorFilter.matrix` with offsets in 0 to 255; `null` means no filter.
- `FermanHatchTokens` (static): `redactPending` and `thumbLines`, as `FermanHatch` and
  `FermanHatchStripe` values from the supplement file.
- Names: `--` stripped, lowerCamelCase, half steps such as `--space-1-5` become `space1_5`, and fields
  are sorted with numbers in order (`ink50` before `ink100`). Two renames avoid the colliding prefixes:
  `--text-<size>` becomes `FermanTypeTokens.size<Size>` and `--type-<role>` becomes
  `FermanTypeRoleTokens.<role>`.
- Generated constructors use Dart 3.13's `const new(...)` form, which very_good_analysis 11 requires;
  callers still write `FermanColorTokens(...)`.

Rules the generator follows, each covered by a test:

- It reads the design's `styles.css` order (fonts, colors, typography, spacing, effects, base), then
  `fm-additions.css`. `fonts.css` and `base.css` declare no custom properties.
- Alpha is `alpha × 255` rounded half up, computed exactly on the decimal digits (0.70 → `0xB3`,
  0.07 → `0x12`).
- The dim page matrix is composed left to right without clamping between steps. This only affects
  near-black, which ends at 0 either way.
- `--font-doc-cjk` and `--font-hand-1` to `--font-hand-3` have no bundled family, so their `family` is
  `null` and the platform default applies.

`app/lib/design/theme.dart` (hand-written) wraps these classes in `ThemeExtension`s, supplies their
`copyWith` (the generated classes have none), and wires light, dark, dim, touch, CJK and reduced
motion into the app's theme. Reduced motion is taken when `MediaQuery.disableAnimationsOf` is true.

### Checks

- Unit tests assert the counts (348 declarations, 269 unique names) and spot values: dark
  `surfaceCanvas` is `0xFF0E0E0D`; `editChanged` is `0xFF2A4DAF` (the additions override); the body
  type role has height 18/13; the dark focus-ring gap is `0xFF1D1C1B`.
- The build fails on any unresolved `var()` or any value the classifier cannot type.
- **CI regenerates `tokens.g.dart` and fails if the committed file differs**
  ([ADR 0017](0017-testing-and-ci.md)).
- A CI script fails when widget code outside `app/lib/design/` uses literal colours, durations, radii or
  sizes (for example `Color(0x…)`, `Duration(milliseconds: …)`, `BorderRadius.circular(<number>)`), with
  a small reviewed allow-list for things like `0` and `1`.

### What the pipeline does not invent

There is no high-contrast token set in the design ([G23](../DESIGN_GAPS.md#g23)). The generator leaves
room for one but does not invent values; the UI follows the OS high-contrast and reduced-motion signals
where the tokens allow, and the gap stays open until the design adds a set.

## Consequences

### Positive

- One source of truth for every visual value, matching the design exactly, including the additions.
- Light, dark, touch, dim, CJK and reduced motion come from the same file and cannot drift.
- Design updates (a re-export, [Q11](../QUESTIONS.md#q11)) become a regenerate-and-review step.

### Negative

- A custom parser to maintain. It is small because the CSS subset is regular, and tests pin its output.
- Shadows and blur cannot match CSS pixel for pixel; small differences are accepted and checked against
  the design references ([ADR 0017](0017-testing-and-ci.md)).
- The supplement file is a second, hand-maintained source. Each entry cites its origin, and the list is
  reviewed when the design is re-exported.

### Follow-up

- M1: the generator, its tests, `tokens.g.dart`, `theme.dart`, the CI freshness and literal-value checks.
  Built before the component library ([ADR 0011](0011-flutter-state-navigation-components.md)). The
  generator, its tests and `tokens.g.dart` exist (phase D2); `theme.dart` and the literal-value check
  come with phase F.

## Alternatives considered

- **Hand-copy values into Dart.** Fast to start, guaranteed to drift, and the brief asks for a generator.
- **Read only `tokens/*.css`.** Misses 31 tokens and gets 3 values wrong ([G05](../DESIGN_GAPS.md#g05)).
- **A full CSS parser package or a Node tool.** More than this subset needs, and a Node tool would add a
  runtime to the app build. Node stays limited to the design-reference renderer.
- **Resolve tokens at run time from bundled CSS.** Ships design files, which the brief forbids, and moves
  parsing into app start-up.
- **Material `ThemeData` colour scheme only.** Too coarse for about 120 colours and the on-page marks.

## References

- [Brief](../BRIEF.md) §2, §6
- [ARCHITECTURE.md](../ARCHITECTURE.md), sections 2.4 and 2.5
- [DESIGN_INVENTORY.md](../DESIGN_INVENTORY.md) (full token list)
- [ADR 0011](0011-flutter-state-navigation-components.md), [ADR 0013](0013-fonts-and-icons.md),
  [ADR 0017](0017-testing-and-ci.md)
- [G03](../DESIGN_GAPS.md#g03), [G05](../DESIGN_GAPS.md#g05), [G23](../DESIGN_GAPS.md#g23),
  [Q11](../QUESTIONS.md#q11)
- Artboards f3 (edit marks), f6 (Windows caption sizes)
