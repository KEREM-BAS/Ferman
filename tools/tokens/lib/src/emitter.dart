/// Writes the generated Dart source. The output is deterministic: classes in
/// a fixed order, fields sorted, no timestamps. It is formatted afterwards
/// with `dart format`.
library;

import 'package:tokens/src/dart_model.dart';

/// The first line of the generated file.
const String generatedHeader =
    '// GENERATED — do not edit; run (cd tools/tokens && dart run)';

const _pageWidth = 80;

/// Emits the Dart library for [classes]. The result is valid but not yet
/// formatted.
String emitDart(List<DartClass> classes) {
  final out = StringBuffer()
    ..writeln(generatedHeader)
    ..writeln('//')
    ..writeln(
      '// Design tokens from the CSS custom properties in design/ '
      '(ADR 0012):',
    )
    ..writeln('// design/_ds/<design system>/tokens/*.css, then')
    ..writeln(
      '// design/ds-additions/fm-additions.css, which loads last and '
      'wins.',
    )
    ..writeln('// Hatch patterns come from tools/tokens/supplement.yaml.')
    ..writeln(
      '// Widgets read these through the ThemeExtensions in theme.dart '
      'and never',
    )
    ..writeln('// hard-code colours, sizes, radii or durations.')
    ..writeln()
    ..writeln("import 'package:flutter/animation.dart';")
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln();

  for (final dartClass in classes) {
    _emitClass(out, dartClass);
    out.writeln();
  }
  _emitSupportClasses(out);
  if (classes.any((c) => !c.isStatic && c.fields.any(_lerpsAsDouble))) {
    out
      ..writeln()
      ..writeln(
        'double _lerpDouble(double a, double b, double t) => a + (b - a) * t;',
      );
  }
  return out.toString();
}

bool _lerpsAsDouble(DartField field) => field.type == 'double';

void _emitClass(StringBuffer out, DartClass dartClass) {
  _doc(out, dartClass.doc, indent: 0);
  if (dartClass.isStatic) {
    out.writeln('abstract final class ${dartClass.name} {');
    for (final field in dartClass.fields) {
      _doc(out, field.doc, indent: 2);
      out
        ..writeln(
          'static const ${field.type} ${field.name} = '
          '${field.values['']};',
        )
        ..writeln();
    }
    out.writeln('}');
    return;
  }

  final name = dartClass.name;
  final instanceNames = dartClass.instances.map((i) => '[${i.name}]');
  final constructorDoc =
      'Creates a set of tokens. The design defines '
      '${instanceNames.join(' and ')}.';
  out.writeln('final class $name {');
  _doc(out, [constructorDoc], indent: 2);
  out.writeln('const new({');
  for (final field in dartClass.fields) {
    out.writeln('required this.${field.name},');
  }
  out
    ..writeln('});')
    ..writeln();

  for (final instance in dartClass.instances) {
    _doc(out, [instance.doc], indent: 2);
    out.writeln('static const $name ${instance.name} = $name(');
    for (final field in dartClass.fields) {
      out.writeln('${field.name}: ${field.values[instance.name]},');
    }
    out
      ..writeln(');')
      ..writeln();
  }

  for (final field in dartClass.fields) {
    _doc(out, field.doc, indent: 2);
    out
      ..writeln('final ${field.type} ${field.name};')
      ..writeln();
  }

  const lerpDoc =
      'Interpolates between this set and [other] by [t], for animated theme '
      'changes. Values that cannot be interpolated switch at t = 0.5.';
  _doc(out, [lerpDoc], indent: 2);
  out
    ..writeln('$name lerp($name other, double t) {')
    ..writeln('return $name(');
  for (final field in dartClass.fields) {
    out.writeln('${field.name}: ${_lerp(field)},');
  }
  out
    ..writeln(');')
    ..writeln('}')
    ..writeln('}');
}

String _lerp(DartField field) {
  final a = field.name;
  final b = 'other.${field.name}';
  return switch (field.type) {
    'Color' => 'Color.lerp($a, $b, t)!',
    'double' => '_lerpDouble($a, $b, t)',
    'List<BoxShadow>' => 'BoxShadow.lerpList($a, $b, t)!',
    'BorderSide' => 'BorderSide.lerp($a, $b, t)',
    'TextStyle' => 'TextStyle.lerp($a, $b, t)!',
    _ => 't < 0.5 ? $a : $b',
  };
}

void _emitSupportClasses(StringBuffer out) {
  out.write('''
/// A CSS font stack reduced to the families the app bundles.
final class FermanFontStack {
  /// Creates a font stack.
  const new({required this.family, required this.fallback});

  /// The first bundled family, for `TextStyle.fontFamily`, or null when the
  /// stack names no bundled family and the platform default applies.
  final String? family;

  /// The other bundled families in CSS order, for
  /// `TextStyle.fontFamilyFallback`.
  final List<String> fallback;
}

/// A repeating stripe pattern: a CSS `repeating-linear-gradient` with hard
/// stops.
final class FermanHatch {
  /// Creates a stripe pattern.
  const new({required this.angle, required this.stripes});

  /// The CSS gradient angle in degrees: 0 points up, 90 right, 180 down;
  /// negative angles turn anticlockwise.
  final double angle;

  /// The stripes in order along the gradient line, repeated to fill.
  final List<FermanHatchStripe> stripes;
}

/// One stripe of a [FermanHatch].
final class FermanHatchStripe {
  /// Creates a stripe.
  const new({required this.color, required this.width});

  /// The stripe colour.
  final Color color;

  /// The stripe width in logical pixels, measured along the gradient line.
  final double width;
}
''');
}

void _doc(StringBuffer out, List<String> paragraphs, {required int indent}) {
  final width = _pageWidth - indent - 4;
  for (final (index, paragraph) in paragraphs.indexed) {
    if (index > 0) out.writeln('///');
    for (final line in _wrap(paragraph, width)) {
      out.writeln(line.isEmpty ? '///' : '/// $line');
    }
  }
}

/// Words that Markdown would read as a list, quote or heading marker at the
/// start of a line.
final _blockMarker = RegExp(r'^(?:[-+*>#]|\d+[.)])$');

/// Greedy word wrap at [width] columns. A word longer than the width gets a
/// line of its own, and a line never starts with a Markdown block marker.
List<String> _wrap(String text, int width) {
  final lines = <List<String>>[];
  var line = <String>[];
  int length(List<String> words) =>
      words.fold(0, (sum, w) => sum + w.length) + words.length - 1;
  for (final word in text.split(' ').where((w) => w.isNotEmpty)) {
    if (line.isNotEmpty && length([...line, word]) > width) {
      final carry = _blockMarker.hasMatch(word) && line.length > 1
          ? [line.removeLast()]
          : <String>[];
      lines.add(line);
      line = carry;
    }
    line.add(word);
  }
  if (line.isNotEmpty) lines.add(line);
  return [for (final words in lines) words.join(' ')];
}
