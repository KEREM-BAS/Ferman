import 'dart:io';

import 'package:checks/checks.dart';

/// Runs every repository check and exits with 1 if any of them failed.
///
/// Usage: `dart run bin/check_all.dart --root <repo> [--base <ref>]`.
void main(List<String> arguments) {
  exitCode = runChecks(
    arguments,
    out: stdout,
    environment: Platform.environment,
  );
}
