import 'package:ferman/design/theme/static_tokens.dart';
import 'package:ferman/design/theme/typography.dart';
import 'package:ferman/design/tokens.g.dart';
// ThemeExtension and Theme live in the Material library; app/lib/design/ is
// one of the two places allowed to import it (S6).
import 'package:flutter/material.dart';

/// Every design token, as one [ThemeExtension] that widgets read with
/// `context.ferman` (ADR 0012).
///
/// The token sets that change with the environment are fields, chosen by
/// [resolve]:
///
/// - [colors], [elevation] and [focus]: light or dark ([brightness]).
/// - [density]: desktop or touch ([FermanDensityTokens]; by platform, not
///   by `VisualDensity`).
/// - [motion]: standard or reduced; reduced when the system asks for
///   reduced motion (`MediaQuery.disableAnimationsOf`), with every duration
///   zero, as the design's `prefers-reduced-motion` block sets.
/// - [pageFilter]: none, or the dim page filter (`data-page="dim"`), a
///   per-user choice applied to PDF pages only, never to the chrome.
/// - [typography]: the type roles for the UI locale, with the CJK overrides
///   for Japanese, Korean and Chinese ([FermanTypography]).
///
/// The token sets that never change are views over the generated constants:
/// [ramps], [pageColors], [typeScale], [space], [size], [radius], [border],
/// [z] and [hatch].
///
/// [light] and [dark] are the defaults the app's `ThemeData` carries; the
/// theme scope (`FermanThemeScope`) resolves them for the locale, the
/// platform and the reduced-motion setting.
@immutable
final class FermanTheme extends ThemeExtension<FermanTheme> {
  /// Creates a theme from token sets. Prefer [light], [dark] and [resolve].
  const new({
    required this.brightness,
    required this.colors,
    required this.elevation,
    required this.focus,
    required this.density,
    required this.motion,
    required this.pageFilter,
    required this.typography,
  });

