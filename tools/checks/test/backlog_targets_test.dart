import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  const check = BacklogTargetsCheck();
  const progress = '''
| Topic | State |
|---|---|
| Milestone | **M4, rest of phase 1: in progress** since M3 closed |
''';

  String backlog(List<String> openRows, {String done = ''}) =>
      '''
# Backlog

```markdown
| B001 | Example | a9-2 | Start | M1 | the entry format's example |
```

## Open

| ID | Feature | Artboards | Where it appears disabled | Target milestone | Notes |
|---|---|---|---|---|---|
${openRows.join('\n')}

## Done

| ID | Feature | Shipped in | Notes |
|---|---|---|---|
| B900 | Shipped | M2 | a Done row with an old milestone |
$done
''';

  Fixture fixture(List<String> openRows) => Fixture()
    ..write('docs/PROGRESS.md', progress)
    ..write('docs/BACKLOG.md', backlog(openRows));

  test('skips without the backlog', () {
    expect((Fixture()..write('docs/PROGRESS.md', progress)).run(check), skips);
  });

  test('fails without the current milestone', () {
    final f = Fixture()
      ..write('docs/PROGRESS.md', '| Milestone | in progress |\n')
      ..write('docs/BACKLOG.md', backlog([]));
    expect(f.run(check), failsWith(['has no "| Milestone | **M<n>" row']));
  });

  test('passes on the current milestone, later ones and phases', () {
    final f = fixture([
      '| B010 | A | a1 | x | M4 (Comment), with each | n |',
      '| B011 | B | a1 | x | M5 at the latest | n |',
      '| B012 | C | a1 | x | After M1, with About (M5) at the latest | n |',
      r'| B013 | D \| E | a1 | x | when a reader shows it, or P2 | n |',
      '| B014 | F | a1 | x | P5 ([Q10](QUESTIONS.md#q10)) | n |',
    ]);
    expect(f.run(check), passes);
  });

  test('fails on a row that targets only a condition', () {
    final f = fixture(['| B020 | A | a1 | x | when a board draws it | n |']);
    expect(f.run(check), failsWith(['B020 targets only a condition']));
  });

  test('fails on a row that targets only past milestones', () {
    final f = fixture([
      '| B030 | A | a1 | x | M3, or M2 with [Q22](QUESTIONS.md#q22) | n |',
    ]);
    expect(
      f.run(check),
      failsWith(['B030 targets a past milestone', 'the current one is M4']),
    );
  });

  test('reads the target after an escaped bar in an earlier cell', () {
    final f = fixture([r'| B040 | A \| M5 | a1 | x | M2 | n |']);
    expect(f.run(check), failsWith(['B040 targets a past milestone']));
  });

  test('ignores fenced rows and Done rows', () {
    expect(fixture([]).run(check), passes);
  });
}
