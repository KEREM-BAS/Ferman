import 'dart:io';

import 'package:path/path.dart' as p;

/// The outcome of one check.
enum Status {
  /// The check ran and found nothing wrong.
  pass,

  /// The check ran and found a problem.
  fail,

  /// The check could not run because its input does not exist yet.
  skip,
}

/// The result of running one [Check].
final class CheckResult {
  /// A passing result, with optional notes.
  const new pass([this.messages = const []]) : status = Status.pass;

  /// A failing result; [messages] says what is wrong, one problem each.
  const new fail(this.messages) : status = Status.fail;

  /// A skipped result; [reason] names the input that does not exist yet.
  new skip(String reason) : status = Status.skip, messages = [reason];

  /// A result that fails when [problems] is not empty and passes otherwise.
  factory from(List<String> problems) =>
      problems.isEmpty ? const CheckResult.pass() : CheckResult.fail(problems);

  /// Whether the check passed, failed or was skipped.
  final Status status;

  /// Problems for a failure, the reason for a skip, notes for a pass.
  final List<String> messages;
}

/// What a check knows about the repository it inspects.
final class CheckContext {
  /// A context for the repository at [root], comparing `design/` with [base].
  new({required String root, this.base = defaultBase})
    : root = p.normalize(p.absolute(root));

  /// The git ref `design/` is compared with when no other is given.
  static const defaultBase = 'origin/main';

  /// The absolute path of the repository root.
  final String root;

  /// The git ref that `design/` must be identical to.
  final String base;

  /// The absolute path of [relative], a `/`-separated path from the root.
  String path(String relative) => p.joinAll([root, ...relative.split('/')]);

  /// The file at [relative] from the root.
  File file(String relative) => File(path(relative));

  /// The directory at [relative] from the root.
  Directory dir(String relative) => Directory(path(relative));

  /// The `/`-separated path of [absolute] relative to the root, for messages.
  String relative(String absolute) =>
      p.relative(absolute, from: root).replaceAll(r'\', '/');

  /// Runs [executable] with [arguments] in the root directory.
  ///
  /// Returns `null` when the executable cannot be started, for example
  /// because it is not installed.
  ProcessResult? run(String executable, List<String> arguments) {
    try {
      return Process.runSync(executable, arguments, workingDirectory: root);
    } on ProcessException {
      return null;
    }
  }
}

/// One repository check.
abstract interface class Check {
  /// The name printed in the report, such as `unsafe_roots`.
  String get name;

  /// Inspects the repository described by [context].
  CheckResult run(CheckContext context);
}
