import 'dart:io';

import 'package:icons/icons.dart';

/// Renders the reference part of docs/COMPONENTS.md from
/// app/test/design/component_spec.json.
///
/// Usage, from `tools/icons`: `dart run icons:component_spec [--root <dir>]
/// [--check]`. `--check` writes nothing and exits with 1 when the document
/// is stale.
Future<void> main(List<String> arguments) async {
  exitCode = await runComponentSpecCli(arguments, out: stdout, err: stderr);
}
