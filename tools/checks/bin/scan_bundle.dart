import 'dart:io';

import 'package:checks/src/bundle_scan.dart';

/// Scans app build output for files from the design export or the
/// design-reference tooling, and exits with 1 if it finds any.
///
/// Usage: `dart run bin/scan_bundle.dart [--root <repo>] <build folder>...`,
/// for example `--root ../.. ../../app/build/web` from `tools/checks`.
void main(List<String> arguments) {
  exitCode = runScanBundle(arguments, out: stdout);
}
