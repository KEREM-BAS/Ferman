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
      GoRoute(
        path: Routes.start,
        builder: (context, state) => const StartScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
