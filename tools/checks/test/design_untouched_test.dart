import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  const check = DesignUntouchedCheck();

  late Fixture fixture;
  setUp(() {
    fixture = Fixture()
      ..write('design/board.html', '<p>board</p>\n')
      ..write('design/_ds/tokens.css', ':root {}\n')
      ..write('README.md', 'readme\n')
      ..commitAll();
  });

  test('passes when design/ matches the base', () {
    expect(fixture.run(check), passes);
  });

  test('ignores changes outside design/', () {
    fixture.write('README.md', 'changed\n');
    expect(fixture.run(check), passes);
  });

  test('fails when a tracked file changed', () {
    fixture.write('design/board.html', '<p>edited</p>\n');
    expect(
      fixture.run(check),
      failsWith(['changed since base: design/board.html']),
    );
  });

  test('fails when a change was committed after the base', () {
    fixture
      ..write('design/_ds/tokens.css', ':root { --x: 1; }\n')
      ..commitAll(message: 'edit', tag: null);
    expect(fixture.run(check), failsWith(['design/_ds/tokens.css']));
  });

  test('fails when a file was deleted', () {
    fixture.delete('design/board.html');
    expect(fixture.run(check), failsWith(['design/board.html']));
  });

  test('fails on an untracked file', () {
    fixture.write('design/new.html', 'new\n');
    expect(fixture.run(check), failsWith(['untracked: design/new.html']));
  });

  test('labels each listed file and summarises the rest unlabelled', () {
    for (var i = 0; i < 22; i++) {
      fixture.write('design/new_${i.toString().padLeft(2, '0')}.html', '');
    }
    final messages = fixture.run(check).messages;
    expect(messages, hasLength(21));
    expect(messages.first, 'untracked: design/new_00.html');
    expect(messages.take(20), everyElement(startsWith('untracked: ')));
    expect(messages.last, '... and 2 more');
  });

  test('fails when the base ref does not exist', () {
    expect(
      fixture.run(check, base: 'origin/nowhere'),
      failsWith(['base ref "origin/nowhere" not found']),
    );
  });
}
