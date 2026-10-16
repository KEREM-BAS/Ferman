/// Pinned lucide-static releases: download, verification and matching.
///
/// The design's glyphs are Lucide's work (ISC, with Feather portions under
/// MIT). To name the release each glyph comes from, the tool compares the
/// design's geometry with the official npm tarballs. The tarballs are pinned
/// by their npm integrity hash, and each licence text by its SHA-256, so the
/// provenance table and the shipped licence texts are reproducible.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:icons/src/design_icons.dart';
import 'package:icons/src/errors.dart';
import 'package:icons/src/svg.dart';
import 'package:path/path.dart' as p;

/// One pinned lucide-static release.
class LucideRelease {
  /// Creates a pin for [version] with its npm [integrity] (SRI, SHA-512) and
  /// the SHA-256 of its `package/LICENSE` file.
  const new(this.version, this.integrity, this.licenseSha256);

  /// The npm version, such as `0.460.0`.
  final String version;

  /// The `dist.integrity` value npm publishes for the tarball.
  final String integrity;

  /// Lower-case hex SHA-256 of the release's `package/LICENSE`.
  final String licenseSha256;

  /// The tarball's file name in the download directory.
  String get tarballName => 'lucide-static-$version.tgz';

  /// Where npm serves the tarball.
  Uri get url =>
      Uri.parse('https://registry.npmjs.org/lucide-static/-/$tarballName');

  /// How the provenance table names this release.
  String get label => 'Lucide $version';
}

/// The releases compared, in the order a match is preferred (G60): the
/// release the design system names first, then the newest, then the two
/// older releases that hold the remaining glyphs.
const List<LucideRelease> lucideReleases = [
  LucideRelease(
    '0.460.0',
    'sha512-X6pIdg7jVxv7YQ/uR241hwhNiztcAfmj181TbcX7HCxxk/3mGaRtAc6b2ftUvQBufb'
        'JE6ehgyzO2uVsa604tWg==',
    '1e7290b35280a048667bbf0ebabac1c7fd52a75300e8b2946ac165715997f2bc',
  ),
  LucideRelease(
    '1.56.0',
    'sha512-R1W4B9jCNbHmqD2JnJW5+DF4JAecKP7RSd+eMqV2aQxLKcB0MRKz0QNHpMvJtE8EhF'
        'X3Qc5V6XmUpiXD2Vcc2w==',
    'b495047bd93a9b06913511076f504daba17d5bbeb3e0650f3bb53a4220329c57',
  ),
  LucideRelease(
    '0.500.0',
    'sha512-ctDfPOCL7cbyELTO/0HL+5AB4wgxNmlRpsWsCDkhA/AZ9jsXOpGQTC8T24cSwcBQjm'
        'ASxXYBlhED/SJfryzUrQ==',
    '1e7290b35280a048667bbf0ebabac1c7fd52a75300e8b2946ac165715997f2bc',
  ),
  LucideRelease(
    '0.300.0',
    'sha512-t8pWokoJSRhzbW9YCus0ZmNnK4AvKg5QZU/Y48JXCTmyoYncEVPLMhJcdgc4MG5xKT'
        'LZpJm+E+O/3AOIVzj6JA==',
    '1e7290b35280a048667bbf0ebabac1c7fd52a75300e8b2946ac165715997f2bc',
  ),
];

/// A group of pinned releases whose `LICENSE` files are byte-identical,
/// shipped as one file.
class LicenseGroup {
  /// Creates a group of [releases] sharing the licence text whose SHA-256 is
  /// [sha256].
  const new(this.sha256, this.releases);

  /// Lower-case hex SHA-256 of the shared text.
  final String sha256;

  /// The releases with this text, in preference order; the first names the
  /// file.
  final List<LucideRelease> releases;

  /// The shipped file, relative to `app/assets/icons/`.
  String get fileName => 'LICENSE-lucide-${releases.first.version}.txt';
}

/// The licence files that ship: one per distinct pinned licence text.
List<LicenseGroup> licenseGroups() {
  final bySha = <String, List<LucideRelease>>{};
  for (final release in lucideReleases) {
    bySha.putIfAbsent(release.licenseSha256, () => []).add(release);
  }
  return [
    for (final MapEntry(key: sha, value: releases) in bySha.entries)
      LicenseGroup(sha, releases),
  ];
}

/// The parts of one verified release the tool uses.
class LucidePackage {
  /// Creates a package for [release] with its [license] text and the SVG
  /// documents of the requested [icons] it contains.
  const new(this.release, this.license, this.icons);

  /// The pinned release.
  final LucideRelease release;

  /// `package/LICENSE`, decoded as UTF-8.
  final String license;

  /// Icon name → SVG document, for the requested names the release has.
  final Map<String, String> icons;
}

