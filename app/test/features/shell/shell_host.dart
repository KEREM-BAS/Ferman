import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/window_frame.dart';
import 'package:ferman/features/shell/shell_screen.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_title_bar.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/fake_desktop_window.dart';

/// The size of the desktop artboards.
const Size artboard = Size(1440, 900);

/// "Available in a future version".
const String futureVersion = 'Available in a future version';

/// The window frame with the shell's title-bar content and the shell, as
/// the router shows `/debug/shell`, at the artboard size, in a fresh
/// provider container (disposed after the test) with [window], the key
/// conventions of [platform] and the region [regionCode] (Türkiye unless
/// given, so times read 14:32 and percentages "%100").
Widget shellHost({
  required FakeDesktopWindow window,
  ShortcutPlatform platform = ShortcutPlatform.linux,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  VoidCallback? onHome,
  VoidCallback? onOpenSettings,
  bool aiEnabled = false,
  String regionCode = 'TR',
}) => UncontrolledProviderScope(
  container: ProviderContainer.test(
    overrides: [
      desktopWindowProvider.overrideWithValue(window),
      shortcutPlatformProvider.overrideWithValue(platform),
      shellAiEnabledProvider.overrideWithValue(aiEnabled),
      initialSettingsProvider.overrideWithValue(
        AppSettings(regionCode: regionCode),
      ),
    ],
  ),
  // The app's default keys (Tab moves focus, Enter activates), which
  // `WidgetsApp` installs in the app.
  child: Shortcuts(
    shortcuts: WidgetsApp.defaultShortcuts,
    child: Actions(
      actions: WidgetsApp.defaultActions,
      child: componentHost(
        SizedBox.fromSize(
          size: artboard,
          child: WindowFrame(
            titleBarContent: ShellTitleBarContent(
              onHome: onHome,
              onOpenSettings: onOpenSettings,
            ),
            child: ShellScreen(onOpenSettings: onOpenSettings),
          ),
        ),
        locale: locale,
        brightness: brightness,
        size: artboard,
      ),
    ),
  ),
);

/// Sets the test view to the artboard size for this test.
void useArtboardView(WidgetTester tester) {
  tester.view
    ..physicalSize = artboard
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The provider container of the shell under test.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ShellScreen)));

/// Pumps [widget] and lets its animations (except the loading tab's
/// spinner, which never stops) finish.
Future<void> pumpShell(WidgetTester tester, Widget widget) async {
  useArtboardView(tester);
  await tester.pumpWidget(widget);
  await settle(tester);
}

/// Lets the shell's animations finish; `pumpAndSettle` never returns while
/// the loading tab's spinner turns.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// The window frame with only the shell's title-bar content, with the
/// shell's placeholder documents and [homeActive].
Widget titleBarHost({
  required FakeDesktopWindow window,
  bool homeActive = false,
}) => UncontrolledProviderScope(
  container: ProviderContainer.test(
    overrides: [
      desktopWindowProvider.overrideWithValue(window),
      shortcutPlatformProvider.overrideWithValue(ShortcutPlatform.linux),
    ],
  ),
  child: componentHost(
    SizedBox.fromSize(
      size: artboard,
      child: WindowFrame(
        titleBarContent: ShellTitleBarContent(homeActive: homeActive),
        child: const SizedBox.expand(),
      ),
    ),
    size: artboard,
  ),
);
