# tools/tokens

Generates `app/lib/design/tokens.g.dart` from the CSS custom properties in `design/`
([ADR 0012](../../docs/adr/0012-design-token-pipeline.md)). Pure Dart; no Flutter needed to run it.

```sh
cd tools/tokens
dart pub get
dart run bin/tokens.dart           # write app/lib/design/tokens.g.dart (only if it changed)
dart run bin/tokens.dart --check   # write nothing; exit 1 if the file is missing or stale
dart test
```

`dart run tokens [options]` runs the same program, and plain `dart run` writes the file, but
`dart run --check` does not work: `dart run` reads the flag as its own option. `--root <dir>` points
at another checkout (`--root ../..` is this one); by default the repository root is the nearest
parent directory that holds `design/` and `tools/tokens/`. Exit codes: 0 success, 1 stale
(`--check`), 2 the token sources cannot be generated, 64 bad usage.

## Inputs

In the order the design loads them, last declaration wins per environment:
`design/_ds/<design system>/tokens/{fonts,colors,typography,spacing,effects,base}.css`, then
`design/ds-additions/fm-additions.css` ([G05](../../docs/DESIGN_GAPS.md#g05)). `fonts.css` and
`base.css` declare no tokens; they are read so the counts prove it. `supplement.yaml` holds the two
hatch patterns that the design draws in component CSS; each entry cites its file and line, and the
generator fails if the cited line no longer contains the CSS. `design/` is only read.

The CSS holds 348 custom-property declarations and 269 unique names (238 in the design system, 31
new in the additions, which also override 3). The tests assert the count per file and environment.

## Pipeline

`css.dart` tokenizer (comments, `@kind` hints, strings, `@media`) → `cascade.dart` environments
(light `:root`, dark, dim, touch, CJK, reduced motion; each is light plus its own overrides) →
`resolver.dart` `var()` per environment with a cycle guard → `classifier.dart` typed values →
`model.dart` placement into classes → `mappers.dart` Dart constants → `emitter.dart` → `dart format`
(the SDK's formatter, run as if on the output path, so CI's format check agrees).

The build stops on any unresolved `var()`, value it cannot type, token that fits no class, token
that changes in an environment its class has no instance for, two tokens with one Dart name, or a
colour that would be filed as a page mark without a page-mark name (see below).

## Colour placement

1. Ramp steps (`--ink-600`, `--paper-25`, …) and `--annot-*` go to `FermanRampTokens`.
2. A colour is **theme-dependent** if and only if a theme environment other than light (today only
   `[data-theme="dark"]`) redeclares it, even to the same value, or it resolves differently there
   (an alias of a redeclared colour). Theme-dependent colours go to `FermanColorTokens` with `light`
   and `dark` instances.
3. Every other colour is the same in all themes and goes to `FermanPageColorTokens`, but only if its
   name is a page-mark name: `--page-bg` or a prefix in `pageMarkColorPrefixes` (`edit-`, `glyph-`,
   `redact-`, `search-`, `form-field-`, `diff-`, `ocr-`, `translated-`, `overflow-`), the set ADR
   0012 names. Otherwise the run stops, so a new UI colour that happens to be equal in both themes
   is never filed as a page mark without notice: redeclare it for dark or extend the prefix list.

## Font families and `app/pubspec.yaml`

`test/pubspec_fonts_test.dart` checks every family that a token font stack or `font` shorthand
names: it must be either kept (in `bundledFontFamilies`) and declared under `flutter: fonts:` in
`app/pubspec.yaml`, or deliberately dropped (not in `bundledFontFamilies`, not declared, listed in
the field's doc comment). While `app/pubspec.yaml` has no fonts section, that test is skipped with a
`SKIP:` reason; the unit tests of the check itself always run.

## Mapping rules

- Colours: `Color(0xAARRGGBB)`. Alpha byte = alpha × 255 rounded half up, computed exactly on the
  decimal digits (`0.70` → `0xB3`, `0.07` → `0x12`).
- Lengths: `double` logical pixels. `em` tracking: a factor, `letterSpacing = em × fontSize`.
- Durations: `Duration`; `cubic-bezier()`: `Cubic`; weights: `FontWeight.wNNN`; z-index: `int`.
- Font stacks: `FermanFontStack(family, fallback)` keeping only the bundled families (IBM Plex
  Sans, Sans Arabic, Sans Hebrew, Sans Devanagari, Mono, Serif); everything else is dropped and
  listed in the field's doc comment.
- `font` shorthand: `TextStyle` with size, weight, family, `height = line height / size` and
  `TextLeadingDistribution.even`. A shorthand without a line height (or with `/normal`) leaves
  `height` null, so the font's own metrics set the line height, as CSS `normal` does; the generator
  never invents a ratio such as 1.2. Every `--type-*` token in the design gives a line height today.
- Shadows: `List<BoxShadow>`, layers reversed (CSS paints the first on top, Flutter the last),
  `blurRadius = (blur / 2 - 0.5) / 0.57735` clamped at 0 so the Gaussian sigma matches,
  `0 0 0 1px` rings become spread 1 with no blur, negative spreads kept. An inset ring becomes an
  inside `BorderSide`; an outline becomes an outside `BorderSide`.
- `--page-filter`: one 5×4 colour matrix for `ColorFilter.matrix` (offsets in 0–255), composed
  from the filter functions left to right; `none` is `null`.

## Output naming (for `theme.dart`)

Field names are the CSS name without `--` in lowerCamelCase; two numeric segments join with `_`
(`--space-1-5` → `space1_5`). Two renames avoid kebab collisions: `--text-<size>` →
`FermanTypeTokens.size<Size>` and `--type-<role>` → `FermanTypeRoleTokens.<role>`. Fields are
sorted naturally. Classes with instances have a `const` constructor, the instances as static
constants and an instance `lerp(other, t)` for `ThemeExtension.lerp`. Classes without instances are
`abstract final` holders of static constants. The generated classes are plain value classes (the
file imports only `flutter/painting` and `flutter/animation`) and have no `copyWith`;
`app/lib/design/theme.dart` wraps them in `ThemeExtension`s and supplies `copyWith`.

| Class | Instances | Holds |
|---|---|---|
| `FermanRampTokens` | static | ink, seal, paper, soot, green, amber, red ramps; `annot*` palette |
| `FermanColorTokens` | `light`, `dark` | semantic UI colours (surface, text, icon, border, accent, status, `pageBorder`, `winCloseHover`) |
| `FermanPageColorTokens` | static | on-page marks, unchanged in dark (edit, glyph, redact, search, form field, diff, OCR, translated, overflow, `pageBg`) |
| `FermanTypeTokens` | static | `size*`, `leading*`, `height*`, `weight*`, `tracking*`, `numericTabular`, `featuresUi`, `font*` stacks |
| `FermanTypeRoleTokens` | `standard`, `cjk` | `TextStyle` roles: `body`, `bodyStrong`, `label`, `caption`, `prose`, `panelTitle`, `dialogTitle`, `headline`, `mono`, `wordmark` |
| `FermanSpaceTokens` | static | `space0` … `space16` |
| `FermanDensityTokens` | `desktop`, `touch` | control heights, `controlPadX`, `icon*`, `hitMin`, bar heights |
| `FermanSizeTokens` | static | layout widths, document tabs, Windows caption, edit-mark geometry, mobile bars |
| `FermanRadiusTokens` | static | `radius*`, `sheetRadius` |
| `FermanBorderTokens` | static | `borderWidth`, `borderWidthStrong` |
| `FermanElevationTokens` | `light`, `dark` | `shadow*` as `List<BoxShadow>` |
| `FermanFocusTokens` | `light`, `dark` | `focusRing`, `focusRingInset`, `focusOutline`, `focusOffset` |
| `FermanMotionTokens` | `standard`, `reduced` | `dur*`, `ease*` |
| `FermanZTokens` | static | `z*` |
| `FermanPageFilterTokens` | `standard`, `dim` | `pageFilter` matrix |
| `FermanHatchTokens` | static | `redactPending`, `thumbLines` (from `supplement.yaml`) |

`FermanFontStack`, `FermanHatch` and `FermanHatchStripe` are the generated value types.
