import 'dart:io';

import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final icons = loadDesignIcons(repoRoot);
  final source = readRepoFile(enumPath);
  final entries = {
    for (final m in RegExp(
      r"^  (\w+)\('([a-z0-9-]+)'(, directional: true)?\)[,;]$",
      multiLine: true,
    ).allMatches(source))
      m.group(2)!: (id: m.group(1)!, directional: m.group(3) != null),
  };

  test('dartIdentifier maps kebab-case to lower camel case', () {
    expect(dartIdentifier('align-center'), 'alignCenter');
    expect(dartIdentifier('grid-2x2'), 'grid2x2');
    expect(dartIdentifier('file-check-2'), 'fileCheck2');
    expect(dartIdentifier('x'), 'x');
    expect(() => dartIdentifier('class'), throwsA(isA<IconsException>()));
    expect(() => dartIdentifier('index'), throwsA(isA<IconsException>()));
  });

  test('the enum has one value per icon, in name order', () {
    expect(entries.keys.toList(), [for (final i in icons) i.name]);
    for (final icon in icons) {
      expect(entries[icon.name]!.id, dartIdentifier(icon.name));
    }
  });

  test('enum values and SVG files are in sync', () {
    final dir = Directory(p.joinAll([repoRoot, ...assetsDir.split('/')]));
    final files = {
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.svg')) p.basenameWithoutExtension(f.path),
    };
    expect(files, entries.keys.toSet());
  });

  test('the enum has no asset path: the app does not load the SVGs', () {
    expect(source, isNot(contains('assetPath')));
    expect(source, isNot(contains("'assets/")));
  });

  test('exactly the directional icons carry the flag', () {
    final flagged = {
      for (final MapEntry(:key, :value) in entries.entries)
        if (value.directional) key,
    };
    expect(flagged, directionalIcons.keys.toSet());
    expect(flagged, {
      'arrow-left',
      'arrow-right',
      'chevron-left',
      'chevron-right',
      'redo-2',
      'skip-back',
      'skip-forward',
      'undo-2',
    });
  });

  test('the enum is what the generator emits, formatted', () async {
    final generated = await formatDart(
      emitIconEnum(icons),
      stdinName: p.joinAll([repoRoot, ...enumPath.split('/')]),
    );
    expect(generated, source);
  });

  test('the enum compiles and runs as plain Dart', () async {
    final dir = Directory.systemTemp.createTempSync('icon_enum_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File(p.join(dir.path, 'icon_name.g.dart')).writeAsStringSync(source);
    File(p.join(dir.path, 'main.dart')).writeAsStringSync(r'''
import 'icon_name.g.dart';

void main() {
  final flipped = IconName.values.where((i) => i.directional).length;
  print('${IconName.values.length} $flipped '
      '${IconName.fromId('grid-2x2')!.id} '
      '${IconName.chevronRight.directional} ${IconName.fromId('nope')}');
}
''');
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      p.join(dir.path, 'main.dart'),
    ], workingDirectory: dir.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      (result.stdout as String).trim().split('\n').last,
      '229 8 grid-2x2 true null',
    );
  });
}
