import 'dart:io';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

/// A dependency entry as `cargo metadata` prints it.
Map<String, dynamic> dep(
  String name, {
  String? kind,
  bool optional = false,
  bool defaults = true,
  List<String> features = const [],
}) => {
  'name': name,
  'kind': kind,
  'optional': optional,
  'uses_default_features': defaults,
  'features': features,
};

/// `cargo metadata --no-deps` output for workspace members [crates].
Map<String, dynamic> metadata(Map<String, List<Map<String, dynamic>>> crates) {
  final packages = [
    for (final MapEntry(key: name, value: deps) in crates.entries)
      {'id': 'path+file:///ws/$name#0.1.0', 'name': name, 'dependencies': deps},
  ];
  return {
    'packages': packages,
    'workspace_members': [for (final package in packages) package['id']],
  };
}

/// The documented graph of ARCHITECTURE.md §2.2.
Map<String, List<Map<String, dynamic>>> documentedGraph() => {
  'ferman-core': [dep('thiserror')],
  'ferman-fonts': [dep('thiserror')],
  'ferman-text': [dep('ferman-core'), dep('ferman-fonts')],
  'ferman-render': [dep('ferman-core'), dep('pdfium-render')],
  'ferman-ops': [dep('ferman-core'), dep('ferman-fonts'), dep('ferman-text')],
  'ferman-api': [
    dep('ferman-core'),
    dep('ferman-fonts'),
    dep('ferman-text'),
    dep('ferman-render'),
    dep('ferman-ops'),
    dep('flutter_rust_bridge', optional: true),
  ],
  'ferman-cli': [dep('ferman-api', defaults: false), dep('insta', kind: 'dev')],
};

void main() {
  const check = CrateGraphCheck();
  List<String> violations(Map<String, List<Map<String, dynamic>>> crates) =>
      CrateGraphCheck.violations(metadata(crates));

  test('accepts the documented graph', () {
    expect(violations(documentedGraph()), isEmpty);
  });

  test('flags an edge that is not in the graph', () {
    final graph = documentedGraph()..['ferman-fonts'] = [dep('ferman-core')];
    expect(violations(graph), [
      'ferman-fonts -> ferman-core: not an edge of ARCHITECTURE.md §2.2',
    ]);
  });

  test('flags dev-dependency edges too', () {
    final graph = documentedGraph()
      ..['ferman-core'] = [dep('ferman-text', kind: 'dev')];
    expect(violations(graph), [
      'ferman-core -> ferman-text (dev): not an edge of ARCHITECTURE.md §2.2',
    ]);
  });

  test('flags a crate that is not in the graph', () {
    final graph = documentedGraph()..['ferman-sign'] = [dep('ferman-core')];
    expect(violations(graph).single, startsWith('ferman-sign: not in the'));
  });

  test('keeps flutter_rust_bridge and pdfium-render behind one door', () {
    final graph = documentedGraph()
      ..['ferman-text'] = [dep('ferman-core'), dep('flutter_rust_bridge')]
      ..['ferman-ops'] = [dep('ferman-core'), dep('pdfium-render')];
    const frb = 'flutter_rust_bridge';
    const pdfium = 'pdfium-render';
    expect(violations(graph), [
      'ferman-text -> $frb: only ferman-api may depend on $frb',
      'ferman-ops -> $pdfium: only ferman-render may depend on $pdfium',
    ]);
  });

  test('requires flutter_rust_bridge to be optional in ferman-api', () {
    final graph = documentedGraph();
    graph['ferman-api']!.last = dep('flutter_rust_bridge');
    expect(
      violations(graph).single,
      'ferman-api -> flutter_rust_bridge: must be optional, behind the frb '
      'feature',
    );
  });

  test('requires ferman-cli to use the facade only', () {
    final withDefaults = documentedGraph()
      ..['ferman-cli'] = [dep('ferman-api')];
    final withFrb = documentedGraph()
      ..['ferman-cli'] = [
        dep('ferman-api', defaults: false, features: ['frb']),
      ];
    for (final graph in [withDefaults, withFrb]) {
      expect(violations(graph).single, contains('must use the facade only'));
    }
  });

  test('keeps test crates out of the shipped graph', () {
    final graph = documentedGraph()
      ..['ferman-core'] = [dep('proptest'), dep('insta', kind: 'build')];
    expect(violations(graph), [
      'ferman-core -> proptest: proptest must be a dev-dependency',
      'ferman-core -> insta (build): insta must be a dev-dependency',
    ]);
  });

  test('skips when there is no Cargo.toml', () {
    expect(Fixture().run(check), skips);
  });

  test('reads a real workspace through cargo metadata', () {
    String manifest(String name, [String deps = '']) =>
        '[package]\nname = "$name"\nversion = "0.1.0"\nedition = "2021"\n'
        '\n[dependencies]\n$deps';
    final fixture = Fixture()
      ..write(
        'Cargo.toml',
        '[workspace]\nmembers = ["crates/*"]\nresolver = "2"\n',
      )
      ..write('crates/ferman-core/Cargo.toml', manifest('ferman-core'))
      ..write('crates/ferman-core/src/lib.rs', '')
      ..write(
        'crates/ferman-fonts/Cargo.toml',
        manifest('ferman-fonts', 'ferman-core = { path = "../ferman-core" }\n'),
      )
      ..write('crates/ferman-fonts/src/lib.rs', '');
    expect(
      fixture.run(check),
      failsWith(['ferman-fonts -> ferman-core: not an edge']),
    );
  }, skip: _hasCargo ? false : 'cargo is not installed');
}

final bool _hasCargo = () {
  try {
    return Process.runSync('cargo', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();
