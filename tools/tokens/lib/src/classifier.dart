/// Types resolved token values.
///
/// The design tooling's `@kind` hint is the only explicit typing in the CSS:
/// `@kind font` marks font features and `@kind other` marks durations,
/// easings, z-indices and the page filter. Everything else is typed from the
/// value's pattern, with two name rules where the value alone is ambiguous:
/// `--tracking-*` holds `em` letter spacing (including a unitless `0`) and
/// `--weight-*` holds font weights. A value that matches nothing fails.
library;

import 'package:tokens/src/color.dart';
import 'package:tokens/src/errors.dart';
import 'package:tokens/src/text.dart';
import 'package:tokens/src/values.dart';

const _number = r'-?(?:\d+\.?\d*|\.\d+)';
final _lengthPattern = RegExp('^($_number)px\$');
final _emPattern = RegExp('^($_number)em\$');
final _numberPattern = RegExp('^$_number\$');
final _integerPattern = RegExp(r'^-?\d+$');
final _durationPattern = RegExp('^($_number)(ms|s)\$');
final _cubicPattern = RegExp(r'^cubic-bezier\((.*)\)$');
final _filterFunctionPattern = RegExp(r'^([a-z-]+)\((.*)\)$');
final _borderStyles = {'solid', 'dashed', 'dotted', 'double'};
final _featureSetting = RegExp(
  r'''^(['"])([A-Za-z0-9 ]{4})\1(?:\s+(\d+|on|off))?$''',
);
final _identifier = RegExp(r'^-?[A-Za-z_][A-Za-z0-9_-]*$');

const _easingKeywords = {
  'linear': CubicValue(0, 0, 1, 1),
  'ease': CubicValue(0.25, 0.1, 0.25, 1),
  'ease-in': CubicValue(0.42, 0, 1, 1),
  'ease-out': CubicValue(0, 0, 0.58, 1),
  'ease-in-out': CubicValue(0.42, 0, 0.58, 1),
};

const _numericFeatureKeywords = {
  'tabular-nums': FontFeatureSetting('tnum', 1),
  'proportional-nums': FontFeatureSetting('pnum', 1),
  'lining-nums': FontFeatureSetting('lnum', 1),
  'oldstyle-nums': FontFeatureSetting('onum', 1),
  'slashed-zero': FontFeatureSetting('zero', 1),
};

const _filterFunctions = {'brightness', 'contrast', 'sepia'};

/// Classifies the resolved [value] of the token [name].
///
/// [kindHint] is the `@kind` hint from the declaration's comment. Throws a
/// [TokenException] when the value cannot be typed or contradicts the hint.
TokenValue classifyToken(String name, String value, {String? kindHint}) {
  final v = collapseWhitespace(value);
  TokenValue? result;
  switch (kindHint) {
    case 'font':
      result = _fontFeatures(v) ?? _fontStack(v);
    case 'other':
      result = _filter(v) ?? _duration(v) ?? _easing(v) ?? _integer(v);
    case null:
      result = _untyped(name, v);
    default:
      throw TokenException('--$name: unknown @kind "$kindHint"');
  }
  if (result == null) {
    final hint = kindHint == null ? '' : ' (@kind $kindHint)';
    throw TokenException('--$name: cannot type the value "$v"$hint');
  }
  return result;
}

TokenValue? _untyped(String name, String v) {
  if (name.startsWith('tracking-')) {
    if (v == '0') return const EmValue(0);
    final em = _emPattern.firstMatch(v);
    return em == null ? null : EmValue(double.parse(em.group(1)!));
  }
  if (name.startsWith('weight-')) {
    final weight = int.tryParse(v);
    if (weight == null || weight < 100 || weight > 900 || weight % 100 != 0) {
      return null;
    }
    return FontWeightValue(weight);
  }
  final argb = parseCssColor(v);
  if (argb != null) return ColorValue(argb);
  return _length(v) ??
      _fontShorthand(v) ??
      _border(v) ??
      _shadow(v) ??
      _fontStack(v);
}

LengthValue? _length(String v) {
  if (v == '0') return const LengthValue(0);
  final match = _lengthPattern.firstMatch(v);
  return match == null ? null : LengthValue(double.parse(match.group(1)!));
}

DurationValue? _duration(String v) {
  final match = _durationPattern.firstMatch(v);
  if (match == null) return null;
  final amount = double.parse(match.group(1)!);
  final micros = match.group(2) == 's' ? amount * 1e6 : amount * 1e3;
  return DurationValue(micros.round());
}

CubicValue? _easing(String v) {
  final keyword = _easingKeywords[v];
  if (keyword != null) return keyword;
  final match = _cubicPattern.firstMatch(v);
  if (match == null) return null;
  final parts = splitTopLevel(match.group(1)!, ',');
  if (parts.length != 4 || !parts.every(_numberPattern.hasMatch)) return null;
  final n = parts.map(double.parse).toList();
  if (n[0] < 0 || n[0] > 1 || n[2] < 0 || n[2] > 1) return null;
  return CubicValue(n[0], n[1], n[2], n[3]);
}

IntegerValue? _integer(String v) =>
    _integerPattern.hasMatch(v) ? IntegerValue(int.parse(v)) : null;

