import 'package:ferman/design/icons/icon_name.g.dart';
import 'package:ferman/design/icons/icon_painter.dart';
import 'package:flutter/foundation.dart';
// The widgets library has its own Icon (for font glyphs); Ferman's Icon
// paints the design's path data instead (ADR 0011, ADR 0013). Files that
// use this widget hide the framework's: `hide Icon`.
import 'package:flutter/widgets.dart' hide Icon;

export 'package:ferman/design/icons/icon_name.g.dart';

/// One glyph of the Ferman design system, the design-system `Icon`
/// component (`components/core/Icon.jsx`, ADR 0011 and ADR 0013).
///
/// It paints the design's exact path data ([IconName]) in a
/// [size] × [size] box, from the 24 × 24 viewBox, with [strokeWidth] in
/// viewBox units and round caps and joins, as the component's inline SVG
/// does ([IconPainter]).
///
/// The colour is [color] when given. Otherwise the icon takes the ambient
/// foreground colour, as the SVG's `currentColor` takes the inherited CSS
/// `color`: the colour of the nearest [DefaultTextStyle], so an icon
/// follows the text around it (a primary button's white label, a disabled
/// or danger menu item); else, when the text style sets no colour, the
/// colour of the nearest [IconTheme]; else opaque black, which is what
/// [Text] paints with when nothing sets a colour. Inside the app the root
/// text style always sets a colour, so an [IconTheme] alone does not
/// recolour an icon: pass [color], or set the text colour around it.
///
/// In a right-to-left [Directionality] the glyph is mirrored when [flipRtl]
/// is true. When [flipRtl] is null, the default, [IconName.directional]
/// decides: exactly the eight glyphs the design flips (arrow-left,
/// arrow-right, chevron-left, chevron-right, undo-2, redo-2, skip-back and
/// skip-forward) mirror.
///
/// Icons are decorative and excluded from semantics unless [semanticLabel]
/// is set; then the icon is an image with that label (the component's
/// `role="img"` and `aria-label`).
class Icon extends StatelessWidget {
  /// Creates an icon showing [name].
  const new(
    this.name, {
    super.key,
    this.size = defaultSize,
    this.color,
    this.strokeWidth = defaultStrokeWidth,
    this.flipRtl,
    this.semanticLabel,
  });

  /// The size the design-system component uses when none is given
  /// (`size = 16`), the desktop `--icon-md`.
  static const double defaultSize = 16;

  /// The stroke width the design-system component uses when none is given
  /// (`strokeWidth = 1.5`), in viewBox units.
  static const double defaultStrokeWidth = IconPainter.defaultStrokeWidth;

  /// The opaque black used when neither [color], the [DefaultTextStyle]
  /// nor an [IconTheme] gives a colour; [Text] paints with the same.
  static const Color fallbackColor = Color(0xFF000000);

  /// The glyph to show.
  final IconName name;

  /// The width and height of the icon in logical pixels, [defaultSize]
  /// unless given.
  final double size;

  /// The colour of the strokes and fills; null means the ambient
  /// foreground colour (see [Icon]).
  final Color? color;

  /// The stroke width in viewBox units (1.5 at 24 px is 1.5 px),
  /// [defaultStrokeWidth] unless given. Screens use 2 for 12 px glyphs and
  /// badges, as the boards do.
  final double strokeWidth;

  /// Whether to mirror the glyph in right to left; null means
  /// [IconName.directional].
  final bool? flipRtl;

  /// The accessible name of the icon; null makes it decorative.
  final String? semanticLabel;

  /// The colour an icon without [color] takes at [context]: the
  /// [DefaultTextStyle] colour (CSS `color`), else the nearest [IconTheme]
  /// colour, else [fallbackColor].
  static Color ambientColor(BuildContext context) =>
      DefaultTextStyle.of(context).style.color ??
      context.dependOnInheritedWidgetOfExactType<IconTheme>()?.data.color ??
      fallbackColor;

  @override
  Widget build(BuildContext context) {
    final mirror =
        (flipRtl ?? name.directional) &&
        Directionality.maybeOf(context) == TextDirection.rtl;
    final glyph = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: IconPainter(
          name: name,
          color: color ?? ambientColor(context),
          strokeWidth: strokeWidth,
          mirror: mirror,
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: glyph);
    return Semantics(
      container: true,
      image: true,
      label: label,
      child: ExcludeSemantics(child: glyph),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<IconName>('name', name))
      ..add(DoubleProperty('size', size, defaultValue: defaultSize))
      ..add(ColorProperty('color', color, defaultValue: null))
      ..add(
        DoubleProperty(
          'strokeWidth',
          strokeWidth,
          defaultValue: defaultStrokeWidth,
        ),
      )
      ..add(
        FlagProperty(
          'flipRtl',
          value: flipRtl,
          ifTrue: 'flipRtl',
          ifFalse: 'no flipRtl',
        ),
      )
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}
