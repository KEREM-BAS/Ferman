import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

String lockFile(Map<String, String> packages) {
  final buffer = StringBuffer('packages:\n');
  packages.forEach((name, dependency) {
    buffer
      ..writeln('  $name:')
      ..writeln('    dependency: "$dependency"')
      ..writeln('    source: hosted')
      ..writeln('    version: "1.0.0"');
  });
  return (buffer..writeln('sdks:\n  dart: ">=3.13.0 <4.0.0"')).toString();
}

void main() {
  const check = PubDenylistCheck();

  test('skips without app/pubspec.lock', () {
    expect(Fixture().run(check), skips);
  });

  test('passes for a lock file without denied packages', () {
    final fixture = Fixture()
      ..write(
        'app/pubspec.lock',
        lockFile({
          'flutter_riverpod': 'direct main',
          'http_parser': 'transitive',
          'http_multi_server': 'transitive',
          'test': 'direct dev',
        }),
      );
    expect(fixture.run(check), passes);
  });

  test('fails for each denied package', () {
    final fixture = Fixture()
      ..write(
        'app/pubspec.lock',
        lockFile({
          'http': 'transitive',
          'google_fonts': 'direct main',
          'firebase_core': 'direct main',
          'sentry_flutter': 'direct main',
          'unified_analytics': 'transitive',
          'firebase_crashlytics': 'direct main',
        }),
      );
    expect(
      fixture.run(check),
      failsWith([
        'contains http (transitive; denied: http)',
        'contains google_fonts (direct main; denied: google_fonts)',
        'contains firebase_core',
        'contains sentry_flutter',
        'contains unified_analytics',
        'contains firebase_crashlytics',
      ]),
    );
  });

  test('accepts an approved exception only as a transitive dependency', () {
    const exceptions = {'http': 'reason'};
    expect(
      PubDenylistCheck.violations({
        'http': {'dependency': 'transitive'},
      }, exceptions: exceptions),
      isEmpty,
    );
    expect(
      PubDenylistCheck.violations({
        'http': {'dependency': 'direct main'},
      }, exceptions: exceptions),
      ['app/pubspec.lock contains http (direct main; denied: http)'],
    );
  });

  test('deniedPattern', () {
    expect(PubDenylistCheck.deniedPattern('dio'), 'dio');
    expect(PubDenylistCheck.deniedPattern('mixpanel_flutter'), 'mixpanel*');
    expect(PubDenylistCheck.deniedPattern('amplitude_flutter'), 'amplitude*');
    expect(PubDenylistCheck.deniedPattern('firebase_analytics'), 'firebase*');
    expect(PubDenylistCheck.deniedPattern('dio_cache'), isNull);
    expect(PubDenylistCheck.deniedPattern('path_provider'), isNull);
  });
}
