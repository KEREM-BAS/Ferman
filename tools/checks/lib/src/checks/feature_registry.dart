import 'package:checks/src/check.dart';
import 'package:checks/src/checks/s6_source.dart';
import 'package:checks/src/text.dart';

/// ROADMAP gate S9: the feature registry and `docs/BACKLOG.md` agree, and
/// every control of a feature that is not built yet takes its disabled
/// state from the registry (approved on 2026-10-16, the first M2 commit).
///
/// The registry is the `Feature` enum in [registryPath]: the features that
/// are visible but do not work yet, each written `name('B018')` with the id
/// of its BACKLOG row. A feature ships by leaving the registry, so a value
/// whose row moved to Done is a feature that shipped and still names
/// controls. Rules:
///
/// - every value can be read: a name and one quoted row id, `B` and three
///   digits, and nothing else;
/// - every value names a row of BACKLOG's Open table, and that row is not
///   also under Done;
/// - every value is used as `Feature.<name>` by a hand-written file of
///   `app/lib/` other than the registry and the gallery, so no value
///   outlives its controls;
/// - `futureVersionReason` (the localized "Available in a future version")
///   is used only by the registry, the gallery in [galleryDir] (its
///   samples) and the component files in [componentReasons], each with its
///   reason; an entry there whose file no longer uses it fails too. The
///   string's getter `availableInFutureVersion` is read only by
///   [reasonPath].
///
/// Dart is read with comments and strings masked, so a name in a comment
/// or a string does not count. Generated files are not read. BACKLOG rows
/// inside fenced code blocks (the entry format's example) do not count.
final class FeatureRegistryCheck implements Check {
  /// Creates the check.
  const new();

  /// The feature registry.
  static const registryPath = 'app/lib/app/feature_registry.dart';

  /// The backlog whose rows the registry names.
  static const backlogPath = 'docs/BACKLOG.md';

  /// The only file that reads the localized reason itself.
  static const reasonPath =
      'app/lib/design/components/foundation/future_version.dart';

  /// The component gallery, whose samples use the reason directly and
  /// whose uses of the registry name no control.
  static const galleryDir = 'app/lib/features/gallery/';

  /// The component files that use `futureVersionReason` themselves, with
  /// the reviewed reason for each.
  static const Map<String, String> componentReasons = {
    reasonPath: 'defines it',
    'app/lib/design/components/annotations/sticky_note.dart':
        'More is disabled with the reason while the screen passes no onMore',
    'app/lib/design/components/fill_sign/signature_pad.dart':
        "Choose image (image signatures, B024) until M4's signature dialog "
        'gives the pad its state from the registry',
  };

  @override
  String get name => 'feature_registry';

  @override
  CheckResult run(CheckContext context) {
    final sources = appSources(context);
    if (sources == null) return CheckResult.skip('app/lib does not exist yet');
    final registryFile = context.file(registryPath);
    if (!registryFile.existsSync()) {
      const missing =
          '$registryPath does not exist: every control of an unfinished '
          'feature names its feature there (ROADMAP gate S9)';
      return const CheckResult.fail([missing]);
    }
    final backlogFile = context.file(backlogPath);
    if (!backlogFile.existsSync()) {
      return const CheckResult.fail(['$backlogPath does not exist']);
    }

    final problems = <String>[];
    final registry = DartSource(registryPath, registryFile.readAsStringSync());
    final features = readFeatures(registry, problems);
    final backlog = BacklogRows.parse(backlogFile.readAsStringSync());
    final used = <String>{};
    final reasonUsers = <String>{};
    for (final source in sources) {
      if (source.path == registryPath) continue;
      if (!source.path.startsWith(galleryDir)) {
        used.addAll(usedFeatures(source));
      }
      if (_reasonUse.hasMatch(source.code)) reasonUsers.add(source.path);
      problems.addAll(reasonFindings(source));
    }
    for (final path in componentReasons.keys) {
      if (!reasonUsers.contains(path)) {
        problems.add(
          'componentReasons lists $path, which no longer uses '
          'futureVersionReason: remove the entry',
        );
      }
    }

    for (final feature in features) {
      final where = '$registryPath:${feature.line}: Feature.${feature.name}';
      final id = feature.backlog;
      final open = backlog.open.contains(id);
      final done = backlog.done.contains(id);
      if (open && done) {
        problems.add(
          '$where names $id, which $backlogPath lists both as open and '
          'under Done: keep one row',
        );
      } else if (done) {
        problems.add(
          '$where names $id, which is under Done in $backlogPath: the '
          'feature shipped, so remove its value and wire its controls, or '
          'reopen the row',
        );
      } else if (!open) {
        problems.add(
          '$where names $id, but $backlogPath has no open row $id: add the '
          "row, or name the feature's row",
        );
      }
      if (!used.contains(feature.name)) {
        problems.add(
          '$where names no control in app/lib (written Feature.'
          '${feature.name}, outside the gallery): use it, or remove it',
        );
      }
    }
    if (problems.isNotEmpty) return CheckResult.fail(capped(problems));
    final note =
        '${features.length} features, each with an open row in '
        '$backlogPath and a control';
    return CheckResult.pass([note]);
  }

