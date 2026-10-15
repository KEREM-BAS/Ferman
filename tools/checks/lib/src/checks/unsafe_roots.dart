import 'dart:io';

import 'package:checks/src/check.dart';
import 'package:checks/src/text.dart';
import 'package:path/path.dart' as p;

/// Every crate root forbids unsafe code, except ferman-api, which denies it
/// so that the FRB-generated module alone can be allowed. No other
/// `allow(unsafe_code)` exists anywhere in `crates/` (ADR 0010,
/// ARCHITECTURE.md §8.1).
final class UnsafeRootsCheck implements Check {
  /// Creates the check.
  const new();

  /// The one crate whose library root denies instead of forbids.
  static const apiCrate = 'ferman-api';

  @override
  String get name => 'unsafe_roots';

  @override
  CheckResult run(CheckContext context) {
    final crates = context.dir('crates');
    if (!crates.existsSync()) {
      return CheckResult.skip('crates/ does not exist yet');
    }
    final problems = <String>[];
    final crateDirs = crates.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final crate in crateDirs) {
      problems.addAll(_checkRoots(context, crate));
    }
    for (final file in _rustFiles(crates)) {
      problems.addAll(_checkOverrides(context, file));
    }
    return CheckResult.from(problems);
  }

  static List<String> _checkRoots(CheckContext context, Directory crate) {
    final name = p.basename(crate.path);
    final src = p.join(crate.path, 'src');
    final binDir = Directory(p.join(src, 'bin'));
    final roots = [
      File(p.join(src, 'lib.rs')),
      File(p.join(src, 'main.rs')),
      if (binDir.existsSync())
        ...binDir.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.rs'),
        ),
    ].where((file) => file.existsSync()).toList();
    if (roots.isEmpty) {
      return ['crates/$name: no crate root (src/lib.rs or src/main.rs)'];
    }

    final problems = <String>[];
    for (final root in roots) {
      final code = stripLineComments(root.readAsStringSync());
      final where = context.relative(root.path);
      final forbids = _innerLint('forbid').hasMatch(code);
      final denies = _innerLint('deny').hasMatch(code);
      final isApiLibrary =
          name == apiCrate && p.basename(root.path) == 'lib.rs';
      if (isApiLibrary) {
        if (!denies) problems.add('$where: missing #![deny(unsafe_code)]');
        if (forbids) {
          problems.add(
            '$where: must deny, not forbid, unsafe code '
            '(forbid would block the FRB-generated module)',
          );
        }
      } else if (!forbids) {
        problems.add('$where: missing #![forbid(unsafe_code)]');
      }
    }
    return problems;
  }

  static List<String> _checkOverrides(CheckContext context, File file) {
    final code = stripLineComments(file.readAsStringSync());
    final where = context.relative(file.path);
    final allowed = where == 'crates/$apiCrate/src/lib.rs'
        ? _frbGenerated.allMatches(code).toList()
        : const <RegExpMatch>[];
    final problems = <String>[];
    for (final match in _override.allMatches(code)) {
      if (!_unsafeCode.hasMatch(match.group(2)!)) continue;
      final line = '\n'.allMatches(code.substring(0, match.start)).length + 1;
      final span = allowed
          .where((m) => m.start <= match.start && match.end <= m.end)
          .firstOrNull;
      if (span == null) {
        problems.add(
          '$where:$line: ${match.group(1)}(unsafe_code) outside the '
          'FRB-generated module declaration',
        );
      } else if (!_frbFeature.hasMatch(span.group(0)!)) {
        problems.add(
          '$where:$line: mod frb_generated must be behind '
          '#[cfg(feature = "frb")]',
        );
      }
    }
    return problems;
  }

  /// Every `.rs` file under `crates/`, outside Cargo `target/` folders.
  static Iterable<File> _rustFiles(Directory crates) => crates
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.rs'))
      .where(
        (file) => !p
            .split(p.relative(file.path, from: crates.path))
            .contains('target'),
      );

  /// `#![<level>(..., unsafe_code, ...)]` as an inner attribute.
  static RegExp _innerLint(String level) =>
      RegExp('#!\\[\\s*$level\\s*\\(([^)]*\\bunsafe_code\\b[^)]*)\\)\\s*\\]');

  /// A lint level that would lift `deny(unsafe_code)`, in any attribute.
  static final _override = RegExp(r'\b(allow|expect|warn)\s*\(([^)]*)\)');

  static final _unsafeCode = RegExp(r'\bunsafe_code\b');

  static final _frbFeature = RegExp(r'cfg\s*\(\s*feature\s*=\s*"frb"\s*\)');

  /// The outer attributes on `mod frb_generated;`, the only place where
  /// `allow(unsafe_code)` is accepted.
  static final _frbGenerated = RegExp(
    r'(?:#\[[^\]]*\]\s*)+(?:pub(?:\s*\([^)]*\))?\s+)?mod\s+frb_generated\s*;',
  );
}
