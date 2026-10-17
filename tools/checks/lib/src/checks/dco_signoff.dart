import 'package:checks/src/check.dart';
import 'package:checks/src/text.dart';

/// Every commit after the base carries a Developer Certificate of Origin
/// sign-off by its author: a `Signed-off-by: Name <email>` trailer equal to
/// the commit's author (QUESTIONS.md Q14, CONTRIBUTING.md, ADR 0017).
///
/// Merge commits are left out: the commits they bring in are checked
/// themselves. CI passes the pull request's base, so every commit of a pull
/// request is checked; on a push to main the base is HEAD itself and there
/// is nothing to check, as for `design_untouched`.
final class DcoSignoffCheck implements Check {
  /// Creates the check.
  const new();

  @override
  String get name => 'dco_signoff';

  // Field and record separators that cannot occur in a name, an email or a
  // subject line.
  static const _field = '\x1f';
  static const _record = '\x1e';
  static const _value = '\x1d';

  // Short hash, author, subject and the values of the Signed-off-by
  // trailers.
  static const _format =
      '%h$_field%an <%ae>$_field%s$_field'
      '%(trailers:key=Signed-off-by,valueonly,separator=$_value)$_record';

  @override
  CheckResult run(CheckContext context) {
    final base = context.base;
    final verify = context.run('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      '$base^{commit}',
    ]);
    if (verify == null) return const CheckResult.fail(['git is not installed']);
    if (verify.exitCode != 0) {
      const hint = 'fetch it (git fetch origin main), or pass --base';
      return CheckResult.fail(['base ref "$base" not found: $hint']);
    }

    final log = context.run('git', [
      '-c',
      'core.quotepath=off',
      '-c',
      'log.showSignature=false',
      'log',
      '--no-merges',
      '--format=$_format',
      '$base..HEAD',
    ]);
    if (log == null || log.exitCode != 0) {
      return CheckResult.fail(['git could not list the commits after $base']);
    }
    final problems = <String>[];
    for (final record in (log.stdout as String).split(_record)) {
      final fields = record.trim().split(_field);
      if (fields.length < 4) continue;
      final [sha, author, subject, trailers, ...] = fields;
      final signoffs = trailers.split(_value).map((value) => value.trim());
      if (!signoffs.contains(author)) {
        problems.add(
          '$sha "$subject": no "Signed-off-by: $author" '
          '(commit with git commit -s; add it to a branch with '
          'git rebase --signoff $base)',
        );
      }
    }
    return CheckResult.from(capped(problems));
  }
}
