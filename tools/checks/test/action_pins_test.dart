import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  const check = ActionPinsCheck();
  const sha = '3d3c42e5aac5ba805825da76410c181273ba90b1';

  test('skips when there are no workflows', () {
    expect(Fixture().run(check), skips);
  });

  test('passes for SHA pins, local actions and docker digests', () {
    final fixture = Fixture()
      ..write('.github/workflows/ci.yml', '''
jobs:
  build:
    steps:
      - uses: actions/checkout@$sha # v7.0.1
      - name: Flutter
        uses: "subosito/flutter-action@$sha"
      - uses: ./.github/actions/setup
      - uses: docker://alpine@sha256:${'a' * 64}
  reuse:
    uses: org/repo/.github/workflows/build.yml@$sha
''');
    expect(fixture.run(check), passes);
  });

  test('fails for tags, branches and short SHAs', () {
    final fixture = Fixture()
      ..write('.github/workflows/ci.yaml', '''
steps:
  - uses: actions/checkout@v4
  - uses: dtolnay/rust-toolchain@stable
  - uses: actions/cache@${sha.substring(0, 7)}
  - uses: docker://alpine:3.20
''');
    expect(
      fixture.run(check),
      failsWith([
        '.github/workflows/ci.yaml:2: actions/checkout@v4 is not pinned',
        'ci.yaml:3: dtolnay/rust-toolchain@stable',
        'ci.yaml:4: actions/cache@3d3c42e',
        'ci.yaml:5: docker://alpine:3.20',
      ]),
    );
  });

  test('checks composite actions under .github/actions/', () {
    final fixture = Fixture()
      ..write('.github/workflows/ci.yml', 'jobs: {}\n')
      ..write(
        '.github/actions/setup/action.yml',
        'runs:\n  steps:\n    - uses: actions/setup-node@v6\n',
      );
    expect(
      fixture.run(check),
      failsWith(['.github/actions/setup/action.yml:3']),
    );
  });

  test('isPinned', () {
    expect(ActionPinsCheck.isPinned('actions/checkout@$sha'), isTrue);
    expect(ActionPinsCheck.isPinned('./local'), isTrue);
    expect(ActionPinsCheck.isPinned('actions/checkout@v7.0.1'), isFalse);
    expect(ActionPinsCheck.isPinned('actions/checkout'), isFalse);
    expect(ActionPinsCheck.isPinned('a/b@${sha.toUpperCase()}'), isFalse);
  });
}
