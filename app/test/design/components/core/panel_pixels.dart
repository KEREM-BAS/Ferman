import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The key of the panel [onPanel] builds.
const Key panelKey = Key('panel');

/// [child] on a panel of [color] with 8 px around it, so an outer focus
/// ring (4 px) lands on the panel, inside the repaint boundary that
/// [PanelPixels.capture] reads.
Widget onPanel(Color color, Widget child) => RepaintBoundary(
  key: panelKey,
  child: ColoredBox(
    color: color,
    child: Padding(padding: const EdgeInsets.all(8), child: child),
  ),
);

/// The rendered pixels of the panel [onPanel] builds, for checks that only
/// the real paint can answer (what shows through a transparent control).
final class PanelPixels {
  const new _(this._bytes, this._width, this._origin);

  final ByteData _bytes;
  final int _width;
  final Offset _origin;

  /// Renders the panel of the current frame.
  static Future<PanelPixels> capture(WidgetTester tester) async {
    final finder = find.byKey(panelKey);
    final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
    final origin = tester.getTopLeft(finder);
    final image = (await tester.runAsync(boundary.toImage))!;
    // rawRgba is the default format.
    final bytes = (await tester.runAsync(image.toByteData))!;
    final width = image.width;
    image.dispose();
    return PanelPixels._(bytes, width, origin);
  }

  /// Where [finder]'s widget sits in the panel's pixels.
  Rect rectOf(WidgetTester tester, Finder finder) =>
      tester.getRect(finder).shift(-_origin);

  /// The colour of the pixel at column [x] and row [y].
  Color at(int x, int y) {
    final i = (y * _width + x) * 4;
    return Color.fromARGB(
      _bytes.getUint8(i + 3),
      _bytes.getUint8(i),
      _bytes.getUint8(i + 1),
      _bytes.getUint8(i + 2),
    );
  }
}
