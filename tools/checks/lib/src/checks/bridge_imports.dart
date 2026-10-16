import 'dart:io';

import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_source.dart';
import 'package:path/path.dart' as p;

/// ROADMAP M1 step 3: only `app/lib/engine/` imports the generated bridge
/// bindings in `app/lib/bridge/` (ARCHITECTURE §3, ADR 0003).
///
/// Everything else in the app, its tests included, talks to the engine
/// through `EngineService`, so the bridge types stay behind one layer and
/// tests can use the fake engine.
///
/// Rules, over every hand-written Dart file in `app/lib/`, `app/test/` and
/// `app/integration_test/`: an `import` or `export` of
/// `package:ferman/bridge/...`, or a relative URI that resolves into
/// `app/lib/bridge/`, outside `app/lib/engine/`. Conditional URIs count.
final class BridgeImportsCheck implements Check {
  /// Creates the check.
  const new();

  /// The generated bindings.
  static const bridgeDir = 'app/lib/bridge/';

  /// The only folder that may import [bridgeDir].
  static const allowedImporter = 'app/lib/engine/';

  /// The folders whose Dart files are checked.
  static const scannedDirs = ['app/lib', 'app/test', 'app/integration_test'];

  @override
  String get name => 'bridge_imports';

  @override
  CheckResult run(CheckContext context) {
    if (!context.dir('app/lib').existsSync()) {
      return CheckResult.skip('app/lib does not exist yet');
    }
    final problems = <String>[];
    for (final dir in scannedDirs) {
      final root = context.dir(dir);
      if (!root.existsSync()) continue;
      final files =
          root
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => p.extension(file.path) == '.dart')
              .map((file) => (file, context.relative(file.path)))
              .where((entry) => !isGenerated(entry.$2))
              .toList()
            ..sort((a, b) => a.$2.compareTo(b.$2));
      for (final (file, path) in files) {
        problems.addAll(findings(DartSource(path, file.readAsStringSync())));
      }
    }
    return CheckResult.from(problems);
  }

  /// Whether [uri], written in the file at [path], names a library in
  /// [bridgeDir].
  static bool isBridgeUri(String path, String uri) {
    if (uri.startsWith('package:ferman/bridge/')) return true;
    if (uri.contains(':')) return false;
    final resolved = p.posix.normalize(
      p.posix.join(p.posix.dirname(path), uri),
    );
    return resolved.startsWith(bridgeDir);
  }

  /// The findings in [source].
  static List<String> findings(DartSource source) {
    if (source.path.startsWith(allowedImporter)) return const [];
    return [
      for (final directive in source.directives)
        for (final uri in directive.uris)
          if (isBridgeUri(source.path, uri))
            _message(source, directive.offset, directive.isExport, uri),
    ];
  }

  static String _message(
    DartSource source,
    int offset,
    bool isExport,
    String uri,
  ) =>
      '${source.path}:${source.lineOf(offset)}: '
      '${isExport ? 'exports' : 'imports'} $uri; only $allowedImporter may '
      'use the bridge, go through EngineService instead';
}
