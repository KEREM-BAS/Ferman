import 'package:checks/src/checks/s6_source.dart';

/// One reviewed exception to an S6 check: code that matches a rule but is
/// right, with the reason it is.
///
/// Keep entries narrow: one file, one rule, and [contains] set to a piece
/// of the offending line. The check fails on an entry without a reason and
/// on an entry that no longer matches anything, so the list cannot go
/// stale.
final class S6Allowance {
  /// An exception to [rule] of [check] in [path], for the lines containing
  /// [contains] (every line of the file when null), because of [reason].
  const new({
    required this.check,
    required this.path,
    required this.rule,
    required this.reason,
    this.contains,
  });

  /// The check name, such as `s6_casing`.
  final String check;

  /// The file, `/`-separated from the repository root (`app/lib/...`), or a
  /// folder ending in `/` for every file under it (for code that must use
  /// physical coordinates, such as the never-mirrored PDF canvas).
  final String path;

  /// The rule name the check reports in brackets, or `*` for every rule of
  /// the check.
  final String rule;

  /// A piece of the offending source line; null accepts every line.
  final String? contains;

  /// Why the code is right. Required and reviewed.
  final String reason;

  /// Whether this entry accepts [finding] (of this entry's check).
  bool matches(S6Finding finding) {
    final pathMatches = path.endsWith('/')
        ? finding.path.startsWith(path)
        : finding.path == path;
    if (!pathMatches) return false;
    if (rule != '*' && rule != finding.rule) return false;
    final piece = contains;
    return piece == null || finding.source.contains(piece);
  }

  @override
  String toString() =>
      '$check $path [$rule]${contains == null ? '' : ' "$contains"'}';
}

/// The reviewed exceptions to the S6 checks (`s6_literals`,
/// `s6_forbidden_api`, `s6_directional`, `s6_casing`,
/// `s6_material_imports`), each with its reason.
///
/// Add an entry only when the code cannot follow the rule, for example a
/// machine string that is lower-cased for comparison and never shown, or
/// the PDF canvas, which is never mirrored and so uses physical positions.
/// Empty: no exception is needed yet.
const List<S6Allowance> s6Allowlist = [];
