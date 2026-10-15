import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_allowlist.dart';
import 'package:checks/src/checks/s6_source.dart';

/// S6: only `app/lib/design/**` and `app/lib/app/app.dart` import
/// Material or Cupertino, and nothing re-exports them (ADR 0011).
///
/// Ferman's widgets are its own components; the design system wraps the
/// few framework pieces that live in the Material library (`Theme`,
/// `ThemeExtension`, `ThemeData`), and the root widget builds the
/// `MaterialApp`. Feature code therefore cannot reach Material's dialogs,
/// tooltips, colours or tabs at all.
///
/// Rules, over every hand-written Dart file in `app/lib/`:
///
/// - `import`: an import of `package:flutter/material.dart`,
///   `package:flutter/cupertino.dart` or a library under
///   `package:flutter/src/material/` or `src/cupertino/`, outside the two
///   allowed places.
/// - `export`: an export of one of those libraries, anywhere (a re-export
///   would hand Material to every importer).
final class S6MaterialImportsCheck implements Check {
  /// Creates the check with [allowlist], by default the reviewed
  /// [s6Allowlist].
  const new({List<S6Allowance>? allowlist})
    : allowlist = allowlist ?? s6Allowlist;

  /// The reviewed exceptions.
  final List<S6Allowance> allowlist;

  /// Where Material and Cupertino may be imported: the design system
  /// (folder) and the root widget (file).
  static const allowedImporters = ['app/lib/design/', 'app/lib/app/app.dart'];

  /// Whether [uri] is the Material or Cupertino library or part of one.
  static bool isMaterialUri(String uri) =>
      uri == 'package:flutter/material.dart' ||
      uri == 'package:flutter/cupertino.dart' ||
      uri.startsWith('package:flutter/src/material/') ||
      uri.startsWith('package:flutter/src/cupertino/');

  /// Whether [path] may import Material and Cupertino.
  static bool mayImport(String path) => allowedImporters.any(
    (allowed) =>
        allowed.endsWith('/') ? path.startsWith(allowed) : path == allowed,
  );

  @override
  String get name => 's6_material_imports';

  @override
  CheckResult run(CheckContext context) {
    final sources = appSources(context);
    if (sources == null) return CheckResult.skip('$s6Root does not exist yet');
    return s6Result(name, [for (final s in sources) ...findings(s)], allowlist);
  }

  /// The findings in [source].
  static List<S6Finding> findings(DartSource source) => [
    for (final directive in source.directives)
      for (final uri in directive.uris.where(isMaterialUri))
        if (directive.isExport)
          source.finding(
            directive.offset,
            'export',
            're-exports $uri; import it where it is needed instead',
          )
        else if (!mayImport(source.path))
          source.finding(
            directive.offset,
            'import',
            'imports $uri; only app/lib/design/ and app/lib/app/app.dart '
                'may, use Ferman components and package:flutter/widgets.dart',
          ),
  ];
}
