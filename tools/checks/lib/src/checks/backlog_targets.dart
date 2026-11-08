import 'package:checks/src/check.dart';

/// The phase 1 feature review of M4 (ROADMAP §8): every open row of
/// `docs/BACKLOG.md` targets the current milestone or a later one, so no
/// row is left behind a milestone that closed, and none waits only for a
/// condition ("when a board draws it") with no milestone at all.
///
/// The target is the fifth cell of a row of the `## Open` section. It
/// passes when it names, as `M1` to `M5` or `P2` to `P5`, at least one
/// milestone at or after the current one; other milestones may stand beside
/// it ("After M1 …; with About (M5) at the latest"). The current milestone
/// is the first `M` and digit of the Milestone row of `docs/PROGRESS.md`'s
/// status table. Rows inside fenced code blocks (the entry format's
/// example) do not count.
final class BacklogTargetsCheck implements Check {
  /// Creates the check.
  const new();

  /// The backlog whose open rows are read.
  static const backlogPath = 'docs/BACKLOG.md';

  /// The progress file whose status table names the current milestone.
  static const progressPath = 'docs/PROGRESS.md';

  /// Phase 1's milestones, then the later phases, in order.
  static const order = ['M1', 'M2', 'M3', 'M4', 'M5', 'P2', 'P3', 'P4', 'P5'];

  @override
  String get name => 'backlog_targets';

  @override
  CheckResult run(CheckContext context) {
    final backlog = context.file(backlogPath);
    final progress = context.file(progressPath);
    if (!backlog.existsSync()) {
      return CheckResult.skip('$backlogPath does not exist yet');
    }
    if (!progress.existsSync()) {
      return CheckResult.skip('$progressPath does not exist yet');
    }
    final current = currentMilestone(progress.readAsStringSync());
    if (current == null) {
      return const CheckResult.fail([
        '$progressPath has no "| Milestone | **M<n>" row in its status table',
      ]);
    }
    final problems = <String>[];
    final targets = openTargets(backlog.readAsStringSync());
    for (final MapEntry(key: id, value: target) in targets.entries) {
      final named = _milestone
          .allMatches(target)
          .map((match) => order.indexOf(match.group(0)!))
          .where((index) => index >= 0)
          .toList();
      if (named.isEmpty) {
        problems.add(
          '$backlogPath: $id targets only a condition ("$target"): name the '
          'milestone or phase that makes it work',
        );
      } else if (named.every((index) => index < order.indexOf(current))) {
        problems.add(
          '$backlogPath: $id targets a past milestone ("$target"; the '
          'current one is $current): move it to Done, or give it a later home',
        );
      }
    }
    if (problems.isNotEmpty) return CheckResult.fail(problems);
    return CheckResult.pass([
      '${targets.length} open rows, each at $current or later',
    ]);
  }

  static final RegExp _milestone = RegExp(r'\b[MP][1-9]\b');

  /// The current milestone, such as `M4`, from the status table of
  /// [progress], or null when it has none.
  static String? currentMilestone(String progress) => RegExp(
    r'^\|\s*Milestone\s*\|\s*\*\*(M[1-9])\b',
    multiLine: true,
  ).firstMatch(progress)?.group(1);

  /// The target cell of each row of the `## Open` section of [markdown],
  /// by id. A cell ends at a `|` that is not escaped as `\|`.
  static Map<String, String> openTargets(String markdown) {
    final targets = <String, String>{};
    var open = false;
    var fenced = false;
    final row = RegExp(r'^\|\s*(B\d{3})\s*\|');
    for (final line in markdown.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        fenced = !fenced;
        continue;
      }
      if (fenced) continue;
      if (line.startsWith('## ')) {
        open = line.substring(3).trim() == 'Open';
        continue;
      }
      final match = row.firstMatch(line);
      if (!open || match == null) continue;
      final cells = line.split(RegExp(r'(?<!\\)\|'));
      // '', id, feature, artboards, where, target, notes, ''
      targets[match.group(1)!] = cells.length > 5 ? cells[5].trim() : '';
    }
    return targets;
  }
}
