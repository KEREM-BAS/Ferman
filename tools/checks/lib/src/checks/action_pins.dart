import 'dart:io';

import 'package:checks/src/check.dart';
import 'package:path/path.dart' as p;

/// Every action a workflow uses is pinned to a full commit SHA, except local
/// `./` actions (ADR 0017). Docker images must be pinned by digest.
final class ActionPinsCheck implements Check {
  /// Creates the check.
  const new();

  @override
  String get name => 'action_pins';

  static final _uses = RegExp(
    r'''^\s*(?:-\s+)?uses\s*:\s*(['"]?)([^'"\s#]+)\1''',
  );
  static final _pinned = RegExp(r'^[^@\s]+@[0-9a-f]{40}$');
  static final _dockerPinned = RegExp(
    r'^docker://[^@\s]+@sha256:[0-9a-f]{64}$',
  );

  @override
  CheckResult run(CheckContext context) {
    final files = _workflowFiles(context);
    if (files.isEmpty) {
      return CheckResult.skip('.github/workflows/ has no workflows yet');
    }
    final problems = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final match = _uses.firstMatch(lines[i]);
        if (match == null) continue;
        final target = match.group(2)!;
        if (!isPinned(target)) {
          problems.add(
            '${context.relative(file.path)}:${i + 1}: $target is not pinned '
            'to a full commit SHA',
          );
        }
      }
    }
    return CheckResult.from(problems);
  }

  /// Whether a `uses:` [target] is pinned (or local).
  static bool isPinned(String target) {
    if (target.startsWith('./')) return true;
    if (target.startsWith('docker://')) return _dockerPinned.hasMatch(target);
    return _pinned.hasMatch(target);
  }

  static List<File> _workflowFiles(CheckContext context) {
    bool isYaml(File file) =>
        file.path.endsWith('.yml') || file.path.endsWith('.yaml');
    final workflows = context.dir('.github/workflows');
    final actions = context.dir('.github/actions');
    return [
      if (workflows.existsSync())
        ...workflows.listSync().whereType<File>().where(isYaml),
      if (actions.existsSync())
        ...actions
            .listSync(recursive: true)
            .whereType<File>()
            .where(isYaml)
            .where((file) => p.basenameWithoutExtension(file.path) == 'action'),
    ]..sort((a, b) => a.path.compareTo(b.path));
  }
}
