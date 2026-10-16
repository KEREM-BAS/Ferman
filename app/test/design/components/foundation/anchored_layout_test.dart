import 'package:ferman/design/components/foundation/anchored_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const overlay = Size(400, 300);
  const bubble = Size(80, 20);
  const anchor = Rect.fromLTWH(160, 100, 40, 20);

  Offset place(
    Rect anchor, {
    AnchorSide side = AnchorSide.bottom,
    AnchorAlignment alignment = AnchorAlignment.center,
    Size child = bubble,
    double gap = 6,
  }) => FermanAnchoredLayout(
    anchor: anchor,
    side: side,
    alignment: alignment,
    gap: gap,
  ).getPositionForChild(overlay, child);

  group('AnchorSide', () {
    test('left and right swap in right to left; top and bottom stay', () {
      expect(AnchorSide.left.resolve(TextDirection.rtl), AnchorSide.right);
      expect(AnchorSide.right.resolve(TextDirection.rtl), AnchorSide.left);
      expect(AnchorSide.top.resolve(TextDirection.rtl), AnchorSide.top);
      expect(AnchorSide.left.resolve(TextDirection.ltr), AnchorSide.left);
    });

    test('opposite and vertical', () {
      expect(AnchorSide.top.opposite, AnchorSide.bottom);
      expect(AnchorSide.left.opposite, AnchorSide.right);
      expect(AnchorSide.bottom.isVertical, isTrue);
      expect(AnchorSide.right.isVertical, isFalse);
    });
  });

  group('FermanAnchoredLayout', () {
    test('centres the surface below the anchor, gap away', () {
      expect(place(anchor), const Offset(140, 126));
    });

    test('opens above, to the left and to the right', () {
      expect(place(anchor, side: AnchorSide.top), const Offset(140, 74));
      expect(place(anchor, side: AnchorSide.left), const Offset(74, 100));
      expect(place(anchor, side: AnchorSide.right), const Offset(206, 100));
    });

    test('lines up the leading or trailing edge', () {
      expect(
        place(anchor, alignment: AnchorAlignment.leading),
        const Offset(160, 126),
      );
      expect(
        place(anchor, alignment: AnchorAlignment.trailing),
        const Offset(120, 126),
      );
    });

    test('flips to the other side when it does not fit', () {
      const nearBottom = Rect.fromLTWH(160, 270, 40, 20);
      expect(place(nearBottom).dy, 270 - 6 - 20);
      const nearTop = Rect.fromLTWH(160, 2, 40, 20);
      expect(place(nearTop, side: AnchorSide.top).dy, 2 + 20 + 6);
    });

    test('stays on its side when the other side has no more room', () {
      const tall = Size(80, 290);
      final y = place(anchor, child: tall).dy;
      // Neither side fits; it stays below and is clamped to the margin.
      expect(y, 8);
    });

    test('keeps a margin from the overlay edges', () {
      const atStart = Rect.fromLTWH(0, 100, 20, 20);
      expect(place(atStart).dx, 8);
      const atEnd = Rect.fromLTWH(390, 100, 10, 20);
      expect(place(atEnd).dx, 400 - 8 - 80);
    });

    test('limits the surface to the overlay minus the margins', () {
      const delegate = FermanAnchoredLayout(
        anchor: anchor,
        side: AnchorSide.bottom,
      );
      final constraints = delegate.getConstraintsForChild(
        BoxConstraints.tight(overlay),
      );
      expect(constraints.maxWidth, 384);
      expect(constraints.maxHeight, 284);
      expect(constraints.minWidth, 0);
    });

    test('relayouts only when an input changes', () {
      const a = FermanAnchoredLayout(anchor: anchor, side: AnchorSide.bottom);
      const same = FermanAnchoredLayout(
        anchor: anchor,
        side: AnchorSide.bottom,
      );
      const moved = FermanAnchoredLayout(
        anchor: Rect.fromLTWH(0, 0, 1, 1),
        side: AnchorSide.bottom,
      );
      expect(a.shouldRelayout(same), isFalse);
      expect(a.shouldRelayout(moved), isTrue);
    });
  });
}
