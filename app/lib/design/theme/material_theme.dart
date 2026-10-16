import 'package:ferman/design/theme/ferman_theme.dart';
import 'package:ferman/design/tokens.g.dart';
// ThemeData lives in the Material library; app/lib/design/ is one of the two
// places allowed to import it (S6).
import 'package:flutter/material.dart';

/// The Material [ThemeData] the app runs on, built from the tokens.
///
/// Ferman's widgets read only the [FermanTheme] extension it carries
/// (`context.ferman`). The rest is the minimum the framework itself looks
/// at, so nothing falls back to Material's blue and white: the colour
/// scheme, the canvas colour, the text selection colours, the icon theme
/// (`textPrimary`, the design's `currentColor`), the UI font family and no
/// ink splashes.
abstract final class FermanMaterialTheme {
  /// The light theme.
  ///
  /// Built on each read, so `ThemeData.platform` follows
  /// `defaultTargetPlatform` (and its test overrides); two reads are equal.
  static ThemeData get light => build(Brightness.light);

  /// The dark theme, built on each read like [light].
  static ThemeData get dark => build(Brightness.dark);

  /// Builds the theme for [brightness].
  static ThemeData build(Brightness brightness) {
    final ferman = FermanTheme.forBrightness(brightness);
    final colors = ferman.colors;
    return ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.textOnAccent,
        secondary: colors.accent,
        onSecondary: colors.textOnAccent,
        error: colors.dangerSolid,
        onError: colors.textOnAccent,
        surface: colors.surfacePanel,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.borderDefault,
        outlineVariant: colors.borderSubtle,
        inverseSurface: colors.surfaceInverse,
        onInverseSurface: colors.textInverse,
        scrim: colors.surfaceScrim,
      ),
      canvasColor: colors.surfacePanel,
      scaffoldBackgroundColor: colors.surfacePanel,
      hoverColor: colors.surfaceHover,
      splashFactory: NoSplash.splashFactory,
      fontFamily: FermanTypeTokens.fontUi.family,
      fontFamilyFallback: FermanTypeTokens.fontUi.fallback,
      iconTheme: IconThemeData(
        color: colors.textPrimary,
        size: ferman.density.iconMd,
      ),
      // base.css: `::selection { background: var(--edit-selection); }`;
      // the caret takes the text colour, as CSS's default `caret-color`.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.textPrimary,
        selectionColor: FermanPageColorTokens.editSelection,
        selectionHandleColor: colors.accent,
      ),
      extensions: [ferman],
    );
  }
}
