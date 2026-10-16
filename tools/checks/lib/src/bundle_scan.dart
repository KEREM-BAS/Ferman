/// Finds files from the design export or the design-reference tooling in app
/// build output: none of them may ship (CLAUDE.md, ROADMAP M1 step 6).
///
/// A file is reported when its name is one only the design export or
/// `tools/design-refs` uses, when it is a web font or lies in an
/// `@fontsource` folder, when it is a React or Babel standalone script under
/// another name, or when its bytes equal a file under `design/`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:checks/src/sha256.dart';
import 'package:checks/src/text.dart';
import 'package:path/path.dart' as p;

/// Files shorter than this are not compared with `design/`: an empty file or
/// a two-byte `{}` is no evidence of a copy.
const minComparedBytes = 64;

/// File names (lowercase) that only the design export and its renderer use.
const Map<String, String> designFileNames = {
  '_ds_bundle.js': 'the design system bundle of the design export',
  'support.js': 'the runtime script of the design export (design/support.js)',
  'fm-additions.css': 'the design additions stylesheet (design/ds-additions)',
  'fm-icons.js': 'the design additions icon script (design/ds-additions)',
  'react.development.js': _react,
  'react.production.min.js': _react,
  'react.profiling.min.js': _react,
  'react-dom.development.js': _react,
  'react-dom.production.min.js': _react,
  'react-dom.profiling.min.js': _react,
  'babel.js': _babel,
  'babel.min.js': _babel,
};

const _react = 'a React UMD script, which the design export loads';
const _babel = 'Babel standalone, which the design export loads';
const _reactHead =
    'a React script under another name (its "@license React" header), '
    'which the design export loads';
const _babelHead =
    'Babel standalone under another name (its ".Babel = {}" header), '
    'which the design export loads';

/// How many bytes of a script are read to recognise React or Babel.
const _headBytes = 1024;

final _babelGlobal = RegExp(r'\.Babel\s*=\s*\{\}');

/// One file that must not be in a build, and why.
final class BundleFinding {
  /// A finding for [path], `/`-separated and relative to the scanned folder.
  const new(this.path, this.reasons);

  /// The file's path, `/`-separated and relative to the scanned folder.
  final String path;

  /// Every reason the file must not ship.
  final List<String> reasons;

  @override
  String toString() => '$path: ${reasons.join('; ')}';
}

/// The files of `design/`, grouped by size and hashed only when a build
/// file has the same size.
final class DesignIndex {
  new _(this.root, this._bySize);