  static final RegExp _enumHeader = RegExp(r'\benum\s+Feature\b[^{;]*\{');

  static final RegExp _value = RegExp(
    r'^\s*([A-Za-z_]\w*)\s*(?:\((.*)\))?\s*$',
    dotAll: true,
  );

  static final RegExp _literal = RegExp(r"""^(['"])(B\d{3})\1$""");

  static final RegExp _maskedLiteral = RegExp(r"""^(['"])\s*\1$""");

  /// The values of the `Feature` enum in [source]; what cannot be read is
  /// added to [problems].
  static List<RegistryFeature> readFeatures(
    DartSource source,
    List<String> problems,
  ) {
    final code = source.code;
    final header = _enumHeader.firstMatch(code);
    if (header == null) {
      problems.add('${source.path}: no enum Feature');
      return const [];
    }
    final features = <RegistryFeature>[];
    void read(int start, int end) {
      final segment = code.substring(start, end);
      if (segment.trim().isEmpty) return;
      final line = source.lineOf(start + segment.indexOf(RegExp(r'\S')));
      final match = _value.firstMatch(segment);
      final inner = match?.group(2);
      if (match == null || inner == null) {
        problems.add(
          '${source.path}:$line: cannot read the Feature value '
          "\"${segment.trim()}\": write name('B000') with its BACKLOG row",
        );
        return;
      }
      final name = match.group(1)!;
      // The argument list's text starts after the value's first `(`.
      final innerStart = start + segment.indexOf('(') + 1;
      final arguments = _arguments(inner);
      String? backlog;
      if (arguments.length == 1) {
        final (argStart, argEnd) = arguments.single;
        final masked = inner.substring(argStart, argEnd).trim();
        final text = source.text
            .substring(innerStart + argStart, innerStart + argEnd)
            .trim();
        if (_maskedLiteral.hasMatch(masked)) {
          backlog = _literal.firstMatch(text)?.group(2);
        }
      }
      if (backlog == null) {
        problems.add(
          '${source.path}:$line: cannot read Feature.$name: write '
          "$name('B000') with its BACKLOG row and nothing else",
        );
        return;
      }
      features.add(RegistryFeature(name: name, backlog: backlog, line: line));
    }

    var depth = 0;
    var start = header.end;
    for (var i = header.end; i < code.length; i++) {
      final char = code[i];
      if (char == '(' || char == '[' || char == '{') {
        depth++;
      } else if (char == ')' || char == ']') {
        depth--;
      } else if (char == '}') {
        if (depth == 0) {
          read(start, i);
          return features;
        }
        depth--;
      } else if (depth == 0 && (char == ',' || char == ';')) {
        read(start, i);
        start = i + 1;
        if (char == ';') return features;
      }
    }
    problems.add('${source.path}: the enum Feature does not end');
    return features;
  }

