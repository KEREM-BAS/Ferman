import 'dart:math' as math;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The weight a typed signature takes: Caveat and Dancing Script at 500 as
/// a5-3 sets them (the engine's FaceInstance does the same).
const double handwritingWeight = 500;

/// A typed signature's line height: the glyphs' own box (`/1`).
const double handwritingLine = 1;

/// The style of [family] at [size] in [color], as a5-3's tiles set it.
TextStyle handwritingStyle(
  BuildContext context,
  String family,
  double size,
  Color color,
) => TextStyle(
  fontFamily: family,
  fontSize: size,
  height: handwritingLine,
  color: color,
  fontVariations: family == 'Homemade Apple'
      ? null
      : const [FontVariation.weight(handwritingWeight)],
);

/// A signature's ink, fitted into the space it is given: the name in its
/// style, the strokes, or the image as chosen (a5-3d's real previews).
/// shortcut: an image shows as chosen, not cleaned to its ink as the engine
/// places it; upgrade when the engine gives the cleaned image back.
class SignaturePreview extends StatelessWidget {
  /// Shows [signature] at most [height] high.
  const new({required this.signature, required this.height, super.key});

  /// What to show.
  final SavedSignature signature;

  /// Its text size, and a drawing's or image's height.
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = signature.color.color;
    return switch (signature.ink) {
      TypedInk(:final text, :final family) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // The name keeps its own direction, whatever the UI's.
        textDirection: TextDirection.ltr,
        style: handwritingStyle(context, family, height, color),
      ),
      DrawnInk(:final strokes, :final width) => SizedBox(
        height: height,
        child: AspectRatio(
          aspectRatio: _aspect(strokes),
          child: CustomPaint(
            painter: _InkPainter(strokes: strokes, width: width, color: color),
          ),
        ),
      ),
      ImageInk(:final bytes) => SizedBox(
        height: height,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, _, _) => Icon(
            IconName.image,
            size: height,
            color: context.ferman.colors.iconSecondary,
          ),
        ),
      ),
    };
  }

  static Rect _bounds(List<List<Offset>> strokes) {
    final points = strokes.expand((stroke) => stroke);
    if (points.isEmpty) return Rect.zero;
    var box = Rect.fromPoints(points.first, points.first);
    for (final point in points) {
      box = box.expandToInclude(Rect.fromPoints(point, point));
    }
    return box;
  }

  static double _aspect(List<List<Offset>> strokes) {
    final box = _bounds(strokes);
    return box.height <= 0 ? 4 : math.max(box.width / box.height, 0.25);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<SavedSignature>('signature', signature))
      ..add(DoubleProperty('height', height));
  }
}

/// The strokes cropped to their ink and fitted into the box.
class _InkPainter extends CustomPainter {
  const new({required this.strokes, required this.width, required this.color});

  final List<List<Offset>> strokes;
  final double width;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final box = SignaturePreview._bounds(strokes).inflate(width);
    if (box.isEmpty) return;
    final scale = math.min(size.width / box.width, size.height / box.height);
    canvas
      ..scale(scale)
      ..translate(-box.left, -box.top);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (final stroke in strokes) {
      canvas.drawPath(SignatureStrokesPainter.pathOf(stroke), paint);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) =>
      !identical(old.strokes, strokes) ||
      old.width != width ||
      old.color != color;
}
