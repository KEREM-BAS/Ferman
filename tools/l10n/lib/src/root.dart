/// Finds the repository root that the l10n commands work in.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The nearest directory at or above [start] that holds `app/l10n.yaml` and
/// `tools/l10n/pubspec.yaml`, or null when there is none.
String? findRepoRoot(String start) {
  var directory = p.normalize(p.absolute(start));
  while (true) {
    if (File(p.join(directory, 'app', 'l10n.yaml')).existsSync() &&
        File(p.join(directory, 'tools', 'l10n', 'pubspec.yaml')).existsSync()) {
      return directory;
    }
    final parent = p.dirname(directory);
    if (parent == directory) return null;
    directory = parent;
  }
}
