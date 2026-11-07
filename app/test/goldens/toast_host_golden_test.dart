import 'package:ferman/app/app.dart';
import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/phone_golden.dart';
import '../helpers/window_golden.dart';

/// Three toasts that stay, so the capture has no timer to wait for: the
/// stack of a11-6 with G49's placement.
Future<void> _stack(WidgetTester tester) async {
  ProviderScope.containerOf(tester.element(find.byType(FermanApp)))
      .read(toastNoticesProvider.notifier)
    ..show(
      tone: ToastTone.danger,
      title: (l10n) => l10n.settingsSaveFailedTitle,
      message: (l10n) => l10n.settingsSaveFailedMessage,
    )
    ..show(
      tone: ToastTone.danger,
      title: (l10n) => l10n.shellSaveError,
      message: (l10n) => l10n.saveToastOther,
      action: (label: (l10n) => l10n.saveAsEllipsis, onPressed: () {}),
    )
    ..show(
      tone: ToastTone.danger,
      title: (l10n) => l10n.shellSaveError,
      message: (l10n) => l10n.saveToastDiskFull,
    );
  await tester.pump();
}

/// The toast stack on the start screen, on the desktop and a phone, in light
/// and dark × en, tr and ar (right to left mirrors it).
Future<void> main() async {
  for (final theme in GoldenTheme.values) {
    for (final language in GoldenLanguage.values) {
      final settings = goldenSettings(
        theme: theme,
        language: language,
        onboardingCompleted: true,
      );
      await windowGoldenTest(
        screen: 'toast_stack',
        chrome: GoldenChrome.win,
        theme: theme,
        language: language,
        settings: settings,
        open: _stack,
      );
      await phoneGoldenTest(
        screen: 'toast_stack',
        theme: theme,
        language: language,
        settings: settings,
        open: _stack,
      );
    }
  }
}