  /// The start and end of each argument in [inner], an argument list's
  /// masked text, split at commas outside brackets; empty ones dropped.
  static List<(int, int)> _arguments(String inner) {
    final parts = <(int, int)>[];
    var depth = 0;
    var start = 0;
    void add(int end) {
      if (inner.substring(start, end).trim().isNotEmpty) {
        parts.add((start, end));
      }
    }

    for (var i = 0; i < inner.length; i++) {
      final char = inner[i];
      if (char == '(' || char == '[' || char == '{') {
        depth++;
      } else if (char == ')' || char == ']' || char == '}') {
        depth--;
      } else if (char == ',' && depth == 0) {
        add(i);
        start = i + 1;
      }
    }
    add(inner.length);
    return parts;
  }

  static final RegExp _featureUse = RegExp(r'\bFeature\s*\.\s*([A-Za-z_]\w*)');

  /// The names [source] uses as `Feature.<name>`.
  static Set<String> usedFeatures(DartSource source) => {
    for (final match in _featureUse.allMatches(source.code)) match.group(1)!,
  };

  static final RegExp _reasonUse = RegExp(r'\bfutureVersionReason\b');

  static final RegExp _getterUse = RegExp(r'\bavailableInFutureVersion\b');

  /// The places where [source] passes the future-version reason without
  /// the registry.
  static List<String> reasonFindings(DartSource source) {
    final path = source.path;
    final findings = <String>[];
    final allowed =
        path == registryPath ||
        path.startsWith(galleryDir) ||
        componentReasons.containsKey(path);
    if (!allowed) {
      for (final match in _reasonUse.allMatches(source.code)) {
        findings.add(
          '$path:${source.lineOf(match.start)}: uses futureVersionReason; '
          "name the control's feature in $registryPath and pass "
          'Feature.<name>.disabledReason(context)',
        );
      }
    }
    if (path != reasonPath) {
      for (final match in _getterUse.allMatches(source.code)) {
        findings.add(
          '$path:${source.lineOf(match.start)}: reads '
          'availableInFutureVersion; take the reason from the feature '
          'registry ($registryPath)',
        );
      }
    }
    return findings;
  }
}

/// One value of the registry's `Feature` enum.
final class RegistryFeature {
  /// The value [name] at [line] of the registry, tracked by the BACKLOG
  /// row [backlog].
  const new({required this.name, required this.backlog, required this.line});

  /// The value's name.
  final String name;

  /// The id of its BACKLOG row, such as `B018`.
  final String backlog;

  /// The 1-based line of the value in the registry.
  final int line;
}

/// The row ids of `docs/BACKLOG.md`'s Open and Done tables.
final class BacklogRows {
  /// The rows [open] and [done].
  const new({required this.open, required this.done});

  /// Reads the rows of [markdown]: a table row is a line that starts with
  /// `| B` and three digits, and it belongs to the `## Open` or `## Done`
  /// section it stands in. Rows of other sections and rows inside fenced
  /// code blocks (the entry format's example) do not count, and neither do
  /// headings inside fences.
  factory parse(String markdown) {
    final open = <String>{};
    final done = <String>{};
    Set<String>? section;
    var fenced = false;
    final row = RegExp(r'^\|\s*(B\d{3})\s*\|');
    for (final line in markdown.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        fenced = !fenced;
        continue;
      }
      if (fenced) continue;
      if (line.startsWith('## ')) {
        section = switch (line.substring(3).trim()) {
          'Open' => open,
          'Done' => done,
          _ => null,
        };
        continue;
      }
      final match = row.firstMatch(line);
      if (match != null) section?.add(match.group(1)!);
    }
    return BacklogRows(open: open, done: done);
  }

  /// The ids of the open rows.
  final Set<String> open;

  /// The ids of the rows under Done.
  final Set<String> done;
}
