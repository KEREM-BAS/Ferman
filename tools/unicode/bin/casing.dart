// Writes the Unicode tables of app/lib/l10n/casing.dart (B004): the part
// between `// dart format off` and `// dart format on`, from the Unicode
// Character Database files that fetch.sh puts in build/unicode/15.0.0/, and
// the Dart VM's own case mappings. `--check` compares instead of writing.
// See README.md.
import 'dart:io';

/// The UCD version the tables come from; casing.dart's docs name it too.
const String version = '15.0.0';

/// The Dart SDK whose VM mappings the deltas leave out.
const String dartVersion = '3.13.5';

/// The blocks of [_caseIgnorableBlocks] and the mark blocks: the ones next
/// to Latin, Greek and Cyrillic letters that the context rules read.
const List<(int, int)> caseIgnorableBlocks = [
  (0x0000, 0x052F),
  (0x1AB0, 0x1AFF),
  (0x1D00, 0x20FF),
  (0xFE00, 0xFE2F),
  (0xFE50, 0xFF6F),
];

const List<(int, int)> markBlocks = [
  (0x0300, 0x036F),
  (0x0483, 0x0489),
  (0x1AB0, 0x1AFF),
  (0x1DC0, 0x1DFF),
  (0x20D0, 0x20FF),
  (0xFE20, 0xFE2F),
];

void main(List<String> args) {
  final root = File.fromUri(Platform.script).parent.parent.parent.parent.path;
  final ucd = Directory('$root/build/unicode/$version');
  final target = File('$root/app/lib/l10n/casing.dart');
  final sdk = Platform.version.split(' ').first;
  if (sdk != dartVersion) {
    stderr.writeln(
      'casing.dart needs Dart $dartVersion, whose VM mappings the tables '
      'complete; this is $sdk.',
    );
    exit(2);
  }
  String read(String name) {
    final file = File('${ucd.path}/$name');
    if (!file.existsSync()) {
      stderr.writeln('${file.path} is missing: run tools/unicode/fetch.sh');
      exit(2);
    }
    return file.readAsStringSync();
  }

  final tables = generate(
    unicodeData: read('UnicodeData.txt'),
    specialCasing: read('SpecialCasing.txt'),
    propList: read('PropList.txt'),
    derivedCore: read('DerivedCoreProperties.txt'),
  );
  final source = target.readAsStringSync();
  const open = '// dart format off\n';
  const close = '// dart format on\n';
  final start = source.indexOf(open);
  final end = source.indexOf(close);
  if (start < 0 || end < start) {
    stderr.writeln('casing.dart has no `dart format off` region');
    exit(2);
  }
  final output =
      source.substring(0, start + open.length) + tables + source.substring(end);
  if (args.contains('--check')) {
    if (output != source) {
      stderr.writeln(
        'app/lib/l10n/casing.dart is stale: run (cd tools/unicode && '
        'dart run bin/casing.dart)',
      );
      exit(1);
    }
    stdout.writeln('casing.dart is current (UCD $version, Dart $sdk).');
  } else {
    target.writeAsStringSync(output);
    stdout.writeln('Wrote the tables of app/lib/l10n/casing.dart.');
  }
}

