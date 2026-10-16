import 'package:ferman/app/window_frame.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

/// Route paths. Modes, document tabs and sidebar tabs are state, not routes.
abstract final class Routes {
  /// The start screen.
  static const String start = '/';
}

/// The app's router.
@riverpod
GoRouter router(Ref ref) {
  final router = GoRouter(
    routes: [
      // Every screen sits in the window frame, whose title bar stays while
      // the screens below it change. Dialogs on the root navigator cover the
      // title bar too.
      ShellRoute(
        builder: (context, state, child) => WindowFrame(child: child),
        routes: [
          GoRoute(
            path: Routes.start,
            builder: (context, state) => const StartScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
