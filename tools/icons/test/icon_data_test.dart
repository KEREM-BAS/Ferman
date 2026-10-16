import 'dart:io';

import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// The SVG attributes of [element] that carry drawing, without
/// [ignoredAttributes].
Map<String, String> drawn(SvgElement element) => {
  for (final MapEntry(:key, :value) in element.attributes.entries)
    if (!ignoredAttributes.contains(key)) key: value,
};

/// Whether [a] and [b] are the same value of [attribute] on [tag]: numbers
/// compare as numbers (`.5` and `0.5`), everything else as text.
bool sameValue(String tag, String attribute, String a, String b) {
  final type = iconElementTypes.singleWhere((t) => t.tag == tag);
  return type.attributes[attribute] == AttributeKind.number
      ? double.parse(a) == double.parse(b)
      : a == b;
}

/// Prints every icon as `<id>\t<markup>`, rebuilding the markup from the
/// compiled const data. The switches have no default, so the program only
/// compiles while the sealed hierarchy is exactly these seven classes.
const String roundTripProgram = r'''
import 'icon_data.g.dart';
import 'icon_element.dart';
import 'icon_name.g.dart';

String n(double value) => value.toString();

String svg(IconElement e) {
  final tag = switch (e) {
    IconPath() => 'path',
    IconCircle() => 'circle',
    IconEllipse() => 'ellipse',
    IconRect() => 'rect',
    IconLine() => 'line',
    IconPolyline() => 'polyline',
    IconPolygon() => 'polygon',
  };
  final attributes = switch (e) {
    IconPath(:final d) => {'d': d},
    IconCircle(:final cx, :final cy, :final r) => {
        'cx': n(cx), 'cy': n(cy), 'r': n(r)},
    IconEllipse(:final cx, :final cy, :final rx, :final ry) => {
        'cx': n(cx), 'cy': n(cy), 'rx': n(rx), 'ry': n(ry)},
    IconRect(:final x, :final y, :final width, :final height,
        :final rx, :final ry) => {
        'x': n(x), 'y': n(y), 'width': n(width), 'height': n(height),
        if (rx != null) 'rx': n(rx),
        if (ry != null) 'ry': n(ry)},
    IconLine(:final x1, :final y1, :final x2, :final y2) => {
        'x1': n(x1), 'y1': n(y1), 'x2': n(x2), 'y2': n(y2)},
    IconPolyline(:final points) => {'points': points},
    IconPolygon(:final points) => {'points': points},
  };
  if (e.filled) attributes['fill'] = 'currentColor';
  final text = [
    for (final MapEntry(:key, :value) in attributes.entries) '$key="$value"',
  ].join(' ');
  return '<$tag $text/>';
}

void main() {
  for (final icon in IconName.values) {
    print('${icon.id}\t${icon.elements.map(svg).join()}');
  }
}
''';

