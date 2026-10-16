import 'dart:ui';

/// Window sizes from the design: desktop artboards are 1440 × 900, and the
/// narrowest supported window is 1024 px wide (ROADMAP §5 step 8, Proposed).
abstract final class WindowMetrics {
  /// The size of a new window, matching the desktop artboards.
  static const Size initialSize = Size(1440, 900);

  /// **Proposed** (ROADMAP §5 step 8, G21): the narrowest window, in
  /// logical pixels. At this width nothing overlaps: the tool rows hide
  /// their labels and move tools into the overflow menu, the right panel
  /// steps aside, and the mode tabs fall back to icons when their labels do
  /// not fit. Change it here; [minimumSize] follows.
  static const double minimumWidth = 1024;

  /// The lowest window, in logical pixels: the shell's bars take 149 px
  /// (title bar 38, mode bar 40, tool row 45, status bar 26), which leaves
  /// the canvas 491 px; and 640 px fits a 1280 × 720 screen (1920 × 1080 at
  /// 150 %) with the Windows taskbar.
  static const double minimumHeight = 640;

  /// The smallest window the shell supports, asked for at start-up through
  /// `DesktopWindow.setMinimumSize`.
  static const Size minimumSize = Size(minimumWidth, minimumHeight);

  /// **Proposed** (G21): the narrowest the canvas gets beside the side
  /// panels before one of them steps aside, in logical pixels: an A4 or
  /// Letter page at about 75 % with its margins. Both panels (216 + 264)
  /// fit from 1120 px; at the 1024 px minimum one of them does.
  static const double canvasMinWidth = 640;

  /// The window title used by the operating system (task switcher, dock).
  static const String title = 'Ferman';
}
