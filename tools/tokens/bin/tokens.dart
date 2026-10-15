import 'dart:io';

import 'package:tokens/tokens.dart';

/// Generates `app/lib/design/tokens.g.dart` from the design tokens.
///
/// Usage, from `tools/tokens`: `dart run bin/tokens.dart [--root <dir>]
/// [--check]`. `dart run tokens …` runs the same program, and plain
/// `dart run` writes the file, but `dart run --check` does not work: `dart
/// run` reads the flag as its own option. `--check` writes nothing and exits
/// with 1 when the file is missing or stale.
Future<void> main(List<String> arguments) async {
  exitCode = await runTokensCli(arguments, out: stdout, err: stderr);
}
