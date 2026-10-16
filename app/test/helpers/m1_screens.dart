import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/features/onboarding/language_picker.dart';
import 'package:ferman/features/onboarding/welcome_step.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The screens of M1 (ROADMAP §5 steps 9 and 10): first run's three steps,
/// the start screen and the three built panes of Settings.
enum M1Screen {
  /// First run, the language picker (a1-1).
  languagePicker('first run: language picker (a1-1)'),

  /// First run, step 1 of 2: everything stays on your device (a1-2b).
  privacyStep('first run: privacy step (a1-2b)'),

  /// First run, step 2 of 2: free forever (a1-2c).
  freeStep('first run: free step (a1-2c)'),

  /// The empty start screen (a1-5, a12-2a).
  start('start screen (a1-5)'),

  /// Settings › General (a11-1).
  settingsGeneral('Settings › General (a11-1)', SettingsPane.general),

  /// Settings › Language and region (a11-1b, a12-2c).
  settingsLanguage(
    'Settings › Language and region (a11-1b)',
    SettingsPane.language,
  ),

  /// Settings › Privacy (a11-1h).
  settingsPrivacy('Settings › Privacy (a11-1h)', SettingsPane.privacy);

  new(this.description, [this.pane]);

  /// The screen and its board, for test names.
  final String description;

  /// The Settings pane, for the Settings screens.
  final SettingsPane? pane;

  /// Whether the screen is part of first run.
  bool get firstRun => index <= freeStep.index;

  /// The settings to start the app with to reach this screen, in the app
  /// language [languageCode] (the system's when null) and the region
  /// [regionCode] (the system's when null).
  AppSettings settings({String? languageCode, String? regionCode}) =>
      AppSettings(
        onboardingCompleted: !firstRun,
        languageCode: languageCode,
        regionCode: regionCode,
      );

  /// The widget type that marks this screen.
  Type get widgetType => switch (this) {
    languagePicker => LanguagePicker,
    privacyStep || freeStep => WelcomeStep,
    start => FmStart,
    _ => FmSettings,
  };

  /// Moves the app, started with [settings], to this screen, through the
  /// screens' own callbacks and routes, whatever the UI language.
  Future<void> open(WidgetTester tester) async {
    switch (this) {
      case languagePicker || start:
        break;
      case privacyStep || freeStep:
        tester.widget<LanguagePicker>(find.byType(LanguagePicker)).onContinue();
        await tester.pumpAndSettle();
        if (this == freeStep) {
          tester.widget<WelcomeStep>(find.byType(WelcomeStep)).onNext();
          await tester.pumpAndSettle();
        }
      case settingsGeneral || settingsLanguage || settingsPrivacy:
        final context = tester.element(find.byType(FmStart));
        // The push completes only when Settings closes.
        unawaited(
          GoRouter.of(context).push<void>(Routes.settingsPane(pane!.path)),
        );
        await tester.pumpAndSettle();
    }
    expect(find.byType(widgetType), findsOneWidget, reason: description);
  }
}

/// The two window sizes the M1 screens are checked at: the boards'
/// 1440 × 900 and a 1024 × 768 window, the Proposed least width (G21).
const List<Size> m1WindowSizes = [Size(1440, 900), Size(1024, 768)];

/// "1440 × 900".
String sizeName(Size size) => '${size.width.toInt()} × ${size.height.toInt()}';
