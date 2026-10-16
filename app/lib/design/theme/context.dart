import 'package:ferman/design/theme/ferman_theme.dart';
import 'package:flutter/widgets.dart';

/// `context.ferman`: the design tokens at a [BuildContext].
extension FermanThemeContext on BuildContext {
  /// The [FermanTheme] at this context, resolved by the nearest
  /// `FermanThemeScope` for the locale, the density and reduced motion.
  ///
  /// For example `context.ferman.colors.textPrimary`,
  /// `context.ferman.typography.body`, `context.ferman.space.space2` or
  /// `context.ferman.motion.durFast`. Registers this context for rebuilds
  /// when the theme changes.
  FermanTheme get ferman => FermanTheme.of(this);
}
