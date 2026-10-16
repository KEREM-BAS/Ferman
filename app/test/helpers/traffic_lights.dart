import 'package:ferman/app/platform_window.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

import 'fake_desktop_window.dart';

/// A [FakeDesktopWindow] for goldens that also offers the last
/// traffic-light layout the title bar sent as a listenable ([layout]), for
/// [SimulatedTrafficLights].
class GoldenDesktopWindow extends FakeDesktopWindow {
  /// A window with Ferman's title bar for [platform].
  new(super.platform);

  final ValueNotifier<TrafficLightLayout?> _layout = ValueNotifier(null);

  /// The layout the title bar last sent to the native side, or null before
  /// it sent one (and always on Windows and Linux).
  ValueListenable<TrafficLightLayout?> get layout => _layout;

  @override
  Future<void> setTrafficLightLayout(TrafficLightLayout layout) async {
    await super.setTrafficLightLayout(layout);
    _layout.value = layout;
  }

  @override
  void dispose() {
    _layout.dispose();
    super.dispose();
  }
}

/// Paints the macOS traffic lights over [child], where the native window
/// places its close, minimize and zoom buttons, for goldens only.
///
/// The real lights are native views above the Flutter view: `TitleBar`
/// leaves an empty slot and sends a [TrafficLightLayout] through the
/// `ferman/window` channel, and `MainFlutterWindow.swift`
/// (`layoutTrafficLights`) moves the buttons into it. A golden has no
/// native window, so this widget paints them on top of the whole view, as
/// the system does, from the layout the title bar sent ([layout]). The
/// painting is a simulation: the colours are the design's (FmWindow), not
/// the system's own rendering of the buttons.
class SimulatedTrafficLights extends StatelessWidget {
  /// Paints the lights of [layout] over [child].
  const new({required this.layout, required this.child, super.key});

  /// The layout the title bar sent; nothing is painted while it is null.
  final ValueListenable<TrafficLightLayout?> layout;

  /// The window's content.
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: TrafficLightsPainter(layout),
    child: child,
  );
}

/// Paints the three traffic lights of the [TrafficLightLayout] that
/// [layout] holds, as `MainFlutterWindow.swift` places the native buttons
/// and in the colours FmWindow draws them.
///
/// Placement (`layoutTrafficLights`): the buttons' container spans the top
/// of the window and is `titleBarHeight` tall (the title bar above its
/// bottom line, 37 px); each circle is `diameter` wide (12 px), centred
/// vertically in it; the first starts `leading` (14 px) from the leading
/// edge and each next one `diameter + spacing` (12 + 8 px) further. In
/// right to left the leading edge is the right one and close is
/// rightmost (a12-1ar). The native code aligns the buttons' frames to whole
/// device pixels; at 1x a circle centred in the 37 px bar starts half a
/// pixel down, as the design's own lights do (FmWindow centres them in the
/// same 37 px), so the painter keeps the exact centre.
///
/// Colours (`FmWindow.dc.html` line 18, [WindowChrome]): close `#FF5F57`,
/// minimize `#FEBC2E`, zoom `#28C840`, each with an inner edge
/// `inset 0 0 0 0.5px rgba(0,0,0,.25)`. The design draws the same lights in
/// light and dark.
class TrafficLightsPainter extends CustomPainter {
  /// Paints the lights of [layout] and repaints when it changes.
  new(this.layout) : super(repaint: layout);

  /// The layout the title bar sent.
  final ValueListenable<TrafficLightLayout?> layout;

  /// The lights from the leading edge: close, minimize, zoom.
  static const List<Color> colors = [
    WindowChrome.macClose,
    WindowChrome.macMinimize,
    WindowChrome.macZoom,
  ];

  /// The circles of [layout] in a window [width] wide, in [colors] order.
  static List<Rect> circles(TrafficLightLayout layout, double width) => [
    for (var index = 0; index < colors.length; index++)
      Rect.fromLTWH(
        _circleStart(layout, index, width),
        (layout.titleBarHeight - layout.diameter) / 2,
        layout.diameter,
        layout.diameter,
      ),
  ];

  // `offset` and `circleStart` in `layoutTrafficLights`.
  static double _circleStart(
    TrafficLightLayout layout,
    int index,
    double width,
  ) {
    final offset = layout.leading + index * (layout.diameter + layout.spacing);
    return layout.rightToLeft ? width - offset - layout.diameter : offset;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final value = layout.value;
    if (value == null) return;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = WindowChrome.macLightEdgeWidth
      ..color = WindowChrome.macLightEdge;
    final circles = TrafficLightsPainter.circles(value, size.width);
    for (var index = 0; index < circles.length; index++) {
      final circle = circles[index];
      canvas
        ..drawOval(circle, Paint()..color = colors[index])
        // The inset shadow: a ring inside the edge, as wide as the spread.
        ..drawOval(circle.deflate(WindowChrome.macLightEdgeWidth / 2), edge);
    }
  }

  @override
  bool shouldRepaint(TrafficLightsPainter oldDelegate) =>
      oldDelegate.layout != layout;
}