FilterValue? _filter(String v) {
  if (v == 'none') return const FilterValue([]);
  final functions = <FilterFunction>[];
  for (final part in splitTopLevelWords(v)) {
    final match = _filterFunctionPattern.firstMatch(part);
    if (match == null || !_filterFunctions.contains(match.group(1))) {
      return null;
    }
    final argument = match.group(2)!.trim();
    final double amount;
    if (argument.endsWith('%')) {
      final percent = argument.substring(0, argument.length - 1);
      if (!_numberPattern.hasMatch(percent)) return null;
      amount = double.parse(percent) / 100;
    } else {
      if (!_numberPattern.hasMatch(argument)) return null;
      amount = double.parse(argument);
    }
    if (amount < 0) return null;
    functions.add(FilterFunction(match.group(1)!, amount));
  }
  return functions.isEmpty ? null : FilterValue(functions);
}

FontFeaturesValue? _fontFeatures(String v) {
  final keywords = v.split(' ');
  if (keywords.every(_numericFeatureKeywords.containsKey)) {
    return FontFeaturesValue([
      for (final keyword in keywords) _numericFeatureKeywords[keyword]!,
    ]);
  }
  final settings = <FontFeatureSetting>[];
  for (final part in splitTopLevel(v, ',')) {
    final match = _featureSetting.firstMatch(part);
    if (match == null) return null;
    final raw = match.group(3);
    final value = switch (raw) {
      null || 'on' => 1,
      'off' => 0,
      _ => int.parse(raw),
    };
    settings.add(FontFeatureSetting(match.group(2)!, value));
  }
  return FontFeaturesValue(settings);
}

/// A comma-separated list of quoted family names and identifiers, with at
/// least one quoted name so that a lone keyword is never taken for a stack.
FontStackValue? _fontStack(String v) {
  final parts = splitTopLevel(v, ',');
  var quoted = false;
  final families = <String>[];
  for (final part in parts) {
    if (part.isEmpty) return null;
    final isQuoted =
        part.length >= 2 &&
        (part.startsWith("'") && part.endsWith("'") ||
            part.startsWith('"') && part.endsWith('"'));
    if (isQuoted) {
      quoted = true;
      families.add(unquote(part));
    } else if (part.split(' ').every(_identifier.hasMatch)) {
      families.add(part);
    } else {
      return null;
    }
  }
  return quoted ? FontStackValue(families) : null;
}

/// `[normal|italic|oblique] [weight] size[/line-height] families`.
FontShorthandValue? _fontShorthand(String v) {
  final words = splitTopLevelWords(v);
  var index = 0;
  var italic = false;
  var weight = 400;
  var sawStyle = false;
  var sawWeight = false;
  while (index < words.length) {
    final word = words[index];
    if (!sawStyle && (word == 'italic' || word == 'oblique')) {
      italic = true;
      sawStyle = true;
    } else if (!sawWeight && _integerPattern.hasMatch(word)) {
      weight = int.parse(word);
      sawWeight = true;
    } else if (!sawWeight && word == 'bold') {
      weight = 700;
      sawWeight = true;
    } else if (word == 'normal') {
      // `normal` may stand for the style or the weight.
    } else {
      break;
    }
    index++;
  }
  if (index >= words.length - 1) return null;
  final sizeAndLeading = words[index].split('/');
  if (sizeAndLeading.length > 2) return null;
  final size = _lengthPattern.firstMatch(sizeAndLeading.first);
  if (size == null) return null;
  double? lineHeightPx;
  double? lineHeightNumber;
  if (sizeAndLeading.length == 2) {
    final leading = sizeAndLeading.last;
    final px = _lengthPattern.firstMatch(leading);
    if (px != null) {
      lineHeightPx = double.parse(px.group(1)!);
    } else if (_numberPattern.hasMatch(leading)) {
      lineHeightNumber = double.parse(leading);
    } else if (leading != 'normal') {
      // `normal` is the font's own line height: both stay null.
      return null;
    }
  }
  final stack = _fontStack(words.sublist(index + 1).join(' '));
  if (stack == null) return null;
  if (weight < 100 || weight > 900 || weight % 100 != 0) return null;
  return FontShorthandValue(
    italic: italic,
    weight: weight,
    size: double.parse(size.group(1)!),
    lineHeightPx: lineHeightPx,
    lineHeightNumber: lineHeightNumber,
    families: stack.families,
  );
}

/// `width style colour`, as in `2px solid #3A60C6`.
BorderValue? _border(String v) {
  final words = splitTopLevelWords(v);
  if (words.length != 3) return null;
  final width = _length(words[0]);
  final argb = parseCssColor(words[2]);
  if (width == null || argb == null || !_borderStyles.contains(words[1])) {
    return null;
  }
  return BorderValue(width: width.px, style: words[1], argb: argb);
}

/// A comma-separated list of `[inset] x y [blur [spread]] colour` layers;
/// the colour may also come first, as CSS allows.
ShadowValue? _shadow(String v) {
  final layers = <ShadowLayer>[];
  for (final layer in splitTopLevel(v, ',')) {
    final words = splitTopLevelWords(layer);
    final inset = words.remove('inset');
    if (words.length < 3) return null;
    var argb = parseCssColor(words.last);
    var lengthWords = words.sublist(0, words.length - 1);
    if (argb == null) {
      argb = parseCssColor(words.first);
      lengthWords = words.sublist(1);
    }
    if (argb == null) return null;
    final lengths = <double>[];
    for (final word in lengthWords) {
      final length = _length(word);
      if (length == null) return null;
      lengths.add(length.px);
    }
    if (lengths.length < 2 || lengths.length > 4) return null;
    if (lengths.length > 2 && lengths[2] < 0) return null;
    layers.add(
      ShadowLayer(
        inset: inset,
        x: lengths[0],
        y: lengths[1],
        blur: lengths.length > 2 ? lengths[2] : 0,
        spread: lengths.length > 3 ? lengths[3] : 0,
        argb: argb,
      ),
    );
  }
  return layers.isEmpty ? null : ShadowValue(layers);
}
