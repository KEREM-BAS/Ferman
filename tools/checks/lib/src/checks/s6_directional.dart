import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_allowlist.dart';
import 'package:checks/src/checks/s6_source.dart';

/// S6: layout uses start and end, never left and right, so Arabic, Persian
/// and Hebrew mirror the UI (brief §6, ADR 0014: `EdgeInsetsDirectional`
/// and `AlignmentDirectional` everywhere).
///
/// Scope: every hand-written Dart file in `app/lib/`, the design system
/// included. The PDF canvas is never mirrored and positions pages
/// physically; such code gets an allow-list entry (a folder entry is
/// allowed) with its reason.
///
/// Rules, each pointing to the directional equivalent:
///
/// - `insets`: `EdgeInsets.only(left:/right: …)`, `EdgeInsets.fromLTRB(…)`
///   and `EdgeInsets.symmetric(horizontal: …)`; use `EdgeInsetsDirectional`
///   (`.only(start:, end:)`, `.fromSTEB`, `.symmetric`). Vertical-only and
///   `EdgeInsets.all` are direction-neutral and allowed.
/// - `alignment`: `Alignment` and `FractionalOffset` `.topLeft`,
///   `.topRight`, `.centerLeft`, `.centerRight`, `.bottomLeft`,
///   `.bottomRight`, and `Alignment(x, y)` unless `x` is the literal 0; use
///   `AlignmentDirectional` (`topStart`, `centerEnd`, …).
/// - `positioned`: `Positioned(…)` and `Positioned.fill(…)` with `left:` or
///   `right:`, `Positioned.fromRect` and `Positioned.fromRelativeRect`; use
///   `PositionedDirectional(start:, end:)` or `Positioned.directional`.
/// - `text-align`: `TextAlign.left` and `TextAlign.right`; use
///   `TextAlign.start` and `TextAlign.end`.
/// - `border-radius`: `BorderRadius.only(…)` with a corner and
///   `BorderRadius.horizontal(…)`; use `BorderRadiusDirectional`, or
///   `BorderRadius.vertical` for top or bottom corners.
/// - `border`: `Border(left:/right: …)`; use `BorderDirectional(start:,
///   end:)`.
final class S6DirectionalCheck implements Check {
  /// Creates the check with [allowlist], by default the reviewed
  /// [s6Allowlist].
  const new({List<S6Allowance>? allowlist})
    : allowlist = allowlist ?? s6Allowlist;

  /// The reviewed exceptions.
  final List<S6Allowance> allowlist;

  @override
  String get name => 's6_directional';

  @override
  CheckResult run(CheckContext context) {
    final sources = appSources(context);
    if (sources == null) return CheckResult.skip('$s6Root does not exist yet');
    return s6Result(name, [for (final s in sources) ...findings(s)], allowlist);
  }

  /// The findings in [source].
  static List<S6Finding> findings(DartSource source) {
    final result = <S6Finding>[];
    void add(int offset, String rule, String what, String instead) =>
        result.add(source.finding(offset, rule, '$what; use $instead'));
    bool hasNamed(DartCall call, List<String> names) =>
        names.any((name) => call.named(name) != null);

    for (final call in source.calls(
      r'(?<![\w$])EdgeInsets\s*\.\s*(only|fromLTRB|symmetric)\s*\(',
    )) {
      final physical = switch (call.groups.first) {
        'only' => hasNamed(call, ['left', 'right']),
        'symmetric' => hasNamed(call, ['horizontal']),
        _ => true,
      };
      if (physical) {
        add(
          call.offset,
          'insets',
          'EdgeInsets.${call.groups.first} with left/right',
          'EdgeInsetsDirectional',
        );
      }
    }

    for (final match in RegExp(
      r'(?<![\w$])(Alignment|FractionalOffset)\s*\.\s*'
      '(topLeft|topRight|centerLeft|centerRight|bottomLeft|bottomRight)'
      r'(?![\w$])',
    ).allMatches(source.code)) {
      add(
        match.start,
        'alignment',
        '${match.group(1)}.${match.group(2)}',
        'AlignmentDirectional',
      );
    }
    for (final call in source.calls(r'(?<![\w$])Alignment\s*\(')) {
      final x = call.positional.firstOrNull;
      if (x != null && !x.isZero) {
        add(
          call.offset,
          'alignment',
          'Alignment(x, y) with a horizontal offset',
          'AlignmentDirectional(start, y)',
        );
      }
    }

    for (final call in source.calls(
      r'(?<![\w$])Positioned\s*(?:\.\s*(fill|fromRect|fromRelativeRect)\s*)?\(',
    )) {
      final constructor = call.groups.first;
      final physical =
          constructor == 'fromRect' ||
          constructor == 'fromRelativeRect' ||
          hasNamed(call, ['left', 'right']);
      if (physical) {
        add(
          call.offset,
          'positioned',
          'Positioned${constructor == null ? '' : '.$constructor'} with '
              'left/right',
          'PositionedDirectional or Positioned.directional',
        );
      }
    }

    for (final match in RegExp(
      r'(?<![\w$])TextAlign\s*\.\s*(left|right)(?![\w$])',
    ).allMatches(source.code)) {
      add(
        match.start,
        'text-align',
        'TextAlign.${match.group(1)}',
        'TextAlign.start or TextAlign.end',
      );
    }

    for (final call in source.calls(
      r'(?<![\w$])BorderRadius\s*\.\s*(only|horizontal)\s*\(',
    )) {
      final physical =
          call.groups.first == 'horizontal' ||
          hasNamed(call, ['topLeft', 'topRight', 'bottomLeft', 'bottomRight']);
      if (physical) {
        add(
          call.offset,
          'border-radius',
          'BorderRadius.${call.groups.first} with left/right corners',
          'BorderRadiusDirectional, or BorderRadius.vertical',
        );
      }
    }

    for (final call in source.calls(r'(?<![\w$])Border\s*\(')) {
      if (hasNamed(call, ['left', 'right'])) {
        add(
          call.offset,
          'border',
          'Border with left/right',
          'BorderDirectional(start:, end:)',
        );
      }
    }
    result.sort((a, b) => a.line.compareTo(b.line));
    return result;
  }
}