/// The text between `// dart format off` and `// dart format on`.
String generate({
  required String unicodeData,
  required String specialCasing,
  required String propList,
  required String derivedCore,
}) {
  final upper = <int, int>{};
  final lower = <int, int>{};
  final combining = <int, int>{};
  for (final line in _lines(unicodeData)) {
    final fields = line.split(';');
    final code = int.parse(fields[0], radix: 16);
    final ccc = int.parse(fields[3]);
    if (ccc != 0) combining[code] = ccc;
    if (fields[12].isNotEmpty) upper[code] = int.parse(fields[12], radix: 16);
    if (fields[13].isNotEmpty) lower[code] = int.parse(fields[13], radix: 16);
  }

  final out = StringBuffer()
    ..writeln(
      '// The tables below come from the Unicode Character Database $version',
    )
    ..writeln('// (SpecialCasing.txt, UnicodeData.txt, PropList.txt and')
    ..writeln(
      "// DerivedCoreProperties.txt); the Dart VM's mappings are Dart "
      "$dartVersion's.",
    )
    ..writeln('// Unicode data is covered by the Unicode License v3')
    ..writeln('// (https://www.unicode.org/license.txt), a permissive licence.')
    ..writeln(
      '// `dart format off` keeps the inversion lists in rows. GENERATED — '
      'do not',
    )
    ..writeln(
      '// edit; run (cd tools/unicode && bash fetch.sh && dart run '
      'bin/casing.dart).',
    )
    ..writeln()
    ..writeln(
      '/// The unconditional entries of SpecialCasing-$version.txt: code '
      'point →',
    )
    ..writeln(
      '/// full upper-case and title-case mapping. Their lower-case mappings '
      'are',
    )
    ..writeln(
      '/// the simple ones, except U+0130, which [LocaleCasing.lower] '
      'handles.',
    )
    ..writeln('const Map<int, _Full> _fullMappings = {');
  final full = <int, String>{};
  for (final line in _lines(specialCasing)) {
    final fields = line.split(';').map((field) => field.trim()).toList();
    // A fifth field is a condition: language or context.
    if (fields.length > 5 && fields[4].isNotEmpty) continue;
    final code = int.parse(fields[0], radix: 16);
    full[code] =
        '  0x${_hex(code, 4)}: _Full(${_string(fields[3])}, '
        '${_string(fields[2])}),';
  }
  for (final code in full.keys.toList()..sort()) {
    out.writeln(full[code]);
  }
  out.writeln('};');

  // The simple mappings the VM leaves out: each code point once, in order.
  final deltas = <(int, int, int)>[];
  final all = {...upper.keys, ...lower.keys}.toList()..sort();
  for (final code in all) {
    final char = String.fromCharCode(code);
    final up = upper[code];
    final low = lower[code];
    final missingUp = up != null && char.toUpperCase() == char;
    final missingLow = low != null && char.toLowerCase() == char;
    if (!missingUp && !missingLow) continue;
    deltas.add((code, missingUp ? up - code : 0, missingLow ? low - code : 0));
  }
  out
    ..writeln()
    ..writeln(
      '/// Simple case mappings of UnicodeData-$version.txt that the Dart VM',
    )
    ..writeln(
      '/// (Dart $dartVersion) does not apply: ${deltas.length} code points, '
      'all unmapped by the VM.',
    )
    ..writeln('/// Sorted by [_Delta.start].')
    ..writeln('const List<_Delta> _deltas = [');
  var i = 0;
  while (i < deltas.length) {
    final (code, up, low) = deltas[i];
    // Upper and lower case alternating from an upper-case code point.
    var pairs = 0;
    while (i + 2 * pairs + 1 < deltas.length) {
      final (a, aUp, aLow) = deltas[i + 2 * pairs];
      final (b, bUp, bLow) = deltas[i + 2 * pairs + 1];
      if (a != code + 2 * pairs ||
          b != a + 1 ||
          aUp != 0 ||
          aLow != 1 ||
          bUp != -1 ||
          bLow != 0) {
        break;
      }
      pairs++;
    }
    if (pairs > 0) {
      out.writeln(
        '  _Delta.alternating(0x${_hex(code, 4)}, '
        '0x${_hex(code + 2 * pairs - 1, 4)}),',
      );
      i += 2 * pairs;
      continue;
    }
    var j = i;
    while (j + 1 < deltas.length &&
        deltas[j + 1].$1 == deltas[j].$1 + 1 &&
        deltas[j + 1].$2 == up &&
        deltas[j + 1].$3 == low) {
      j++;
    }
    final named = [
      if (up != 0) 'upper: $up',
      if (low != 0) 'lower: $low',
    ].join(', ');
    out.writeln(
      '  _Delta(0x${_hex(code, 4)}, 0x${_hex(deltas[j].$1, 4)}, $named),',
    );
    i = j + 1;
  }
  out.writeln('];');

  bool inBlocks(int code, List<(int, int)> blocks) =>
      blocks.any((block) => block.$1 <= code && code <= block.$2);
  final softDotted = _property(propList, 'Soft_Dotted');
  final cased = _property(derivedCore, 'Cased');
  final ignorable = _property(
    derivedCore,
    'Case_Ignorable',
  ).where((code) => inBlocks(code, caseIgnorableBlocks));
  final above = combining.entries
      .where((mark) => mark.value == 230 && inBlocks(mark.key, markBlocks))
      .map((mark) => mark.key);
  final other = combining.entries
      .where((mark) => mark.value != 230 && inBlocks(mark.key, markBlocks))
      .map((mark) => mark.key);
  _list(
    out,
    '/// Soft_Dotted (PropList-$version.txt), complete.',
    '_softDotted',
    softDotted,
  );
  _list(
    out,
    '/// Cased (DerivedCoreProperties-$version.txt), complete.',
    '_cased',
    cased,
  );
  _list(
    out,
    '/// Case_Ignorable (DerivedCoreProperties-$version.txt) in '
        '${_blocks(caseIgnorableBlocks)}.',
    '_caseIgnorable',
    ignorable,
  );
  _list(
    out,
    '/// Canonical combining class 230 (UnicodeData-$version.txt) in the '
        'mark blocks ${_blocks(markBlocks)}.',
    '_marksAbove',
    above,
  );
  _list(
    out,
    '/// Every other nonzero canonical combining class in the same mark '
        'blocks.',
    '_marksOther',
    other,
  );
  return out.toString();
}

