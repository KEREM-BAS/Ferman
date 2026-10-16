/// Renders the generated part of docs/COMPONENTS.md from the component spec.
///
/// The spec, `app/test/design/component_spec.json`, is written by careful
/// reading of the design export (G02) and walked by the app's component
/// tests. The prose of COMPONENTS.md (schema, rules, open points) is written
/// by hand; only the region between [beginMarker] and [endMarker] is
/// rendered here, so the document and the JSON cannot drift apart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:icons/src/cli.dart'
    show exitError, exitStale, exitUsage, findRoot;
import 'package:icons/src/errors.dart';
import 'package:icons/src/text.dart';
import 'package:path/path.dart' as p;

/// The component spec, relative to the repository root.
const String componentSpecPath = 'app/test/design/component_spec.json';

/// The component document, relative to the repository root.
const String componentsDocPath = 'docs/COMPONENTS.md';

/// Opens the rendered region of COMPONENTS.md.
const String beginMarker =
    '<!-- BEGIN GENERATED COMPONENT REFERENCE: tools/icons, '
    'dart run icons:component_spec -->';

/// Closes the rendered region of COMPONENTS.md.
const String endMarker = '<!-- END GENERATED COMPONENT REFERENCE -->';

/// Decodes the spec JSON, checking only that it is an object.
Map<String, Object?> decodeSpec(String json) {
  final Object? data;
  try {
    data = jsonDecode(json);
  } on FormatException catch (error) {
    throw IconsException(
      '$componentSpecPath is not valid JSON: ${error.message}',
    );
  }
  if (data is! Map<String, Object?>) {
    throw IconsException('$componentSpecPath must hold a JSON object.');
  }
  return data;
}

/// Returns [doc] with its generated region replaced by the reference
/// rendered from [spec].
String renderComponentsDoc(String doc, Map<String, Object?> spec) {
  final begin = doc.indexOf(beginMarker);
  final end = doc.indexOf(endMarker);
  if (begin < 0 || end < begin) {
    throw IconsException(
      '$componentsDocPath needs the markers "$beginMarker" and "$endMarker".',
    );
  }
  return '${doc.substring(0, begin + beginMarker.length)}\n\n'
      '${renderReference(spec)}\n'
      '${doc.substring(end)}';
}

/// Renders the component reference: a summary table, the enums and one
/// section per component.
String renderReference(Map<String, Object?> spec) {
  final files = _map(spec['sourceFiles']);
  final components = _list(spec['components']).map(_map).toList();
  final out = StringBuffer()
    ..writeln('### Rules')
    ..writeln();
  for (final rule in _list(spec['rules']).map(_str)) {
    out.writeln('- $rule');
  }
  out
    ..writeln()
    ..writeln('### Tiers')
    ..writeln();
  for (final MapEntry(key: tier, value: text) in _map(spec['tiers']).entries) {
    out.writeln('- Tier $tier: ${_str(text)}');
  }
  out
    ..writeln()
    ..writeln('### State names')
    ..writeln()
    ..writeln('| State | Meaning |')
    ..writeln('|---|---|');
  for (final MapEntry(key: name, value: text) in _map(
    spec['stateVocabulary'],
  ).entries) {
    out.writeln('| `$name` | ${_cell(_str(text))} |');
  }
  out
    ..writeln()
    ..writeln('| Trigger | Meaning |')
    ..writeln('|---|---|');
  for (final MapEntry(key: name, value: text) in _map(
    spec['triggers'],
  ).entries) {
    out.writeln('| `$name` | ${_cell(_str(text))} |');
  }
  out
    ..writeln()
    ..writeln('### Named types')
    ..writeln()
    ..writeln('| Type | Meaning |')
    ..writeln('|---|---|');
  for (final MapEntry(key: name, value: text) in _map(spec['types']).entries) {
    out.writeln('| `$name` | ${_cell(_str(text))} |');
  }
  out
    ..writeln()
    ..writeln('### Summary')
    ..writeln()
    ..writeln(
      '${components.length} entries. Tier 1 is built to full depth first '
      '(used by the M1 screens); tier 2 is complete visually with data passed '
      'in.',
    )
    ..writeln()
    ..writeln('| Component | Flutter | Kind | Group | Tier | Interactive |')
    ..writeln('|---|---|---|---|---|---|');
  for (final c in components) {
    out.writeln(
      '| [${_str(c['name'])}](#${_anchor(_str(c['name']))}) | '
      '`${_str(c['flutterClass'])}` | ${_str(c['kind'])} | '
      '${_str(c['group'])} | ${c['tier']} | '
      '${c['interactive'] == true ? 'yes' : ''} |',
    );
  }
  out
    ..writeln()
    ..writeln('### Enums')
    ..writeln()
    ..writeln('| Dart enum | DS values | Dart values | Source |')
    ..writeln('|---|---|---|---|');
  for (final MapEntry(key: name, value: raw) in _map(spec['enums']).entries) {
    final e = _map(raw);
    out.writeln(
      '| `$name` | ${_codeList(e['ds'])} | ${_codeList(e['dart'])} | '
      '${_cell(_str(e['source']))} |',
    );
  }
  var group = '';
  for (final c in components) {
    if (c['group'] != group) {
      group = _str(c['group']);
      out
        ..writeln()
        ..writeln('### Group: $group');
    }
    _renderComponent(out, c, files);
  }
  return out.toString();
}

