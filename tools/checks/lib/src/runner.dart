import 'dart:io';

import 'package:args/args.dart';
import 'package:checks/src/check.dart';
import 'package:checks/src/checks/action_pins.dart';
import 'package:checks/src/checks/arb_parity.dart';
import 'package:checks/src/checks/bridge_imports.dart';
import 'package:checks/src/checks/build_untracked.dart';
import 'package:checks/src/checks/component_spec.dart';
import 'package:checks/src/checks/crate_graph.dart';
import 'package:checks/src/checks/dco_signoff.dart';
import 'package:checks/src/checks/design_untouched.dart';
import 'package:checks/src/checks/frb_versions.dart';
import 'package:checks/src/checks/pub_denylist.dart';
import 'package:checks/src/checks/s6_casing.dart';
import 'package:checks/src/checks/s6_directional.dart';
import 'package:checks/src/checks/s6_forbidden_api.dart';
import 'package:checks/src/checks/s6_literals.dart';
import 'package:checks/src/checks/s6_material_imports.dart';
import 'package:checks/src/checks/unsafe_roots.dart';
import 'package:checks/src/checks/version_sync.dart';

/// Every check, in the order the report lists them.
const List<Check> allChecks = [
  DesignUntouchedCheck(),
  // Every commit of a pull request is signed off by its author (Q14).
  DcoSignoffCheck(),
  BuildUntrackedCheck(),
  UnsafeRootsCheck(),
  CrateGraphCheck(),
  ActionPinsCheck(),
  VersionSyncCheck(),
  ArbParityCheck(),
  PubDenylistCheck(),
  FrbVersionsCheck(),
  BridgeImportsCheck(),
  // Every component of the spec exists with the spec's names (M1 G10).
  ComponentSpecCheck(),
  // S6: the Flutter conventions of brief §6 in app/lib (ADR 0011, 0012,
  // 0014), with the reviewed exceptions in s6_allowlist.dart.
  S6MaterialImportsCheck(),
  S6ForbiddenApiCheck(),
  S6LiteralsCheck(),
  S6DirectionalCheck(),
  S6CasingCheck(),
];

/// Exit status when every check passed or was skipped.
const exitOk = 0;

/// Exit status when at least one check failed.
const exitFailed = 1;

/// Exit status for invalid arguments.
const exitUsage = 64;

/// Runs the checks selected by [arguments] and writes a report to [out].
///
/// [environment] supplies `CHECKS_BASE`, the default for `--base` when it is
/// set and not empty. Returns the process exit status: [exitOk],
/// [exitFailed] or [exitUsage].
int runChecks(
  List<String> arguments, {
  required StringSink out,
  Map<String, String> environment = const {},
}) {
  final parser = ArgParser()
    ..addOption('root', help: 'The repository root.', defaultsTo: '.')
    ..addOption(
      'base',
      help:
          'The git ref design/ is compared with '
          '(default: \$CHECKS_BASE, else ${CheckContext.defaultBase}).',
    )
    ..addMultiOption(
      'only',
      help: 'Run only these checks.',
      allowed: [for (final check in allChecks) check.name],
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (error) {
    out
      ..writeln(error.message)
      ..writeln(parser.usage);
    return exitUsage;
  }
  if (args.flag('help')) {
    out
      ..writeln('Usage: dart run bin/check_all.dart [options]')
      ..writeln(parser.usage);
    return exitOk;
  }

  // Without this, a mistyped root shows up as "git is not installed" and as
  // skips, because every input looks missing.
  final root = args.option('root')!;
  if (!Directory(root).existsSync()) {
    out.writeln('--root: directory not found: $root');
    return exitUsage;
  }

  // An empty CHECKS_BASE (a CI expression that had no value) means unset.
  final envBase = environment['CHECKS_BASE'] ?? '';
  final context = CheckContext(
    root: root,
    base:
        args.option('base') ??
        (envBase.isEmpty ? CheckContext.defaultBase : envBase),
  );
  final only = args.multiOption('only');
  final selected = [
    for (final check in allChecks)
      if (only.isEmpty || only.contains(check.name)) check,
  ];

  var failed = 0;
  var skipped = 0;
  for (final check in selected) {
    final result = check.run(context);
    switch (result.status) {
      case Status.skip:
        skipped++;
        out.writeln('SKIP  ${check.name}: ${result.messages.join('; ')}');
        continue;
      case Status.fail:
        failed++;
        out.writeln('FAIL  ${check.name}');
      case Status.pass:
        out.writeln('PASS  ${check.name}');
    }
    // Problems of a failure, or notes on a pass, one per line.
    for (final message in result.messages) {
      out.writeln('      $message');
    }
  }
  final passed = selected.length - failed - skipped;
  out.writeln(
    '${selected.length} checks: $passed passed, $failed failed, '
    '$skipped skipped',
  );
  return failed == 0 ? exitOk : exitFailed;
}
