import 'package:ferman/app/app.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/onboarding/language_picker.dart';
import 'package:ferman/features/onboarding/onboarding_screen.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/l10n/isolated_fallback.g.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The boards' 1440 × 900 window, reset after the test.
  void useBoardSize(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('first run starts with the language picker', (tester) async {
    useBoardSize(tester);
    await tester.pumpWidget(const ProviderScope(child: FermanApp()));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePicker), findsOneWidget);
    expect(find.byType(FmStart), findsNothing);
  });

  testWidgets('starts on the start screen once first run is done', (
    tester,
  ) async {
    useBoardSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(
            const AppSettings(onboardingCompleted: true),
          ),
          engineServiceProvider.overrideWithValue(const FakeEngineService()),
        ],
        child: const FermanApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FmStart), findsOneWidget);
    expect(find.text('Drop a PDF here'), findsOneWidget);
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(onboardingCompleted: true),
    List<Locale> systemLocales = const [Locale('en', 'US')],
  }) async {
    useBoardSize(tester);
    tester.platformDispatcher.localesTestValue = systemLocales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final container = ProviderContainer(
      overrides: [
        initialSettingsProvider.overrideWithValue(settings),
        engineServiceProvider.overrideWithValue(const FakeEngineService()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FermanApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('direction follows the chosen language (G20, ADR 0014)', () {
    for (final code in ['fa', 'he']) {
      testWidgets('$code mirrors the whole UI with English strings', (
        tester,
      ) async {
        await pumpApp(
          tester,
          settings: AppSettings(onboardingCompleted: true, languageCode: code),
        );
        final screen = tester.element(find.byType(FmStart));
        expect(Directionality.of(screen), TextDirection.rtl);
        expect(Localizations.localeOf(screen), const Locale('en'));
        // The English string, in a left-to-right isolate so that it keeps
        // its own order in the mirrored UI (G93).
        expect(
          find.text(IsolatedFallbackLocalizations.isolate('Drop a PDF here')),
          findsOneWidget,
        );
      });
    }

    testWidgets('a Persian or Hebrew system starts right to left', (
      tester,
    ) async {
      await pumpApp(tester, systemLocales: const [Locale('he', 'IL')]);
      final screen = tester.element(find.byType(FmStart));
      expect(Directionality.of(screen), TextDirection.rtl);
      expect(Localizations.localeOf(screen), const Locale('en'));
    });

    testWidgets('German, untranslated too, stays left to right', (
      tester,
    ) async {
      await pumpApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'de',
        ),
      );
      final screen = tester.element(find.byType(FmStart));
      expect(Directionality.of(screen), TextDirection.ltr);
      expect(Localizations.localeOf(screen), const Locale('en'));
      // Left to right, the English strings need no isolates.
      expect(find.text('Drop a PDF here'), findsOneWidget);
    });

    testWidgets('Arabic keeps its own strings and direction', (tester) async {
      await pumpApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'ar',
        ),
      );
      final screen = tester.element(find.byType(FmStart));
      expect(Directionality.of(screen), TextDirection.rtl);
      expect(Localizations.localeOf(screen), const Locale('ar'));
    });
  });

  group('an unknown location', () {
    testWidgets('opens the start screen once first run is done', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      container.read(routerProvider).go('/no-such-route');
      await tester.pumpAndSettle();
      expect(find.byType(FmStart), findsOneWidget);
      expect(find.text('Page Not Found'), findsNothing);
    });

    testWidgets('opens first run until it is done', (tester) async {
      final container = await pumpApp(tester, settings: const AppSettings());
      container.read(routerProvider).go('/no-such-route');
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Page Not Found'), findsNothing);
    });
  });
}
