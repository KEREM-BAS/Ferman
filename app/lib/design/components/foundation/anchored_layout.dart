import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The side of an anchor a floating surface opens on, in physical terms.
///
/// Components take logical sides from their callers and resolve them with
/// [resolve] for the ambient text direction.
enum AnchorSide {
  /// Above the anchor.
  top,

  /// Below the anchor.
  bottom,

  /// To the left of the anchor.
  left,

  /// To the right of the anchor.
  right;

  /// This side mirrored for [direction]: left and right swap in right to
  /// left, top and bottom stay.
  AnchorSide resolve(TextDirection direction) {
    if (direction == TextDirection.ltr) return this;
    return switch (this) {
      AnchorSide.left => AnchorSide.right,
      AnchorSide.right => AnchorSide.left,
      AnchorSide.top || AnchorSide.bottom => this,
    };
  }

  /// The opposite side.
  AnchorSide get opposite => switch (this) {
    AnchorSide.top => AnchorSide.bottom,
    AnchorSide.bottom => AnchorSide.top,
    AnchorSide.left => AnchorSide.right,
    AnchorSide.right => AnchorSide.left,
  };

  /// Whether the surface sits above or below the anchor.
  bool get isVertical => this == AnchorSide.top || this == AnchorSide.bottom;
}

/// How a floating surface lines up with its anchor across the side it opens
/// on, in physical terms.
enum AnchorAlignment {
  /// Centred on the anchor (tooltips: the CSS `translateX(-50%)`).
  center,

  /// The surface's left or top edge on the anchor's (menus and popovers in
  /// left to right).
  leading,

  /// The surface's right or bottom edge on the anchor's (menus and popovers
  /// in right to left).
  trailing,
}

/// Places a floating surface (tooltip, popover, menu) next to an [anchor]
/// rectangle inside an overlay.
///
/// The surface opens on [side], [gap] away from the anchor, lined up by
/// [alignment]. When it does not fit on [side] and fits better on the
/// opposite side, it flips. It is then kept [margin] inside the overlay on
/// both axes, and its constraints never let it grow beyond the overlay
/// minus the margins.
///
/// Use it with `OverlayPortal.overlayChildLayoutBuilder`, whose layout info
/// gives the anchor's size and paint transform in the overlay
/// ([anchorRect]).
class FermanAnchoredLayout extends SingleChildLayoutDelegate {
  /// Lays out a surface next to [anchor].
  const new({
    required this.anchor,
    required this.side,
    this.alignment = AnchorAlignment.center,
    this.gap = 0,
    this.margin = 8,
  });

  /// The anchor's rectangle in the overlay's coordinates.
  final Rect anchor;

  /// The preferred side.
  final AnchorSide side;

  /// How the surface lines up with the anchor across [side].
  final AnchorAlignment alignment;

  /// The distance between the anchor and the surface.
  final double gap;

  /// The distance the surface keeps from the overlay's edges.
  final double margin;

  /// The anchor's rectangle in the overlay from an
  /// `OverlayPortal.overlayChildLayoutBuilder` layout info.
  static Rect anchorRect(OverlayChildLayoutInfo info) =>
      MatrixUtils.transformRect(
        info.childPaintTransform,
        Offset.zero & info.childSize,
      );

  /// The side the surface ends up on for an overlay of [size] and a surface
  /// of [childSize]: [side], or its opposite when the surface does not fit
  /// on [side] and the opposite has more room.
  AnchorSide effectiveSide(Size size, Size childSize) {
    double room(AnchorSide s) => switch (s) {
      AnchorSide.top => anchor.top - gap - margin,
      AnchorSide.bottom => size.height - anchor.bottom - gap - margin,
      AnchorSide.left => anchor.left - gap - margin,
      AnchorSide.right => size.width - anchor.right - gap - margin,
    };
    final needed = side.isVertical ? childSize.height : childSize.width;
    if (room(side) >= needed) return side;
    return room(side.opposite) > room(side) ? side.opposite : side;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.max(0, constraints.maxWidth - 2 * margin);
    final maxHeight = math.max(0, constraints.maxHeight - 2 * margin);
    return BoxConstraints(
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final placed = effectiveSide(size, childSize);
    double across(double start, double end, double extent) =>
        switch (alignment) {
          AnchorAlignment.center => (start + end - extent) / 2,
          AnchorAlignment.leading => start,
          AnchorAlignment.trailing => end - extent,
        };
    final (x, y) = switch (placed) {
      AnchorSide.top => (
        across(anchor.left, anchor.right, childSize.width),
        anchor.top - gap - childSize.height,
      ),
      AnchorSide.bottom => (
        across(anchor.left, anchor.right, childSize.width),
        anchor.bottom + gap,
      ),
      AnchorSide.left => (
        anchor.left - gap - childSize.width,
        across(anchor.top, anchor.bottom, childSize.height),
      ),
      AnchorSide.right => (
        anchor.right + gap,
        across(anchor.top, anchor.bottom, childSize.height),
      ),
    };
    double clamp(double value, double extent, double available) {
      final max = available - margin - extent;
      if (max < margin) return margin;
      return value.clamp(margin, max);
    }

    return Offset(
      clamp(x, childSize.width, size.width),
      clamp(y, childSize.height, size.height),
    );
  }

  @override
  bool shouldRelayout(FermanAnchoredLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      side != oldDelegate.side ||
      alignment != oldDelegate.alignment ||
      gap != oldDelegate.gap ||
      margin != oldDelegate.margin;
}
