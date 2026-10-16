import 'package:checks/src/check.dart';
import 'package:checks/src/text.dart';

/// `design/` is read-only: nothing in it differs from the base ref, and no
/// untracked file has been added to it (CLAUDE.md, ROADMAP step 6).
final class DesignUntouchedCheck implements Check {
  /// Creates the check.
  const new();

  @override
  String get name => 'design_untouched';

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

    final changed = _gitLines(context, [
      'diff',
      '--name-only',
      base,
      '--',
      'design/',
    ]);
    final untracked = _gitLines(context, [
      'ls-files',
      '--others',
      '--exclude-standard',
      '--',
      'design/',
    ]);
    if (changed == null || untracked == null) {
      return const CheckResult.fail(['git could not list design/']);
    }
    return CheckResult.from([
      ...capped([for (final path in changed) 'changed since $base: $path']),
      ...capped([for (final path in untracked) 'untracked: $path']),
    ]);
  }

  static List<String>? _gitLines(CheckContext context, List<String> args) {
    final result = context.run('git', ['-c', 'core.quotepath=off', ...args]);
    if (result == null || result.exitCode != 0) return null;
    return (result.stdout as String)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}
