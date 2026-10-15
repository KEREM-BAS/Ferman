/// The Ferman theme: the design tokens of `tokens.g.dart` wrapped for
/// widgets (ADR 0012).
///
/// - `FermanTheme`, a `ThemeExtension` with every token set: colours,
///   shadows and focus ring (light, dark), density (desktop, touch), motion
///   (standard, reduced), the page filter (none, dim) and the type roles for
///   the UI locale (standard, CJK), plus views of the constant sets
///   (spacing, radii, sizes, borders, z order, ramps, page colours, type
///   scale, hatches).
/// - `context.ferman`, the `BuildContext` extension widgets read it with.
/// - `FermanThemeScope`, which resolves the theme for the locale, the
///   platform's density and the system's reduced-motion setting, and sets
///   the base text style.
/// - `FermanMaterialTheme`, the light and dark `ThemeData` that carry the
///   extension, with the minimum Material settings the framework reads.
/// - `FermanTypography` and `FermanFontFamilies`: the type roles per locale,
///   the font chain per script and the system CJK families (ADR 0013).
///
/// Widgets read tokens only through `context.ferman` and never hard-code
/// colours, sizes, radii or durations; `tools/checks` enforces that outside
/// `app/lib/design/` (S6). The generated constants are exported for the
/// design system itself; outside it, reading a set that varies (colours,
/// shadows, focus, density, motion, page filter, type roles) from its
/// constant instead of `context.ferman` fails the `theme-bypass` rule,
/// because it would ignore dark mode, touch density, reduced motion or the
/// locale.
library;

export 'package:ferman/design/theme/context.dart';
export 'package:ferman/design/theme/ferman_theme.dart';
export 'package:ferman/design/theme/material_theme.dart';
export 'package:ferman/design/theme/static_tokens.dart';
export 'package:ferman/design/theme/theme_scope.dart';
export 'package:ferman/design/theme/typography.dart';
export 'package:ferman/design/tokens.g.dart';
