import 'dart:convert';
import 'dart:io';

import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// Extracts the icon map that opens with [marker] in [path] line by line
/// with a regular expression, independently of the tool's JavaScript
/// reader. The map ends at the first line that is `};`.
Map<String, String> independentExtract(
  String path,
  String marker,
  String quote,
) {
  final all = readRepoFile(path).split('\n');
  final start = all.indexWhere((line) => line.contains(marker));
  final end = all.indexWhere((line) => line.trim() == '};', start);
  final lines = all.sublist(start + 1, end);
  final pattern = RegExp(
    '^\\s*"([a-z0-9-]+)": $quote((?:[^$quote\\\\]|\\\\.)*)$quote,?\\s*\$',
  );
  final icons = <String, String>{};
  for (final line in lines) {
    final match = pattern.firstMatch(line);
    if (match == null) continue;
    final raw = match.group(2)!;
    icons[match.group(1)!] = quote == '"'
        ? jsonDecode('"$raw"') as String
        : raw.replaceAll(r"\'", "'").replaceAll(r'\\', r'\');
  }
  return icons;
}

void main() {
  final icons = loadDesignIcons(repoRoot);

  test('the design has exactly 229 icons: 145 in ICON_PATHS, 84 added', () {
    expect(icons, hasLength(229));
    expect(totalIconCount, 229);
    expect(icons.where((i) => i.origin == IconOrigin.bundle), hasLength(145));
    expect(icons.where((i) => i.origin == IconOrigin.additions), hasLength(84));
    expect({for (final i in icons) i.name}, hasLength(229));
  });

  test('icons are sorted by name', () {
    final names = [for (final i in icons) i.name];
    expect(names, [...names]..sort());
  });

  test('the reader agrees with an independent line-by-line extraction', () {
    final bundle = independentExtract(bundlePath, 'const ICON_PATHS = {', '"');
    final additions = independentExtract(additionsPath, 'var ADD = {', "'");
    expect(bundle, hasLength(145));
    expect(additions, hasLength(84));
    for (final icon in icons) {
      final expected = icon.origin == IconOrigin.bundle
          ? bundle[icon.name]
          : additions[icon.name];
      expect(icon.markup, expected, reason: icon.name);
    }
  });

  test('every generated SVG holds the source markup byte for byte', () {
    final bundle = independentExtract(bundlePath, 'const ICON_PATHS = {', '"');
    final additions = independentExtract(additionsPath, 'var ADD = {', "'");
    final dir = Directory(p.joinAll([repoRoot, ...assetsDir.split('/')]));
    final svgs = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.svg'))
        .toList();
    expect(svgs, hasLength(229));
    for (final file in svgs) {
      final name = p.basenameWithoutExtension(file.path);
      final source = bundle[name] ?? additions[name];
      expect(source, isNotNull, reason: '$name is not a design icon');
      final content = readText(file);
      expect(innerMarkup(content), source, reason: name);
      expect(content, svgFile(source!), reason: name);
    }
  });

  test('the generated root element carries the design system stroke', () {
    final svg = svgFile('<path d="M0 0"/>');
    for (final attribute in [
      'viewBox="0 0 24 24"',
      'fill="none"',
      'stroke="currentColor"',
      'stroke-width="1.5"',
      'stroke-linecap="round"',
      'stroke-linejoin="round"',
    ]) {
      expect(svg, contains(attribute));
    }
    expect('stroke-width="1.5"'.allMatches(svg), hasLength(1));
    expect(svg, endsWith('</svg>\n'));
  });

  test('a changed count fails loudly', () {
    final root = copyRoot(withOutputs: false);
    addTearDown(() => Directory(root).deleteSync(recursive: true));
    final file = File(p.joinAll([root, ...additionsPath.split('/')]));
    file.writeAsStringSync(
      file.readAsStringSync().replaceFirst(
        'var ADD = {',
        'var ADD = {\n    "extra-icon": \'<path d="M1 1"/>\',',
      ),
    );
    expect(
      () => loadDesignIcons(root),
      throwsA(
        isA<IconsException>().having(
          (e) => e.message,
          'message',
          contains('85'),
        ),
      ),
    );
  });
}
