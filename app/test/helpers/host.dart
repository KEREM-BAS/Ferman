import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Icon;

/// Wraps [child] in what a Ferman widget needs outside the app: a
/// [Directionality] and, when [textStyle] is given, a [DefaultTextStyle].
///
/// The child is centred, so it takes its own size instead of the test
/// view's.
Widget host(
  Widget child, {
  TextDirection textDirection = TextDirection.ltr,
  TextStyle? textStyle,
}) {
  Widget result = Center(child: child);
  if (textStyle != null) {
    result = DefaultTextStyle(style: textStyle, child: result);
  }
  return Directionality(textDirection: textDirection, child: result);
}

/// The RGBA pixels of [painter] painted into a [width] × [height] image.
///
/// Call it from a plain `test`, or inside `tester.runAsync` in a
/// `testWidgets`, because the image is made by the engine asynchronously.
Future<RgbaImage> paintToImage(
  CustomPainter painter, {
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData();
    return RgbaImage(width, height, data!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// Raw RGBA pixels, four bytes per pixel, rows from the top.
final class RgbaImage {
  /// Wraps [bytes] of an image [width] pixels wide and [height] tall.
  const new(this.width, this.height, this.bytes);

  /// The width in pixels.
  final int width;

  /// The height in pixels.
  final int height;

  /// The pixels.
  final Uint8List bytes;

  /// The alpha value of the pixel at ([x], [y]).
  int alphaAt(int x, int y) => bytes[(y * width + x) * 4 + 3];

  /// The sum of all alpha values: how much ink the image holds.
  int get ink {
    var sum = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      sum += bytes[i];
    }
    return sum;
  }

  /// The largest difference of any channel of any pixel between this image
  /// and [other], which must have the same size.
  int maxDifference(RgbaImage other) {
    assert(
      other.width == width && other.height == height,
      'images differ in size',
    );
    var max = 0;
    for (var i = 0; i < bytes.length; i++) {
      final difference = (bytes[i] - other.bytes[i]).abs();
      if (difference > max) max = difference;
    }
    return max;
  }

  /// This image mirrored around its vertical centre line.
  RgbaImage flippedHorizontally() {
    final out = Uint8List(bytes.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final from = (y * width + x) * 4;
        final to = (y * width + (width - 1 - x)) * 4;
        out.setRange(to, to + 4, bytes, from);
      }
    }
    return RgbaImage(width, height, out);
  }

  /// This image at half its width and height, each pixel the average of a
  /// 2 × 2 block. The width and height must be even.
  RgbaImage halved() {
    assert(width.isEven && height.isEven, 'odd image size');
    final w = width ~/ 2;
    final h = height ~/ 2;
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        for (var c = 0; c < 4; c++) {
          var sum = 0;
          for (var dy = 0; dy < 2; dy++) {
            for (var dx = 0; dx < 2; dx++) {
              sum += bytes[((2 * y + dy) * width + 2 * x + dx) * 4 + c];
            }
          }
          out[(y * w + x) * 4 + c] = (sum + 2) ~/ 4;
        }
      }
    }
    return RgbaImage(w, h, out);
  }

  /// The mean difference of the alpha values of this image and [other],
  /// which must have the same size: 0 when the coverage is identical, 255
  /// when every pixel is opaque in one and clear in the other.
  double meanAlphaDifference(RgbaImage other) {
    assert(
      other.width == width && other.height == height,
      'images differ in size',
    );
    var sum = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      sum += (bytes[i] - other.bytes[i]).abs();
    }
    return sum / (width * height);
  }
}
