import 'package:ferman/app/app.dart';
import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/onboarding/onboarding_screen.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/features/shell/shell_screen.dart';
import 'package:ferman/features/shell/shell_title_bar.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import 'shell_host.dart';

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  /// The whole app with Ferman's own Linux title bar, first run done.
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(onboardingCompleted: true),
  }) async {
    useArtboardView(tester);
    final container = ProviderContainer.test(
      overrides: [
        engineServiceProvider.overrideWithValue(FakeEngineService()),
        desktopWindowProvider.overrideWithValue(window),
        initialSettingsProvider.overrideWithValue(settings),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FermanApp()),
    );
    await settle(tester);
    return container;
  }

  Finder iconButton(String label) => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.label == label,
  );

  ShellTitleBarContent titleBar(WidgetTester tester) =>
      tester.widget<ShellTitleBarContent>(find.byType(ShellTitleBarContent));

  testWidgets('the start screen shows the home header of a1-5', (tester) async {
    await pumpApp(tester);
    expect(find.byType(FmStart), findsOneWidget);
    expect(find.byType(ShellTitleBarContent), findsOneWidget);
    expect(titleBar(tester).homeActive, isTrue);
    // The "Ferman" wordmark tab, and no documents before M2 (noTabs).
    expect(
      find.descendant(
        of: find.byType(ShellTitleBarContent),
        matching: find.text('Ferman'),
      ),
      findsOneWidget,
    );
    expect(iconButton('Home'), findsNothing);
    expect(find.byType(DocumentTab), findsNothing);
    // "+" opens files and Settings works; Search waits for its milestone.
    final plus = tester.widget<IconButton>(iconButton('Open file'));
    expect(plus.disabledReason, isNull);
    expect(plus.onPressed, isNotNull);
    expect(
      tester
          .widget<Button>(
            find.ancestor(
              of: find.text('Search'),
              matching: find.byType(Button),
            ),
          )
          .disabledReason,
      futureVersion,
    );
    final settings = tester.widget<IconButton>(iconButton('Settings'));
    expect(settings.disabledReason, isNull);
    expect(settings.shortcut, ['Ctrl', ',']);
  });

  testWidgets('Settings opens from the start screen’s title bar, under the '
      'bare bar, and closes back to the home header', (tester) async {
    await pumpApp(tester);
    await tester.tap(iconButton('Settings'));
    await settle(tester);
    expect(find.byType(FmSettings), findsOneWidget);
    expect(find.byType(ShellTitleBarContent), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(FmStart), findsOneWidget);
    expect(titleBar(tester).homeActive, isTrue);
  });

  testWidgets('Ctrl+, opens Settings from the start screen once, through the '
      'shortcut table', (tester) async {
    await pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.byType(FmSettings), findsOneWidget);
    // One Settings page, not two stacked ones.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(FmSettings), findsNothing);
    expect(find.byType(FmStart), findsOneWidget);
  });

  testWidgets('the start screen leaves the editor’s keys alone', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    final sidebar = await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    final jump = await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(sidebar, isFalse);
    expect(jump, isFalse);
  });

  testWidgets('the window keys work on the start screen, first run and '
      'Settings', (tester) async {
    final container = await pumpApp(tester, settings: const AppSettings());
    Future<void> quit() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }

    expect(find.byType(OnboardingScreen), findsOneWidget);
    await quit();
    expect(window.calls, ['close']);

    // Finish first run, then the start screen.
    await container
        .read(settingsProvider.notifier)
        .change((settings) => settings.copyWith(onboardingCompleted: true));
    container.read(routerProvider).go(Routes.start);
    await settle(tester);
    expect(find.byType(FmStart), findsOneWidget);
    await quit();
    expect(window.calls, ['close', 'close']);

    container.read(routerProvider).go(Routes.settings);
    await settle(tester);
    expect(find.byType(FmSettings), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(window.calls, ['close', 'close', 'close']);
  });

  testWidgets('the shell at /debug/shell has its documents; Home goes back '
      'to the home header', (tester) async {
    final container = await pumpApp(tester);
    expect(find.byType(FmWindow), findsNothing);

    container.read(routerProvider).go(Routes.debugShell);
    await settle(tester);
    expect(find.byType(FmWindow), findsOneWidget);
    expect(titleBar(tester).homeActive, isFalse);
    expect(find.byType(DocumentTab), findsNWidgets(5));

    await tester.tap(iconButton('Home'));
    await settle(tester);
    expect(find.byType(FmWindow), findsNothing);
    expect(find.byType(FmStart), findsOneWidget);
    expect(titleBar(tester).homeActive, isTrue);
    expect(find.byType(DocumentTab), findsNothing);
  });

  testWidgets('first run keeps the bare title bar', (tester) async {
    await pumpApp(tester, settings: const AppSettings());
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(ShellTitleBarContent), findsNothing);
  });
}
