/// Maps typed token values to Dart types and constant expressions.
library;

import 'dart:math' as math;

import 'package:tokens/src/color.dart';
import 'package:tokens/src/color_matrix.dart';
import 'package:tokens/src/errors.dart';
import 'package:tokens/src/values.dart';

/// The font families the app bundles in `app/assets/fonts` (ADR 0013; Plex
/// Sans Hebrew and Devanagari approved in Q08). Every other family in a CSS
/// stack is dropped: CSS generic and system keywords, the CJK families
/// (system fonts cover CJK) and the handwriting faces, which wait for Q08.
const Set<String> bundledFontFamilies = {
  'IBM Plex Sans',
  'IBM Plex Sans Arabic',
  'IBM Plex Sans Hebrew',
  'IBM Plex Sans Devanagari',
  'IBM Plex Mono',
  'IBM Plex Serif',
};

/// A Dart type and a constant expression of that type.
typedef MappedValue = ({String type, String expression});

/// Maps [value] to a Dart constant. [name] is the CSS token name, for
/// messages.
MappedValue mapValue(TokenValue value, {required String name}) =>
    switch (value) {
      ColorValue(:final argb) => (type: 'Color', expression: dartColor(argb)),
      LengthValue(:final px) => (type: 'double', expression: dartNumber(px)),
      EmValue(:final em) => (type: 'double', expression: dartNumber(em)),
      IntegerValue(value: final integer) => (
        type: 'int',
        expression: '$integer',
      ),
      FontWeightValue(:final weight) => (
        type: 'FontWeight',
        expression: 'FontWeight.w$weight',
      ),
      DurationValue(:final microseconds) => (
        type: 'Duration',
        expression: dartDuration(microseconds),
      ),
      CubicValue(:final a, :final b, :final c, :final d) => (
        type: 'Cubic',
        expression: 'Cubic(${[a, b, c, d].map(dartNumber).join(', ')})',
      ),
      FontStackValue(:final families) => (
        type: 'FermanFontStack',
        expression: _fontStack(families),
      ),
      FontFeaturesValue(:final features) => (
        type: 'List<FontFeature>',
        expression: '<FontFeature>[${features.map(_feature).join(', ')}]',
      ),
      final FontShorthandValue shorthand => (
        type: 'TextStyle',
        expression: _textStyle(shorthand),
      ),
      ShadowValue(:final layers) => _shadow(layers, name),
      BorderValue(:final width, :final style, :final argb) => _outline(
        width,
        style,
        argb,
        name,
      ),
      FilterValue(:final functions) => (
        type: 'List<double>?',
        expression: _matrix(composeColorMatrix(functions)),
      ),
    };

/// `Color(0xAARRGGBB)`.
String dartColor(int argb) => 'Color(${argbHex(argb)})';

