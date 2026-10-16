import 'package:checks/src/check.dart';
import 'package:checks/src/text.dart';

/// Nothing under `build/` (design references, downloads, packaging) or the
/// Flutter output `app/build/` is tracked by git (CLAUDE.md).
final class BuildUntrackedCheck implements Check {
  /// Creates the check.
  const new();

  /// The output directories that must never be committed.
  static const outputDirs = ['build/', 'app/build/'];

  @override
  String get name => 'build_untracked';

  @override
  CheckResult run(CheckContext context) {
    final result = context.run('git', [
      '-c',
      'core.quotepath=off',
      'ls-files',
      '--',
      ...outputDirs,
    ]);
    if (result == null) return const CheckResult.fail(['git is not installed']);
    if (result.exitCode != 0) {
      return CheckResult.fail(['git ls-files failed: ${result.stderr}'.trim()]);
    }
    final tracked = (result.stdout as String)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return CheckResult.from(
      capped([for (final path in tracked) 'tracked build output: $path']),
    );
  }
}
