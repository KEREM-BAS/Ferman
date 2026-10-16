import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  const check = VersionSyncCheck();
  const cargo = '''
[workspace]
members = ["crates/*"]

[workspace.package]
version = "0.1.0" # the app version
edition = "2024"
''';

  test('skips without Cargo.toml', () {
    final fixture = Fixture()..write('app/pubspec.yaml', 'version: 0.1.0\n');
    expect(fixture.run(check), skips);
  });

  test('skips without app/pubspec.yaml', () {
    final fixture = Fixture()..write('Cargo.toml', cargo);
    expect(fixture.run(check), skips);
  });

  test('passes when the versions match, ignoring the build number', () {
    final fixture = Fixture()
      ..write('Cargo.toml', cargo)
      ..write('app/pubspec.yaml', 'name: ferman\nversion: 0.1.0+7\n');
    expect(fixture.run(check), passes);
  });

  test('fails when the versions differ', () {
    final fixture = Fixture()
      ..write('Cargo.toml', cargo)
      ..write('app/pubspec.yaml', 'name: ferman\nversion: 0.2.0+1\n');
    expect(
      fixture.run(check),
      failsWith(['0.1.0 differs from app/pubspec.yaml version 0.2.0']),
    );
  });

  test('reads only [workspace.package]', () {
    final fixture = Fixture()
      ..write(
        'Cargo.toml',
        '[package]\nversion = "9.9.9"\n\n[[bin]]\nname = "x"\n'
            'version = "8.8.8"\n',
      )
      ..write('app/pubspec.yaml', 'version: 9.9.9\n');
    expect(
      fixture.run(check),
      failsWith(['Cargo.toml has no version in [workspace.package]']),
    );
  });

  test('fails when the pubspec has no version', () {
    final fixture = Fixture()
      ..write('Cargo.toml', cargo)
      ..write('app/pubspec.yaml', 'name: ferman\n');
    expect(fixture.run(check), failsWith(['has no version']));
  });
}
