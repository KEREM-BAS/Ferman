import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fonts.dart';

/// The font size of the samples. The test font, which Flutter uses for any
/// family it has not loaded, draws each glyph as a box one em wide.
const double _size = 40;

TextPainter _layout(String text, TextStyle style) => TextPainter(
  text: TextSpan(
    text: text,
    style: style.copyWith(fontSize: _size),
  ),
  textDirection: TextDirection.ltr,
)..layout();

/// The RGBA pixels of [text] drawn at the top left of a square canvas
/// twice the font size wide, so renders compare byte for byte.
Future<List<int>> _pixels(String text, TextStyle style) async {
  final side = (2 * _size).round();
  final painter = _layout(text, style);
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset.zero);
  final picture = recorder.endRecording();
  final image = await picture.toImage(side, side);
  final data = (await image.toByteData())!;
  image.dispose();
  picture.dispose();
  painter.dispose();
  return data.buffer.asUint8List();
}

void main() {
  test('flutter_test_config loads every bundled family', () {
    expect(
      loadedAppFontFamilies,
      containsAll(<String>[
        'IBM Plex Sans',
        'IBM Plex Serif',
        'IBM Plex Mono',
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ]),
    );
  });

  test('text renders with the real fonts, not the test font', () {
    for (final family in loadedAppFontFamilies) {
      final width = _layout('MZALA', TextStyle(fontFamily: family)).width;
      // Five test-font boxes are exactly five em wide.
      expect(width, isNot(closeTo(5 * _size, 0.5)), reason: family);
    }
  });

  test(
    'CJK text uses the system Noto Sans CJK font when it is installed',
    () async {
      const sample = '永';
      final viaFallback = await _pixels(
        sample,
        const TextStyle(
          fontFamily: 'IBM Plex Sans',
          fontFamilyFallback: [notoSansCjkFamily],
          color: Color(0xFF000000),
        ),
      );
      // What an unloaded family would draw: the test font's box.
      final testFont = await _pixels(
        sample,
        const TextStyle(fontFamily: 'FlutterTest', color: Color(0xFF000000)),
      );
      // What Plex Sans alone draws: its missing-glyph box.
      final plexOnly = await _pixels(
        sample,
        const TextStyle(fontFamily: 'IBM Plex Sans', color: Color(0xFF000000)),
      );
      expect(viaFallback, isNot(testFont));
      expect(viaFallback, isNot(plexOnly));
      // A full-width ideograph is one em wide.
      expect(
        _layout(sample, const TextStyle(fontFamily: notoSansCjkFamily)).width,
        closeTo(_size, 0.5),
      );
    },
    skip: cjkFallbackLoaded
        ? false
        : 'fonts-noto-cjk is not installed ($notoSansCjkPath)',
  );
}