  /// Lists every file of [design] of at least [minComparedBytes] bytes.
  ///
  /// Throws a [FileSystemException] when [design] cannot be listed.
  factory load(Directory design) {
    final root = p.normalize(p.absolute(design.path));
    final bySize = <int, List<String>>{};
    for (final entity in Directory(
      root,
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final length = entity.lengthSync();
      if (length < minComparedBytes) continue;
      bySize.putIfAbsent(length, () => []).add(entity.path);
    }
    // Sorted, so a file with several copies in design/ lists them in order.
    for (final paths in bySize.values) {
      paths.sort();
    }
    return DesignIndex._(root, bySize);
  }

  /// The absolute path of the design folder.
  final String root;

  final Map<int, List<String>> _bySize;
  final _hashes = <String, String>{};

  /// How many files are compared.
  int get fileCount =>
      _bySize.values.fold(0, (count, paths) => count + paths.length);

  /// The design files with the same bytes as [file], whose length is
  /// [length], as `/`-separated paths from the design folder's parent
  /// (`design/...`).
  List<String> copiesOf(File file, int length) {
    final candidates = _bySize[length];
    if (candidates == null) return const [];
    final hash = sha256OfFile(file);
    return [
      for (final candidate in candidates)
        if ((_hashes[candidate] ??= sha256OfFile(File(candidate))) == hash)
          p.relative(candidate, from: p.dirname(root)).replaceAll(r'\', '/'),
    ];
  }
}

/// Scans every file under [dir]: how many files it holds, and the findings,
/// sorted by path.
///
/// Symbolic links are not followed into folders; a link to a file is
/// checked like the file.
({int files, List<BundleFinding> findings}) scanBuild(
  Directory dir,
  DesignIndex design,
) {
  final root = p.normalize(p.absolute(dir.path));
  final findings = <BundleFinding>[];
  var files = 0;
  for (final entity in Directory(
    root,
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is Directory) continue;
    files++;
    final relative = p.relative(entity.path, from: root).replaceAll(r'\', '/');
    final reasons = <String>[..._nameReasons(relative)];
    try {
      if (FileSystemEntity.isFileSync(entity.path)) {
        reasons.addAll(_contentReasons(File(entity.path), design));
      }
    } on FileSystemException catch (error) {
      reasons.add('could not be read (${error.message})');
    }
    if (reasons.isNotEmpty) findings.add(BundleFinding(relative, reasons));
  }
  findings.sort((a, b) => a.path.compareTo(b.path));
  return (files: files, findings: findings);
}

Iterable<String> _nameReasons(String relative) sync* {
  final segments = relative.toLowerCase().split('/');
  final name = segments.last;
  if (name.endsWith('.dc.html')) {
    yield 'a design board of the design export (*.dc.html)';
  }
  final known = designFileNames[name];
  if (known != null) yield known;
  if (name.endsWith('.woff') || name.endsWith('.woff2')) {
    yield "a web font: the app bundles only IBM's TTF files, and woff and "
        'woff2 files come from the design export or @fontsource';
  }
  if (segments.contains('@fontsource')) {
    yield 'from an @fontsource package (the design-reference fonts)';
  }
}

Iterable<String> _contentReasons(File file, DesignIndex design) sync* {
  final length = file.lengthSync();
  final name = p.basename(file.path).toLowerCase();
  final isScript =
      name.endsWith('.js') || name.endsWith('.mjs') || name.endsWith('.cjs');
  if (isScript && !designFileNames.containsKey(name)) {
    final head = _head(file);
    if (head.contains('@license React')) yield _reactHead;
    if (_babelGlobal.hasMatch(head)) yield _babelHead;
  }
  if (length >= minComparedBytes) {
    for (final copy in design.copiesOf(file, length)) {
      yield 'identical to $copy';
    }
  }
}

String _head(File file) {
  final input = file.openSync();
  try {
    final buffer = Uint8List(_headBytes);
    final count = input.readIntoSync(buffer);
    return String.fromCharCodes(buffer, 0, count);
  } finally {
    input.closeSync();
  }
}

/// Exit status when no folder holds a design file.
const scanOk = 0;

/// Exit status when a folder holds at least one design file.
const scanFound = 1;

/// Exit status for invalid arguments or a missing folder.
const scanUsage = 64;

/// Scans the build folders named in [arguments] and writes a report to
/// [out]; returns [scanOk], [scanFound] or [scanUsage].
///
/// Usage: `dart run bin/scan_bundle.dart [--root <repo>] <folder>...`. The
/// folders are relative to the current directory; `design/` is found under
/// the repository root.
int runScanBundle(List<String> arguments, {required StringSink out}) {
  final parser = ArgParser()
    ..addOption(
      'root',
      help: 'The repository root, whose design/ is compared.',
      defaultsTo: '.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');
  const usage =
      'Usage: dart run bin/scan_bundle.dart [--root <repo>] <build folder>...';

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (error) {
    out
      ..writeln(error.message)
      ..writeln(usage)
      ..writeln(parser.usage);
    return scanUsage;
  }
  if (args.flag('help')) {
    out
      ..writeln(usage)
      ..writeln(parser.usage);
    return scanOk;
  }
  final folders = args.rest;
  if (folders.isEmpty) {
    out
      ..writeln('no build folder given')
      ..writeln(usage);
    return scanUsage;
  }
  // A mistyped folder must not pass as an empty, clean build.
  final missing = [
    for (final folder in folders)
      if (!Directory(folder).existsSync()) folder,
  ];
  if (missing.isNotEmpty) {
    out.writeln('build folder not found: ${missing.join(', ')}');
    return scanUsage;
  }
  final designDir = Directory(p.join(args.option('root')!, 'design'));
  if (!designDir.existsSync()) {
    out.writeln('design/ not found: ${designDir.path} (pass --root)');
    return scanUsage;
  }
  final design = DesignIndex.load(designDir);
  if (design.fileCount == 0) {
    out.writeln('design/ has no file to compare: ${designDir.path}');
    return scanUsage;
  }

  var found = 0;
  for (final folder in folders) {
    final (:files, :findings) = scanBuild(Directory(folder), design);
    if (findings.isEmpty) {
      out.writeln('PASS  $folder: $files files, none from the design export');
      continue;
    }
    found++;
    out.writeln(
      'FAIL  $folder: ${findings.length} of $files files must not ship',
    );
    for (final line in capped([
      for (final finding in findings) '$finding',
    ], limit: 50)) {
      out.writeln('      $line');
    }
  }
  out.writeln(
    '${folders.length} folders scanned against ${design.fileCount} files of '
    'design/: $found with design files',
  );
  return found == 0 ? scanOk : scanFound;
}
