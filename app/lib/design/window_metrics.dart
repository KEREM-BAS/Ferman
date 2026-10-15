import 'dart:ui';

/// Window sizes from the design: desktop artboards are 1440 × 900, and the
/// narrowest supported window is 1024 px wide (ROADMAP §5 step 8, Proposed).
abstract final class WindowMetrics {
  /// The size of a new window, matching the desktop artboards.
  static const Size initialSize = Size(1440, 900);

  /// The smallest window the shell supports.
  static const Size minimumSize = Size(1024, 640);

  /// The window title used by the operating system (task switcher, dock).
  static const String title = 'Ferman';
}
