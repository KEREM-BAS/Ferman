import 'dart:io';

import 'package:icons/icons.dart';

/// Writes the icon SVGs, PROVENANCE.md and `icon_name.g.dart`.
///
/// Usage, from `tools/icons`: `dart run [--root <dir>] [--check]
/// [--lucide <dir>]`. `--check` writes nothing and exits with 1 when a
/// generated file is stale.
Future<void> main(List<String> arguments) async {
  exitCode = await runIconsCli(arguments, out: stdout, err: stderr);
}
