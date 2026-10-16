/// The logic of `dart run icons`, kept here so tests can drive it.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:icons/src/errors.dart';
import 'package:icons/src/generator.dart';
import 'package:path/path.dart' as p;

/// Exit code when `--check` finds a generated file missing or stale.
const int exitStale = 1;

/// Exit code when the sources cannot be generated.
const int exitError = 2;

/// Exit code for bad command-line usage.
const int exitUsage = 64;

final ArgParser _parser = ArgParser()
  ..addOption(
    'root',
    help:
        'Repository root. Defaults to the nearest parent directory that '
        'holds design/ and tools/icons/.',
    valueHelp: 'dir',
  )
  ..addFlag(
    'check',
    negatable: false,
    help:
        'Write nothing; exit with $exitStale if a generated file is '
        'missing, stale or unexpected.',
  )
  ..addOption(
    'lucide',
    help:
        'Directory with the pinned lucide-static tarballs (downloaded with '
        'curl when missing). Recomputes the matches and the licence texts '
        'instead of reading the committed matches file.',
    valueHelp: 'dir',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

/// Runs the icons tool with [arguments] and returns the exit code.
///
/// Messages go to [out]; problems go to [err]. [workingDirectory] is where
/// the search for the repository root starts (the current directory by
/// default).
Future<int> runIconsCli(
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
  final cwd = workingDirectory ?? Directory.current.path;
  final rootOption = options.option('root');
  final root = rootOption == null
      ? findRoot(cwd)
      : p.normalize(p.absolute(cwd, rootOption));
  if (root == null) {
    err.writeln(
      'Cannot find the repository root (a directory with design/ and '
      'tools/icons/); pass --root.',
    );
    return exitUsage;
  }
  final lucideOption = options.option('lucide');
  final lucideDir = lucideOption == null
      ? null
      : p.normalize(p.absolute(cwd, lucideOption));
  final check = options.flag('check');

  try {
    final output = await generateIcons(root, lucideDir: lucideDir);
    if (check) {
      final differences = compareWithDisk(root, output);
      if (differences.isEmpty) {
        out.writeln(
          'Icons are up to date (${output.svgPaths.length} SVGs, '
          '${output.files.length - output.svgPaths.length} other files).',
        );
        return 0;
      }
      err.writeln('Generated icon files are out of date:');
      for (final d in differences) {
        err.writeln('  $d');
      }
      err.writeln('Run (cd tools/icons && dart run).');
      return exitStale;
    }
    final changed = writeOutput(root, output);
    out.writeln(
      changed.isEmpty
          ? 'Icons are up to date.'
          : 'Updated ${changed.length} files: ${changed.take(5).join(', ')}'
                '${changed.length > 5 ? ', …' : ''}.',
    );
    return 0;
  } on IconsException catch (error) {
    err.writeln('icons: $error');
    return exitError;
  }
}

String get _usage =>
    'Writes the design icons as SVG assets, PROVENANCE.md and the IconName '
    'enum (ADR 0013).\n\n'
    'Usage: dart run icons [--root <dir>] [--check] [--lucide <dir>]\n\n'
    '${_parser.usage}';

/// The nearest directory at or above [start] that holds `design/` and
/// `tools/icons/pubspec.yaml`, or `null`.
String? findRoot(String start) {
  var directory = p.normalize(p.absolute(start));
  while (true) {
    if (Directory(p.join(directory, 'design')).existsSync() &&
        File(p.join(directory, 'tools', 'icons', 'pubspec.yaml'))
            .existsSync()) {
      return directory;
    }
    final parent = p.dirname(directory);
    if (parent == directory) return null;
    directory = parent;
  }
}
