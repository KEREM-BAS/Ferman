/// Reads the gen-l10n output under a repository root and produces the
/// formatted contents of `app/lib/l10n/isolated_fallback.g.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:l10n/src/emitter.dart';
import 'package:l10n/src/errors.dart';
import 'package:l10n/src/messages.dart';
import 'package:path/path.dart' as p;

/// The gen-l10n output read, relative to the repository root
/// (`output-dir` and `output-localization-file` in `app/l10n.yaml`).
const String inputPath = 'app/lib/l10n/gen/app_localizations.dart';

/// The abstract localizations class in [inputPath] (`output-class`).
const String localizationsClass = 'AppLocalizations';

/// The generated file, relative to the repository root.
const String outputPath = 'app/lib/l10n/isolated_fallback.g.dart';

/// The messages of [inputPath] under [root].
List<Message> loadMessages(String root) {
  final file = File(p.joinAll([root, ...inputPath.split('/')]));
  if (!file.existsSync()) {
    throw L10nException(
      '$inputPath is missing; run `flutter gen-l10n` in app/ first',
    );
  }
  try {
    return parseMessages(
      file.readAsStringSync(),
      className: localizationsClass,
    );
  } on L10nException catch (error) {
    throw L10nException('$inputPath: $error');
  }
}

/// Returns the formatted Dart source for [root], ready to write to
/// [outputPath].
Future<String> generateIsolatedFallback(String root) async {
  final source = emitIsolatedFallback(loadMessages(root));
  return await formatDart(source, stdinName: p.join(root, outputPath));
}

/// Formats [source] with the SDK's `dart format`, as if it lived at
/// [stdinName], so that the result matches what `dart format` produces for
/// the committed file (same language version and page width).
Future<String> formatDart(String source, {required String stdinName}) async {
  final process = await Process.start(_dartExecutable(), [
    'format',
    '--stdin-name=$stdinName',
  ]);
  final stdoutText = process.stdout.transform(utf8.decoder).join();
  final stderrText = process.stderr.transform(utf8.decoder).join();
  process.stdin.add(utf8.encode(source));
  await process.stdin.close();
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw L10nException(
      'dart format failed on the generated source:\n${await stderrText}',
    );
  }
  return await stdoutText;
}

/// The `dart` executable running this program, so the formatter matches the
/// SDK; falls back to `dart` on the PATH when running as a compiled binary.
String _dartExecutable() {
  final executable = Platform.resolvedExecutable;
  final name = p.basenameWithoutExtension(executable);
  return name == 'dart' ? executable : 'dart';
}
