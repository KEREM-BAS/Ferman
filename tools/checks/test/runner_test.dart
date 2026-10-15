import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  late Fixture fixture;
  setUp(() {
    fixture = Fixture()
      ..write('design/board.html', 'board\n')
      ..commitAll();
  });

  ({int exitCode, String output}) run(
    List<String> arguments, {
    Map<String, String> environment = const {},
  }) {
    final out = StringBuffer();
    final exitCode = runChecks(
      ['--root', fixture.dir.path, ...arguments],
      out: out,
      environment: environment,
    );
    return (exitCode: exitCode, output: out.toString());
  }

  test('reports every check and passes when nothing fails', () {
    final result = run(['--base', 'base']);
    expect(result.exitCode, exitOk);
    expect(result.output, contains('PASS  design_untouched\n'));
    expect(result.output, contains('PASS  build_untracked\n'));
    expect(
      result.output,
      contains('SKIP  unsafe_roots: crates/ does not exist yet\n'),
    );
    expect(
      result.output,
      endsWith('15 checks: 2 passed, 0 failed, 13 skipped\n'),
    );
  });

  test('fails with the problems listed under the check', () {
    fixture.write('design/board.html', 'edited\n');
    final result = run(['--base', 'base']);
    expect(result.exitCode, exitFailed);
    expect(
      result.output,
      contains(
        'FAIL  design_untouched\n'
        '      changed since base: design/board.html\n',
      ),
    );
  });

  test('takes the base from CHECKS_BASE', () {
    final result = run(
      ['--only', 'design_untouched'],
      environment: {'CHECKS_BASE': 'missing-ref'},
    );
    expect(result.exitCode, exitFailed);
    expect(result.output, contains('base ref "missing-ref" not found'));
  });

  test('treats an empty CHECKS_BASE as unset', () {
    final result = run(
      ['--only', 'design_untouched'],
      environment: {'CHECKS_BASE': ''},
    );
    expect(result.output, contains('base ref "origin/main" not found'));
  });

  test('runs only the selected checks', () {
    final result = run(['--only', 'build_untracked,arb_parity']);
    expect(
      result.output,
      'PASS  build_untracked\n'
      'SKIP  arb_parity: app/lib/l10n/app_en.arb does not exist yet\n'
      '2 checks: 1 passed, 0 failed, 1 skipped\n',
    );
  });

  test('rejects unknown options and check names', () {
    expect(run(['--only', 'nope']).exitCode, exitUsage);
    expect(run(['--frobnicate']).exitCode, exitUsage);
  });

  test('rejects a root that does not exist', () {
    final out = StringBuffer();
    final missing = '${fixture.dir.path}/missing';
    final exitCode = runChecks(['--root', missing], out: out);
    expect(exitCode, exitUsage);
    expect(out.toString(), '--root: directory not found: $missing\n');
  });

  test('prints help', () {
    final result = run(['--help']);
    expect(result.exitCode, exitOk);
    expect(result.output, contains('--root'));
  });
}
