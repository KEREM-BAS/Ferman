import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/icons/icon_painter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/host.dart';

const _ink = Color(0xFF3A3732);
const _textColor = Color(0xFF6F6A62);
const _iconThemeColor = Color(0xFF2A4DAF);

/// The painter of the only [Icon] in the tree.
IconPainter _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Icon), matching: find.byType(CustomPaint)),
  );
  return paint.painter! as IconPainter;
}

/// The pixels of an [Icon] of [size] as the framework paints it, at a
/// device pixel ratio of 1.
Future<RgbaImage> _paintedIcon(
  WidgetTester tester, {
  required double size,
}) async {
  await tester.pumpWidget(
    host(
      RepaintBoundary(
        child: Icon(IconName.search, size: size, color: _ink),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .ancestor(of: find.byType(Icon), matching: find.byType(RepaintBoundary))
        .first,
  );
  final image = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData();
      return RgbaImage(image.width, image.height, data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
  return image!;
}

void main() {
  group('Icon size', () {
    testWidgets('defaults to the design-system 16 px', (tester) async {
      await tester.pumpWidget(host(const Icon(IconName.search)));
      expect(tester.getSize(find.byType(Icon)), const Size.square(16));
      expect(Icon.defaultSize, 16);
    });

    testWidgets('takes the given size', (tester) async {
      await tester.pumpWidget(host(const Icon(IconName.search, size: 24)));
      expect(tester.getSize(find.byType(Icon)), const Size.square(24));
    });

    testWidgets('paints the 24 viewBox scaled into the box', (tester) async {
      final small = await _paintedIcon(tester, size: 12);
      final large = await _paintedIcon(tester, size: 24);
      expect(small.width, 12);
      expect(large.width, 24);
      expect(small.ink, greaterThan(0));
      // At twice the size the strokes are twice as long and twice as wide
      // (the stroke width is in viewBox units): about four times the ink.
      expect(large.ink / small.ink, inInclusiveRange(3.5, 5));
      // And the same coverage in the same places: the 24 px glyph halved
      // matches the 12 px one (about 9 of 255 apart on average; a glyph
      // drawn unscaled and clipped to the box is about 60 apart).
      expect(small.meanAlphaDifference(large.halved()), lessThan(20));
    });
  });

  group('Icon colour', () {
    testWidgets('uses the given colour', (tester) async {
      await tester.pumpWidget(
        host(
          const Icon(IconName.search, color: _ink),
          textStyle: const TextStyle(color: _textColor),
        ),
      );
      expect(_painterOf(tester).color, _ink);
    });

    testWidgets('inherits the DefaultTextStyle colour, like currentColor', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Icon(IconName.search),
          textStyle: const TextStyle(color: _textColor),
        ),
      );
      expect(_painterOf(tester).color, _textColor);
    });

    testWidgets('follows the DefaultTextStyle colour even under an IconTheme', (
      tester,
    ) async {
      // Material's Theme, and so the app's, always inserts an IconTheme with
      // a colour; the icon still follows the text around it.
      await tester.pumpWidget(
        host(
          const IconTheme(
            data: IconThemeData(color: _iconThemeColor),
            child: Icon(IconName.search),
          ),
          textStyle: const TextStyle(color: _textColor),
        ),
      );
      expect(_painterOf(tester).color, _textColor);
    });

    testWidgets('follows a nearer DefaultTextStyle colour', (tester) async {
      await tester.pumpWidget(
        host(
          const DefaultTextStyle(
            style: TextStyle(color: _ink),
            child: Icon(IconName.search),
          ),
          textStyle: const TextStyle(color: _textColor),
        ),
      );
      expect(_painterOf(tester).color, _ink);
    });

    testWidgets('uses the IconTheme colour when the text style has none', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const IconTheme(
            data: IconThemeData(color: _iconThemeColor),
            child: Icon(IconName.search),
          ),
        ),
      );
      expect(_painterOf(tester).color, _iconThemeColor);
    });

    testWidgets('falls back to opaque black when nothing sets a colour', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Icon(IconName.search)));
      expect(_painterOf(tester).color, Icon.fallbackColor);
      expect(Icon.fallbackColor, const Color(0xFF000000));
    });
  });

  group('Icon stroke', () {
    testWidgets('defaults to the design-system 1.5 in viewBox units', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Icon(IconName.search)));
      expect(_painterOf(tester).strokeWidth, 1.5);
      expect(Icon.defaultStrokeWidth, 1.5);
    });

    testWidgets('takes the given stroke width', (tester) async {
      await tester.pumpWidget(
        host(const Icon(IconName.search, size: 12, strokeWidth: 2)),
      );
      expect(_painterOf(tester).strokeWidth, 2);
    });
  });

  group('Icon mirroring', () {
    const directionalIds = {
      'arrow-left',
      'arrow-right',
      'chevron-left',
      'chevron-right',
      'undo-2',
      'redo-2',
      'skip-back',
      'skip-forward',
    };

    test('exactly the eight glyphs the design flips are directional', () {
      expect({
        for (final name in IconName.values)
          if (name.directional) name.id,
      }, directionalIds);
    });

    Future<bool> mirrored(
      WidgetTester tester,
      IconName name, {
      required TextDirection direction,
      bool? flipRtl,
    }) async {
      await tester.pumpWidget(
        host(Icon(name, flipRtl: flipRtl), textDirection: direction),
      );
      return _painterOf(tester).mirror;
    }

    testWidgets('directional glyphs mirror in right to left only', (
      tester,
    ) async {
      for (final name in IconName.values.where((n) => n.directional)) {
        expect(
          await mirrored(tester, name, direction: TextDirection.rtl),
          isTrue,
          reason: '${name.id} in right to left',
        );
        expect(
          await mirrored(tester, name, direction: TextDirection.ltr),
          isFalse,
          reason: '${name.id} in left to right',
        );
      }
    });

    testWidgets('other glyphs never mirror by default', (tester) async {
      for (final name in [
        IconName.arrowLeftRight,
        IconName.chevronsLeft,
        IconName.chevronsRight,
        IconName.send,
        IconName.search,
      ]) {
        expect(
          await mirrored(tester, name, direction: TextDirection.rtl),
          isFalse,
          reason: name.id,
        );
      }
    });

    testWidgets('flipRtl overrides the directional flag', (tester) async {
      expect(
        await mirrored(
          tester,
          IconName.chevronRight,
          direction: TextDirection.rtl,
          flipRtl: false,
        ),
        isFalse,
      );
      expect(
        await mirrored(
          tester,
          IconName.send,
          direction: TextDirection.rtl,
          flipRtl: true,
        ),
        isTrue,
      );
      expect(
        await mirrored(
          tester,
          IconName.send,
          direction: TextDirection.ltr,
          flipRtl: true,
        ),
        isFalse,
      );
    });

    testWidgets('a mirrored glyph is the left-to-right one flipped', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const painter = IconPainter(name: IconName.arrowRight, color: _ink);
        const mirrored = IconPainter(
          name: IconName.arrowRight,
          color: _ink,
          mirror: true,
        );
        final ltr = await paintToImage(painter, width: 24, height: 24);
        final rtl = await paintToImage(mirrored, width: 24, height: 24);
        expect(ltr.ink, greaterThan(0));
        expect(rtl.bytes, isNot(ltr.bytes));
        // Anti-aliased edges are not sampled exactly symmetrically, so edge
        // pixels may differ slightly; unmirrored, whole strokes differ.
        expect(
          rtl.maxDifference(ltr.flippedHorizontally()),
          lessThanOrEqualTo(16),
        );
        expect(rtl.maxDifference(ltr), greaterThan(100));
      });
    });
  });

  group('Icon semantics', () {
    testWidgets('is excluded from semantics without a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const Icon(IconName.search)));
      final labelled = tester.semantics.simulatedAccessibilityTraversal().where(
        (node) => node.label.isNotEmpty,
      );
      expect(labelled, isEmpty);
      handle.dispose();
    });

    testWidgets('is an image with its label when labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const Icon(IconName.search, semanticLabel: 'Search')),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Search')),
        matchesSemantics(label: 'Search', isImage: true),
      );
      handle.dispose();
    });
  });

  testWidgets('every IconName builds and paints without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Wrap(
          children: [
            for (final name in IconName.values) Icon(name, color: _ink),
          ],
        ),
      ),
    );
    expect(find.byType(Icon), findsNWidgets(IconName.values.length));
    expect(IconName.values, hasLength(229));
    expect(tester.takeException(), isNull);
  });

  testWidgets('describes its properties', (tester) async {
    const icon = Icon(
      IconName.chevronRight,
      size: 12,
      color: _ink,
      strokeWidth: 2,
      flipRtl: false,
      semanticLabel: 'Next',
    );
    final description = icon.toDiagnosticsNode().toStringDeep();
    expect(description, contains('chevronRight'));
    expect(description, contains('size: 12.0'));
    expect(description, contains('strokeWidth: 2.0'));
    expect(description, contains('no flipRtl'));
    expect(description, contains('semanticLabel: "Next"'));
  });
}
