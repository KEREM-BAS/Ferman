import 'package:ferman/app/router.dart';
import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The root widget. This file and `lib/design/` are the only places allowed
/// to import Material: the app uses Ferman's own components everywhere else.
///
/// Direction: the chosen language's ([AppLanguage.textDirection]), set
/// below the localizations and above the router, so every route, popup and
/// the title bar follow it. It equals the localizations' own for English,
/// Turkish and Arabic; Persian and Hebrew, whose strings fall back to
/// English (`appLocaleProvider`), still mirror the UI (G20, ADR 0014).
///
/// Theme: the light and dark [FermanMaterialTheme]s, switched by
/// `themeModeProvider` (match system, light, dark) while the app runs. One
/// [FermanThemeScope] below the localizations resolves the Ferman theme for
/// the UI locale, the platform's density (touch on iOS and Android, desktop
/// elsewhere) and reduced motion. When the system
/// asks for reduced motion (`MediaQuery.disableAnimationsOf`), the theme
/// switch is instant and every token duration is zero; otherwise the switch
/// takes the base duration with the ease-out curve.
class FermanApp extends ConsumerWidget {
  /// Creates the root widget.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(appLanguageProvider).textDirection;
    final motion = FermanTheme.motionFor(
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: ref.watch(appLocaleProvider),
      theme: FermanMaterialTheme.light,
      darkTheme: FermanMaterialTheme.dark,
      themeMode: switch (ref.watch(themeModeProvider)) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      // Always an AnimationStyle, never AnimationStyle.noAnimation: that
      // makes MaterialApp swap AnimatedTheme for Theme, which would remount
      // everything below it when reduced motion is turned on or off. Under
      // reduced motion durBase is zero, so the switch completes in the
      // frame it starts.
      themeAnimationStyle: AnimationStyle(
        duration: motion.durBase,
        curve: motion.easeOut,
      ),
      builder: (context, child) => Directionality(
        textDirection: direction,
        child: FermanThemeScope(
          touch: FermanThemeScope.isTouchPlatform(Theme.of(context).platform),
          child: _AppSurface(child: child),
        ),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// The app's background, as `.fm-root` paints it (`--surface-panel`).
class _AppSurface extends StatelessWidget {
  const new({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.ferman.colors.surfacePanel,
    child: child ?? const SizedBox.shrink(),
  );
}
