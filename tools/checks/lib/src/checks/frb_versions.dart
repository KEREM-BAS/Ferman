import 'package:checks/src/check.dart';
import 'package:checks/src/text.dart';
import 'package:yaml/yaml.dart';

/// The flutter_rust_bridge crate in `Cargo.lock` and the Dart package in
/// `app/pubspec.lock` are both exactly [expected]. The codegen version is
/// compared in CI, where the tool is installed.
final class FrbVersionsCheck implements Check {
  /// Creates the check.
  const new();

  /// The pinned flutter_rust_bridge version (ADR 0002).
  static const expected = '2.13.0';

  static const _package = 'flutter_rust_bridge';

  @override
  String get name => 'frb_versions';

  @override
  CheckResult run(CheckContext context) {
    final cargoLock = context.file('Cargo.lock');
    final pubLock = context.file('app/pubspec.lock');
    if (!cargoLock.existsSync()) {
      return CheckResult.skip('Cargo.lock does not exist yet');
    }
    if (!pubLock.existsSync()) {
      return CheckResult.skip('app/pubspec.lock does not exist yet');
    }

    final rustVersions = cargoLockVersions(
      cargoLock.readAsStringSync(),
      _package,
    );
    if (rustVersions.isEmpty) {
      return CheckResult.skip('Cargo.lock has no $_package yet');
    }
    final yaml = loadYaml(pubLock.readAsStringSync());
    final packages = yaml is YamlMap ? yaml['packages'] : null;
    final entry = packages is YamlMap ? packages[_package] : null;
    final dartVersion = entry is YamlMap ? entry['version'] : null;
    if (dartVersion is! String) {
      return CheckResult.skip('app/pubspec.lock has no $_package yet');
    }

    return CheckResult.from([
      for (final version in rustVersions)
        if (version != expected)
          'Cargo.lock has $_package $version, expected $expected',
      if (dartVersion != expected)
        'app/pubspec.lock has $_package $dartVersion, expected $expected',
    ]);
  }
}
