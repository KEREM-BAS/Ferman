import 'dart:io';

import 'package:checks/checks.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A temporary repository root for one test, deleted when the test ends.
final class Fixture {
  /// Creates an empty root and registers its deletion.
  new() : dir = Directory.systemTemp.createTempSync('checks_test_') {
    addTearDown(() => dir.deleteSync(recursive: true));
  }

  /// The root directory.
  final Directory dir;

  /// A context for this root, comparing `design/` with [base].
  CheckContext context({String base = 'base'}) =>
      CheckContext(root: dir.path, base: base);

  /// Runs [check] on this root.
  CheckResult run(Check check, {String base = 'base'}) =>
      check.run(context(base: base));

  /// Writes [content] to the `/`-separated path [relative].
  void write(String relative, String content) {
    File(_path(relative))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  /// Deletes the file at [relative].
  void delete(String relative) => File(_path(relative)).deleteSync();

  /// Runs git in the root with a throwaway identity; fails the test on error.
  void git(List<String> arguments) {
    final result = Process.runSync('git', [
      '-c',
      'user.name=checks',
      '-c',
      'user.email=checks',
      '-c',
      'commit.gpgsign=false',
      '-c',
      'core.autocrlf=false',
      ...arguments,
    ], workingDirectory: dir.path);
    if (result.exitCode != 0) {
      fail('git ${arguments.join(' ')} failed: ${result.stderr}');
    }
  }

  /// Initialises a repository, commits everything and tags it `base`.
  void commitAll({String message = 'base', String? tag = 'base'}) {
    if (!Directory(_path('.git')).existsSync()) git(['init', '-q']);
    git(['add', '-A']);
    git(['commit', '-q', '--allow-empty', '-m', message]);
    if (tag != null) git(['tag', tag]);
  }

  String _path(String relative) =>
      p.joinAll([dir.path, ...relative.split('/')]);
}

/// Matches a [CheckResult] with [status] whose messages match [messages].
Matcher hasResult(Status status, [Object? messages]) => isA<CheckResult>()
    .having((result) => result.status, 'status', status)
    .having((result) => result.messages, 'messages', messages ?? anything);

/// Matches a passing [CheckResult].
final Matcher passes = hasResult(Status.pass);

/// Matches a skipped [CheckResult].
final Matcher skips = hasResult(Status.skip);

/// Matches a failing [CheckResult] with a message containing each of
/// [fragments].
Matcher failsWith(List<String> fragments) => hasResult(
  Status.fail,
  allOf([for (final fragment in fragments) contains(contains(fragment))]),
);
