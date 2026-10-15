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
/// ring is painted behind [child] and extends 4 px beyond it, as the CSS
/// box shadow does; the control's own background covers the inside. An
/// [inset] ring is painted over [child]. A [field] ring is painted behind
/// [child] and extends 1 px.
///
/// The ring never changes the control's size, so focusing a control never
/// moves its neighbours. It is purely visual: focus itself is handled by
/// the component (usually through `FermanInteractive`).
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
  });

  /// Whether the ring shows; usually the component's focus-visible state.
  final bool visible;

  /// The control the ring surrounds.
  final Widget child;

  /// Which ring to draw.
  final FocusRingStyle style;

  /// The control's corner radii, which the ring follows.
  final BorderRadiusGeometry borderRadius;

  /// The box shadows of a [FocusRingStyle.outer] ring in [theme]: the
  /// design's `--focus-ring`, the focus colour outside a gap of the raised
  /// surface colour.
  static List<BoxShadow> outerShadows(FermanTheme theme) =>
      theme.focus.focusRing;

  /// The box shadow of a [FocusRingStyle.field] ring in [theme]:
  /// `0 0 0 1px var(--border-focus)`.
  static List<BoxShadow> fieldShadows(FermanTheme theme) => [
    BoxShadow(color: theme.colors.borderFocus, spreadRadius: 1),
  ];

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    final theme = context.ferman;
    return switch (style) {
      FocusRingStyle.outer => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: outerShadows(theme),
        ),
        child: child,
      ),
      FocusRingStyle.field => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: fieldShadows(theme),
        ),
        child: child,
      ),
      FocusRingStyle.inset => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.fromBorderSide(theme.focus.focusRingInset),
        ),
        child: child,
      ),
    };
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
      );
  }
}
