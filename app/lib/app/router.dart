import 'package:ferman/app/window_frame.dart';
import 'package:ferman/features/gallery/gallery_screen.dart';
import 'package:ferman/features/onboarding/onboarding_screen.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/features/shell/shell_screen.dart';
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

  /// The editor: the shell with the documents opened (a1-13).
  static const String editor = '/editor';

  /// The editor shell with the M1 placeholder documents (M1 phases H2 to
  /// H5), until a document opens.
  static const String debugShell = '/debug/shell';

  /// The component gallery (M1 phase G10): every component of the library
  /// with its variants and states, for review against the design. A debug
  /// surface like [debugShell].
  static const String debugGallery = '/debug/gallery';
}

/// The app's router; kept, since opening files moves it.
@Riverpod(keepAlive: true)
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
              onDocument: () => context.go(Routes.editor),
              onOpenSettings: () => context.push(Routes.settings),
            ),
            Routes.editor || Routes.debugShell => ShellTitleBarContent(
              onHome: () => context.go(Routes.start),
              onOpenSettings: () => context.push(Routes.settings),
            ),
            _ => null,
          },
          takesFiles: switch (state.uri.path) {
            Routes.start || Routes.editor || Routes.debugShell => true,
            _ => false,
          },
          child: child,
        ),
        routes: [
          GoRoute(
            path: Routes.start,
            builder: (context, state) => const FmStart(),
          ),
          GoRoute(
            path: Routes.welcome,
            builder: (context, state) => const OnboardingScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const FmSettings(),
          ),
          for (final path in [Routes.editor, Routes.debugShell])
            GoRoute(
              path: path,
              builder: (context, state) =>
                  FmWindow(onOpenSettings: () => context.push(Routes.settings)),
            ),
          GoRoute(
            path: Routes.debugGallery,
            builder: (context, state) => const GalleryScreen(),
          ),
          GoRoute(
            path: '${Routes.settings}/:pane',
            builder: (context, state) => FmSettings(
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
