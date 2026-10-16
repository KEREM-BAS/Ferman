import 'package:ferman/app/app.dart';
import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts the app in a fresh provider container and returns the container.
Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  // First run is done, so the router opens the start screen.
  final container = ProviderContainer.test(
    overrides: [
      initialSettingsProvider.overrideWithValue(
        const AppSettings(onboardingCompleted: true),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const FermanApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// The theme the start screen sees.
FermanTheme _ferman(WidgetTester tester) =>
    tester.element(find.byType(StartScreen)).ferman;

/// The colour the app paints behind the start screen.
Color _background(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find
          .ancestor(
            of: find.byType(StartScreen),
            matching: find.byType(ColoredBox),
          )
          .first,
    )
    .color;

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
      ..clearPlatformBrightnessTestValue()
      ..clearAccessibilityFeaturesTestValue();
  });

  testWidgets('the theme mode starts at match system', (tester) async {
    final container = await _pumpApp(tester);
    expect(container.read(themeModeProvider), AppThemeMode.system);
    expect(_ferman(tester).colors, same(FermanColorTokens.light));
    expect(_background(tester), FermanColorTokens.light.surfacePanel);
  });

  testWidgets('light, dark and match system switch live, without a restart', (
    tester,
  ) async {
    final container = await _pumpApp(tester);
    // The root navigator: the window frame's shell route adds a nested one.
    final screen = tester.state(find.byType(Navigator).first);
    final notifier = container.read(themeModeProvider.notifier);
    await notifier.select(AppThemeMode.dark);
    await tester.pumpAndSettle();
    expect(_ferman(tester).colors, same(FermanColorTokens.dark));
    expect(_ferman(tester).isDark, isTrue);
    expect(_background(tester), FermanColorTokens.dark.surfacePanel);
    expect(
      DefaultTextStyle.of(tester.element(find.byType(StartScreen))).style.color,
      FermanColorTokens.dark.textPrimary,
    );

    await notifier.select(AppThemeMode.light);
    await tester.pumpAndSettle();
    expect(_ferman(tester).colors, same(FermanColorTokens.light));

    // Match system follows the platform brightness as it changes.
    await notifier.select(AppThemeMode.system);
    await tester.pumpAndSettle();
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(_ferman(tester).colors, same(FermanColorTokens.dark));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(_ferman(tester).colors, same(FermanColorTokens.light));

    // The same navigator (and so the same screens and their state) stayed
    // mounted throughout: nothing restarted.
    expect(tester.state(find.byType(Navigator).first), same(screen));
    expect(find.text('Drop a PDF here'), findsOneWidget);
  });

  testWidgets('the switch animates over the base duration', (tester) async {
    final container = await _pumpApp(tester);
    await container.read(themeModeProvider.notifier).select(AppThemeMode.dark);
    await tester.pump();
    final half = FermanMotionTokens.standard.durBase ~/ 2;
    await tester.pump(half);
    final middle = _ferman(tester).colors.surfacePanel;
    expect(middle, isNot(FermanColorTokens.light.surfacePanel));
    expect(middle, isNot(FermanColorTokens.dark.surfacePanel));
    await tester.pump(half);
    await tester.pump();
    expect(_ferman(tester).colors, same(FermanColorTokens.dark));
  });

  testWidgets('reduced motion: zero durations and an instant switch', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    final container = await _pumpApp(tester);
    final motion = _ferman(tester).motion;
    expect(motion, same(FermanMotionTokens.reduced));
    expect(motion.durInstant, Duration.zero);
    expect(motion.durFast, Duration.zero);
    expect(motion.durBase, Duration.zero);
    expect(motion.durSlow, Duration.zero);

    await container.read(themeModeProvider.notifier).select(AppThemeMode.dark);
    await tester.pump();
    expect(_ferman(tester).colors, same(FermanColorTokens.dark));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('standard motion when the system does not reduce it', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(_ferman(tester).motion, same(FermanMotionTokens.standard));

    // Turning reduced motion on while the app runs takes effect at once.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(_ferman(tester).motion, same(FermanMotionTokens.reduced));
  });

  testWidgets('turning reduced motion on and off keeps the app mounted', (
    tester,
  ) async {
    await _pumpApp(tester);
    State<StatefulWidget> router() =>
        tester.state(find.byWidgetPredicate((widget) => widget is Router));
    final mounted = router();
    final scope = tester.element(find.byType(FermanThemeScope));

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(router(), same(mounted));
    expect(tester.element(find.byType(FermanThemeScope)), same(scope));
    expect(_ferman(tester).motion, same(FermanMotionTokens.reduced));

    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    expect(router(), same(mounted));
    expect(tester.element(find.byType(FermanThemeScope)), same(scope));
    expect(_ferman(tester).motion, same(FermanMotionTokens.standard));
  });

  testWidgets('the app resolves the type roles for the UI locale', (
    tester,
  ) async {
    await _pumpApp(tester);
    final context = tester.element(find.byType(StartScreen));
    final ferman = context.ferman;
    expect(ferman.typography.locale, Localizations.localeOf(context));
    expect(Theme.of(context).extension<FermanTheme>(), same(ferman));
  });

  testWidgets('the app picks the density by platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await _pumpApp(tester);
      expect(_ferman(tester).density, same(FermanDensityTokens.desktop));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('touch density on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pumpApp(tester);
      expect(_ferman(tester).density, same(FermanDensityTokens.touch));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
