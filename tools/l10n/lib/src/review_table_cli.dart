/// The logic of `dart run l10n:review_table`, kept here so tests can drive
/// it.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:l10n/src/cli.dart' show exitError, exitStale, exitUsage;
import 'package:l10n/src/errors.dart';
import 'package:l10n/src/review_table.dart';
import 'package:l10n/src/root.dart';
import 'package:path/path.dart' as p;

/// The command that renders the table, for messages.
const String reviewTableCommand =
    '(cd tools/l10n && dart run l10n:review_table)';

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
        'Write nothing; exit with $exitStale if the table in $reviewDocPath '
        'differs from what the ARB files give.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

/// Renders the table of [reviewDocPath] with [arguments] and returns the exit
/// code.
///
/// Messages go to [out]; problems go to [err]. [workingDirectory] is where
/// the search for the repository root starts (the current directory by
/// default).
Future<int> runReviewTableCli(
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
    generated = generateReviewDoc(root);
  } on L10nException catch (error) {
    err.writeln('review_table: $error');
    return exitError;
  }

  final file = File(p.joinAll([root, ...reviewDocPath.split('/')]));
  final current = file
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  if (current == generated) {
    out.writeln('$reviewDocPath is up to date.');
    return 0;
  }
  if (options.flag('check')) {
    err.writeln('$reviewDocPath is stale; run $reviewTableCommand.');
    return exitStale;
  }
  file.writeAsStringSync(generated);
  out.writeln('Wrote $reviewDocPath.');
  return 0;
}

String get _usage =>
    'Renders the translation table of $reviewDocPath from the ARB files in '
    '$arbDirectory.\n\n'
    'Usage, from tools/l10n: dart run l10n:review_table [--root <dir>] '
    '[--check]\n\n'
    '${_parser.usage}';
