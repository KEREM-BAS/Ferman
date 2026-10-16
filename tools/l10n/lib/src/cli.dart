/// The command-line entry point's logic, kept here so tests can drive it.
///
/// Run from `tools/l10n`: `dart run l10n [--root <dir>] [--check]` (plain
/// `dart run` writes the file but cannot take options, because `dart run`
/// reads them as its own).
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:l10n/src/errors.dart';
import 'package:l10n/src/generator.dart';
import 'package:l10n/src/root.dart';
import 'package:path/path.dart' as p;

/// Exit code when `--check` finds the generated file stale or missing.
const int exitStale = 1;

/// Exit code when the gen-l10n output cannot be read or wrapped.
const int exitError = 2;

/// Exit code for bad command-line usage.
const int exitUsage = 64;

/// The command that regenerates the file, for messages.
const String writeCommand = '(cd tools/l10n && dart run l10n)';

final ArgParser _parser = ArgParser()
  ..addOption(
    'root',
    help:
        'Repository root. Defaults to the nearest parent directory that '
        'holds app/l10n.yaml and tools/l10n/.',
    valueHelp: 'dir',
  )
  ..addFlag(
    'check',
    negatable: false,
    help:
        'Write nothing; exit with $exitStale if $outputPath is missing or '
        'differs from what the generator would write.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

/// Runs the generator with [arguments] and returns the exit code.
///
/// Messages go to [out]; problems go to [err]. [workingDirectory] is where
/// the search for the repository root starts (the current directory by
/// default).
Future<int> runL10nCli(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
  String? workingDirectory,
}) async {
  final ArgResults options;
  try {
    options = _parser.parse(arguments);
  } on FormatException catch (error) {
    err
      ..writeln(error.message)
      ..writeln(_usage);
    return exitUsage;
  }
  if (options.flag('help')) {
    out.writeln(_usage);
    return 0;
  }
  if (options.rest.isNotEmpty) {
    err
      ..writeln('Unexpected arguments: ${options.rest.join(' ')}')
      ..writeln(_usage);
    return exitUsage;
  }

  final rootOption = options.option('root');
  final root = rootOption == null
      ? findRepoRoot(workingDirectory ?? Directory.current.path)
      : p.normalize(p.absolute(rootOption));
  if (root == null) {
    err.writeln(
      'Cannot find the repository root (a directory with app/l10n.yaml and '
      'tools/l10n/); pass --root.',
    );
    return exitUsage;
  }

  final String generated;
  try {
    generated = await generateIsolatedFallback(root);
  } on L10nException catch (error) {
    err.writeln('l10n: $error');
    return exitError;
  }

  final file = File(p.joinAll([root, ...outputPath.split('/')]));
  final current = file.existsSync() ? file.readAsStringSync() : null;
  if (current == generated) {
    out.writeln('$outputPath is up to date.');
    return 0;
  }
  if (options.flag('check')) {
    err.writeln(
      current == null
          ? '$outputPath is missing; run $writeCommand.'
          : '$outputPath is stale; run $writeCommand.',
    );
    return exitStale;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(generated);
  out.writeln('Wrote $outputPath.');
  return 0;
}

String get _usage =>
    'Generates $outputPath from $inputPath (G93).\n\n'
    'Usage, from tools/l10n: dart run l10n [--root <dir>] [--check]\n\n'
    '${_parser.usage}';
