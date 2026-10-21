import 'dart:convert';

import 'package:checks/src/check.dart';

/// Approved by the owner on 2026-10-16 (ROADMAP M1 step 1): the Ferman
/// crates depend on each other only along the edges of ARCHITECTURE.md
/// §2.2, and the crates that keep a third-party library behind one door are
/// the only ones that use it.
///
/// Reads `cargo metadata --format-version 1 --no-deps`, so it needs cargo
/// but no network.
final class CrateGraphCheck implements Check {
  /// Creates the check.
  const new();

  /// The allowed edges between Ferman crates (ARCHITECTURE.md §2.2).
  static const allowedEdges = <String, Set<String>>{
    'ferman-core': {},
    'ferman-fonts': {},
    'ferman-text': {'ferman-core', 'ferman-fonts'},
    'ferman-render': {'ferman-core'},
    'ferman-ops': {'ferman-core', 'ferman-fonts', 'ferman-text'},
    'ferman-api': {
      'ferman-core',
      'ferman-fonts',
      'ferman-text',
      'ferman-render',
      'ferman-ops',
    },
    'ferman-cli': {'ferman-api'},
  };

  /// Third-party crates that only one Ferman crate may depend on.
  static const singleDoor = <String, String>{
    'flutter_rust_bridge': 'ferman-api',
    'pdfium-render': 'ferman-render',
    // The document model: lopdf objects never leave ferman-core (ADR 0004).
    'lopdf': 'ferman-core',
  };

  /// Crates for tests and benchmarks that must stay dev-dependencies.
  static const devOnly = {'criterion', 'insta', 'proptest'};

  @override
  String get name => 'crate_graph';

  @override
  CheckResult run(CheckContext context) {
    if (!context.file('Cargo.toml').existsSync()) {
      return CheckResult.skip('Cargo.toml does not exist yet');
    }
    final result = context.run('cargo', [
      'metadata',
      '--format-version',
      '1',
      '--no-deps',
    ]);
    if (result == null) {
      return const CheckResult.fail(['cargo is not installed']);
    }
    if (result.exitCode != 0) {
      return CheckResult.fail([
        'cargo metadata failed: ${(result.stderr as String).trim()}',
      ]);
    }
    final metadata = jsonDecode(result.stdout as String);
    if (metadata is! Map<String, dynamic>) {
      return const CheckResult.fail(['cargo metadata printed no object']);
    }
    return CheckResult.from(violations(metadata));
  }

  /// The rule violations in the output of `cargo metadata --no-deps`.
  static List<String> violations(Map<String, dynamic> metadata) {
    final members = {...metadata['workspace_members'] as List<dynamic>};
    final packages = (metadata['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((package) => members.contains(package['id']))
        .toList();
    final memberNames = {for (final p in packages) p['name'] as String};
    final problems = <String>[];

    for (final package in packages) {
      final name = package['name'] as String;
      final allowed = allowedEdges[name];
      if (allowed == null) {
        problems.add(
          '$name: not in the crate graph of ARCHITECTURE.md §2.2 '
          '(a new crate needs the graph, an ADR if it changes the layers, '
          'and this check updated)',
        );
        continue;
      }
      final dependencies = (package['dependencies'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final dependency in dependencies) {
        problems.addAll(
          _checkDependency(name, allowed, memberNames, dependency),
        );
      }
    }
    return problems;
  }

  static List<String> _checkDependency(
    String from,
    Set<String> allowed,
    Set<String> members,
    Map<String, dynamic> dependency,
  ) {
    final to = dependency['name'] as String;
    final kind = dependency['kind'] as String? ?? 'normal';
    final edge = '$from -> $to${kind == 'normal' ? '' : ' ($kind)'}';
    final problems = <String>[];

    if (members.contains(to) && !allowed.contains(to)) {
      problems.add('$edge: not an edge of ARCHITECTURE.md §2.2');
    }
    final door = singleDoor[to];
    if (door != null && door != from) {
      problems.add('$edge: only $door may depend on $to');
    }
    if (devOnly.contains(to) && kind != 'dev') {
      problems.add('$edge: $to must be a dev-dependency');
    }
    if (from == 'ferman-cli' && to == 'ferman-api') {
      final features = (dependency['features'] as List<dynamic>).cast<String>();
      if (dependency['uses_default_features'] != false ||
          features.contains('frb')) {
        problems.add(
          '$edge: must use the facade only '
          '(default-features = false, without the frb feature)',
        );
      }
    }
    if (from == 'ferman-api' &&
        to == 'flutter_rust_bridge' &&
        dependency['optional'] != true) {
      problems.add('$edge: must be optional, behind the frb feature');
    }
    return problems;
  }
}