void main() {
  final icons = loadDesignIcons(repoRoot);

  group('element types', () {
    test('every type the icons use is known, and every known type is used', () {
      final used = {
        for (final icon in icons)
          for (final element in parseShapes(icon.markup)) element.tag,
      };
      expect(used, {for (final t in iconElementTypes) t.tag});
      expect(used, {
        'path',
        'circle',
        'ellipse',
        'rect',
        'line',
        'polyline',
        'polygon',
      });
    });

    test('every icon converts, with every attribute kept', () {
      var count = 0;
      for (final icon in icons) {
        final source = parseShapes(icon.markup);
        final data = iconElements(icon.name, icon.markup);
        expect(data, hasLength(source.length), reason: icon.name);
        for (final (i, element) in data.indexed) {
          expect(element.type.tag, source[i].tag, reason: icon.name);
          expect(
            element.toSvgAttributes(),
            drawn(source[i]),
            reason: icon.name,
          );
          count++;
        }
      }
      expect(count, greaterThan(229));
    });

    test('icon_element.dart declares each class with its fields', () {
      final source = readRepoFile(elementPath);
      expect(source, contains('sealed class IconElement {'));
      expect(source, contains('final bool filled;'));
      expect(
        RegExp(r'final class (\w+) extends IconElement')
            .allMatches(source)
            .map((m) => m.group(1))
            .toSet(),
        {for (final t in iconElementTypes) t.dartClass},
      );
      for (final type in iconElementTypes) {
        final start = source.indexOf('final class ${type.dartClass} ');
        final end = source.indexOf('\n}\n', start);
        final body = source.substring(start, end);
        for (final MapEntry(key: name, value: kind)
            in type.attributes.entries) {
          final dartType = switch (kind) {
            AttributeKind.number =>
              type.optional.contains(name) ? 'double?' : 'double',
            AttributeKind.pathData || AttributeKind.points => 'String',
          };
          expect(
            body,
            contains('final $dartType $name;'),
            reason: '${type.dartClass}.$name',
          );
          expect(
            body,
            contains(
              type.optional.contains(name)
                  ? 'this.$name,'
                  : 'required this.$name',
            ),
            reason: '${type.dartClass}.$name',
          );
        }
        expect(body, contains('super.filled'), reason: type.dartClass);
      }
    });
  });

  group('conversion', () {
    IconElementData one(String markup) => iconElements('t', markup).single;

    test('numbers keep their source text, strings are quoted', () {
      expect(
        one('<circle cx="12" cy="1.5" r=".5" fill="currentColor"/>').toDart(),
        'IconCircle(cx: 12, cy: 1.5, r: .5, filled: true)',
      );
      expect(
        one('<path d="m9 18 6-6-6-6"/>').toDart(),
        "IconPath(d: 'm9 18 6-6-6-6')",
      );
      expect(
        one('<polygon points="6 3 20 12 6 21"/>').toDart(),
        "IconPolygon(points: '6 3 20 12 6 21')",
      );
      expect(
        one('<line y2="-2" x1="1e2" x2="3" y1="4"/>').toDart(),
        'IconLine(x1: 1e2, y1: 4, x2: 3, y2: -2)',
      );
    });

    test('rect radii are optional and stay absent', () {
      final plain = one('<rect x="1" y="2" width="3" height="4"/>');
      expect(plain.toDart(), 'IconRect(x: 1, y: 2, width: 3, height: 4)');
      expect(plain.toSvgAttributes().keys, ['x', 'y', 'width', 'height']);
      expect(
        one('<rect width="3" height="4" x="1" y="2" ry="2"/>').toDart(),
        'IconRect(x: 1, y: 2, width: 3, height: 4, ry: 2)',
      );
    });

    test('the listed harmless attributes are dropped', () {
      final element = one('<path class="a" id="b" key="c" d="M1 1"/>');
      expect(element.toDart(), "IconPath(d: 'M1 1')");
      expect(element.toSvgAttributes(), {'d': 'M1 1'});
    });

    test('dartString escapes what Dart needs', () {
      expect(dartString(r"a'b\c$d"), r"'a\'b\\c\$d'");
    });

    test('anything else stops the tool', () {
      for (final markup in [
        '<text x="1" y="2"/>',
        '<use href="#a"/>',
        '<path d="M1 1" stroke-width="2"/>',
        '<path d="M1 1" transform="scale(2)"/>',
        '<circle cx="1" cy="1" r="1" fill="none"/>',
        '<circle cx="1" cy="1" r="1" fill="red"/>',
        '<circle cx="1" cy="1"/>',
        '<circle cx="1" cy="1" r="1px"/>',
        '<circle cx="+1" cy="1" r="1"/>',
        '<rect x="1" y="1" width="50%" height="1"/>',
        '<path d="url(#a)"/>',
        '<path d="L1 1"/>',
        '<polyline points="1 2 3"/>',
        '<polyline points="1 2"/>',
        '<polygon points="1,2 a,b"/>',
      ]) {
        expect(
          () => iconElements('t', markup),
          throwsA(
            isA<IconsException>().having(
              (e) => e.message,
              'message',
              contains('Icon "t"'),
            ),
          ),
          reason: markup,
        );
      }
    });
  });

  group('icon_data.g.dart', () {
    final source = readRepoFile(dataPath);

    test('is what the generator emits, formatted', () async {
      final generated = await formatDart(
        emitIconData(icons),
        stdinName: p.joinAll([repoRoot, ...dataPath.split('/')]),
      );
      expect(generated, source);
    });

    test('has one case per icon, in name order', () {
      final cases = RegExp(
        r'^    IconName\.(\w+) => const \[',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)).toList();
      expect(cases, hasLength(229));
      expect(cases, [for (final i in icons) dartIdentifier(i.name)]);
    });

    test('compiles and round-trips to the design markup', () async {
      final dir = Directory.systemTemp.createTempSync('icon_data_');
      addTearDown(() => dir.deleteSync(recursive: true));
      for (final path in [dataPath, elementPath, enumPath]) {
        File(p.join(dir.path, p.posix.basename(path)))
            .writeAsStringSync(readRepoFile(path));
      }
      File(p.join(dir.path, 'main.dart')).writeAsStringSync(roundTripProgram);
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        p.join(dir.path, 'main.dart'),
      ], workingDirectory: dir.path);
      expect(result.exitCode, 0, reason: '${result.stderr}');

      final printed = {
        for (final line in (result.stdout as String).trim().split('\n'))
          if (line.contains('\t'))
            line.split('\t').first: line.split('\t').last.trim(),
      };
      expect(printed, hasLength(229));
      expect(printed.keys.toList(), [for (final i in icons) i.name]);
      for (final icon in icons) {
        final expected = parseShapes(icon.markup);
        final actual = parseShapes(printed[icon.name]!);
        expect(actual, hasLength(expected.length), reason: icon.name);
        for (final (i, element) in actual.indexed) {
          final want = drawn(expected[i]);
          expect(element.tag, expected[i].tag, reason: icon.name);
          expect(
            element.attributes.keys.toSet(),
            want.keys.toSet(),
            reason: icon.name,
          );
          for (final MapEntry(key: name, :value) in want.entries) {
            expect(
              sameValue(element.tag, name, element.attributes[name]!, value),
              isTrue,
              reason:
                  '${icon.name} $name: ${element.attributes[name]} '
                  'vs $value',
            );
          }
        }
      }
    });
  });
}
