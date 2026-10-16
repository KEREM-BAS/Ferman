import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_allowlist.dart';
import 'package:checks/src/checks/s6_material_imports.dart';
import 'package:checks/src/checks/s6_source.dart';

/// S6: no Material or Cupertino dialogs, sheets, pickers, snack bars,
/// popup menus, tooltips or tab views, and no GetX, anywhere in `app/lib/`
/// (brief §6, ADR 0011). Every dialog, menu, popover, sheet, toast and
/// tooltip is a Ferman component shown through widgets-layer primitives;
/// mode and sidebar tabs are segmented controls over an `IndexedStack`.
///
/// Rules, over every hand-written Dart file in `app/lib/`, including the
/// design system (an exception needs an allow-list entry with a reason):
///
/// - `api`: a use of one of [forbidden] that resolves to Material's or
///   Cupertino's: the file imports `material.dart`, `cupertino.dart` or a
///   library under `package:flutter/src/material/` or `src/cupertino/` with
///   the name visible (no `show` without it, no `hide` of it), and uses the
///   name unprefixed (not as `something.name`) or through that import's
///   prefix. Names are matched as whole identifiers in code, never in
///   comments or strings. Resolving through the imports keeps false
///   positives out: the design system has its own `Tooltip` and `Dialog`
///   components (ADR 0011), and a Ferman `showMenu` flag is not Material's
///   `showMenu`. Feature code cannot import Material at all
///   (`s6_material_imports`), so there every forbidden use is caught twice.
/// - `getx`: an import of GetX (`package:get/`, `package:get_storage/`).
final class S6ForbiddenApiCheck implements Check {
  /// Creates the check with [allowlist], by default the reviewed
  /// [s6Allowlist].
  const new({List<S6Allowance>? allowlist})
    : allowlist = allowlist ?? s6Allowlist;

  /// The reviewed exceptions.
  final List<S6Allowance> allowlist;

  /// The forbidden Material and Cupertino names, with what to use instead.
  static const forbidden = <String, String>{
    'showDialog': 'a Ferman Dialog shown through an Overlay',
    'showAdaptiveDialog': 'a Ferman Dialog shown through an Overlay',
    'AlertDialog': 'the Ferman Dialog component',
    'SimpleDialog': 'the Ferman Dialog component',
    'Dialog': 'the Ferman Dialog component',
    'AboutDialog': 'the Ferman Dialog component',
    'showAboutDialog': 'the Ferman Dialog component',
    'showCupertinoDialog': 'a Ferman Dialog shown through an Overlay',
    'CupertinoAlertDialog': 'the Ferman Dialog component',
    'showCupertinoModalPopup': 'a Ferman popover or sheet',
    'showCupertinoSheet': 'a Ferman sheet',
    'CupertinoActionSheet': 'a Ferman menu or sheet',
    'showModalBottomSheet': 'a Ferman sheet',
    'showBottomSheet': 'a Ferman sheet',
    'showDatePicker': "Ferman's date-picker popover",
    'showDateRangePicker': "Ferman's date-picker popover",
    'showTimePicker': "Ferman's own picker",
    'SnackBar': 'the Ferman Toast component',
    'PopupMenuButton': 'the Ferman Menu component',
    'showMenu': 'the Ferman Menu component',
    'Tooltip': 'the Ferman Tooltip component',
    'TabBarView': 'a segmented control over an IndexedStack',
    'TabBar': 'the Ferman ModeTabs or SegmentedControl component',
  };

  /// Import URI prefixes of GetX.
  static const getxPackages = ['package:get/', 'package:get_storage/'];

  @override
  String get name => 's6_forbidden_api';

  @override
  CheckResult run(CheckContext context) {
    final sources = appSources(context);
    if (sources == null) return CheckResult.skip('$s6Root does not exist yet');
    return s6Result(name, [for (final s in sources) ...findings(s)], allowlist);
  }

  /// The findings in [source].
  static List<S6Finding> findings(DartSource source) {
    final result = <S6Finding>[];
    final code = source.code;
    final directives = source.directives;
    final frameworkImports = [
      for (final directive in directives)
        if (!directive.isExport &&
            directive.uris.any(S6MaterialImportsCheck.isMaterialUri))
          directive,
    ];
    if (frameworkImports.isNotEmpty) {
      for (final MapEntry(key: api, value: instead) in forbidden.entries) {
        final unprefixed = frameworkImports.any(
          (directive) => directive.showsUnprefixed(api),
        );
        final prefixes = {
          for (final directive in frameworkImports)
            if (directive.prefix case final prefix?)
              if (directive.shown?.contains(api) ??
                  !directive.hidden.contains(api))
                prefix,
        };
        final use = RegExp('(?<![\\w\$])(?:(\\w+)\\s*\\.\\s*)?$api(?![\\w\$])');
        for (final match in use.allMatches(code)) {
          final qualifier = match.group(1);
          final resolves = qualifier == null
              ? unprefixed && !_isMemberAccess(code, match.start)
              : prefixes.contains(qualifier);
          if (!resolves) continue;
          result.add(
            source.finding(
              match.start,
              'api',
              '$api (Material/Cupertino) is forbidden; use $instead, or '
                  'hide it from the import',
            ),
          );
        }
      }
    }

    for (final directive in directives) {
      for (final uri in directive.uris) {
        if (getxPackages.any(uri.startsWith)) {
          result.add(
            source.finding(
              directive.offset,
              'getx',
              'GetX ($uri) is forbidden',
            ),
          );
        }
      }
    }
    result.sort((a, b) => a.line.compareTo(b.line));
    return result;
  }

  /// Whether the identifier at [offset] follows a `.` (a member, not a
  /// type: `foo.Tooltip` where `foo` is not an import prefix).
  static bool _isMemberAccess(String code, int offset) {
    var i = offset - 1;
    while (i >= 0 && (code[i] == ' ' || code[i] == '\n' || code[i] == '\t')) {
      i--;
    }
    return i >= 0 && code[i] == '.';
  }
}
