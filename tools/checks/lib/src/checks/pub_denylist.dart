import 'package:checks/src/check.dart';
import 'package:yaml/yaml.dart';

/// **Proposed** (ROADMAP M1 step 2): `app/pubspec.lock` holds no HTTP
/// client, font downloader, analytics or crash-reporting package, because
/// the app uses the network only for the four uses the brief allows, through
/// one gateway (ADR 0015).
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
  /// the reason the owner accepted it. A direct dependency on one of them
  /// still fails. Empty until an exception is approved.
  static const transitiveExceptions = <String, String>{};

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
    return CheckResult.from(violations(packages));
  }

  /// The denied entries in the `packages` map of a `pubspec.lock`.
  static List<String> violations(
    Map<dynamic, dynamic> packages, {
    Map<String, String> exceptions = transitiveExceptions,
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