void _renderComponent(
  StringBuffer out,
  Map<String, Object?> c,
  Map<String, Object?> files,
) {
  final name = _str(c['name']);
  out
    ..writeln()
    ..writeln('#### $name')
    ..writeln()
    ..writeln(
      '`${_str(c['flutterClass'])}` · ${_str(c['kind'])} · tier '
      '${c['tier']}${c['interactive'] == true ? ' · interactive' : ''} · '
      '${_sourceText(_map(c['source']))}',
    )
    ..writeln()
    ..writeln(_str(c['summary']))
    ..writeln()
    ..writeln('Tier: ${_str(c['tierReason'])}');
  final usedIn = _list(c['usedIn']).map(_str).toList();
  if (usedIn.isNotEmpty) {
    out
      ..writeln()
      ..writeln('Drawn in: ${usedIn.join(', ')}.');
  }
  final props = _list(c['props']).map(_map).toList();
  if (props.isNotEmpty) {
    out
      ..writeln()
      ..writeln('| DS prop | Lint | Dart | Type | Default | Values | Notes |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final prop in props) {
      _propRow(out, prop);
    }
  }
  for (final item in _list(c['itemTypes']).map(_map)) {
    out
      ..writeln()
      ..writeln(
        'Item type `${_str(item['name'])}` → `${_str(item['dart'])}`'
        '${item['declared'] == true ? ' (declared in the lint config)' : ''}:',
      )
      ..writeln()
      ..writeln('| DS field | Lint | Dart | Type | Default | Values | Notes |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final field in _list(item['fields']).map(_map)) {
      _propRow(out, field);
    }
    final itemStates = _list(item['states']).map(_map).toList();
    if (itemStates.isNotEmpty) {
      out
        ..writeln()
        ..writeln('Item states:')
        ..writeln();
      _statesTable(out, itemStates, files);
    }
  }
  final variants = _map(c['variants']);
  final sizes = _list(c['sizes']).map(_str).toList();
  if (variants.isNotEmpty || sizes.isNotEmpty) {
    out.writeln();
    final parts = [
      for (final MapEntry(key: k, value: v) in variants.entries)
        'Variants ($k): ${_codeList(v)}.',
      if (sizes.isNotEmpty) 'Sizes: ${_codeList(sizes)}.',
    ];
    out.writeln(parts.join(' '));
  }
  final states = _list(c['states']).map(_map).toList();
  if (states.isNotEmpty) {
    out
      ..writeln()
      ..writeln('States:')
      ..writeln();
    _statesTable(out, states, files);
  }
  final entries = c['entries'];
  if (entries is List<Object?>) {
    out
      ..writeln()
      ..writeln('| Value | Label | Icon | Details |')
      ..writeln('|---|---|---|---|');
    for (final e in entries.map(_map)) {
      final details = [
        if (e['key'] != null) 'key ${e['key']}',
        if (e['colored'] == true) 'coloured',
        if (e['menu'] == true) 'menu',
      ];
      out.writeln(
        '| `${_str(e['id'])}` | ${_str(e['label'])} | `${_str(e['icon'])}` | '
        '${details.join(', ')} |',
      );
    }
  } else if (entries is Map<String, Object?>) {
    final data = entries['dataFile'] == null
        ? ''
        : '; element data in `${_str(entries['dataFile'])}`';
    out
      ..writeln()
      ..writeln(
        '${entries['count']} values in `${_str(entries['generatedFile'])}`'
        '$data; directional: ${_codeList(entries['directional'])}.',
      );
  }
  final keyboard = _list(c['keyboard']).map(_map).toList();
  if (keyboard.isNotEmpty) {
    out
      ..writeln()
      ..writeln('Keyboard:')
      ..writeln();
    for (final k in keyboard) {
      out.writeln('- ${_codeList(k['keys'])}: ${_str(k['action'])}');
    }
  }
  final semantics = _map(c['semantics']);
  final flutter = _list(semantics['properties']).map(_str).join(', ');
  out
    ..writeln()
    ..writeln(
      'Semantics: role ${_str(semantics['role'])}; label '
      '${_str(semantics['label'])}'
      '${flutter.isEmpty ? '' : '; Flutter: $flutter'}.',
    );
  final notes = _list(c['notes']).map(_str).toList();
  if (notes.isNotEmpty) {
    out
      ..writeln()
      ..writeln('Notes:')
      ..writeln();
    for (final n in notes) {
      out.writeln('- $n');
    }
  }
}

