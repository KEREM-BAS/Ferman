/// Computes every file the icons tool owns.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:icons/src/dart_enum.dart';
import 'package:icons/src/design_icons.dart';
import 'package:icons/src/errors.dart';
import 'package:icons/src/icon_data.dart';
import 'package:icons/src/lucide.dart';
import 'package:icons/src/provenance.dart';
import 'package:icons/src/svg.dart';
import 'package:icons/src/text.dart';
import 'package:path/path.dart' as p;

/// The provenance table, relative to the repository root.
const String provenancePath = '$assetsDir/PROVENANCE.md';

/// The path of the shipped licence file of [group], relative to the
/// repository root.
String licensePath(LicenseGroup group) => '$assetsDir/${group.fileName}';

/// The files one run produces, keyed by repository-relative path with `/`
/// separators.
class IconsOutput {
  /// Creates an output with the files to write and the licence files that
  /// must already be in place.
  const new(this.files, this.requiredLicenses);

  /// Path → exact content.
  final Map<String, String> files;

  /// Licence files a run without `--lucide` cannot write but checks: path →
  /// expected SHA-256.
  final Map<String, String> requiredLicenses;

  /// The SVG paths among [files].
  Iterable<String> get svgPaths =>
      files.keys.where((path) => path.endsWith('.svg'));
}

/// Generates everything from the design export under [root].
///
/// With [lucideDir], the pinned lucide-static tarballs in that directory
/// (downloaded when missing and [download] is true) decide the matches,
/// and the matches file and licence texts are part of the output. Without
/// it, the committed matches file is used and the licence files are only
/// checked.
Future<IconsOutput> generateIcons(
  String root, {
  String? lucideDir,
  bool download = true,
}) async {
  final icons = loadDesignIcons(root);
  final files = <String, String>{};
  final requiredLicenses = <String, String>{};

  final Map<String, List<String>> matches;
  if (lucideDir != null) {
    final names = {for (final icon in icons) icon.name};
    final packages = [
      for (final release in lucideReleases)
        await loadLucide(lucideDir, release, names, download: download),
    ];
    matches = matchIcons(icons, packages);
    files[matchesPath] = encodeMatches(matches, icons);
    for (final group in licenseGroups()) {
      final package = packages.firstWhere(
        (pkg) => pkg.release == group.releases.first,
      );
      files[licensePath(group)] = package.license;
    }
  } else {
    final file = _file(root, matchesPath);
    if (!file.existsSync()) {
      throw IconsException(
        '$matchesPath is missing; run '
        '(cd tools/icons && dart run icons --lucide ../../build/lucide).',
      );
    }
    matches = decodeMatches(readText(file), icons);
    for (final group in licenseGroups()) {
      requiredLicenses[licensePath(group)] = group.sha256;
    }
  }

  for (final icon in icons) {
    files['$assetsDir/${icon.name}.svg'] = svgFile(icon.markup);
  }
  files[provenancePath] = renderProvenance(icons, matches);
  files[enumPath] = await formatDart(
    emitIconEnum(icons),
    stdinName: p.joinAll([root, ...enumPath.split('/')]),
  );
  files[dataPath] = await formatDart(
    emitIconData(icons),
    stdinName: p.joinAll([root, ...dataPath.split('/')]),
  );
  return IconsOutput(files, requiredLicenses);
}

/// One way the files on disk differ from [IconsOutput].
class Difference {
  /// Creates a difference for [path] with a short [reason].
  const new(this.path, this.reason);

  /// Repository-relative path.
  final String path;

  /// `missing`, `stale`, `unexpected` or `wrong licence text`.
  final String reason;

  @override
  String toString() => '$path ($reason)';
}

/// Compares [output] with the files under [root], including SVG files in
/// the assets folder that the output does not contain.
///
/// Line endings do not count, so a CRLF checkout is up to date.
List<Difference> compareWithDisk(String root, IconsOutput output) {
  final differences = <Difference>[];
  for (final MapEntry(key: path, value: content) in output.files.entries) {
    final file = _file(root, path);
    if (!file.existsSync()) {
      differences.add(Difference(path, 'missing'));
    } else if (!_sameText(file, content)) {
      differences.add(Difference(path, 'stale'));
    }
  }
  differences.addAll(_licenseDifferences(root, output.requiredLicenses));
  for (final path in unexpectedSvgs(root, output)) {
    differences.add(Difference(path, 'unexpected'));
  }
  return differences;
}

/// Licence files that are missing or whose text (with LF line endings, as
/// the pinned hashes were taken) does not have the pinned SHA-256.
List<Difference> _licenseDifferences(String root, Map<String, String> shas) {
  return [
    for (final MapEntry(key: path, value: sha) in shas.entries)
      if (!_file(root, path).existsSync())
        Difference(path, 'missing')
      else if (sha256
              .convert(utf8.encode(readText(_file(root, path))))
              .toString() !=
          sha)
        Difference(path, 'wrong licence text'),
  ];
}

bool _sameText(File file, String content) =>
    readText(file) == normalizeNewlines(content);

/// SVG files in the assets folder that [output] does not produce.
List<String> unexpectedSvgs(String root, IconsOutput output) {
  final dir = _directory(root, assetsDir);
  if (!dir.existsSync()) return const [];
  final expected = output.svgPaths.toSet();
  return [
    for (final entity in dir.listSync())
      if (entity is File && entity.path.endsWith('.svg'))
        '$assetsDir/${p.basename(entity.path)}',
  ].where((path) => !expected.contains(path)).toList()..sort();
}

/// Writes [output] under [root], deleting unexpected SVG files, and returns
/// the paths it changed. A file that differs only in its line endings is
/// left alone.
///
/// Throws [IconsException] before writing anything when a required licence
/// file is missing or wrong, because only a `--lucide` run can write it.
List<String> writeOutput(String root, IconsOutput output) {
  final licenses = _licenseDifferences(root, output.requiredLicenses);
  if (licenses.isNotEmpty) {
    throw IconsException(
      'Licence files need the Lucide tarballs: ${licenses.join(', ')}. Run '
      '(cd tools/icons && dart run icons --lucide ../../build/lucide). '
      'Nothing was written.',
    );
  }
  final changed = <String>[];
  for (final MapEntry(key: path, value: content) in output.files.entries) {
    final file = _file(root, path);
    if (file.existsSync() && _sameText(file, content)) continue;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    changed.add(path);
  }
  for (final path in unexpectedSvgs(root, output)) {
    _file(root, path).deleteSync();
    changed.add(path);
  }
  return changed;
}

/// Formats [source] with the SDK's `dart format`, as if it lived at
/// [stdinName], so the result matches what `dart format` produces for the
/// committed file.
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
    throw IconsException(
      'dart format failed on generated $stdinName:\n${await stderrText}',
    );
  }
  return await stdoutText;
}

/// The `dart` executable running this program, so the formatter matches the
/// SDK; falls back to `dart` on the PATH when running as a compiled binary.
String _dartExecutable() {
  final executable = Platform.resolvedExecutable;
  return p.basenameWithoutExtension(executable) == 'dart' ? executable : 'dart';
}

File _file(String root, String path) =>
    File(p.joinAll([root, ...path.split('/')]));

Directory _directory(String root, String path) =>
    Directory(p.joinAll([root, ...path.split('/')]));
