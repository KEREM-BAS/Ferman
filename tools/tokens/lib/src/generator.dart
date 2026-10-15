/// Reads the token sources under a repository root and produces the
/// formatted contents of `app/lib/design/tokens.g.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tokens/src/cascade.dart';
import 'package:tokens/src/css.dart';
import 'package:tokens/src/emitter.dart';
import 'package:tokens/src/errors.dart';
import 'package:tokens/src/model.dart';
import 'package:tokens/src/supplement.dart';

/// The generated file, relative to the repository root.
const String outputPath = 'app/lib/design/tokens.g.dart';

/// Parses the token stylesheets under [root] in cascade order.
TokenCascade loadCascade(String root) {
  final sheets = <CssStylesheet>[];
  for (final source in tokenSources) {
    final file = File(p.joinAll([root, ...source.path.split('/')]));
    if (!file.existsSync()) {
      throw TokenException('missing token file ${source.path}');
    }
    sheets.add(parseStylesheet(file.readAsStringSync(), file: source.label));
  }
  return TokenCascade.fromSheets(sheets);
}

/// Builds the token model from the design files and the supplement under
/// [root].
TokenModel loadModel(String root) =>
    TokenModel.build(loadCascade(root), Supplement.load(root));

/// Returns the formatted Dart source for [root], ready to write to
/// [outputPath].
Future<String> generateTokens(String root) async {
  final source = emitDart(loadModel(root).classes);
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
    throw TokenException(
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
