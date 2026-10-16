import 'package:ferman/app/window_frame.dart';
import 'package:ferman/features/onboarding/onboarding_screen.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/features/shell/shell_screen.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_title_bar.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// Route paths. Modes, document tabs and sidebar tabs are state, not routes.
abstract final class Routes {
  /// The start screen.
  static const String start = '/';

  /// First run (a1-1, a1-2b, a1-2c), which the router shows instead of the
  /// start screen until `AppSettings.onboardingCompleted` is set.
  static const String welcome = '/welcome';

  /// Settings, on the General pane (a11-1): a window-styled surface inside
  /// the main window (ARCHITECTURE.md §12). Push it, so closing it returns
  /// to the screen below.
  static const String settings = '/settings';

  /// Settings on the pane with the path segment [pane] (`privacy`,
  /// `language`; see `SettingsPane`).
  static String settingsPane(String pane) => '$settings/$pane';

  /// The editor shell with placeholder documents (M1 phases H2 to H5). In
  /// M1 it is reachable only here; documents open into it from M2 on.
  static const String debugShell = '/debug/shell';
}

/// The app's router.
@riverpod
GoRouter router(Ref ref) {
  final router = GoRouter(
    // An unknown location (a web address, a mistyped path) goes to the
    // start screen, through the redirect below: first run until it is done.
    // No undesigned error page with untranslated text.
    onException: (context, state, router) => router.go(Routes.start),
    // First run comes before the start screen until it is done; the
    // settings are read, not watched, so a change never rebuilds the router.
    redirect: (context, state) {
      final completed = ref.read(settingsProvider).onboardingCompleted;
      return switch (state.matchedLocation) {
        Routes.start when !completed => Routes.welcome,
        Routes.welcome when completed => Routes.start,
        _ => null,
      };
    },
    routes: [
      // Every screen sits in the window frame, whose title bar stays while
      // the screens below it change. Dialogs on the root navigator cover the
      // title bar too. The start screen shows the home header of a1-5 (the
      // "Ferman" tab, no documents before M2, "+", Search and Settings), the
      // shell its documents; first run and Settings keep the bare bar, as
      // their boards draw it.
      ShellRoute(
        builder: (context, state, child) => WindowFrame(
          titleBarContent: switch (state.uri.path) {
            Routes.start => ShellTitleBarContent(
              homeActive: true,
              documents: const ShellDocumentList(documents: []),
              onOpenSettings: () => context.push(Routes.settings),
            ),
            Routes.debugShell => ShellTitleBarContent(
              onHome: () => context.go(Routes.start),
              onOpenSettings: () => context.push(Routes.settings),
            ),
            _ => null,
          },
          child: child,
        ),
        routes: [
          GoRoute(
            path: Routes.start,
            builder: (context, state) => const StartScreen(),
          ),
          GoRoute(
            path: Routes.welcome,
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: Routes.debugShell,
            builder: (context, state) => ShellScreen(
              onOpenSettings: () => context.push(Routes.settings),
            ),
          ),
          GoRoute(
            path: '${Routes.settings}/:pane',
            builder: (context, state) => SettingsScreen(
              initialPane: SettingsPane.fromPath(state.pathParameters['pane']),
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
