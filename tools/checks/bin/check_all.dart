import 'dart:io';

import 'package:checks/checks.dart';

/// Runs every repository check, the S6 checks of `app/lib/` included, and
/// exits with 1 if any of them failed.
///
/// Usage: `dart run bin/check_all.dart --root <repo> [--base <ref>]`, with
/// `--only <check>,...` to run some of them.
void main(List<String> arguments) {
  exitCode = runChecks(
    arguments,
    out: stdout,
    environment: Platform.environment,
  );
}
