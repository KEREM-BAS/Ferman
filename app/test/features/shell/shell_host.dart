import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/window_frame.dart';
import 'package:ferman/features/shell/shell_screen.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_title_bar.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/fake_desktop_window.dart';
import 'german_like_localizations.dart';

/// The size of the desktop artboards.
const Size artboard = Size(1440, 900);

/// "Available in a future version".
const String futureVersion = 'Available in a future version';

/// The window frame with the shell's title-bar content and the shell, as
/// the router shows `/debug/shell`, at the artboard size, in a fresh
/// provider container (disposed after the test) with [window], the key
/// conventions of [platform] and the region [regionCode] (Türkiye unless
/// given, so times read 14:32 and percentages "%100").
///
/// [size] makes the window resizable: the shell takes its value, so a test
/// can narrow and widen the window while the providers and widgets keep
/// their state ([resizeShell]). [germanLike] replaces the English labels
/// with [GermanLikeLocalizations], [localizations] with the strings of
/// another delegate (the pseudo-locale).
Widget shellHost({
  required FakeDesktopWindow window,
  ShortcutPlatform platform = ShortcutPlatform.linux,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  VoidCallback? onHome,
  VoidCallback? onOpenSettings,
  bool aiEnabled = false,
  String regionCode = 'TR',
  ValueListenable<Size>? size,
  bool germanLike = false,
  LocalizationsDelegate<AppLocalizations>? localizations,
}) {
  Widget frame(Size size) {
    final shell = SizedBox.fromSize(
      size: size,
      child: WindowFrame(
        titleBarContent: ShellTitleBarContent(
          onHome: onHome,
          onOpenSettings: onOpenSettings,
        ),
        child: FmWindow(onOpenSettings: onOpenSettings),
      ),
    );
    final delegate =
        localizations ?? (germanLike ? const GermanLikeDelegate() : null);
    return componentHost(
      delegate != null
          ? Builder(
              builder: (context) => Localizations.override(
                context: context,
                delegates: [delegate],
                child: shell,
              ),
            )
          : shell,
      locale: locale,
      brightness: brightness,
      size: size,
    );
  }

  return UncontrolledProviderScope(
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
        child: size == null
            ? frame(artboard)
            : ValueListenableBuilder<Size>(
                valueListenable: size,
                builder: (context, value, _) => frame(value),
              ),
      ),
    ),
  );
}

/// Pumps [widget] in a test view and window of the size [sizes] holds and
/// lets it settle.
Future<void> pumpShellAt(
  WidgetTester tester,
  Widget widget,
  ValueNotifier<Size> sizes,
) async {
  tester.view
    ..physicalSize = sizes.value
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await settle(tester);
}

/// Resizes the window of a shell pumped with [pumpShellAt] to [size] and
/// lets the shell follow.
Future<void> resizeShell(
  WidgetTester tester,
  ValueNotifier<Size> sizes,
  Size size,
) async {
  tester.view.physicalSize = size;
  sizes.value = size;
  await settle(tester);
}

/// Sets the test view to the artboard size for this test.
void useArtboardView(WidgetTester tester) {
  tester.view
    ..physicalSize = artboard
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The provider container of the shell under test.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FmWindow)));

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
  // Narrow rows and panels follow the laid-out width a frame later (G21).
  await tester.pump();
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
