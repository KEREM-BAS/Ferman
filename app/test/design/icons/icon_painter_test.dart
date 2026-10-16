import 'dart:ui' show PictureRecorder;

import 'package:ferman/design/icons/icon_data.g.dart';
import 'package:ferman/design/icons/icon_element.dart';
import 'package:ferman/design/icons/icon_name.g.dart';
import 'package:ferman/design/icons/icon_painter.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/host.dart';

const _ink = Color(0xFF3A3732);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IconPainter.pathsOf', () {
    test('has one path per SVG element of every icon', () {
      for (final name in IconName.values) {
        expect(
          IconPainter.pathsOf(name),
          hasLength(name.elements.length),
          reason: name.id,
        );
      }
    });

    test('keeps every icon inside its 24 × 24 viewBox', () {
      // The design draws inside the viewBox; a misparsed command would
      // throw the path far outside it. Lucide's arcs may touch the edge.
      const viewBox = Rect.fromLTWH(-0.5, -0.5, 25, 25);
      for (final name in IconName.values) {
        for (final path in IconPainter.pathsOf(name)) {
          final bounds = path.getBounds();
          expect(
            viewBox.contains(bounds.topLeft) &&
                viewBox.contains(bounds.bottomRight),
            isTrue,
            reason: '${name.id}: $bounds',
          );
        }
      }
    });

    test('parses each icon once and caches the paths', () {
      final first = IconPainter.pathsOf(IconName.search);
      final second = IconPainter.pathsOf(IconName.search);
      for (var i = 0; i < first.length; i++) {
        expect(identical(first[i], second[i]), isTrue);
      }
    });

    test('draws each element kind at its SVG geometry', () {
      // archive: <rect x="2" y="3" width="20" height="5" rx="1"/>, then
      // two paths.
      expect(
        IconPainter.pathsOf(IconName.archive).first.getBounds(),
        const Rect.fromLTRB(2, 3, 22, 8),
      );
      // ellipse: <ellipse cx="12" cy="12" rx="10" ry="7"/>.
      expect(
        IconPainter.pathsOf(IconName.ellipse).single.getBounds(),
        const Rect.fromLTRB(2, 5, 22, 19),
      );
      // minus: <path d="M5 12h14"/>.
      expect(
        IconPainter.pathsOf(IconName.minus).single.getBounds(),
        const Rect.fromLTRB(5, 12, 19, 12),
      );
      // Every element kind the generator emits occurs at least once.
      final kinds = {
        for (final name in IconName.values)
          for (final element in name.elements) element.runtimeType,
      };
      expect(kinds, {
        IconPath,
        IconCircle,
        IconEllipse,
        IconRect,
        IconLine,
        IconPolyline,
        IconPolygon,
      });
    });

    test('fills only the elements the design fills', () {
      final filled = {
        for (final name in IconName.values)
          if (name.elements.any((element) => element.filled)) name.id,
      };
      expect(filled, {'key-round', 'palette', 'tag'});
    });
  });

  group('IconPainter.paint', () {
    test('paints every icon with visible ink', () async {
      for (final name in IconName.values) {
        final image = await paintToImage(
          IconPainter(name: name, color: _ink),
          width: 24,
          height: 24,
        );
        expect(image.ink, greaterThan(0), reason: name.id);
      }
    });

    test(
      'scales the stroke with the size, as the SVG attribute does',
      () async {
        final small = await paintToImage(
          const IconPainter(name: IconName.minus, color: _ink),
          width: 24,
          height: 24,
        );
        final large = await paintToImage(
          const IconPainter(name: IconName.minus, color: _ink),
          width: 48,
          height: 48,
        );
        // Twice the size: twice as long and twice as thick.
        expect(large.ink / small.ink, closeTo(4, 0.4));
      },
    );

    test('takes the stroke width in viewBox units', () async {
      final thin = await paintToImage(
        const IconPainter(name: IconName.minus, color: _ink),
        width: 24,
        height: 24,
      );
      final thick = await paintToImage(
        const IconPainter(name: IconName.minus, color: _ink, strokeWidth: 3),
        width: 24,
        height: 24,
      );
      // Round caps add half the width at each end, so a bit over twice.
      expect(thick.ink / thin.ink, inInclusiveRange(1.9, 2.4));
    });

    test('centres the viewBox in a box that is not square', () async {
      final wide = await paintToImage(
        const IconPainter(name: IconName.minus, color: _ink),
        width: 48,
        height: 24,
      );
      // The 24 × 24 glyph sits in the middle: nothing in the outer columns.
      for (var y = 0; y < 24; y++) {
        for (final x in [0, 1, 2, 3, 44, 45, 46, 47]) {
          expect(wide.alphaAt(x, y), 0, reason: '($x, $y)');
        }
      }
      expect(wide.ink, greaterThan(0));
    });

    test('paints nothing into an empty box', () {
      // An empty size must not throw or divide by zero.
      final recorder = PictureRecorder();
      const IconPainter(
        name: IconName.search,
        color: _ink,
      ).paint(Canvas(recorder), Size.zero);
      recorder.endRecording().dispose();
    });
  });

  test('repaints only when something visible changes', () {
    const base = IconPainter(name: IconName.search, color: _ink);
    expect(
      base.shouldRepaint(const IconPainter(name: IconName.search, color: _ink)),
      isFalse,
    );
    expect(
      base.shouldRepaint(const IconPainter(name: IconName.x, color: _ink)),
      isTrue,
    );
    expect(
      base.shouldRepaint(
        const IconPainter(name: IconName.search, color: Color(0xFF000000)),
      ),
      isTrue,
    );
    expect(
      base.shouldRepaint(
        const IconPainter(name: IconName.search, color: _ink, strokeWidth: 2),
      ),
      isTrue,
    );
    expect(
      base.shouldRepaint(
        const IconPainter(name: IconName.search, color: _ink, mirror: true),
      ),
      isTrue,
    );
  });
}
