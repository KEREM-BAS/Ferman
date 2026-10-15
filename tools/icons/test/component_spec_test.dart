import 'dart:convert';
import 'dart:io';

import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

typedef Json = Map<String, Object?>;

Json map(Object? value) => value! as Json;
List<Object?> list(Object? value) => value! as List<Object?>;
List<Json> maps(Object? value) => list(value).cast<Json>();

void main() {
  final spec = decodeSpec(readRepoFile(componentSpecPath));
  final components = maps(spec['components']);
  final byName = {for (final c in components) c['name']! as String: c};
  final sourceFiles = map(spec['sourceFiles']).cast<String, String>();
  final enums = map(spec['enums']);
  final adherence = map(jsonDecode(readRepoFile(spec['adherence']! as String)));
  final manifest = map(
    jsonDecode(readRepoFile(map(spec['manifest'])['path']! as String)),
  );
  const future = 'Available in a future version';

  /// Declared props and enum rules of the lint config, keyed by component.
  final declared = <String, List<String>>{};
  final enumRules = <String, List<String>>{};
  for (final rule in list(
    map(adherence['rules'])['no-restricted-syntax'],
  ).skip(1)) {
    if (rule is! Json) continue;
    final selector = rule['selector']! as String;
    final message = rule['message']! as String;
    final element = RegExp(r"name\.name='(\w+)'\]").firstMatch(selector);
    if (element == null) continue;
    final name = element.group(1)!;
    if (message.contains('Declared props: ')) {
      declared[name] = message
          .split('Declared props: ')[1]
          .replaceFirst(RegExp(r'\.$'), '')
          .split(', ');
    }
    final attribute = RegExp(r"JSXAttribute\[name\.name='(\w+)'\]")
        .firstMatch(selector);
    final values = RegExp(r'value!=/\^\(\?:([^)]*)\)\$/').firstMatch(selector);
    if (attribute != null && values != null) {
      enumRules['$name.${attribute.group(1)}'] = values.group(1)!.split('|');
    }
  }

  /// The props of [owner]: a component, or an item type of any component.
  List<Json>? propsOf(String owner) {
    final component = byName[owner];
    if (component != null) return maps(component['props']);
    for (final c in components) {
      for (final item in maps(c['itemTypes'])) {
        if (item['name'] == owner) return maps(item['fields']);
      }
    }
    return null;
  }

  Iterable<Json> allStates(Json c) sync* {
    yield* maps(c['states']);
    for (final item in maps(c['itemTypes'])) {
      yield* maps(item['states']);
    }
  }

  group('schema', () {
    test('top-level keys', () {
      expect(spec['schemaVersion'], 1);
      expect(spec['futureVersionTooltip'], future);
      expect(spec['documentation'], componentsDocPath);
      for (final key in [
        'description',
        'manifest',
        'adherence',
        'sourceFiles',
        'tiers',
        'stateVocabulary',
        'triggers',
        'types',
        'rules',
        'enums',
        'components',
      ]) {
        expect(spec.containsKey(key), isTrue, reason: key);
      }
      expect(map(spec['tiers']).keys, ['1', '2']);
    });

    test('every component has the documented keys and types', () {
      const kinds = {'widget', 'enum', 'internal', 'addition'};
      final triggers = map(spec['triggers']).keys.toSet();
      for (final c in components) {
        final name = c['name'];
        expect(c['flutterClass'], isA<String>(), reason: '$name');
        expect(kinds, contains(c['kind']), reason: '$name');
        expect(c['group'], isA<String>(), reason: '$name');
        expect(c['tier'], anyOf(1, 2), reason: '$name');
        expect(c['tierReason'], isA<String>(), reason: '$name');
        expect(c['summary'], isA<String>(), reason: '$name');
        expect(c['source'], isA<Json>(), reason: '$name');
        expect(c['usedIn'], isA<List<Object?>>(), reason: '$name');
        expect(c['interactive'], isA<bool>(), reason: '$name');
        expect(c['variants'], isA<Json>(), reason: '$name');
        expect(c['sizes'], isA<List<Object?>>(), reason: '$name');
        expect(c['keyboard'], isA<List<Object?>>(), reason: '$name');
        expect(c['notes'], isA<List<Object?>>(), reason: '$name');
        final semantics = map(c['semantics']);
        expect(semantics.keys, containsAll(['role', 'label', 'properties']));
        for (final k in maps(c['keyboard'])) {
          expect(list(k['keys']), isNotEmpty, reason: '$name');
          expect(k['action'], isA<String>(), reason: '$name');
        }
        final names = <String>{};
        for (final s in allStates(c)) {
          expect(
            s['name'],
            matches(RegExp(r'^[a-z][A-Za-z0-9]*$')),
            reason: '$name',
          );
          expect(
            triggers,
            contains(s['trigger']),
            reason: '$name ${s['name']}',
          );
          expect(s['refs'], isA<List<Object?>>(), reason: '$name ${s['name']}');
          names.add(s['name']! as String);
        }
        final own = maps(c['states']).map((s) => s['name']).toList();
        expect(own.toSet(), hasLength(own.length), reason: '$name duplicates');
      }
      expect(byName, hasLength(components.length));
    });

    test('every prop has the documented keys', () {
      for (final c in components) {
        final all = [
          ...maps(c['props']),
          for (final item in maps(c['itemTypes'])) ...maps(item['fields']),
        ];
        for (final prop in all) {
          final label = '${c['name']}.${prop['ds'] ?? prop['dart']}';
          for (final key in [
            'ds',
            'dart',
            'type',
            'required',
            'default',
            'declared',
          ]) {
            expect(prop.containsKey(key), isTrue, reason: '$label $key');
          }
          expect(prop['ds'] ?? prop['dart'], isNotNull, reason: label);
          if (prop['dart'] == null) {
            expect(prop['omitReason'], isA<String>(), reason: label);
            expect(prop['type'], 'n/a', reason: label);
          }
          if (prop.containsKey('dartDefault')) {
            expect(
              prop['dartDefault'],
              isNot(equals(prop['default'])),
              reason: '$label: dartDefault only when it differs',
            );
          }
          final enumName = prop['dartEnum'];
          if (enumName != null) {
            final e = map(enums[enumName]);
            expect(prop['values'], e['ds'], reason: label);
            expect(
              (prop['type']! as String).replaceAll('?', ''),
              enumName,
              reason: label,
            );
          }
        }
      }
    });

    test('enums pair every DS value with a Dart identifier', () {
      const reserved = {
        'default',
        'switch',
        'case',
        'class',
        'new',
        'null',
        'true',
        'false',
      };
      for (final MapEntry(key: name, value: raw) in enums.entries) {
        final e = map(raw);
        final ds = list(e['ds']);
        final dart = list(e['dart']);
        expect(dart, hasLength(ds.length), reason: name);
        for (final v in dart.cast<String>()) {
          expect(v, matches(RegExp(r'^[a-z][A-Za-z0-9]*$')), reason: name);
          expect(reserved, isNot(contains(v)), reason: name);
        }
        expect(dart.toSet(), hasLength(dart.length), reason: name);
      }
    });

    test('every source reference points at a line holding its text', () {
      final cache = <String, List<String>>{};
      List<String> linesOf(String alias) => cache.putIfAbsent(alias, () {
        final path = sourceFiles[alias];
        expect(path, isNotNull, reason: 'unknown source alias $alias');
        return readRepoFile(path!).split('\n');
      });
      var count = 0;
      for (final c in components) {
        for (final s in allStates(c)) {
          for (final ref in maps(s['refs'])) {
            final lines = linesOf(ref['file']! as String);
            final line = ref['line']! as int;
            expect(line, inInclusiveRange(1, lines.length), reason: '$ref');
            expect(
              lines[line - 1],
              contains(ref['text']),
              reason: '${c['name']} $ref',
            );
            count++;
          }
        }
        final source = map(c['source']);
        for (final d in maps(source['design'] ?? <Object?>[])) {
          expect(sourceFiles, contains(d['file']), reason: '${c['name']}');
          final lines = linesOf(d['file']! as String);
          final range = list(d['lines']).cast<int>();
          expect(range[0], lessThanOrEqualTo(range[1]));
          expect(
            range[1],
            lessThanOrEqualTo(lines.length),
            reason: '${c['name']}',
          );
        }
        for (final css in list(source['css'] ?? <Object?>[])) {
          expect(sourceFiles, contains(css), reason: '${c['name']}');
        }
      }
      expect(count, greaterThan(300));
    });

    test('bundle sections start at their source marker', () {
      final bundle = readRepoFile(sourceFiles['bundle']!).split('\n');
      for (final c in components) {
        final section = map(c['source'])['bundle'];
        if (section == null) continue;
        final s = map(section);
        final range = list(s['lines']).cast<int>();
        expect(bundle[range[0] - 1], '// ${s['file']}', reason: '${c['name']}');
        expect(
          bundle[range[1] - 1],
          contains('__ds_ns.__errors.push'),
          reason: '${c['name']}',
        );
      }
    });
  });

  group('coverage', () {
    test('all 45 manifest entries, the internal pieces and the additions', () {
      final names = maps(manifest['components']).map((c) => c['name']).toList();
      expect(names, hasLength(45));
      expect(byName.keys, containsAll(names));
      for (final internal in ['Field', 'Popover', 'Scrim']) {
        expect(byName[internal]?['kind'], 'internal');
      }
      const additions = {
        'DocumentTab': 'DocumentTab',
        'WindowChrome': 'WindowChrome',
        'SaveIndicator': 'SaveIndicator',
        'DatePicker': 'DatePicker',
        'MentionList': 'MentionList',
        'CommentCard': 'CommentCard',
        'ThumbnailBadges': 'ThumbnailBadges',
        'FmNumber': 'FmNumber',
      };
      for (final MapEntry(:key, :value) in additions.entries) {
        expect(byName[key]?['kind'], 'addition', reason: key);
        expect(byName[key]?['flutterClass'], value, reason: key);
      }
      expect(components, hasLength(45 + 3 + additions.length));
    });

    test('Flutter names are the design-system names', () {
      const renamed = {
        'ICON_PATHS': 'IconName',
        'FERMAN_MODES': 'FermanMode',
        'ANNOTATION_TOOLS': 'AnnotationTool',
      };
      for (final c in components.where((c) => c['kind'] != 'addition')) {
        expect(
          c['flutterClass'],
          renamed[c['name']] ?? c['name'],
          reason: '${c['name']}',
        );
      }
      for (final name in renamed.keys) {
        expect(byName[name]!['kind'], 'enum');
      }
    });

    test('FermanMode has the eight drawn modes (G09)', () {
      final ids = maps(byName['FERMAN_MODES']!['entries']).map((e) => e['id']);
      expect(ids, [
        'view',
        'edit',
        'comment',
        'sign',
        'organize',
        'convert',
        'protect',
        'tools',
      ]);
    });

    test('IconName points at the generated enum and element data', () {
      final entries = map(byName['ICON_PATHS']!['entries']);
      expect(entries['generatedFile'], enumPath);
      expect(entries['dataFile'], dataPath);
      expect(entries['count'], totalIconCount);
      expect(
        list(entries['directional']).toSet(),
        directionalIcons.keys.toSet(),
      );
    });
  });

  group('agreement with the lint config', () {
    test('it declares 38 components and item types', () {
      expect(declared, hasLength(38));
    });

    test('every declared prop is in the spec and marked declared', () {
      for (final MapEntry(key: owner, value: names) in declared.entries) {
        final props = propsOf(owner);
        expect(props, isNotNull, reason: '$owner is missing');
        for (final name in names) {
          final prop = props!.where((p) => p['ds'] == name);
          expect(prop, hasLength(1), reason: '$owner.$name');
          expect(prop.single['declared'], isTrue, reason: '$owner.$name');
        }
        for (final prop in props!) {
          if (prop['declared'] == true) {
            expect(names, contains(prop['ds']), reason: '$owner.${prop['ds']}');
          }
        }
      }
    });

    test('every enum rule has the same values in the spec', () {
      expect(enumRules, hasLength(35));
      for (final MapEntry(key: path, value: values) in enumRules.entries) {
        final [owner, name] = path.split('.');
        final prop = propsOf(owner)!.singleWhere((p) => p['ds'] == name);
        expect(prop['values'], values, reason: path);
      }
    });
  });

  group('decisions', () {
    test('rules name every Material and widgets class a DS name clashes '
        'with', () {
      final rule = list(spec['rules']).first! as String;
      final names = RegExp(r'clashing names \(([^)]*)\)').firstMatch(rule);
      expect(names, isNotNull, reason: rule);
      expect(names!.group(1)!.split(', '), [
        'Icon',
        'IconButton',
        'Tooltip',
        'Dialog',
        'Badge',
        'Radio',
        'Switch',
        'TextField',
        'Banner',
        'Checkbox',
      ]);
    });

    test('decision 3: Icon.flipRtl defaults to null in Dart', () {
      final flip = maps(byName['Icon']!['props'])
          .singleWhere((p) => p['ds'] == 'flipRtl');
      expect(flip['type'], 'bool?');
      expect(flip['default'], false, reason: 'the bundle default');
      expect(flip.containsKey('dartDefault'), isTrue);
      expect(flip['dartDefault'], isNull);
      expect(flip['notes'], contains('IconName.directional'));
    });

    test('decision 1: arrow keys stop on disabled-with-reason items', () {
      for (final name in ['Toolbar', 'AnnotationTools']) {
        final actions = maps(byName[name]!['keyboard'])
            .where((k) => list(k['keys']).contains('ArrowRight'))
            .map((k) => k['action']! as String)
            .first;
        expect(actions, contains('disabled-with-reason'), reason: name);
        expect(actions, contains('plain disabled'), reason: name);
      }
      for (final c in components) {
        for (final k in maps(c['keyboard'])) {
          final action = k['action']! as String;
          if (action.contains('enabled')) {
            expect(
              action,
              contains('disabled-with-reason'),
              reason: '${c['name']}: $action',
            );
          }
        }
      }
    });

    test('the Icon is painted from the generated data, not an SVG asset', () {
      final icon = byName['Icon']!;
      expect(icon['summary'], contains('element data'));
      final notes = list(icon['notes']).join(' ');
      expect(notes, contains('icon_data.g.dart'));
      expect(notes, contains('not loaded at run time'));
      expect(notes, isNot(contains('replace the root stroke-width')));
    });
  });

  group('states', () {
    Iterable<Json> withReason(Iterable<Json> states) =>
        states.where((s) => s['name'] == 'disabledWithReason');

    test('G10: disabled with the future-version tooltip', () {
      for (final name in ['Button', 'IconButton', 'ToolButton', 'DropZone']) {
        final state = withReason(maps(byName[name]!['states']));
        expect(state, hasLength(1), reason: name);
        expect(state.single['tooltip'], future, reason: name);
        expect(state.single['gap'], 'G10', reason: name);
        expect(
          maps(byName[name]!['props'])
              .any((p) => p['dart'] == 'disabledReason'),
          isTrue,
          reason: name,
        );
      }
      for (final (stateName, prop) in [
        ('toolDisabledWithReason', 'disabledReasons'),
        ('colorsDisabledWithReason', 'colorsDisabledReason'),
      ]) {
        final tools = byName['AnnotationTools']!;
        final state = maps(tools['states'])
            .singleWhere((s) => s['name'] == stateName);
        expect(state['prop'], prop, reason: stateName);
        expect(state['tooltip'], future, reason: stateName);
        expect(state['gap'], 'G10', reason: stateName);
        expect(
          maps(tools['props']).any((p) => p['dart'] == prop),
          isTrue,
          reason: prop,
        );
      }
      for (final (component, item) in [
        ('Menu', 'MenuItem'),
        ('SegmentedControl', 'SegmentOption'),
        ('CommandPalette', 'CommandItem'),
      ]) {
        final type = maps(byName[component]!['itemTypes'])
            .singleWhere((i) => i['name'] == item);
        final state = withReason(maps(type['states']));
        expect(state, hasLength(1), reason: item);
        expect(state.single['tooltip'], future, reason: item);
        expect(
          maps(type['fields']).any((f) => f['dart'] == 'disabledReason'),
          isTrue,
          reason: item,
        );
      }
    });

    test('G22: every interactive component has a focus-visible state', () {
      for (final c in components.where((c) => c['interactive'] == true)) {
        expect(
          allStates(c).any(
            (s) =>
                (s['name']! as String).toLowerCase().contains('focusvisible'),
          ),
          isTrue,
          reason: '${c['name']}',
        );
      }
    });

    test('states driven by a prop name a real parameter', () {
      for (final c in components) {
        final params = {
          for (final prop in maps(c['props'])) ...[prop['ds'], prop['dart']],
          for (final item in maps(c['itemTypes']))
            for (final f in maps(item['fields'])) ...[f['ds'], f['dart']],
        };
        for (final s in allStates(c)) {
          if (s['prop'] != null) {
            expect(
              params,
              contains(s['prop']),
              reason: '${c['name']} ${s['name']}',
            );
          }
        }
      }
    });

    test('variants and sizes use the values of their enum props', () {
      for (final c in components) {
        final props = maps(c['props']);
        final variants = map(c['variants']);
        for (final MapEntry(key: name, value: values) in variants.entries) {
          final prop = props.where((p) => p['ds'] == name || p['dart'] == name);
          // A variant of an item type (thumbnail badge kinds) has no prop.
          if (prop.isEmpty) continue;
          expect(prop.single['values'], values, reason: '${c['name']}.$name');
        }
        final sizes = list(c['sizes']);
        if (sizes.isNotEmpty) {
          final size = props.firstWhere(
            (p) => p['ds'] == 'size' || p['dart'] == 'size',
          );
          expect(size['values'], sizes, reason: '${c['name']}');
        }
      }
    });
  });

  test('tier 1 widgets are drawn in the M1 sources', () {
    const m1 = {'FmWindow', 'FmStart', 'FmSettings', '01 First run and files'};
    const indirect = {
      'Tooltip',
      'Field',
    }; // Reached through IconButton and TextField.
    for (final c in components.where(
      (c) => c['tier'] == 1 && c['kind'] == 'widget',
    )) {
      if (indirect.contains(c['name'])) continue;
      final usedIn = list(c['usedIn']).toSet();
      expect(usedIn.intersection(m1), isNotEmpty, reason: '${c['name']}');
    }
  });

  test('COMPONENTS.md is rendered from the spec', () {
    final doc = readRepoFile(componentsDocPath);
    expect(renderComponentsDoc(doc, spec), doc);
    for (final c in components) {
      expect(doc, contains('#### ${c['name']}\n'));
    }
  });

  group('component_spec CLI', () {
    test('--check passes on the committed files', () async {
      final out = StringBuffer();
      final err = StringBuffer();
      final code = await runComponentSpecCli(
        ['--check'],
        out: out,
        err: err,
        workingDirectory: repoRoot,
      );
      expect(code, 0, reason: '$err');
    });

    test(
      'a CRLF checkout of the spec and the document is up to date',
      () async {
        final root = Directory.systemTemp.createTempSync('spec_crlf_').path;
        addTearDown(() => Directory(root).deleteSync(recursive: true));
        for (final path in [
          componentSpecPath,
          componentsDocPath,
          'tools/icons/pubspec.yaml',
        ]) {
          final target = File(p.joinAll([root, ...path.split('/')]));
          target.parent.createSync(recursive: true);
          target.writeAsStringSync(readRepoFile(path));
          convertToCrlf(target);
        }
        Directory(p.join(root, 'design')).createSync();
        final doc = File(p.joinAll([root, ...componentsDocPath.split('/')]));
        final before = doc.readAsStringSync();
        expect(before, contains('\r\n'));
        final out = StringBuffer();
        final err = StringBuffer();
        expect(
          await runComponentSpecCli(
            ['--check', '--root', root],
            out: out,
            err: err,
          ),
          0,
          reason: '$err',
        );
        expect(
          await runComponentSpecCli(['--root', root], out: out, err: err),
          0,
        );
        expect(out.toString(), contains('is up to date'));
        expect(doc.readAsStringSync(), before);
      },
    );

    test('--check fails on a stale document and a run repairs it', () async {
      final root = Directory.systemTemp.createTempSync('spec_root_').path;
      addTearDown(() => Directory(root).deleteSync(recursive: true));
      for (final path in [
        componentSpecPath,
        componentsDocPath,
        'tools/icons/pubspec.yaml',
      ]) {
        final target = File(p.joinAll([root, ...path.split('/')]));
        target.parent.createSync(recursive: true);
        target.writeAsStringSync(readRepoFile(path));
      }
      Directory(p.join(root, 'design')).createSync();
      final doc = File(p.joinAll([root, ...componentsDocPath.split('/')]));
      doc.writeAsStringSync(
        doc.readAsStringSync().replaceFirst('#### Button\n', '#### Knopf\n'),
      );
      final err = StringBuffer();
      expect(
        await runComponentSpecCli(
          ['--check', '--root', root],
          out: StringBuffer(),
          err: err,
        ),
        exitStale,
      );
      expect(
        await runComponentSpecCli(
          ['--root', root],
          out: StringBuffer(),
          err: err,
        ),
        0,
      );
      expect(doc.readAsStringSync(), readRepoFile(componentsDocPath));
    });
  });
}