/// The data lines of a UCD file, without comments.
Iterable<String> _lines(String text) sync* {
  for (final raw in text.split('\n')) {
    final line = raw.split('#').first.trim();
    if (line.isNotEmpty) yield line;
  }
}

/// The code points a PropList-style file gives [name].
Set<int> _property(String text, String name) {
  final codes = <int>{};
  for (final line in _lines(text)) {
    final [range, property, ...] = line
        .split(';')
        .map((field) => field.trim())
        .toList();
    if (property != name) continue;
    final bounds = range.split('..');
    final first = int.parse(bounds.first, radix: 16);
    final last = int.parse(bounds.last, radix: 16);
    for (var code = first; code <= last; code++) {
      codes.add(code);
    }
  }
  return codes;
}

/// [codes] as an inversion list, eight values a row.
void _list(StringBuffer out, String doc, String name, Iterable<int> codes) {
  final sorted = codes.toSet().toList()..sort();
  final bounds = <int>[];
  for (final code in sorted) {
    if (bounds.isNotEmpty && bounds.last == code) {
      bounds.last = code + 1;
    } else {
      bounds
        ..add(code)
        ..add(code + 1);
    }
  }
  out
    ..writeln()
    ..writeln(_wrap(doc))
    ..writeln('const List<int> $name = [');
  for (var at = 0; at < bounds.length; at += 8) {
    final row = bounds.skip(at).take(8).map((value) => '0x${_hex(value, 1)}');
    out.writeln('  ${row.join(', ')},');
  }
  out.writeln('];');
}

/// A doc comment wrapped at 80 columns.
String _wrap(String doc) {
  final words = doc.substring(4).split(' ');
  final lines = <String>[];
  var line = '///';
  for (final word in words) {
    if ('$line $word'.length >= 80) {
      lines.add(line);
      line = '/// $word';
    } else {
      line = '$line $word';
    }
  }
  return [...lines, line].join('\n');
}

/// The blocks as "U+0000 to U+052F, …, and U+FE50 to U+FF6F".
String _blocks(List<(int, int)> blocks) {
  final named = [
    for (final (first, last) in blocks)
      'U+${_hex(first, 4)} to U+${_hex(last, 4)}',
  ];
  return '${named.take(named.length - 1).join(', ')} and ${named.last}';
}

String _hex(int value, int width) =>
    value.toRadixString(16).toUpperCase().padLeft(width, '0');

/// A Dart string of the code points in [codes] ("0053 0053"): printable
/// ASCII as is, the rest as `\u` escapes.
String _string(String codes) {
  final text = StringBuffer("'");
  for (final code in codes.split(' ').where((part) => part.isNotEmpty)) {
    final value = int.parse(code, radix: 16);
    final printable =
        value >= 0x20 && value < 0x7F && value != 0x27 && value != 0x5C;
    text.write(printable ? String.fromCharCode(value) : '\\u${_hex(value, 4)}');
  }
  return (text..write("'")).toString();
}
