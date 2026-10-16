import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A ring that turns while something loads, the design-system `Spinner`
/// component (`components/feedback/feedback.css`, `.fm-spinner`). Never the
/// Material progress indicator (ADR 0011).
///
/// The ring is [size] × [size], drawn in the default border colour with its
/// top quarter in the accent colour ([onAccent]: translucent white with a
/// white quarter, for filled accent surfaces). The stroke is 1.5 px up to
/// 12 px, 3 px from 32 px and 2 px between ([strokeWidthFor]).
///
/// It turns once every 0.8 s ([period]). The design's reduced-motion block
/// zeroes only the duration tokens, not this keyframe timing, and the spec
/// keeps spinners turning so that progress stays visible (COMPONENTS.md,
/// decision 12); so the ring keeps turning under reduced motion.
///
/// For screen readers it is a loading indicator in a polite live region
/// labelled [semanticLabel]. With no label it is decorative: use that when
/// the surrounding text already says what is happening (a status-bar task).
class Spinner extends StatelessWidget {
  /// Creates a spinner.
  const new({
    super.key,
    this.size = defaultSize,
    this.onAccent = false,
    this.semanticLabel,
  });

  /// The design-system default size (`size = 16`).
  static const double defaultSize = 16;

  /// `.fm-spinner` `animation: fm-spin 0.8s linear infinite`.
  static const Duration period = Duration(milliseconds: 800);

  /// `.fm-spinner--on-accent` `border-color: rgba(255,255,255,.35)`.
  static const Color onAccentTrackColor = Color(0x59FFFFFF);

  /// `.fm-spinner--on-accent` `border-top-color: #FFFFFF`.
  static const Color onAccentArcColor = Color(0xFFFFFFFF);

  /// The width and height in logical pixels.
  final double size;

  /// Whether the spinner sits on a filled accent surface.
  final bool onAccent;

  /// What is loading, for screen readers (the design's `label`, "Loading"
  /// by default, which the screens pass localized); null makes the spinner
  /// decorative.
  final String? semanticLabel;

  /// The ring's stroke width at [size] (`Spinner.jsx`): 1.5 at 12 px or
  /// less, 3 at 32 px or more, else 2.
  static double strokeWidthFor(double size) => size <= 12
      ? 1.5
      : size >= 32
      ? 3
      : 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.ferman.colors;
    final ring = SizedBox.square(
      dimension: size,
      child: SpinRotation(
        period: period,
        child: CustomPaint(
          size: Size.square(size),
          painter: SpinnerPainter(
            trackColor: onAccent ? onAccentTrackColor : colors.borderDefault,
            arcColor: onAccent ? onAccentArcColor : colors.accent,
            strokeWidth: strokeWidthFor(size),
          ),
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: ring);
    return Semantics(
      container: true,
      role: SemanticsRole.loadingSpinner,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(child: ring),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('size', size, defaultValue: defaultSize))
      ..add(FlagProperty('onAccent', value: onAccent, ifTrue: 'onAccent'))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

/// Paints a [Spinner] ring: a full circle in [trackColor] and its top
/// quarter in [arcColor], as a CSS circle with a coloured `border-top`
/// draws it (the quarter between the two upper diagonals).
class SpinnerPainter extends CustomPainter {
  /// Creates the painter.
  const new({
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  /// The colour of the ring.
  final Color trackColor;

  /// The colour of the top quarter.
  final Color arcColor;

  /// The stroke width, inside the painted square.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawOval(rect, paint);
    paint.color = arcColor;
    canvas.drawArc(rect, -3 * math.pi / 4, math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(SpinnerPainter oldDelegate) =>
      oldDelegate.trackColor != trackColor ||
      oldDelegate.arcColor != arcColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Turns [child] clockwise once per [period], linearly and without end: the
/// design's `fm-spin` keyframes (`tokens/base.css`), used by [Spinner] and
/// by the loading `Button`.
///
/// It keeps turning under reduced motion, as the CSS animation does (its
/// timing is a literal, not a duration token).
class SpinRotation extends StatefulWidget {
  /// Turns [child] once per [period].
  const new({required this.period, required this.child, super.key});

  /// The time for one full turn.
  final Duration period;

  /// What turns.
  final Widget child;

  @override
  State<SpinRotation> createState() => _SpinRotationState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Duration>('period', period));
  }
}

class _SpinRotationState extends State<SpinRotation>
    with SingleTickerProviderStateMixin {
  // Preserve: the platform's reduce-motion setting must not stop the turn.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
    animationBehavior: AnimationBehavior.preserve,
  )..repeat();

  @override
  void didUpdateWidget(SpinRotation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _controller
        ..duration = widget.period
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _controller, child: widget.child);
}
