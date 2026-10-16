import 'dart:math' as math;

import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The ways the design system draws keyboard focus (G22, `effects.css`).
enum FocusRingStyle {
  /// `--focus-ring`: a 2 px gap in the raised surface colour, then 2 px of
  /// the focus colour, outside the control's own shape. Buttons, icon
  /// buttons, checkboxes, switches, thumbnails and pickers.
  outer,

  /// `--focus-ring-inset`: 2 px of the focus colour inside the control's
  /// shape. Tabs, segments and list rows, which sit edge to edge.
  inset,

  /// The field ring of `.fm-input:focus`: 1 px of the focus colour around
  /// the field, which also turns its border the focus colour.
  field,
}

/// Draws the design system's focus ring around [child] while [visible].
///
/// The ring follows [borderRadius], the shape of the control. An [outer]
/// ring is painted as bands outside that shape, 4 px wide in all; a
/// [field] ring as a 1 px band. The inside of the shape is left unpainted,
/// as CSS clips an outer box shadow to the outside of the border box, so a
/// transparent control (a ghost button) still shows its parent's colour
/// while focused ([FocusRingPainter]). An [inset] ring is painted over
/// [child].
///
/// The outer and field rings fade and grow in over [duration] with
/// [curve], as a CSS `box-shadow` transition does (pass the component's
/// `context.ferman.motion` duration, which is zero under reduced motion);
/// the default zero duration switches them at once. The inset ring always
/// switches at once: the controls that use it have no box-shadow
/// transition.
///
/// The ring never changes the control's size, so focusing a control never
/// moves its neighbours, and the widget tree stays the same whether the
/// ring shows or not, so showing it never rebuilds [child] from scratch
/// (focus nodes and animations below it keep their state). It is purely
/// visual: focus itself is handled by the component (usually through
/// `FermanInteractive`).
///
/// [outer]: FocusRingStyle.outer
/// [inset]: FocusRingStyle.inset
/// [field]: FocusRingStyle.field
class FocusRing extends StatelessWidget {
  /// Draws a [style] ring around [child] when [visible].
  const new({
    required this.visible,
    required this.child,
    super.key,
    this.style = FocusRingStyle.outer,
    this.borderRadius = BorderRadius.zero,
    this.duration = Duration.zero,
    this.curve = Curves.linear,
  });

  /// Whether the ring shows; usually the component's focus-visible state.
  final bool visible;

  /// The control the ring surrounds.
  final Widget child;

  /// Which ring to draw.
  final FocusRingStyle style;

  /// The control's corner radii, which the ring follows.
  final BorderRadiusGeometry borderRadius;

  /// How long an outer or field ring takes to appear and disappear; zero
  /// (the default) switches it at once.
  final Duration duration;

  /// The easing of [duration].
  final Curve curve;

  /// The box shadows of a [FocusRingStyle.outer] ring in [theme]: the
  /// design's `--focus-ring`, the focus colour outside a gap of the raised
  /// surface colour, in paint order (the gap last, on top).
  static List<BoxShadow> outerShadows(FermanTheme theme) =>
      theme.focus.focusRing;

  /// The box shadow of a [FocusRingStyle.field] ring in [theme]:
  /// `0 0 0 1px var(--border-focus)`.
  static List<BoxShadow> fieldShadows(FermanTheme theme) => [
    BoxShadow(color: theme.colors.borderFocus, spreadRadius: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    if (style == FocusRingStyle.inset) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: visible
            ? BoxDecoration(
                borderRadius: borderRadius,
                border: Border.fromBorderSide(theme.focus.focusRingInset),
              )
            : const BoxDecoration(),
        child: child,
      );
    }
    final layers = style == FocusRingStyle.outer
        ? outerShadows(theme)
        : fieldShadows(theme);
    final radius = borderRadius.resolve(Directionality.maybeOf(context));
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: visible ? 1 : 0),
      duration: duration,
      curve: curve,
      builder: (context, progress, child) => CustomPaint(
        painter: FocusRingPainter(
          layers: layers,
          borderRadius: radius,
          progress: progress,
        ),
        child: child,
      ),
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('visible', value: visible, ifTrue: 'visible'))
      ..add(EnumProperty<FocusRingStyle>('style', style))
      ..add(
        DiagnosticsProperty<BorderRadiusGeometry>(
          'borderRadius',
          borderRadius,
          defaultValue: BorderRadius.zero,
        ),
      )
      ..add(
        DiagnosticsProperty<Duration>(
          'duration',
          duration,
          defaultValue: Duration.zero,
        ),
      );
  }
}

/// Paints an outer or field [FocusRing]: each of [layers] as a band from
/// the control's shape (its size with [borderRadius]) out to the layer's
/// spread, in list order, so the last layer is on top. The inside of the
/// shape stays unpainted, as CSS clips an outer box shadow to the outside
/// of the border box.
///
/// Only a layer's colour and spread are used (focus rings have no offset
/// or blur). The corners grow by the spread as CSS spread shadows do,
/// sharper where the control's radius is smaller than the spread
/// ([spreadRadius]).
///
/// [progress] (0 to 1) scales each layer's spread and opacity, as a CSS
/// transition from no shadow does; at 0 nothing is painted.
class FocusRingPainter extends CustomPainter {
  /// Paints [layers] around a shape with corners of [borderRadius].
  const new({
    required this.layers,
    required this.borderRadius,
    this.progress = 1,
  });

  /// The ring's layers as box shadows, in paint order.
  final List<BoxShadow> layers;

  /// The control's corner radii.
  final BorderRadius borderRadius;

  /// How far the ring has appeared, from 0 (not at all) to 1.
  final double progress;

  /// The radius of a CSS spread shadow's corner for a box corner of
  /// radius [radius] and a shadow spread of [spread] (CSS Backgrounds 3,
  /// `box-shadow`): the radius plus the spread, but where the radius is
  /// smaller than the spread the spread counts only by
  /// `1 + (radius / spread - 1)³`, so a square corner stays square.
  static double spreadRadius(double radius, double spread) {
    if (spread <= 0) return radius;
    if (radius >= spread) return radius + spread;
    final ratio = radius / spread;
    return radius + spread * (1 + math.pow(ratio - 1, 3));
  }

  static Radius _spreadCorner(Radius corner, double spread) =>
      Radius.elliptical(
        spreadRadius(corner.x, spread),
        spreadRadius(corner.y, spread),
      );

  /// The outer edge of a band [spread] wide around [inner].
  static RRect spreadRRect(RRect inner, double spread) =>
      RRect.fromLTRBAndCorners(
        inner.left - spread,
        inner.top - spread,
        inner.right + spread,
        inner.bottom + spread,
        topLeft: _spreadCorner(inner.tlRadius, spread),
        topRight: _spreadCorner(inner.trRadius, spread),
        bottomRight: _spreadCorner(inner.brRadius, spread),
        bottomLeft: _spreadCorner(inner.blRadius, spread),
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final inner = borderRadius.toRRect(Offset.zero & size);
    for (final layer in layers) {
      final spread = layer.spreadRadius * progress;
      if (spread <= 0) continue;
      final color = layer.color;
      canvas.drawDRRect(
        spreadRRect(inner, spread),
        inner,
        Paint()..color = color.withValues(alpha: color.a * progress),
      );
    }
  }

  @override
  bool shouldRepaint(FocusRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.borderRadius != borderRadius ||
      !listEquals(oldDelegate.layers, layers);
}
