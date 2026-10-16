import 'dart:io';

import 'package:l10n/l10n.dart';

/// Generates `app/lib/l10n/isolated_fallback.g.dart` from the gen-l10n
/// output.
///
/// Usage, from `tools/l10n`: `dart run l10n [--root <dir>] [--check]`. Plain
/// `dart run` writes the file, but `dart run --check` does not work: `dart
/// run` reads the flag as its own option. `--check` writes nothing and exits
/// with 1 when the file is missing or stale.
Future<void> main(List<String> arguments) async {
  exitCode = await runL10nCli(arguments, out: stdout, err: stderr);
}
