import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
// The theme the app installs is a Material ThemeData that carries the
// Ferman extension; nothing else from Material is used.
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart' hide Icon;

/// Wraps [child] in what a Ferman component has inside the app: media
/// query, localizations ([locale]), the light or dark theme
/// ([brightness]), the resolved Ferman theme scope, text direction (from
/// the locale unless [textDirection] is given) and an [Overlay] for
/// tooltips and popovers.
///
/// [forcedStates] wraps the child in a [FermanForcedStates]. The child is
/// centred, so it takes its own size.
Widget componentHost(
  Widget child, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  TextDirection? textDirection,
  bool disableAnimations = false,
  Set<WidgetState>? forcedStates,
  Size size = const Size(800, 600),
}) {
  final direction =
      textDirection ??
      (locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr);
  Widget content = Center(child: child);
  if (forcedStates != null) {
    content = FermanForcedStates(states: forcedStates, child: content);
  }
  return MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: disableAnimations),
    child: Localizations(
      locale: locale,
      delegates: AppLocalizations.localizationsDelegates,
      child: Theme(
        data: brightness == Brightness.dark
            ? FermanMaterialTheme.dark
            : FermanMaterialTheme.light,
        child: Directionality(
          textDirection: direction,
          child: FermanThemeScope(child: Overlay.wrap(child: content)),
        ),
      ),
    ),
  );
}
