import 'dart:math' as math;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The lines of [now] that differ from [before], a block's lines before its
/// first edit: those between the longest run that stayed the same at the
/// start and the longest that stayed the same at the end.
List<TextLine> changedLines(List<String> before, List<TextLine> now) {
  final most = math.min(before.length, now.length);
  var start = 0;
  while (start < most && before[start] == now[start].text) {
    start++;
  }
  var end = 0;
  while (end < most - start &&
      before[before.length - 1 - end] == now[now.length - 1 - end].text) {
    end++;
  }
  return now.sublist(start, now.length - end);
}

/// One changed line's marks on the canvas (f3): the line's box, its
/// baseline's position across the line, the margin bar, and whether the
/// line runs down the page.
typedef EditMark = ({Rect line, double baseline, Rect bar, bool vertical});

/// The marks of [line], a changed line of a block framed at [frame] and
/// running in [direction], all on the canvas. The bar's [barGap] and
/// [barWidth] stay in screen pixels at every zoom, as the underline does.
EditMark editMark({
  required Rect line,
  required Rect frame,
  required Offset baseline,
  required BlockDirection direction,
  required double barGap,
  required double barWidth,
}) => (
  line: line,
  baseline: direction == BlockDirection.vertical ? baseline.dx : baseline.dy,
  // The bar sits outside the block's own start: the canvas does not mirror
  // with the UI, and a vertical block starts at its top.
  bar: switch (direction) {
    BlockDirection.leftToRight => Rect.fromLTWH(
      frame.left - barGap - barWidth,
      line.top,
      barWidth,
      line.height,
    ),
    BlockDirection.rightToLeft => Rect.fromLTWH(
      frame.right + barGap,
      line.top,
      barWidth,
      line.height,
    ),
    BlockDirection.vertical => Rect.fromLTWH(
      line.left,
      frame.top - barGap - barWidth,
      line.width,
      barWidth,
    ),
  },
  vertical: direction == BlockDirection.vertical,
);

/// Paints the marks of the changed lines on the canvas (f3): a dotted
/// underline and a margin bar, a line and never a fill. It paints only on
/// the screen: nothing here reaches the engine, so the marks are never saved
/// or printed.
class EditMarksPainter extends CustomPainter {
  /// Paints [marks] in [color], snapped to [devicePixelRatio].
  const new({
    required this.marks,
    required this.color,
    required this.devicePixelRatio,
  });

  /// The changed lines' marks.
  final List<EditMark> marks;

  /// `--edit-mark`.
  final Color color;

  /// The screen's pixels per logical pixel.
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Paint()..color = color;
    final underline = MarkPaint.dottedUnderline(
      color,
      PageMark.editedThickness,
      PageMark.underlineOffset,
      devicePixelRatio: devicePixelRatio,
    );
    for (final mark in marks) {
      canvas.drawRect(mark.bar, bar);
      if (!mark.vertical) {
        underline(
          canvas,
          MarkFragment(rect: mark.line, baseline: mark.baseline),
        );
        continue;
      }
      // Text that runs down the page: the underline turned with it, along
      // the column's right side.
      canvas
        ..save()
        ..translate(mark.line.right, mark.line.top)
        ..rotate(-math.pi / 2);
      underline(
        canvas,
        MarkFragment(
          rect: Rect.fromLTWH(-mark.line.height, 0, mark.line.height, 0),
          baseline: 0,
        ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(EditMarksPainter old) =>
      !listEquals(old.marks, marks) ||
      old.color != color ||
      old.devicePixelRatio != devicePixelRatio;
}
