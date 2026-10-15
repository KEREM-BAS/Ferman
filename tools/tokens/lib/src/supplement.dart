/// Values the design draws in component CSS instead of as tokens, read from
/// `tools/tokens/supplement.yaml` (ADR 0012).
///
/// Every entry cites the design file and line it was copied from. Loading
/// checks that the cited line still contains the CSS, so a design re-export
/// that moves or changes it stops the run instead of drifting silently.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tokens/src/cascade.dart';
import 'package:tokens/src/color.dart';
import 'package:tokens/src/dart_model.dart';
import 'package:tokens/src/errors.dart';
import 'package:tokens/src/mappers.dart';
import 'package:tokens/src/naming.dart';
import 'package:tokens/src/resolver.dart';
import 'package:tokens/src/text.dart';
import 'package:yaml/yaml.dart';

/// The supplement file, relative to the repository root.
const String supplementPath = 'tools/tokens/supplement.yaml';

final _citation = RegExp(r'^(.+):(\d+)$');
final _gradient = RegExp(r'^repeating-linear-gradient\((.*)\)$');
final _angle = RegExp(r'^(-?\d+(?:\.\d+)?)deg$');
final _length = RegExp(r'^(?:0|(-?\d+(?:\.\d+)?)px)$');
const _sideAngles = {
  'to top': 0.0,
  'to right': 90.0,
  'to bottom': 180.0,
  'to left': 270.0,
};

/// One stripe pattern from the supplement.
final class HatchSpec {
  /// Creates a hatch entry.
  const new({
    required this.name,
    required this.doc,
    required this.source,
    required this.css,
  });

  /// The kebab-case entry name, such as `redact-pending`.
  final String name;

  /// One-sentence documentation.
  final String doc;

  /// The cited `path:line`, relative to the repository root.
  final String source;

  /// The `repeating-linear-gradient(...)` copied from the design.
  final String css;
}

/// The parsed supplement.
final class Supplement {
  /// Creates a supplement with [hatches].
  const new(this.hatches);

  /// Reads and checks `tools/tokens/supplement.yaml` under [root].
  ///
  /// Throws a [TokenException] when the file is malformed or a citation no
  /// longer matches the design.
  factory load(String root) {
    final file = File(p.join(root, supplementPath));
    if (!file.existsSync()) {
      throw TokenException('missing $supplementPath');
    }
    final Object? document;
    try {
      document = loadYaml(file.readAsStringSync());
    } on YamlException catch (error) {
      throw TokenException('$supplementPath: ${error.message}');
    }
    final hatches = <HatchSpec>[];
    final entries = document is YamlMap ? document['hatches'] : null;
    if (entries is! YamlMap) {
      throw TokenException('$supplementPath: expected a "hatches" map');
    }
    for (final MapEntry(:key, :value) in entries.entries) {
      if (key is! String || value is! YamlMap) {
        throw TokenException('$supplementPath: malformed hatch "$key"');
      }
      String field(String name) {
        final text = value[name];
        if (text is! String || text.trim().isEmpty) {
          throw TokenException('$supplementPath: hatch "$key" needs "$name"');
        }
        return text.trim();
      }

      final spec = HatchSpec(
        name: key,
        doc: field('doc'),
        source: field('source'),
        css: collapseWhitespace(field('css')),
      );
      _checkCitation(root, spec);
      hatches.add(spec);
    }
    return Supplement(List.unmodifiable(hatches));
  }

  /// The stripe patterns, in file order.
  final List<HatchSpec> hatches;

  /// The `FermanHatchTokens` fields, with `var()` resolved by [light].
  List<DartField> hatchFields(VarResolver light) => [
    for (final hatch in hatches)
      DartField(
        name: camelCase(hatch.name),
        type: 'FermanHatch',
        doc: [
          _sentence(hatch.doc),
          'Source: `${hatch.css}` (${_shortSource(hatch.source)}).',
        ],
        values: {
          '': hatchExpression(
            light.resolveValue(hatch.css, context: 'hatch ${hatch.name}'),
            name: hatch.name,
          ),
        },
        cssNames: const [],
      ),
  ];
}

/// Maps a resolved `repeating-linear-gradient(...)` with hard stops in the
/// two-position form (`colour start end`, each stop starting where the
/// previous one ended) to a `FermanHatch` constant expression.
String hatchExpression(String css, {required String name}) {
  final match = _gradient.firstMatch(css);
  if (match == null) {
    throw TokenException('hatch $name: expected repeating-linear-gradient()');
  }
  final arguments = splitTopLevel(match.group(1)!, ',');
  var angle = 180.0;
  final first = arguments.first;
  final degrees = _angle.firstMatch(first);
  if (degrees != null) {
    angle = double.parse(degrees.group(1)!);
    arguments.removeAt(0);
  } else if (_sideAngles.containsKey(first)) {
    angle = _sideAngles[first]!;
    arguments.removeAt(0);
  }
  if (arguments.length < 2) {
    throw TokenException('hatch $name: needs at least two colour stops');
  }
  final stripes = <String>[];
  var position = 0.0;
  for (final stop in arguments) {
    final words = splitTopLevelWords(stop);
    final argb = words.isEmpty ? null : parseCssColor(words.first);
    final positions = [for (final word in words.skip(1)) _px(word)];
    if (argb == null || positions.length != 2 || positions.contains(null)) {
      throw TokenException(
        'hatch $name: expected "colour start end" hard stops, got "$stop"',
      );
    }
    final start = positions[0]!;
    final end = positions[1]!;
    if (start != position || end <= start) {
      throw TokenException('hatch $name: stops must be contiguous ("$stop")');
    }
    position = end;
    stripes.add(
      'FermanHatchStripe(color: ${dartColor(argb)}, '
      'width: ${dartNumber(end - start)})',
    );
  }
  return 'FermanHatch(angle: ${dartNumber(angle)}, '
      'stripes: <FermanHatchStripe>[${stripes.join(', ')}])';
}

double? _px(String word) {
  final match = _length.firstMatch(word);
  if (match == null) return null;
  return match.group(1) == null ? 0 : double.parse(match.group(1)!);
}

void _checkCitation(String root, HatchSpec spec) {
  final citation = _citation.firstMatch(spec.source);
  if (citation == null) {
    throw TokenException(
      '$supplementPath: hatch "${spec.name}" source must be "path:line"',
    );
  }
  final path = citation.group(1)!;
  final line = int.parse(citation.group(2)!);
  final file = File(p.join(root, path));
  if (!file.existsSync()) {
    throw TokenException(
      '$supplementPath: hatch "${spec.name}" cites $path, which is missing',
    );
  }
  final lines = file.readAsLinesSync();
  if (line < 1 ||
      line > lines.length ||
      !collapseWhitespace(lines[line - 1]).contains(spec.css)) {
    throw TokenException(
      '$supplementPath: hatch "${spec.name}" no longer matches ${spec.source}; '
      'review the design change and update the entry',
    );
  }
}

String _shortSource(String source) {
  final designSystem = designSystemTokensDir.substring(
    0,
    designSystemTokensDir.length - 'tokens'.length,
  );
  return source.startsWith(designSystem)
      ? source.substring(designSystem.length)
      : source;
}

String _sentence(String text) =>
    RegExp(r'[.!?]$').hasMatch(text) ? text : '$text.';
