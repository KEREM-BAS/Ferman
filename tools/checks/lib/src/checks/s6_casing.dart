import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_allowlist.dart';
import 'package:checks/src/checks/s6_source.dart';

/// S6: user-visible text is cased with the locale-aware casing utility in
/// `app/lib/l10n/`, never with Dart's `toUpperCase` and `toLowerCase`,
/// which ignore the language: Turkish must show "İMZALA", not "IMZALA"
/// (brief §6, ARCHITECTURE §11.2, ADR 0014).
///
/// Scope: every hand-written Dart file in `app/lib/` except
/// `app/lib/l10n/**`, where the casing utility lives.
///
/// Rule `case`: any `.toUpperCase` or `.toLowerCase` (a call or a
/// tear-off). A script cannot tell user-visible text from a machine string,
/// so a machine string (a file extension compared case-insensitively, a hex
/// digest) gets an allow-list entry with its reason; Dart's root-locale
/// casing is right for those.
final class S6CasingCheck implements Check {
  /// Creates the check with [allowlist], by default the reviewed
  /// [s6Allowlist].
  const new({List<S6Allowance>? allowlist})
    : allowlist = allowlist ?? s6Allowlist;

  /// The reviewed exceptions.
  final List<S6Allowance> allowlist;

  /// The localization folder, home of the casing utility.
  static const exempt = 'app/lib/l10n/';

  @override
  String get name => 's6_casing';

  @override
  CheckResult run(CheckContext context) {
    final sources = appSources(
      context,
      include: (path) => !path.startsWith(exempt),
    );
    if (sources == null) return CheckResult.skip('$s6Root does not exist yet');
    return s6Result(name, [for (final s in sources) ...findings(s)], allowlist);
  }

  /// The findings in [source].
  static List<S6Finding> findings(DartSource source) => [
    for (final match in RegExp(
      r'\.\s*(toUpperCase|toLowerCase)(?![\w$])',
    ).allMatches(source.code))
      source.finding(
        match.start,
        'case',
        '${match.group(1)} is not locale-aware; use the casing utility in '
            'app/lib/l10n/ for user-visible text',
      ),
  ];
}
