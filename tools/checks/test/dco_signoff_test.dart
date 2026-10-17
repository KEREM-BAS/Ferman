import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  const check = DcoSignoffCheck();
  // The fixture's throwaway identity, as a sign-off names it.
  const author = 'checks <checks>';

  late Fixture fixture;
  setUp(() {
    fixture = Fixture()
      ..write('README.md', 'readme\n')
      ..commitAll();
  });

  void commit(String message, {String file = 'a.txt'}) {
    fixture
      ..write(file, message)
      ..commitAll(message: message, tag: null);
  }

  test('passes with no commits after the base', () {
    expect(fixture.run(check), passes);
    // A push to main compares HEAD with itself.
    commit('unsigned');
    expect(fixture.run(check, base: 'HEAD'), passes);
  });

  test('passes when every commit is signed off by its author', () {
    commit('feat: one\n\nSigned-off-by: $author');
    commit(
      'fix: two\n\nBody.\n\n'
      'Signed-off-by: someone <else>\nSigned-off-by: $author',
    );
    expect(fixture.run(check), passes);
  });

  test('fails on a commit without a sign-off, naming it', () {
    commit('feat: one\n\nSigned-off-by: $author');
    commit('fix: two');
    expect(
      fixture.run(check),
      failsWith(['"fix: two": no "Signed-off-by: $author"', 'git commit -s']),
    );
  });

  test("fails when the sign-off is not the author's", () {
    commit('docs: three\n\nSigned-off-by: someone <else>');
    expect(fixture.run(check), failsWith(['"docs: three"']));
  });

  test('a sign-off in the body, not in the trailers, does not count', () {
    commit('docs: four\n\nSigned-off-by: $author\n\nMore text after it.');
    expect(fixture.run(check), failsWith(['"docs: four"']));
  });

  test('leaves merge commits out', () {
    fixture.git(['checkout', '-q', '-b', 'side']);
    commit('feat: side\n\nSigned-off-by: $author', file: 'side.txt');
    fixture.git(['checkout', '-q', '-']);
    commit('feat: main\n\nSigned-off-by: $author', file: 'main.txt');
    fixture.git(['merge', '-q', '--no-ff', '--no-edit', 'side']);
    expect(fixture.run(check), passes);
  });

  test('fails when the base ref does not exist', () {
    expect(
      fixture.run(check, base: 'origin/nowhere'),
      failsWith(['base ref "origin/nowhere" not found']),
    );
  });
}