/// Loads [release] from [directory], downloading the tarball with curl when
/// it is missing and [download] is true, and checks it against its pins.
///
/// Only `package/LICENSE` and `package/icons/<name>.svg` for [names] are
/// read.
Future<LucidePackage> loadLucide(
  String directory,
  LucideRelease release,
  Set<String> names, {
  bool download = true,
}) async {
  final file = File(p.join(directory, release.tarballName));
  if (!file.existsSync()) {
    if (!download) {
      throw IconsException('Missing ${file.path}.');
    }
    await _download(release.url, file);
  }
  final bytes = file.readAsBytesSync();
  final integrity = sriSha512(bytes);
  if (integrity != release.integrity) {
    throw IconsException(
      '${file.path} does not match the pinned integrity of lucide-static '
      '${release.version} (got $integrity). Delete it and download again.',
    );
  }
  final wanted = {for (final n in names) 'package/icons/$n.svg': n};
  final entries = readTarGz(
    bytes,
    (path) => path == 'package/LICENSE' || wanted.containsKey(path),
  );
  final licenseBytes = entries['package/LICENSE'];
  if (licenseBytes == null) {
    throw IconsException('${file.path} has no package/LICENSE.');
  }
  final licenseSha = sha256.convert(licenseBytes).toString();
  if (licenseSha != release.licenseSha256) {
    throw IconsException(
      'The LICENSE of lucide-static ${release.version} does not match its '
      'pinned SHA-256 (got $licenseSha).',
    );
  }
  final icons = <String, String>{};
  for (final MapEntry(key: path, value: data) in entries.entries) {
    final name = wanted[path];
    if (name != null) icons[name] = utf8.decode(data);
  }
  return LucidePackage(release, utf8.decode(licenseBytes), icons);
}

Future<void> _download(Uri url, File target) async {
  target.parent.createSync(recursive: true);
  final partial = File('${target.path}.part');
  final ProcessResult result;
  try {
    result = await Process.run('curl', [
      '--fail',
      '--silent',
      '--show-error',
      '--location',
      '--retry',
      '3',
      '--output',
      partial.path,
      url.toString(),
    ]);
  } on ProcessException catch (error) {
    throw IconsException('Cannot run curl to download $url: ${error.message}');
  }
  if (result.exitCode != 0) {
    if (partial.existsSync()) partial.deleteSync();
    throw IconsException('curl could not download $url: ${result.stderr}');
  }
  partial.renameSync(target.path);
}

/// The npm-style integrity string (`sha512-<base64>`) of [bytes].
String sriSha512(List<int> bytes) =>
    'sha512-${base64.encode(sha512.convert(bytes).bytes)}';

/// Returns the regular files of the gzip-compressed tar archive [bytes]
/// whose paths satisfy [want], keyed by path.
///
/// Understands ustar names with a prefix, PAX `path` records and GNU long
/// names, which covers npm tarballs.
Map<String, List<int>> readTarGz(
  List<int> bytes,
  bool Function(String path) want,
) {
  final List<int> tar;
  try {
    tar = gzip.decode(bytes);
  } on FormatException catch (error) {
    throw IconsException('Not a gzip archive: ${error.message}');
  }
  final files = <String, List<int>>{};
  String? longName;
  var pos = 0;
  while (pos + 512 <= tar.length) {
    final header = tar.sublist(pos, pos + 512);
    if (header.every((b) => b == 0)) break;
    final size = _octal(header, 124, 12);
    final type = header[156];
    final dataStart = pos + 512;
    final dataEnd = dataStart + size;
    if (dataEnd > tar.length) throw IconsException('Truncated tar archive.');
    final data = tar.sublist(dataStart, dataEnd);
    pos = dataStart + (size + 511) ~/ 512 * 512;

    if (type == 0x78 /* x: PAX header for the next entry */ ) {
      longName = _paxPath(data) ?? longName;
      continue;
    }
    if (type == 0x4C /* L: GNU long name for the next entry */ ) {
      longName = _cString(data, 0, data.length);
      continue;
    }
    var path = _cString(header, 0, 100);
    final isUstar = _cString(header, 257, 6).startsWith('ustar');
    if (isUstar) {
      final prefix = _cString(header, 345, 155);
      if (prefix.isNotEmpty) path = '$prefix/$path';
    }
    if (longName != null) {
      path = longName;
      longName = null;
    }
    final regular = type == 0x30 /* 0 */ || type == 0 /* old tar */;
    if (regular && want(path)) files[path] = data;
  }
  return files;
}

int _octal(List<int> header, int offset, int length) {
  if (header[offset] & 0x80 != 0) {
    throw IconsException('Tar entries over 8 GB are not supported.');
  }
  final text = _cString(header, offset, length).trim();
  if (text.isEmpty) return 0;
  final value = int.tryParse(text, radix: 8);
  if (value == null) throw IconsException('Bad tar size field "$text".');
  return value;
}

String _cString(List<int> bytes, int offset, int length) {
  var end = offset;
  while (end < offset + length && bytes[end] != 0) {
    end++;
  }
  return utf8.decode(bytes.sublist(offset, end));
}

String? _paxPath(List<int> data) {
  // Records look like "<length> <key>=<value>\n".
  final text = utf8.decode(data);
  String? path;
  var pos = 0;
  while (pos < text.length) {
    final space = text.indexOf(' ', pos);
    if (space < 0) break;
    final length = int.tryParse(text.substring(pos, space));
    if (length == null || length <= 0) break;
    final record = text.substring(space + 1, pos + length - 1);
    final eq = record.indexOf('=');
    if (eq > 0 && record.substring(0, eq) == 'path') {
      path = record.substring(eq + 1);
    }
    pos += length;
  }
  return path;
}

/// For every icon, the pinned releases (in preference order) whose file of
/// the same name draws the same geometry; an empty list means no release
/// matches.
Map<String, List<String>> matchIcons(
  List<DesignIcon> icons,
  List<LucidePackage> packages,
) {
  return {
    for (final icon in icons)
      icon.name: [
        for (final package in packages)
          if (package.icons[icon.name] case final document?)
            if (sameGeometry(
              parseShapes(icon.markup),
              parseShapes(svgDocumentChildren(document)),
            ))
              package.release.version,
      ],
  };
}
