import 'dart:convert';
import 'dart:io';

import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;

/// The repository root, found from the test's working directory
/// (`tools/icons`).
final String repoRoot = findRoot(Directory.current.path)!;

/// Reads a repository file given by its `/`-separated relative [path], with
/// its line endings normalized to `\n` so the tests pass on a CRLF checkout.
String readRepoFile(String path) =>
    readText(File(p.joinAll([repoRoot, ...path.split('/')])));

/// Rewrites every line ending of [file] as CRLF, as a Windows checkout with
/// `core.autocrlf` does.
void convertToCrlf(File file) {
  file.writeAsStringSync(
    normalizeNewlines(file.readAsStringSync()).replaceAll('\n', '\r\n'),
  );
}

/// Copies what the generator reads and writes into a fresh temporary
/// directory that looks like a repository root, and returns its path.
///
/// [withOutputs] also copies the committed generated files, so `--check`
/// passes on the copy until a test changes something.
String copyRoot({bool withOutputs = true}) {
  final temp = Directory.systemTemp.createTempSync('icons_root_').path;
  void copy(String relative) {
    final from = p.joinAll([repoRoot, ...relative.split('/')]);
    final to = p.joinAll([temp, ...relative.split('/')]);
    if (FileSystemEntity.isDirectorySync(from)) {
      for (final entity in Directory(from).listSync(recursive: true)) {
        if (entity is File) {
          final target = File(p.join(to, p.relative(entity.path, from: from)));
          target.parent.createSync(recursive: true);
          entity.copySync(target.path);
        }
      }
    } else {
      File(to).parent.createSync(recursive: true);
      File(from).copySync(to);
    }
  }

  copy(bundlePath);
  copy(additionsPath);
  copy('tools/icons/pubspec.yaml');
  copy(matchesPath);
  if (withOutputs) {
    copy(assetsDir);
    copy(enumPath);
    copy(dataPath);
    copy(elementPath);
  }
  return temp;
}

/// Runs the CLI with [arguments] and returns the exit code with what it
/// printed.
Future<({int code, String out, String err})> runCli(
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runIconsCli(
    arguments,
    out: out,
    err: err,
    workingDirectory: workingDirectory ?? repoRoot,
  );
  return (code: code, out: out.toString(), err: err.toString());
}

/// Builds a gzip-compressed ustar archive of [files] (path → content).
///
/// With [paxNames], each entry's path is carried in a PAX header instead of
/// the ustar name field.
List<int> buildTarGz(Map<String, String> files, {bool paxNames = false}) {
  final out = <int>[];
  void entry(String name, List<int> data, int type) {
    final header = List<int>.filled(512, 0);
    void put(int offset, int length, String value) {
      final bytes = utf8.encode(value);
      for (var i = 0; i < bytes.length && i < length; i++) {
        header[offset + i] = bytes[i];
      }
    }

    put(0, 100, name);
    put(100, 8, '0000644');
    put(124, 12, data.length.toRadixString(8).padLeft(11, '0'));
    put(136, 12, '00000000000');
    header[156] = type;
    put(257, 6, 'ustar');
    put(263, 2, '00');
    for (var i = 148; i < 156; i++) {
      header[i] = 0x20;
    }
    final checksum = header.fold<int>(0, (sum, b) => sum + b);
    put(148, 8, '${checksum.toRadixString(8).padLeft(6, '0')}\x00 ');
    out
      ..addAll(header)
      ..addAll(data)
      ..addAll(List<int>.filled((512 - data.length % 512) % 512, 0));
  }

  for (final MapEntry(key: path, value: content) in files.entries) {
    if (paxNames) {
      final record = ' path=$path\n';
      var length = record.length + 1;
      while ('$length$record'.length != length) {
        length = '$length$record'.length;
      }
      entry('PaxHeader', utf8.encode('$length$record'), 0x78);
      entry('ignored-name', utf8.encode(content), 0x30);
    } else {
      entry(path, utf8.encode(content), 0x30);
    }
  }
  out.addAll(List<int>.filled(1024, 0));
  return gzip.encode(out);
}
