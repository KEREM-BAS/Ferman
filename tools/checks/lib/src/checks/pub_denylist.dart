import 'dart:convert';
import 'dart:io';

import 'package:checks/src/check.dart';
import 'package:yaml/yaml.dart';

/// A denied package the owner accepted as a transitive dependency: the
/// packages allowed to bring it, and why.
typedef DenylistException = ({Set<String> from, String reason});

/// Approved by the owner on 2026-10-16 (ROADMAP M1 step 2):
/// `app/pubspec.lock` holds no HTTP client, font downloader, analytics or
/// crash-reporting package, because the app uses the network only for the
/// uses ADR 0015 lists, through one gateway.
final class PubDenylistCheck implements Check {
  /// Creates the check.
  const new();

  /// Package name patterns that must not appear; `*` matches any text.
  static const denied = [
    'http',
    'dio',
    'google_fonts',
    'firebase*',
    'sentry*',
    '*analytics*',
    '*crashlytics*',
    'amplitude*',
    'mixpanel*',
  ];

  /// Denied packages accepted as transitive dependencies only, each with
  /// the packages allowed to bring it and the reason the owner accepted it.
  /// A direct dependency on one of them still fails, and so do an import of
  /// one anywhere in `app/lib/` and, once `flutter pub get` has resolved the
  /// app (`app/.dart_tool/package_config.json`), any other package that
  /// depends on it.
  static const transitiveExceptions = <String, DenylistException>{
    'http': (
      from: {'file_selector_platform_interface'},
      reason:
          'file_selector_platform_interface (ADR 0018) declares it and never '
          'imports it; approved by the owner on 2026-10-30',
    ),
  };

  @override
  String get name => 'pub_denylist';

  @override
  CheckResult run(CheckContext context) {
    final lock = context.file('app/pubspec.lock');
    if (!lock.existsSync()) {
      return CheckResult.skip('app/pubspec.lock does not exist yet');
    }
    final yaml = loadYaml(lock.readAsStringSync());
    final packages = yaml is YamlMap ? yaml['packages'] : null;
    if (packages is! YamlMap) {
      return const CheckResult.fail(['app/pubspec.lock has no packages']);
    }
    return CheckResult.from([
      ...violations(packages),
      ...imports(context),
      ...dependents(context),
    ]);
  }

  /// The files of `app/lib/` that name an excepted package's library in a
  /// URI: an import, export or part, a conditional import's alternatives
  /// included.
  static List<String> imports(
    CheckContext context, {
    Map<String, DenylistException> exceptions = transitiveExceptions,
  }) {
    final lib = context.dir('app/lib');
    if (exceptions.isEmpty || !lib.existsSync()) return const [];
    final uses = RegExp(
      '[\'"]package:(${exceptions.keys.map(RegExp.escape).join('|')})/',
    );
    final files =
        lib
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return [
      for (final file in files)
        for (final use in uses.allMatches(file.readAsStringSync()))
          '${context.relative(file.path)} imports ${use.group(1)}',
    ];
  }

  /// The resolved packages, from `app/.dart_tool/package_config.json`,
  /// that depend on an excepted package without being allowed to; none
  /// before `flutter pub get`.
  static List<String> dependents(
    CheckContext context, {
    Map<String, DenylistException> exceptions = transitiveExceptions,
  }) {
    final config = context.file('app/.dart_tool/package_config.json');
    if (exceptions.isEmpty || !config.existsSync()) return const [];
    final json = jsonDecode(config.readAsStringSync());
    final packages = json is Map ? json['packages'] : null;
    if (packages is! List) {
      return const ['app/.dart_tool/package_config.json has no packages'];
    }
    final problems = <String>[];
    for (final package in packages.whereType<Map<dynamic, dynamic>>()) {
      final name = package['name'];
      final root = package['rootUri'];
      if (name is! String || root is! String) continue;
      final pubspec = File.fromUri(
        config.uri
            .resolve(root.endsWith('/') ? root : '$root/')
            .resolve('pubspec.yaml'),
      );
      if (!pubspec.existsSync()) continue;
      final yaml = loadYaml(pubspec.readAsStringSync());
      final needs = yaml is YamlMap ? yaml['dependencies'] : null;
      if (needs is! YamlMap) continue;
      for (final excepted in exceptions.keys) {
        if (needs.containsKey(excepted) &&
            !exceptions[excepted]!.from.contains(name)) {
          problems.add(
            '$name depends on $excepted, which only '
            '${exceptions[excepted]!.from.join(', ')} may bring',
          );
        }
      }
    }
    return problems..sort();
  }

  /// The denied entries in the `packages` map of a `pubspec.lock`.
  static List<String> violations(
    Map<dynamic, dynamic> packages, {
    Map<String, DenylistException> exceptions = transitiveExceptions,
  }) {
    final names = packages.keys.cast<String>().toList()..sort();
    final problems = <String>[];
    for (final name in names) {
      final pattern = deniedPattern(name);
      if (pattern == null) continue;
      final entry = packages[name];
      final kind = entry is Map ? entry['dependency'] as String? : null;
      if (kind == 'transitive' && exceptions.containsKey(name)) continue;
      problems.add(
        'app/pubspec.lock contains $name '
        '(${kind ?? 'unknown dependency type'}; denied: $pattern)',
      );
    }
    return problems;
  }

  /// The pattern in [denied] that [package] matches, or `null`.
  static String? deniedPattern(String package) {
    for (final pattern in denied) {
      final regex = RegExp(
        '^${pattern.split('*').map(RegExp.escape).join('.*')}\$',
      );
      if (regex.hasMatch(package)) return pattern;
    }
    return null;
  }
}
