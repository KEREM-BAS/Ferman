import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme, ThemeData, ThemeExtension;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures the context of the widget below the scope under test.
final class _Probe {
  late BuildContext context;

  Widget get widget => Builder(
    builder: (context) {
      this.context = context;
      return const SizedBox.shrink();
    },
  );
}

/// The scope under [Localizations] for [locale], the way the app nests it.
Widget _app({
  required Widget child,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  bool disableAnimations = false,
  bool touch = false,
  bool pageDim = false,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Localizations(
      locale: locale,
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: Theme(
        data: theme ?? FermanMaterialTheme.light,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FermanThemeScope(touch: touch, pageDim: pageDim, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('outside any theme, context.ferman is the light theme', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(probe.widget);
    expect(probe.context.ferman, same(FermanTheme.light));
  });

  testWidgets('resolves the theme for the locale', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(
      _app(locale: const Locale('ja'), child: probe.widget),
    );
    final ferman = probe.context.ferman;
    expect(ferman.typography.isCjk, isTrue);
    expect(ferman.typography.body.locale, const Locale('ja'));
    expect(ferman.typography.body.height, 20 / 13);
    expect(ferman.colors, same(FermanColorTokens.light));
  });

  testWidgets('reduced motion picks the reduced durations', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(_app(child: probe.widget));
    expect(probe.context.ferman.motion, same(FermanMotionTokens.standard));
    expect(
      probe.context.ferman.motion.durFast,
      const Duration(milliseconds: 120),
    );

    await tester.pumpWidget(_app(disableAnimations: true, child: probe.widget));
    expect(probe.context.ferman.motion, same(FermanMotionTokens.reduced));
    expect(probe.context.ferman.motion.durFast, Duration.zero);
    expect(probe.context.ferman.motion.durSlow, Duration.zero);
  });

  testWidgets('uses the desktop density unless told to use touch', (
    tester,
  ) async {
    // Widget tests run as Android by default; the scope ignores the
    // platform, so they keep the desktop sizes.
    expect(defaultTargetPlatform, TargetPlatform.android);
    final probe = _Probe();
    await tester.pumpWidget(_app(child: probe.widget));
    expect(probe.context.ferman.density, same(FermanDensityTokens.desktop));

    await tester.pumpWidget(_app(touch: true, child: probe.widget));
    expect(probe.context.ferman.density, same(FermanDensityTokens.touch));
    expect(IconTheme.of(probe.context).size, FermanDensityTokens.touch.iconMd);
  });

  test('isTouchPlatform: iOS and Android only', () {
    expect(FermanThemeScope.isTouchPlatform(TargetPlatform.android), isTrue);
    expect(FermanThemeScope.isTouchPlatform(TargetPlatform.iOS), isTrue);
    expect(FermanThemeScope.isTouchPlatform(TargetPlatform.windows), isFalse);
    expect(FermanThemeScope.isTouchPlatform(TargetPlatform.macOS), isFalse);
    expect(FermanThemeScope.isTouchPlatform(TargetPlatform.linux), isFalse);
    expect(FermanThemeScope.isTouchPlatform(TargetPlatform.fuchsia), isFalse);
  });

  testWidgets('pageDim applies the dim filter', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(_app(pageDim: true, child: probe.widget));
    expect(probe.context.ferman.pageColorFilter, isNotNull);
  });

  testWidgets('keeps the dark colours of the theme above', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(
      _app(theme: FermanMaterialTheme.dark, child: probe.widget),
    );
    expect(probe.context.ferman.colors, same(FermanColorTokens.dark));
    expect(Theme.of(probe.context).brightness, Brightness.dark);
  });

  testWidgets('sets the base text style and icon theme', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(
      _app(theme: FermanMaterialTheme.dark, child: probe.widget),
    );
    final style = DefaultTextStyle.of(probe.context).style;
    final ferman = probe.context.ferman;
    expect(style.color, FermanColorTokens.dark.textPrimary);
    expect(style.fontSize, ferman.typography.body.fontSize);
    expect(style.height, ferman.typography.body.height);
    expect(style.fontFamily, 'IBM Plex Sans');
    expect(style.fontFeatures, FermanTypeTokens.featuresUi);
    expect(style.locale, const Locale('en'));
    final icons = IconTheme.of(probe.context);
    expect(icons.color, FermanColorTokens.dark.textPrimary);
    expect(icons.size, FermanDensityTokens.desktop.iconMd);
  });

  testWidgets('keeps other theme extensions', (tester) async {
    final probe = _Probe();
    final theme = FermanMaterialTheme.light.copyWith(
      extensions: [FermanTheme.light, const _Other()],
    );
    await tester.pumpWidget(_app(theme: theme, child: probe.widget));
    expect(Theme.of(probe.context).extension<_Other>(), isNotNull);
  });

  testWidgets('does not notify dependents when nothing changes', (
    tester,
  ) async {
    var builds = 0;
    final counter = Builder(
      builder: (context) {
        context.ferman;
        builds++;
        return const SizedBox.shrink();
      },
    );
    await tester.pumpWidget(_app(child: counter));
    await tester.pumpWidget(_app(child: counter));
    expect(builds, 1);
  });

  test('describes its properties', () {
    final description = const FermanThemeScope(
      touch: true,
      pageDim: true,
      child: SizedBox.shrink(),
    ).toDiagnosticsNode().getProperties().map((p) => p.toString());
    expect(description, containsAll(['touch', 'pageDim']));
  });
}

final class _Other extends ThemeExtension<_Other> {
  const new();

  @override
  _Other copyWith() => this;

  @override
  _Other lerp(covariant _Other? other, double t) => this;
}