  /// The theme for [brightness]: [light] or [dark].
  factory forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The theme at [context]: the [FermanTheme] of the nearest [Theme], or
  /// [light] or [dark] for its brightness when it has none.
  ///
  /// Registers [context] for rebuilds when the theme changes.
  factory of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<FermanTheme>() ??
        FermanTheme.forBrightness(theme.brightness);
  }

  /// The light theme (`:root`): desktop density, standard motion, no page
  /// filter, the standard type roles.
  static final FermanTheme light = FermanTheme(
    brightness: Brightness.light,
    colors: FermanColorTokens.light,
    elevation: FermanElevationTokens.light,
    focus: FermanFocusTokens.light,
    density: FermanDensityTokens.desktop,
    motion: FermanMotionTokens.standard,
    pageFilter: FermanPageFilterTokens.standard,
    typography: FermanTypography.standard,
  );

  /// The dark theme (`[data-theme="dark"]`): as [light], with the dark
  /// colours, shadows and focus ring. The PDF page stays paper-white.
  static final FermanTheme dark = FermanTheme(
    brightness: Brightness.dark,
    colors: FermanColorTokens.dark,
    elevation: FermanElevationTokens.dark,
    focus: FermanFocusTokens.dark,
    density: FermanDensityTokens.desktop,
    motion: FermanMotionTokens.standard,
    pageFilter: FermanPageFilterTokens.standard,
    typography: FermanTypography.standard,
  );

  /// Light or dark.
  final Brightness brightness;

  /// Semantic UI colours: surfaces, text, icons, borders, accent, status.
  ///
  /// Translucent values such as `surfaceHover` are overlays to paint over
  /// the surface beneath.
  final FermanColorTokens colors;

  /// Shadows (`--shadow-*`).
  final FermanElevationTokens elevation;

  /// The focus ring, its inset and outline variants, and the focus offset.
  final FermanFocusTokens focus;

  /// Control heights, padding, icon sizes, the minimum hit size and bar
  /// heights, for desktop or touch.
  final FermanDensityTokens density;

  /// Durations and easing curves; every duration is zero under reduced
  /// motion.
  final FermanMotionTokens motion;

  /// The colour matrix for PDF pages: none, or the dim filter.
  final FermanPageFilterTokens pageFilter;

  /// The type roles for the UI locale (`--type-*`). Named `typography`
  /// because [ThemeExtension.type] is the extension's key.
  final FermanTypography typography;

  /// Colour ramps and the annotation palette.
  FermanRamps get ramps => const FermanRamps();

  /// On-page mark colours; the same in light and dark.
  FermanPageColors get pageColors => const FermanPageColors();

  /// Sizes, line heights, weights, tracking, font features and stacks.
  FermanTypeScale get typeScale => const FermanTypeScale();

  /// The spacing scale.
  FermanSpacing get space => const FermanSpacing();

  /// Layout sizes that do not depend on the density.
  FermanSizes get size => const FermanSizes();

  /// Corner radii.
  FermanRadii get radius => const FermanRadii();

  /// Border widths.
  FermanBorders get border => const FermanBorders();

  /// Stacking order of overlays.
  FermanLayers get z => const FermanLayers();

  /// Hatch patterns.
  FermanHatches get hatch => const FermanHatches();

  /// Whether this is the dark theme.
  bool get isDark => brightness == Brightness.dark;

  /// The filter to paint PDF pages with (`ColorFiltered`), or null for
  /// none. Never apply it to the chrome.
  ColorFilter? get pageColorFilter {
    final matrix = pageFilter.pageFilter;
    return matrix == null ? null : ColorFilter.matrix(matrix);
  }

  /// The motion set for the system's reduced-motion setting: the reduced
  /// set, every duration zero, when [reduceMotion] is true, else the
  /// standard one.
  ///
  /// [resolve] picks [motion] with it. The root widget uses it for the
  /// theme-switch animation, above `FermanThemeScope`, where
  /// `context.ferman` is not resolved yet.
  static FermanMotionTokens motionFor({required bool reduceMotion}) =>
      reduceMotion ? FermanMotionTokens.reduced : FermanMotionTokens.standard;

  /// This theme for the given environment, keeping [brightness], [colors],
  /// [elevation] and [focus]:
  ///
  /// - [locale]: the UI locale; picks the type roles and the font chain.
  /// - [reduceMotion]: the reduced-motion durations instead of the standard
  ///   ones.
  /// - [touch]: the touch density instead of the desktop density.
  /// - [pageDim]: the dim page filter.
  ///
  /// The result depends only on these arguments and the kept fields, so
  /// resolving a resolved theme again changes nothing.
  FermanTheme resolve({
    Locale? locale,
    bool reduceMotion = false,
    bool touch = false,
    bool pageDim = false,
  }) => copyWith(
    density: touch ? FermanDensityTokens.touch : FermanDensityTokens.desktop,
    motion: motionFor(reduceMotion: reduceMotion),
    pageFilter: pageDim
        ? FermanPageFilterTokens.dim
        : FermanPageFilterTokens.standard,
    typography: FermanTypography.forLocale(locale),
  );

  @override
  FermanTheme copyWith({
    Brightness? brightness,
    FermanColorTokens? colors,
    FermanElevationTokens? elevation,
    FermanFocusTokens? focus,
    FermanDensityTokens? density,
    FermanMotionTokens? motion,
    FermanPageFilterTokens? pageFilter,
    FermanTypography? typography,
  }) => FermanTheme(
    brightness: brightness ?? this.brightness,
    colors: colors ?? this.colors,
    elevation: elevation ?? this.elevation,
    focus: focus ?? this.focus,
    density: density ?? this.density,
    motion: motion ?? this.motion,
    pageFilter: pageFilter ?? this.pageFilter,
    typography: typography ?? this.typography,
  );

  /// Interpolates every token set by [t], for animated theme changes.
  /// Values that cannot be interpolated (durations, curves, the page
  /// filter, font families, the brightness) switch at t = 0.5.
  @override
  FermanTheme lerp(covariant FermanTheme? other, double t) {
    if (other == null || identical(this, other)) return this;
    return FermanTheme(
      brightness: t < 0.5 ? brightness : other.brightness,
      colors: _same(colors, other.colors) ?? colors.lerp(other.colors, t),
      elevation:
          _same(elevation, other.elevation) ??
          elevation.lerp(other.elevation, t),
      focus: _same(focus, other.focus) ?? focus.lerp(other.focus, t),
      density: _same(density, other.density) ?? density.lerp(other.density, t),
      motion: _same(motion, other.motion) ?? motion.lerp(other.motion, t),
      pageFilter:
          _same(pageFilter, other.pageFilter) ??
          pageFilter.lerp(other.pageFilter, t),
      typography: typography.lerp(other.typography, t),
    );
  }

  /// [a] when [b] is the same object, so lerping equal sets keeps the
  /// constant instances (and [==] stays true); otherwise null.
  static T? _same<T extends Object>(T a, T b) => identical(a, b) ? a : null;

  /// Equal when every token set is the same object and [typography] is
  /// equal.
  /// The generated token classes have no value equality, so a lerped set
  /// is never equal to a constant one.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FermanTheme &&
          other.brightness == brightness &&
          identical(other.colors, colors) &&
          identical(other.elevation, elevation) &&
          identical(other.focus, focus) &&
          identical(other.density, density) &&
          identical(other.motion, motion) &&
          identical(other.pageFilter, pageFilter) &&
          other.typography == typography;

  @override
  int get hashCode => Object.hash(
    brightness,
    identityHashCode(colors),
    identityHashCode(elevation),
    identityHashCode(focus),
    identityHashCode(density),
    identityHashCode(motion),
    identityHashCode(pageFilter),
    typography,
  );
}