/// The shortest Dart literal for [value], rounded to 4 decimal places.
/// Whole numbers print without a decimal point (`prefer_int_literals`).
String dartNumber(double value) {
  final rounded = (value * 10000).round() / 10000;
  if (rounded == rounded.roundToDouble()) {
    final whole = rounded.round();
    return whole == 0 ? '0' : '$whole';
  }
  var text = rounded.toStringAsFixed(4);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// `Duration.zero`, or a `Duration` in the largest exact unit.
String dartDuration(int microseconds) {
  if (microseconds == 0) return 'Duration.zero';
  if (microseconds % 1000 == 0) {
    return 'Duration(milliseconds: ${microseconds ~/ 1000})';
  }
  return 'Duration(microseconds: $microseconds)';
}

/// Converts a CSS shadow blur radius to Flutter's `BoxShadow.blurRadius`.
///
/// CSS blurs with a Gaussian of sigma = blur / 2. Flutter turns blurRadius
/// into sigma = 0.57735 × blurRadius + 0.5 (and 0 for 0). Solving for the
/// same sigma gives blurRadius = (blur / 2 − 0.5) / 0.57735, clamped at 0, so
/// a 0 px CSS blur stays a hard edge.
double flutterBlurRadius(double cssBlur) =>
    math.max(0, (cssBlur / 2 - 0.5) / 0.57735);

/// Splits a CSS font stack into the first bundled family, the bundled
/// fallbacks and the dropped names.
({String? family, List<String> fallback, List<String> dropped}) splitFontStack(
  List<String> families,
) {
  final kept = families.where(bundledFontFamilies.contains).toList();
  return (
    family: kept.isEmpty ? null : kept.first,
    fallback: kept.skip(1).toList(),
    dropped: families.where((f) => !bundledFontFamilies.contains(f)).toList(),
  );
}

String _quote(String value) => "'${value.replaceAll("'", r"\'")}'";

String _stringList(List<String> values) =>
    '<String>[${values.map(_quote).join(', ')}]';

String _fontStack(List<String> families) {
  final split = splitFontStack(families);
  final family = split.family == null ? 'null' : _quote(split.family!);
  return 'FermanFontStack(family: $family, '
      'fallback: ${_stringList(split.fallback)})';
}

String _feature(FontFeatureSetting feature) {
  const named = {
    'tnum': 'FontFeature.tabularFigures()',
    'pnum': 'FontFeature.proportionalFigures()',
    'lnum': 'FontFeature.liningFigures()',
    'onum': 'FontFeature.oldstyleFigures()',
    'zero': 'FontFeature.slashedZero()',
  };
  if (feature.value == 1 && named.containsKey(feature.tag)) {
    return named[feature.tag]!;
  }
  return switch (feature.value) {
    1 => 'FontFeature.enable(${_quote(feature.tag)})',
    0 => 'FontFeature.disable(${_quote(feature.tag)})',
    _ => 'FontFeature(${_quote(feature.tag)}, ${feature.value})',
  };
}

/// A `TextStyle` for a `font` shorthand.
///
/// `height` is the line height divided by the size, with even leading
/// distribution to match CSS half-leading. A shorthand without a line height
/// (or with `/normal`) leaves `height` null, so Flutter uses the font's own
/// line height, which is what CSS `normal` means; no ratio is invented.
String _textStyle(FontShorthandValue font) {
  final split = splitFontStack(font.families);
  return [
    'TextStyle(',
    if (split.family != null) 'fontFamily: ${_quote(split.family!)}, ',
    if (split.fallback.isNotEmpty)
      'fontFamilyFallback: ${_stringList(split.fallback)}, ',
    'fontSize: ${dartNumber(font.size)}, ',
    'fontWeight: FontWeight.w${font.weight}, ',
    if (font.italic) 'fontStyle: FontStyle.italic, ',
    if (_height(font) case final height?) ...[
      'height: $height, ',
      'leadingDistribution: TextLeadingDistribution.even, ',
    ],
    ')',
  ].join();
}

/// The `TextStyle.height` expression for [font], or null when the shorthand
/// gives no line height.
String? _height(FontShorthandValue font) {
  if (font.lineHeightPx case final px?) {
    final bothWhole =
        px == px.roundToDouble() && font.size == font.size.roundToDouble();
    return bothWhole
        ? '${px.round()} / ${font.size.round()}'
        : dartNumber(px / font.size);
  }
  if (font.lineHeightNumber case final number?) return dartNumber(number);
  return null;
}

MappedValue _shadow(List<ShadowLayer> layers, String name) {
  final insetLayers = layers.where((layer) => layer.inset).toList();
  if (insetLayers.isNotEmpty) {
    final ring = insetLayers.single;
    if (layers.length != 1 ||
        ring.x != 0 ||
        ring.y != 0 ||
        ring.blur != 0 ||
        ring.spread <= 0) {
      throw TokenException(
        '--$name: only a single inset ring ("inset 0 0 0 Npx colour") can be '
        'mapped; BoxShadow cannot paint inset shadows',
      );
    }
    // An inset ring is an inside border of the same width.
    return (
      type: 'BorderSide',
      expression:
          'BorderSide(color: ${dartColor(ring.argb)}, '
          'width: ${dartNumber(ring.spread)})',
    );
  }
  // CSS paints the first layer on top; Flutter paints the last on top.
  final boxShadows = layers.reversed.map((layer) {
    final blur = flutterBlurRadius(layer.blur);
    return [
      'BoxShadow(color: ${dartColor(layer.argb)}, ',
      if (layer.x != 0 || layer.y != 0)
        'offset: Offset(${dartNumber(layer.x)}, ${dartNumber(layer.y)}), ',
      if (dartNumber(blur) != '0') 'blurRadius: ${dartNumber(blur)}, ',
      if (layer.spread != 0) 'spreadRadius: ${dartNumber(layer.spread)}, ',
      ')',
    ].join();
  });
  return (
    type: 'List<BoxShadow>',
    expression: '<BoxShadow>[${boxShadows.join(', ')}]',
  );
}

MappedValue _outline(double width, String style, int argb, String name) {
  if (style != 'solid') {
    throw TokenException('--$name: only solid outlines can be mapped');
  }
  return (
    type: 'BorderSide',
    expression:
        'BorderSide(color: ${dartColor(argb)}, width: ${dartNumber(width)}, '
        'strokeAlign: BorderSide.strokeAlignOutside)',
  );
}

String _matrix(List<double>? matrix) =>
    matrix == null ? 'null' : '<double>[${matrix.map(dartNumber).join(', ')}]';
