import 'package:ferman/design/window_metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Whether the app runs as a desktop app (macOS, Windows or Linux).
bool get isDesktop =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Sets the initial window size and the title on desktop. Does nothing on
/// the web. The minimum size goes through the `DesktopWindow` once it has
/// started (`applyWindowLimits`).
Future<void> setUpWindow() async {
  if (!isDesktop) return;
  await windowManager.ensureInitialized();
  await windowManager.setSize(WindowMetrics.initialSize);
  await windowManager.setTitle(WindowMetrics.title);
}
