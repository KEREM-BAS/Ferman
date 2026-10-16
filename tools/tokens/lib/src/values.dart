/// Typed token values produced by the classifier.
library;

/// A token value after `var()` resolution and classification.
sealed class TokenValue {
  const new();

  /// A short name for the kind of value, used in messages and grouping.
  String get kind;
}

/// A colour as a 32-bit ARGB integer.
final class ColorValue extends TokenValue {
  /// Creates a colour.
  const new(this.argb);

  /// The colour as `0xAARRGGBB`.
  final int argb;

  @override
  String get kind => 'colour';
}

/// A length in CSS pixels (`Npx` or a unitless `0`).
final class LengthValue extends TokenValue {
  /// Creates a length.
  const new(this.px);

  /// The length in logical pixels.
  final double px;

  @override
  String get kind => 'length';
}

/// A letter-spacing factor in `em`, applied as `em × fontSize`.
final class EmValue extends TokenValue {
  /// Creates a factor.
  const new(this.em);

  /// The factor.
  final double em;

  @override
  String get kind => 'em';
}

/// A plain integer, used for z-index ordering.
final class IntegerValue extends TokenValue {
  /// Creates an integer.
  const new(this.value);

  /// The integer.
  final int value;

  @override
  String get kind => 'z-index';
}

/// A font weight from 100 to 900.
final class FontWeightValue extends TokenValue {
  /// Creates a weight.
  const new(this.weight);

  /// The numeric weight.
  final int weight;

  @override
  String get kind => 'font weight';
}

/// A duration.
final class DurationValue extends TokenValue {
  /// Creates a duration of [microseconds].
  const new(this.microseconds);

  /// The duration in microseconds.
  final int microseconds;

  @override
  String get kind => 'duration';
}

/// A cubic Bézier easing curve.
final class CubicValue extends TokenValue {
  /// Creates a curve through the control points (a, b) and (c, d).
  const new(this.a, this.b, this.c, this.d);

  /// First control point x.
  final double a;

  /// First control point y.
  final double b;

  /// Second control point x.
  final double c;

  /// Second control point y.
  final double d;

  @override
  String get kind => 'easing';
}

/// A font-family list.
final class FontStackValue extends TokenValue {
  /// Creates a stack from CSS [families] in order, unquoted.
  const new(this.families);

  /// The families, unquoted, in CSS order.
  final List<String> families;

  @override
  String get kind => 'font family list';
}

/// One OpenType feature setting.
final class FontFeatureSetting {
  /// Creates a setting of [tag] to [value].
  const new(this.tag, this.value);

  /// The four-letter OpenType tag.
  final String tag;

  /// The feature value; 1 enables, 0 disables.
  final int value;
}

/// A list of font features (`tabular-nums`, `'kern' 1, 'liga' 1`).
final class FontFeaturesValue extends TokenValue {
  /// Creates a feature list.
  const new(this.features);

  /// The features in order.
  final List<FontFeatureSetting> features;

  @override
  String get kind => 'font features';
}

/// The CSS `font` shorthand: `[style] weight size/line-height families`.
final class FontShorthandValue extends TokenValue {
  /// Creates a shorthand value.
  const new({
    required this.italic,
    required this.weight,
    required this.size,
    required this.lineHeightPx,
    required this.lineHeightNumber,
    required this.families,
  });

  /// Whether the style is italic or oblique.
  final bool italic;

  /// The numeric weight.
  final int weight;

  /// The font size in pixels.
  final double size;

  /// The line height in pixels, when given in `px`.
  final double? lineHeightPx;

  /// The line height as a multiple of the size, when unitless.
  ///
  /// Both this and [lineHeightPx] are null when the shorthand gives no line
  /// height or gives `normal`: the font's own line height applies.
  final double? lineHeightNumber;

  /// The font families, unquoted, in CSS order.
  final List<String> families;

  @override
  String get kind => 'font shorthand';
}

/// One `box-shadow` layer.
final class ShadowLayer {
  /// Creates a layer.
  const new({
    required this.inset,
    required this.x,
    required this.y,
    required this.blur,
    required this.spread,
    required this.argb,
  });

  /// Whether the layer is an inset shadow.
  final bool inset;

  /// Horizontal offset in pixels.
  final double x;

  /// Vertical offset in pixels.
  final double y;

  /// CSS blur radius in pixels.
  final double blur;

  /// Spread in pixels; may be negative.
  final double spread;

  /// The colour as `0xAARRGGBB`.
  final int argb;
}

/// A `box-shadow` list, in CSS order (the first layer paints on top).
final class ShadowValue extends TokenValue {
  /// Creates a shadow list.
  const new(this.layers);

  /// The layers in CSS order.
  final List<ShadowLayer> layers;

  @override
  String get kind => 'shadow';
}

/// A border or outline shorthand, `width style colour`.
final class BorderValue extends TokenValue {
  /// Creates a border value.
  const new({required this.width, required this.style, required this.argb});

  /// The width in pixels.
  final double width;

  /// The CSS line style, such as `solid`.
  final String style;

  /// The colour as `0xAARRGGBB`.
  final int argb;

  @override
  String get kind => 'border';
}

/// One CSS filter function, such as `brightness(0.86)`.
final class FilterFunction {
  /// Creates a function call.
  const new(this.name, this.amount);

  /// The function name.
  final String name;

  /// The amount as a fraction (`86%` is 0.86).
  final double amount;
}

/// A CSS `filter` list; empty for `none`.
final class FilterValue extends TokenValue {
  /// Creates a filter list.
  const new(this.functions);

  /// The functions in the order CSS applies them.
  final List<FilterFunction> functions;

  @override
  String get kind => 'filter';
}
