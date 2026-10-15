import 'package:checks/src/check.dart';
import 'package:checks/src/text.dart';
import 'package:yaml/yaml.dart';

/// The Cargo workspace version equals the app version in
/// `app/pubspec.yaml`, without its `+build` number.
final class VersionSyncCheck implements Check {
  /// Creates the check.
  const new();

  @override
  String get name => 'version_sync';

  @override
  CheckResult run(CheckContext context) {
    final cargo = context.file('Cargo.toml');
    final pubspec = context.file('app/pubspec.yaml');
    if (!cargo.existsSync()) {
      return CheckResult.skip('Cargo.toml does not exist yet');
    }
    if (!pubspec.existsSync()) {
      return CheckResult.skip('app/pubspec.yaml does not exist yet');
    }

    final workspaceVersion = tomlString(
      cargo.readAsStringSync(),
      table: 'workspace.package',
      key: 'version',
    );
    if (workspaceVersion == null) {
      return const CheckResult.fail([
        'Cargo.toml has no version in [workspace.package]',
      ]);
    }
    final yaml = loadYaml(pubspec.readAsStringSync());
    final appVersion = yaml is YamlMap ? yaml['version'] : null;
    if (appVersion is! String) {
      return const CheckResult.fail(['app/pubspec.yaml has no version']);
    }
    final withoutBuild = appVersion.split('+').first;
    if (withoutBuild == workspaceVersion) return const CheckResult.pass();
    final message =
        'Cargo.toml workspace version $workspaceVersion differs from '
        'app/pubspec.yaml version $withoutBuild (from $appVersion)';
    return CheckResult.fail([message]);
  }
}