void _propRow(StringBuffer out, Map<String, Object?> prop) {
  final ds = prop['ds'] == null ? '—' : '`${_str(prop['ds'])}`';
  final dart = prop['dart'] == null ? '—' : '`${_str(prop['dart'])}`';
  final type =
      '`${_str(prop['type'])}`${prop['required'] == true ? ' (required)' : ''}';
  final values = prop['values'] == null ? '' : _codeList(prop['values']);
  final notes = [
    if (prop['omitReason'] != null) 'Omitted: ${_str(prop['omitReason'])}',
    if (prop['notes'] != null) _str(prop['notes']),
  ].join(' ');
  final defaults = [
    _defaultText(prop['default']),
    if (prop.containsKey('dartDefault'))
      'Dart: `${_dartExpression(prop['dartDefault'])}`',
  ].where((text) => text.isNotEmpty).join('; ');
  out.writeln(
    '| $ds | ${prop['declared'] == true ? 'yes' : ''} | $dart | $type | '
    '$defaults | $values | ${_cell(notes)} |',
  );
}

void _statesTable(
  StringBuffer out,
  List<Map<String, Object?>> states,
  Map<String, Object?> files,
) {
  out
    ..writeln('| State | Trigger | Sources | Notes |')
    ..writeln('|---|---|---|---|');
  for (final s in states) {
    final refs = _list(s['refs'])
        .map(_map)
        .map((r) {
          final path = _str(files[r['file']]);
          return '`${p.posix.basename(path)}:${r['line']}`';
        })
        .join(', ');
    final trigger = s['prop'] == null
        ? _str(s['trigger'])
        : '${_str(s['trigger'])} (`${_str(s['prop'])}`)';
    final notes = [
      if (s['gap'] != null) '${_str(s['gap'])}.',
      if (s['tooltip'] != null) 'Tooltip: "${_str(s['tooltip'])}".',
      if (s['notes'] != null) _str(s['notes']),
    ].join(' ');
    out.writeln(
      '| `${_str(s['name'])}` | $trigger | $refs | ${_cell(notes)} |',
    );
  }
}

