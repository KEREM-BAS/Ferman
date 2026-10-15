import 'package:ferman/design/theme/ferman_theme.dart';
import 'package:ferman/design/tokens.g.dart';
import 'package:flutter/foundation.dart';
// Theme lives in the Material library; app/lib/design/ is one of the two
// places allowed to import it (S6).
import 'package:flutter/material.dart';

/// Resolves the [FermanTheme] of the nearest [Theme] for the environment
/// below it, and sets the design's base text style (`.fm-root` in
/// `base.css`).
///
/// It reads:
///
/// - the UI locale (`Localizations.localeOf`), for the type roles, the CJK
///   overrides and the text locale of every style;
/// - `MediaQuery.disableAnimationsOf`, for the reduced-motion durations;
/// - [touch], for the touch density instead of the desktop one;
/// - [pageDim], for the dim page filter.
///
/// Below it, `context.ferman` gives the resolved theme, the default text
/// style is the body role in `textPrimary` with the UI font features, and
/// the icon theme takes `textPrimary` (the design's `currentColor`) and the
/// density's medium icon size.
///
/// The app puts one scope inside `MaterialApp.builder`, under the
/// localizations and the animated theme, so a theme switch animates the
/// resolved values too, and sets [touch] from the platform
/// ([isTouchPlatform]). The scope itself never looks at the platform, so
/// widget tests, which run as Android by default, keep the desktop sizes
/// unless they ask for touch. Tests can put it anywhere: without a Ferman
/// theme above, it starts from [FermanTheme.light] or [FermanTheme.dark]
/// for the ambient brightness.
class FermanThemeScope extends StatelessWidget {
  /// Creates a scope around [child].
  const new({
    required this.child,
    super.key,
    this.touch = false,
    this.pageDim = false,
  });

  /// The widget below this scope.
  final Widget child;

  /// Whether to use the touch density (`data-density="touch"`, 44 px
  /// targets) instead of the desktop density.
  final bool touch;

  /// Whether PDF pages take the dim filter (`data-page="dim"`).
  final bool pageDim;

  /// Whether [platform] gets the touch density: iOS and Android, phones and
  /// tablets. Desktop systems keep the dense desktop sizes; the density is
  /// chosen by platform, not by `VisualDensity` (ADR 0012).
  static bool isTouchPlatform(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => false,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = FermanTheme.of(context).resolve(
      locale: Localizations.maybeLocaleOf(context),
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      touch: touch,
      pageDim: pageDim,
    );
    return Theme(
      data: theme.copyWith(
        extensions: [
          for (final extension in theme.extensions.values)
            if (extension is! FermanTheme) extension,
          resolved,
        ],
        iconTheme: theme.iconTheme.copyWith(
          color: resolved.colors.textPrimary,
          size: resolved.density.iconMd,
        ),
      ),
      child: DefaultTextStyle(
        style: resolved.typography.body.copyWith(
          color: resolved.colors.textPrimary,
          fontFeatures: FermanTypeTokens.featuresUi,
        ),
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('touch', value: touch, ifTrue: 'touch'))
      ..add(FlagProperty('pageDim', value: pageDim, ifTrue: 'pageDim'));
  }
}
