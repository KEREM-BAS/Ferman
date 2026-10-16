/// The command-line entry point's logic, kept here so tests can drive it.
///
/// Run from `tools/tokens`: `dart run bin/tokens.dart [--root <dir>]
/// [--check]` (`dart run tokens …` is the same program; plain `dart run`
/// writes the file but cannot take options, because `dart run` reads them
/// as its own).
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:tokens/src/errors.dart';
import 'package:tokens/src/generator.dart';

/// Exit code when `--check` finds the generated file stale or missing.
const int exitStale = 1;

/// Exit code when the token sources cannot be generated.
const int exitError = 2;

/// Exit code for bad command-line usage.
const int exitUsage = 64;

final ArgParser _parser = ArgParser()
  ..addOption(
    'root',
    help:
        'Repository root. Defaults to the nearest parent directory that '
        'holds design/ and tools/tokens/.',
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
Future<int> runTokensCli(
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

  final root = options.option('root') == null
      ? _findRoot(workingDirectory ?? Directory.current.path)
      : p.normalize(p.absolute(options.option('root')!));
  if (root == null) {
    err.writeln(
      'Cannot find the repository root (a directory with design/ and '
      'tools/tokens/); pass --root.',
    );
    return exitUsage;
  }

  final String generated;
  try {
    generated = await generateTokens(root);
  } on TokenException catch (error) {
    err.writeln('tokens: $error');
    return exitError;
  }

  final file = File(p.joinAll([root, ...outputPath.split('/')]));
  final current = file.existsSync() ? file.readAsStringSync() : null;
  if (options.flag('check')) {
    if (current == generated) {
      out.writeln('$outputPath is up to date.');
      return 0;
    }
    err.writeln(
      current == null
          ? '$outputPath is missing; run $writeCommand.'
          : '$outputPath is stale; run $writeCommand.',
    );
    return exitStale;
  }
  if (current == generated) {
    out.writeln('$outputPath is up to date.');
    return 0;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(generated);
  out.writeln('Wrote $outputPath.');
  return 0;
}

/// The command that regenerates the file, for messages.
const String writeCommand = '(cd tools/tokens && dart run bin/tokens.dart)';

String get _usage =>
    'Generates $outputPath from the design tokens (ADR 0012).\n\n'
    'Usage, from tools/tokens: dart run bin/tokens.dart [--root <dir>] '
    '[--check]\n\n'
    '${_parser.usage}';

String? _findRoot(String start) {
  var directory = p.normalize(p.absolute(start));
  while (true) {
    if (Directory(p.join(directory, 'design')).existsSync() &&
        File(p.join(directory, 'tools', 'tokens', 'pubspec.yaml'))
            .existsSync()) {
      return directory;
    }
    final parent = p.dirname(directory);
    if (parent == directory) return null;
    directory = parent;
  }
}
