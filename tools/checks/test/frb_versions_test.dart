import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

String cargoLock(List<String> frbVersions) {
  final buffer = StringBuffer('version = 4\n\n')
    ..writeln('[[package]]\nname = "anyhow"\nversion = "1.0.104"\n');
  for (final version in frbVersions) {
    buffer
      ..writeln('[[package]]')
      ..writeln('name = "flutter_rust_bridge"')
      ..writeln('version = "$version"')
      ..writeln('dependencies = [\n "anyhow",\n]\n');
  }
  return buffer.toString();
}

String pubLock(String? frbVersion) => [
  'packages:',
  '  args:',
  '    version: "2.7.0"',
  if (frbVersion != null) ...[
    '  flutter_rust_bridge:',
    '    dependency: "direct main"',
    '    version: "$frbVersion"',
  ],
].join('\n');

void main() {
  const check = FrbVersionsCheck();

  Fixture withLocks({List<String>? rust, String? dart}) {
    final fixture = Fixture();
    if (rust != null) fixture.write('Cargo.lock', cargoLock(rust));
    if (dart != null) fixture.write('app/pubspec.lock', pubLock(dart));
    return fixture;
  }

  test('skips when a lock file or the package is missing', () {
    expect(withLocks(dart: '2.13.0').run(check), skips);
    expect(withLocks(rust: ['2.13.0']).run(check), skips);
    expect(withLocks(rust: [], dart: '2.13.0').run(check), skips);
    final noDartEntry = Fixture()
      ..write('Cargo.lock', cargoLock(['2.13.0']))
      ..write('app/pubspec.lock', pubLock(null));
    expect(noDartEntry.run(check), skips);
  });

  test('passes when both are 2.13.0', () {
    expect(withLocks(rust: ['2.13.0'], dart: '2.13.0').run(check), passes);
  });

  test('fails when either differs', () {
    expect(
      withLocks(rust: ['2.12.0'], dart: '2.14.0-beta.2').run(check),
      failsWith([
        'Cargo.lock has flutter_rust_bridge 2.12.0, expected 2.13.0',
        'app/pubspec.lock has flutter_rust_bridge 2.14.0-beta.2',
      ]),
    );
  });

  test('checks every version in Cargo.lock', () {
    expect(
      withLocks(rust: ['2.13.0', '2.11.1'], dart: '2.13.0').run(check),
      failsWith(['flutter_rust_bridge 2.11.1']),
    );
  });
}
