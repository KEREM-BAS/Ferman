import 'package:checks/src/text.dart';
import 'package:test/test.dart';

void main() {
  test('stripLineComments removes line and doc comments only', () {
    expect(
      stripLineComments('//! doc\nlet a = 1; // note\n/// item\nlet b;\n'),
      '\nlet a = 1; \n\nlet b;\n',
    );
  });

  group('tomlString', () {
    const toml = '''
[package]
version = "1.0.0"

[workspace.package]
edition = "2024"
version = "0.1.0"   # comment

[[bin]]
version = "2.0.0"
''';

    test('reads a key from the named table', () {
      expect(
        tomlString(toml, table: 'workspace.package', key: 'version'),
        '0.1.0',
      );
      expect(tomlString(toml, table: 'package', key: 'version'), '1.0.0');
    });

    test('treats array tables as tables of their own', () {
      expect(tomlString(toml, table: 'bin', key: 'version'), '2.0.0');
    });

    test('returns null for a missing table or key', () {
      expect(tomlString(toml, table: 'workspace', key: 'version'), isNull);
      expect(tomlString(toml, table: 'package', key: 'name'), isNull);
    });
  });

  test('cargoLockVersions finds every version of a crate', () {
    const lock = '''
version = 4

[[package]]
name = "syn"
version = "2.0.119"

[[package]]
name = "serde"
version = "1.0.229"
dependencies = [
 "syn 3.0.9",
]

[[package]]
name = "syn"
version = "3.0.9"

[metadata]
name = "syn"
version = "9.9.9"
''';
    expect(cargoLockVersions(lock, 'syn'), ['2.0.119', '3.0.9']);
    expect(cargoLockVersions(lock, 'quote'), isEmpty);
  });

  test('capped keeps short lists and summarises long ones', () {
    expect(capped(['a', 'b']), ['a', 'b']);
    expect(capped(['a', 'b', 'c'], limit: 2), ['a', 'b', '... and 1 more']);
  });
}
