import 'package:checks/checks.dart';
import 'package:test/test.dart';

const S6Finding _finding = S6Finding(
  path: 'app/lib/features/a.dart',
  line: 3,
  rule: 'case',
  message: 'toUpperCase is not locale-aware',
  source: 'final k = key.toUpperCase();',
);

/// The names of the S6 checks in the runner.
final Set<String> _s6Checks = {
  for (final check in allChecks)
    if (check.name.startsWith('s6_')) check.name,
};

void main() {
  group('S6Allowance.matches', () {
    test('by file, rule and line content', () {
      const entry = S6Allowance(
        check: 's6_casing',
        path: 'app/lib/features/a.dart',
        rule: 'case',
        contains: 'key.toUpperCase()',
        reason: 'r',
      );
      expect(entry.matches(_finding), isTrue);
    });

    test('a folder path, any rule and any line', () {
      const entry = S6Allowance(
        check: 's6_casing',
        path: 'app/lib/features/',
        rule: '*',
        reason: 'r',
      );
      expect(entry.matches(_finding), isTrue);
    });

    test('not another file, folder, rule or line', () {
      for (final entry in const [
        S6Allowance(
          check: 's6_casing',
          path: 'app/lib/features/b.dart',
          rule: 'case',
          reason: 'r',
        ),
        S6Allowance(
          check: 's6_casing',
          path: 'app/lib/feat/',
          rule: 'case',
          reason: 'r',
        ),
        S6Allowance(
          check: 's6_casing',
          path: 'app/lib/features/a.dart',
          rule: 'color',
          reason: 'r',
        ),
        S6Allowance(
          check: 's6_casing',
          path: 'app/lib/features/a.dart',
          rule: 'case',
          contains: 'other.toUpperCase()',
          reason: 'r',
        ),
        // A file path without the trailing slash is not a folder.
        S6Allowance(
          check: 's6_casing',
          path: 'app/lib/features',
          rule: 'case',
          reason: 'r',
        ),
      ]) {
        expect(entry.matches(_finding), isFalse, reason: '$entry');
      }
    });
  });

  group('s6Result', () {
    test('passes without findings', () {
      expect(s6Result('s6_casing', [], []).status, Status.pass);
      expect(s6Result('s6_casing', [], []).messages, isEmpty);
    });

    test('fails on findings and says how to fix them', () {
      final result = s6Result('s6_casing', [_finding], []);
      expect(result.status, Status.fail);
      expect(result.messages.first, startsWith('app/lib/features/a.dart:3: '));
      expect(result.messages.last, contains('s6_allowlist.dart'));
    });

    test('ignores entries of other checks', () {
      const other = S6Allowance(
        check: 's6_literals',
        path: 'app/lib/features/a.dart',
        rule: '*',
        reason: 'r',
      );
      expect(s6Result('s6_casing', [_finding], [other]).status, Status.fail);
      // ...and does not report them as stale.
      expect(s6Result('s6_casing', [], [other]).status, Status.pass);
    });

    test('fails on an entry without a reason', () {
      const entry = S6Allowance(
        check: 's6_casing',
        path: 'app/lib/features/a.dart',
        rule: 'case',
        reason: '  ',
      );
      final result = s6Result('s6_casing', [_finding], [entry]);
      expect(result.status, Status.fail);
      expect(result.messages, [contains('allow-list entry without a reason')]);
    });

    test('caps long lists of findings', () {
      final many = [
        for (var line = 1; line <= 30; line++)
          S6Finding(
            path: 'app/lib/a.dart',
            line: line,
            rule: 'case',
            message: 'm',
            source: 's',
          ),
      ];
      final result = s6Result('s6_casing', many, []);
      expect(result.messages, contains('... and 10 more'));
    });
  });

  group('the reviewed allow-list', () {
    test('names S6 checks, app/lib paths and gives reasons', () {
      expect(_s6Checks, {
        's6_material_imports',
        's6_forbidden_api',
        's6_literals',
        's6_directional',
        's6_casing',
      });
      for (final entry in s6Allowlist) {
        expect(_s6Checks, contains(entry.check), reason: '$entry');
        expect(entry.path, startsWith('$s6Root/'), reason: '$entry');
        expect(entry.rule, isNotEmpty, reason: '$entry');
        expect(entry.reason.trim(), isNotEmpty, reason: '$entry');
      }
    });
  });
}
