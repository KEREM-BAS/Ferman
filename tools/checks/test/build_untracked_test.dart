import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  const check = BuildUntrackedCheck();

  late Fixture fixture;
  setUp(() {
    fixture = Fixture()
      ..write('README.md', 'readme\n')
      ..commitAll();
  });

  test('passes when build output exists but is not tracked', () {
    fixture.write('build/design-refs/a1-1.png', 'png');
    expect(fixture.run(check), passes);
  });

  test('fails when a file under build/ is tracked', () {
    fixture
      ..write('build/design-refs/a1-1.png', 'png')
      ..git(['add', '-f', 'build/design-refs/a1-1.png']);
    expect(
      fixture.run(check),
      failsWith(['tracked build output: build/design-refs/a1-1.png']),
    );
  });

  test('fails when Flutter output under app/build/ is tracked', () {
    fixture
      ..write('app/build/linux/bundle/ferman', 'elf')
      ..git(['add', '-f', 'app/build']);
    expect(fixture.run(check), failsWith(['app/build/linux/bundle/ferman']));
  });

  test('passes for a source folder named build elsewhere', () {
    fixture
      ..write('crates/ferman-core/src/build/mod.rs', '')
      ..git(['add', 'crates']);
    expect(fixture.run(check), passes);
  });
}
