import 'package:flutter/widgets.dart';

/// Window sizes from the design: desktop artboards are 1440 × 900, and the
/// narrowest supported window is 1024 px wide (ROADMAP §5 step 8, approved
/// by the owner on 2026-10-16).
abstract final class WindowMetrics {
  /// The size of a new window, matching the desktop artboards.
  static const Size initialSize = Size(1440, 900);

  /// Approved by the owner on 2026-10-16 (ROADMAP §5 step 8, G21): the
  /// narrowest window, in logical pixels. At this width nothing overlaps:
  /// the tool rows hide their labels and move tools into the overflow menu,
  /// the right panel steps aside, and the mode tabs fall back to icons when
  /// their labels do not fit. Change it here; [minimumSize] follows.
  static const double minimumWidth = 1024;

  /// The lowest window, in logical pixels: the shell's bars take 149 px
  /// (title bar 38, mode bar 40, tool row 45, status bar 26), which leaves
  /// the canvas 491 px; and 640 px fits a 1280 × 720 screen (1920 × 1080 at
  /// 150 %) with the Windows taskbar.
  static const double minimumHeight = 640;

  /// The smallest window the shell supports, asked for at start-up through
  /// `DesktopWindow.setMinimumSize`.
  static const Size minimumSize = Size(minimumWidth, minimumHeight);

  /// Approved by the owner on 2026-10-17 (G21, G95): the narrowest the
  /// canvas gets beside the side panels before one of them steps aside, in
  /// logical pixels: an A4 or Letter page at about 75 % with its margins.
  /// Both panels (216 + 264) fit from 1120 px; at the 1024 px minimum one of
  /// them does.
  static const double canvasMinWidth = 640;

  /// The widest the sidebar gets when it is dragged wider (B094; G21 asks
  /// for limits no board draws): room for longer bookmark titles and file
  /// names, while a 1440 px window keeps the canvas well above
  /// [canvasMinWidth] with the right panel open.
  static const double sidebarMaxWidth = 360;

  /// The widest the right panel gets when it is dragged wider (B094).
  static const double panelMaxWidth = 400;

  /// Below this width the phone layout replaces the desktop one (G129): the
  /// phone boards are 393 and 412 px wide, and 768 px is where the desktop
  /// screens stop overflowing, measured on first run, the start screen and
  /// Settings. Desktop windows do not get this narrow on macOS and Windows
  /// ([minimumWidth]); on Linux the minimum is a hint that a tiling window
  /// manager can ignore, and such a window takes the phone layout (G129).
  static const double phoneMaxWidth = 768;

  /// Whether a [width] takes the phone layout.
  static bool isPhoneWidth(double width) => width < phoneMaxWidth;

  /// Whether the window around [context] takes the phone layout. It goes by
  /// width, never by platform, and rebuilds [context] when the width changes.
  static bool isPhone(BuildContext context) =>
      isPhoneWidth(MediaQuery.sizeOf(context).width);

  /// The window title used by the operating system (task switcher, dock).
  static const String title = 'Ferman';
}
