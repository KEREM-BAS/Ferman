import 'package:icons/icons.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final icons = loadDesignIcons(repoRoot);
  final matches = decodeMatches(readRepoFile(matchesPath), icons);

  test('the committed matches cover exactly the 229 icons', () {
    expect(matches.keys.toSet(), {for (final i in icons) i.name});
  });

  test('sources agree with G60 and ADR 0013', () {
    final bySource = <String, List<String>>{};
    for (final icon in icons) {
      bySource
          .putIfAbsent(sourceLabel(matches[icon.name]!), () => [])
          .add(icon.name);
    }
    expect(bySource['Lucide 0.460.0'], hasLength(222));
    expect(bySource['Lucide 1.56.0'], ['bell', 'funnel', 'grid-2x2']);
    expect(bySource['Lucide 0.500.0'], ['expand', 'paperclip']);
    expect(bySource['Lucide 0.300.0'], ['file-signature']);
    expect(bySource[fermanDesign], ['ellipse']);
    expect(bySource.keys, hasLength(5));
  });

  test('every ICON_PATHS glyph matches Lucide 0.460.0', () {
    for (final icon in icons.where((i) => i.origin == IconOrigin.bundle)) {
      expect(matches[icon.name]!.first, '0.460.0', reason: icon.name);
    }
  });

  test('encodeMatches round-trips and writes one icon per line', () {
    final encoded = encodeMatches(matches, icons);
    expect(decodeMatches(encoded, icons), matches);
    expect(encoded, readRepoFile(matchesPath));
    expect('\n    "'.allMatches(encoded), hasLength(229));
    final x = icons.singleWhere((i) => i.name == 'x');
    expect(encoded, contains('"x": {"sha256": "${markupSha256(x.markup)}", '));
  });

  test('decodeMatches refuses files for other icons or releases', () {
    expect(
      () => decodeMatches('{"releases": ["0.460.0"], "icons": {}}', icons),
      throwsA(isA<IconsException>()),
    );
    final partial = encodeMatches({...matches}..remove('x'), icons);
    expect(() => decodeMatches(partial, icons), throwsA(isA<IconsException>()));
    final oldShape = readRepoFile(matchesPath).replaceAll(
      RegExp(r'\{"sha256": "[0-9a-f]+", "releases": ([^}]*)\}'),
      r'$1',
    );
    expect(oldShape, isNot(contains('sha256":')));
    expect(
      () => decodeMatches(oldShape, icons),
      throwsA(isA<IconsException>()),
    );
  });

  test('decodeMatches refuses a glyph whose path data changed', () {
    final changed = [
      for (final icon in icons)
        if (icon.name == 'x')
          DesignIcon(icon.name, '<path d="M1 1h2"/>', icon.origin)
        else
          icon,
    ];
    expect(
      () => decodeMatches(readRepoFile(matchesPath), changed),
      throwsA(
        isA<IconsException>().having(
          (e) => e.message,
          'message',
          allOf(contains('[x]'), contains('--lucide')),
        ),
      ),
    );
  });

  test('markupSha256 hashes the UTF-8 markup', () {
    expect(
      markupSha256(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(markupSha256('<path d="M1 1"/>'), isNot(markupSha256('<path/>')));
  });

  test('the provenance table names every icon and the licence files', () {
    final table = renderProvenance(icons, matches);
    expect(table, readRepoFile(provenancePath));
    for (final icon in icons) {
      expect(table, contains('| `${icon.name}` |'));
    }
    expect(
      table,
      contains(
        '| `ellipse` | fm-icons.js | none | Ferman design (pending, Q11) |',
      ),
    );
    expect(table, contains('LICENSE-lucide-0.460.0.txt'));
    expect(table, contains('LICENSE-lucide-1.56.0.txt'));
    expect(table, contains('| Lucide 0.460.0 | 222 |'));
  });
}
