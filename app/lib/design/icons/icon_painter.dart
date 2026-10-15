import 'dart:math' as math;

import 'package:ferman/design/icons/icon_data.g.dart';
import 'package:ferman/design/icons/icon_element.dart';
import 'package:ferman/design/icons/icon_name.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_parsing/path_parsing.dart';

/// Paints one design glyph the way the design system's `Icon` component
/// draws it (`components/core/Icon.jsx` in `_ds_bundle.js`, ADR 0013).
///
/// The component renders an inline SVG with `viewBox="0 0 24 24"`,
/// `fill="none"`, `stroke` in the icon colour, `stroke-width` 1.5 and round
/// caps and joins. The stroke width is an SVG attribute, so it is in viewBox
/// units and scales with the size: 1.5 at 24 px is 1.5 px, at 16 px it is
/// 1 px. This painter does the same: it scales the canvas by size / 24 and
/// strokes every element of [name] with [strokeWidth] in viewBox units.
/// Elements marked [IconElement.filled] are filled first, as SVG paints the
/// fill before the stroke.
///
/// Each element is drawn on its own, as the browser draws each SVG element,
/// so overlapping elements in a translucent colour blend the same way.
/// The paths are parsed once per icon and cached ([pathsOf]).
final class IconPainter extends CustomPainter {
  /// Creates a painter for [name] in [color].
  ///
  /// [strokeWidth] is in viewBox units. [mirror] flips the glyph around
  /// its vertical centre line, as the design's `scaleX(-1)` does for
  /// directional icons in right to left.
  const new({
    required this.name,
    required this.color,
    this.strokeWidth = defaultStrokeWidth,
    this.mirror = false,
  });

  /// The side of the square viewBox the design draws every icon in.
  static const double viewBoxSize = 24;

  /// The stroke width the design-system `Icon` component uses, in viewBox
  /// units (`strokeWidth = 1.5`).
  static const double defaultStrokeWidth = 1.5;

  /// The glyph to paint.
  final IconName name;

  /// The stroke colour, and the fill colour of filled elements.
  final Color color;

  /// The stroke width in viewBox units.
  final double strokeWidth;

  /// Whether the glyph is mirrored horizontally.
  final bool mirror;

  static final Map<IconName, List<_Shape>> _cache = {};

  /// The paths of [name] in viewBox units, one per SVG element in drawing
  /// order, parsed on first use and cached for the life of the app.
  ///
  /// The returned paths are shared: never change them.
  @visibleForTesting
  static List<Path> pathsOf(IconName name) => [
    for (final shape in _shapesOf(name)) shape.path,
  ];

  static List<_Shape> _shapesOf(IconName name) => _cache.putIfAbsent(
    name,
    () => List.unmodifiable([
      for (final element in name.elements)
        _Shape(_pathOf(element), filled: element.filled),
    ]),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // preserveAspectRatio="xMidYMid meet", the SVG default.
    final scale = math.min(size.width, size.height) / viewBoxSize;
    final dx = (size.width - viewBoxSize * scale) / 2;
    final dy = (size.height - viewBoxSize * scale) / 2;

    canvas.save();
    if (mirror) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas
      ..translate(dx, dy)
      ..scale(scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint? fill;
    for (final shape in _shapesOf(name)) {
      if (shape.filled) {
        canvas.drawPath(shape.path, fill ??= Paint()..color = color);
      }
      canvas.drawPath(shape.path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(IconPainter oldDelegate) =>
      oldDelegate.name != name ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.mirror != mirror;
}

/// One parsed element: its path and whether it is also filled.
final class _Shape {
  const new(this.path, {required this.filled});

  final Path path;
  final bool filled;
}

/// The path of one SVG element, following the SVG 1.1 shape definitions.
Path _pathOf(IconElement element) => switch (element) {
  IconPath(:final d) => _parseSvgPath(d),
  IconCircle(:final cx, :final cy, :final r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
  IconEllipse(:final cx, :final cy, :final rx, :final ry) =>
    Path()..addOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 2 * rx, height: 2 * ry),
    ),
  final IconRect rect => _rectPath(rect),
  IconLine(:final x1, :final y1, :final x2, :final y2) =>
    Path()
      ..moveTo(x1, y1)
      ..lineTo(x2, y2),
  // A polyline is the path `M` + points; a polygon closes it with `Z`.
  IconPolyline(:final points) => _parseSvgPath('M$points'),
  IconPolygon(:final points) => _parseSvgPath('M$points Z'),
};

/// `<rect>` with SVG's corner rules: a missing radius takes the other one,
/// and each radius is clamped to half the side it runs along.
Path _rectPath(IconRect rect) {
  final bounds = Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height);
  final rx = (rect.rx ?? rect.ry ?? 0).clamp(0.0, rect.width / 2);
  final ry = (rect.ry ?? rect.rx ?? 0).clamp(0.0, rect.height / 2);
  if (rx == 0 || ry == 0) return Path()..addRect(bounds);
  return Path()..addRRect(RRect.fromRectXY(bounds, rx, ry));
}

Path _parseSvgPath(String data) {
  final writer = _PathWriter();
  writeSvgPathDataToPath(data, writer);
  return writer.path;
}

/// Feeds path_parsing's normalised commands (move, line, cubic, close)
/// into a [Path].
final class _PathWriter implements PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) => path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}
