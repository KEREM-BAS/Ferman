import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  const check = UnsafeRootsCheck();
  const forbid = '//! A crate.\n#![forbid(unsafe_code)]\n\npub fn f() {}\n';
  const apiRoot = '//! The API.\n#![deny(unsafe_code)]\n\npub mod facade;\n';

  late Fixture fixture;
  setUp(() {
    fixture = Fixture()
      ..write('crates/ferman-core/src/lib.rs', forbid)
      ..write('crates/ferman-api/src/lib.rs', apiRoot)
      ..write('crates/ferman-api/src/facade.rs', 'pub fn g() {}\n')
      ..write('crates/ferman-cli/src/main.rs', forbid);
  });

  test('skips when crates/ does not exist', () {
    expect(Fixture().run(check), skips);
  });

  test('passes for forbidding roots and a denying ferman-api', () {
    expect(fixture.run(check), passes);
  });

  test('accepts forbid with other lints in the same attribute', () {
    fixture.write(
      'crates/ferman-core/src/lib.rs',
      '#![forbid(\n    unsafe_code,\n    missing_docs\n)]\n',
    );
    expect(fixture.run(check), passes);
  });

  test('fails when a root does not forbid unsafe code', () {
    fixture.write('crates/ferman-core/src/lib.rs', 'pub fn f() {}\n');
    expect(
      fixture.run(check),
      failsWith([
        'crates/ferman-core/src/lib.rs: missing #![forbid(unsafe_code)]',
      ]),
    );
  });

  test('does not count an attribute inside a comment', () {
    fixture.write(
      'crates/ferman-core/src/lib.rs',
      '// #![forbid(unsafe_code)]\npub fn f() {}\n',
    );
    expect(fixture.run(check), failsWith(['missing #![forbid(unsafe_code)]']));
  });

  test('checks binary roots in src/bin/', () {
    fixture.write('crates/ferman-cli/src/bin/extra.rs', 'fn main() {}\n');
    expect(
      fixture.run(check),
      failsWith(['crates/ferman-cli/src/bin/extra.rs: missing']),
    );
  });

  test('fails for a crate without a root', () {
    fixture.write('crates/ferman-ops/Cargo.toml', '[package]\n');
    expect(fixture.run(check), failsWith(['crates/ferman-ops: no crate root']));
  });

  test('fails when ferman-api forbids instead of denying', () {
    fixture.write('crates/ferman-api/src/lib.rs', forbid);
    expect(
      fixture.run(check),
      failsWith([
        'missing #![deny(unsafe_code)]',
        'must deny, not forbid, unsafe code',
      ]),
    );
  });

  test('fails on allow(unsafe_code) in any other place', () {
    fixture.write(
      'crates/ferman-core/src/lexer.rs',
      'fn a() {}\n\n#[allow(unsafe_code)]\nfn b() {}\n',
    );
    expect(
      fixture.run(check),
      failsWith(['crates/ferman-core/src/lexer.rs:3: allow(unsafe_code)']),
    );
  });

  test('fails on expect, warn and cfg_attr forms too', () {
    fixture.write(
      'crates/ferman-api/src/facade.rs',
      '#[expect(unsafe_code)]\nfn a() {}\n'
          '#[cfg_attr(test, warn(dead_code, unsafe_code))]\nfn b() {}\n',
    );
    expect(
      fixture.run(check),
      failsWith(['facade.rs:1: expect(unsafe_code)', 'facade.rs:3: warn']),
    );
  });

  test('ignores Cargo output under target/', () {
    fixture.write(
      'crates/ferman-core/target/debug/build/out.rs',
      '#[allow(unsafe_code)]\nfn generated() {}\n',
    );
    expect(fixture.run(check), passes);
  });

  test('fails on a crate-wide allow in ferman-api', () {
    fixture.write(
      'crates/ferman-api/src/lib.rs',
      '#![deny(unsafe_code)]\n#![allow(unsafe_code)]\n',
    );
    expect(fixture.run(check), failsWith(['lib.rs:2: allow(unsafe_code)']));
  });

  group('the FRB-generated module', () {
    test('may be allowed on one line', () {
      fixture.write(
        'crates/ferman-api/src/lib.rs',
        '$apiRoot#[cfg(feature = "frb")] #[allow(unsafe_code, missing_docs, '
            'clippy::all)] mod frb_generated;\n',
      );
      expect(fixture.run(check), passes);
    });

    test('may be allowed in the form rustfmt writes', () {
      fixture.write(
        'crates/ferman-api/src/lib.rs',
        '$apiRoot#[cfg(feature = "frb")]\n#[allow(\n    unsafe_code,\n'
            '    missing_docs,\n    clippy::all,\n    clippy::unwrap_used\n)]\n'
            'mod frb_generated;\n',
      );
      expect(fixture.run(check), passes);
    });

    test('must be behind the frb feature', () {
      fixture.write(
        'crates/ferman-api/src/lib.rs',
        '$apiRoot#[allow(unsafe_code)]\nmod frb_generated;\n',
      );
      expect(
        fixture.run(check),
        failsWith(['mod frb_generated must be behind #[cfg(feature = "frb")]']),
      );
    });

    test('is only accepted in the ferman-api root', () {
      fixture.write(
        'crates/ferman-core/src/lib.rs',
        '$forbid#[cfg(feature = "frb")]\n#[allow(unsafe_code)]\n'
            'mod frb_generated;\n',
      );
      expect(
        fixture.run(check),
        failsWith(['ferman-core/src/lib.rs:6: allow(unsafe_code)']),
      );
    });

    test('in a comment is ignored', () {
      fixture.write(
        'crates/ferman-api/src/lib.rs',
        '$apiRoot// #[cfg(feature = "frb")] #[allow(unsafe_code)] '
            'mod frb_generated;\n',
      );
      expect(fixture.run(check), passes);
    });
  });
}
