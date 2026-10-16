import 'package:ferman/design/theme/material_theme.dart';
import 'package:flutter/foundation.dart';
// Theme lives in the Material library; app/lib/design/ is one of the two
// places allowed to import it (S6).
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

/// Gives the widgets below it the light or dark theme, whatever theme the
/// app runs in, without changing the app-wide setting.
///
/// For previews that switch the theme locally: the component gallery at
/// `/debug/gallery` shows every component in light, dark and dim inside an
/// app that stays in its own theme. Put a `FermanThemeScope` below it, so
/// `context.ferman` resolves the new brightness for the locale, the
/// density, reduced motion and the page filter.
///
/// Feature code cannot build a `Theme` itself (only `app/lib/design/` and
/// `app/lib/app/app.dart` may import Material, S6), so this is the one way
/// for it to pick a brightness. The app's own theme switch stays with
/// `themeModeProvider` and `MaterialApp`.
class FermanThemeOverride extends StatelessWidget {
  /// Gives [child] the theme for [brightness].
  const new({required this.brightness, required this.child, super.key});

  /// Light or dark.
  final Brightness brightness;

  /// The widgets that take the theme.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: FermanMaterialTheme.build(brightness), child: child);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Brightness>('brightness', brightness));
  }
}