String _sourceText(Map<String, Object?> source) {
  final parts = <String>[];
  if (source['bundle'] case final Map<String, Object?> bundle) {
    final lines = _list(bundle['lines']);
    parts.add(
      '`_ds_bundle.js` ${_str(bundle['file'])}, lines ${lines[0]}–${lines[1]}',
    );
  }
  for (final d in _list(source['design']).map(_map)) {
    final lines = _list(d['lines']);
    parts.add('`${_str(d['file'])}` lines ${lines[0]}–${lines[1]}');
  }
  final css = _list(source['css']).map(_str).toList();
  if (css.isNotEmpty) {
    parts.add('CSS only (${css.map((c) => '$c.css').join(', ')})');
  }
  if (source['generated'] != null) {
    parts.add('generated `${_str(source['generated'])}`');
  }
  return parts.join('; ');
}

String _defaultText(Object? value) => switch (value) {
  null => '',
  final String s => '`${jsonEncode(s)}`',
  final List<Object?> l when l.isEmpty => '`[]`',
  final Map<String, Object?> m when m.isEmpty => '`{}`',
  _ => '`${jsonEncode(value)}`',
};

/// A `dartDefault` value: a string is already a Dart expression.
String _dartExpression(Object? value) =>
    value is String ? value : jsonEncode(value);

String _codeList(Object? values) =>
    _list(values).map((v) => '`${v is String ? v : jsonEncode(v)}`').join(', ');

String _cell(String text) => text.replaceAll('|', r'\|').replaceAll('\n', ' ');

/// GitHub's heading anchor for a component heading.
String _anchor(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9_ -]'), '')
    .replaceAll(' ', '-');

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value == null) return const {};
  throw IconsException('Expected a JSON object, got ${jsonEncode(value)}.');
}

List<Object?> _list(Object? value) {
  if (value is List<Object?>) return value;
  if (value == null) return const [];
  throw IconsException('Expected a JSON array, got ${jsonEncode(value)}.');
}

String _str(Object? value) => value == null ? '' : '$value';

final ArgParser _parser = ArgParser()
  ..addOption('root', help: 'Repository root.', valueHelp: 'dir')
  ..addFlag(
    'check',
    negatable: false,
    help: 'Write nothing; exit with $exitStale if $componentsDocPath is stale.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

/// Runs `dart run icons:component_spec` with [arguments] and returns the
/// exit code.
Future<int> runComponentSpecCli(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
  String? workingDirectory,
}) async {
  final ArgResults options;
  try {
    options = _parser.parse(arguments);
  } on FormatException catch (error) {
    err
      ..writeln(error.message)
      ..writeln(_parser.usage);
    return exitUsage;
  }
  if (options.flag('help')) {
    out
      ..writeln(
        'Renders the reference part of $componentsDocPath from '
        '$componentSpecPath.\n\n'
        'Usage: dart run icons:component_spec [--root <dir>] [--check]\n',
      )
      ..writeln(_parser.usage);
    return 0;
  }
  if (options.rest.isNotEmpty) {
    err.writeln('Unexpected arguments: ${options.rest.join(' ')}');
    return exitUsage;
  }
  final cwd = workingDirectory ?? Directory.current.path;
  final rootOption = options.option('root');
  final root = rootOption == null
      ? findRoot(cwd)
      : p.normalize(p.absolute(cwd, rootOption));
  if (root == null) {
    err.writeln('Cannot find the repository root; pass --root.');
    return exitUsage;
  }
  final specFile = File(p.joinAll([root, ...componentSpecPath.split('/')]));
  final docFile = File(p.joinAll([root, ...componentsDocPath.split('/')]));
  try {
    if (!specFile.existsSync() || !docFile.existsSync()) {
      throw IconsException('Missing $componentSpecPath or $componentsDocPath.');
    }
    final current = readText(docFile);
    final rendered = renderComponentsDoc(
      current,
      decodeSpec(readText(specFile)),
    );
    if (rendered == current) {
      out.writeln('$componentsDocPath is up to date.');
      return 0;
    }
    if (options.flag('check')) {
      err.writeln(
        '$componentsDocPath is stale; run '
        '(cd tools/icons && dart run icons:component_spec).',
      );
      return exitStale;
    }
    docFile.writeAsStringSync(rendered);
    out.writeln('Wrote $componentsDocPath.');
    return 0;
  } on IconsException catch (error) {
    err.writeln('component_spec: $error');
    return exitError;
  }
}
