import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

List<String> _rules(String code) => [
  for (final finding in S6CasingCheck.findings(
    DartSource('app/lib/features/a.dart', code),
  ))
    finding.rule,
];

void main() {
  test('skips when app/lib does not exist', () {
    expect(Fixture().run(const S6CasingCheck()), skips);
  });

  test('fails outside app/lib/l10n and passes inside it', () {
    final fixture = Fixture()
      ..write(
        'app/lib/features/sign/sign_button.dart',
        'Text label(String s) => Text(s.toUpperCase());\n',
      )
      ..write(
        'app/lib/l10n/casing.dart',
        'String upper(String s) => s.toUpperCase();\n',
      )
      ..write(
        'app/lib/l10n/gen/app_localizations.dart',
        'String f(String s) => s.toLowerCase();\n',
      );
    final result = fixture.run(const S6CasingCheck(allowlist: []));
    const expected =
        'app/lib/features/sign/sign_button.dart:1: toUpperCase is not '
        'locale-aware; use the casing utility in app/lib/l10n/';
    expect(result, failsWith([expected]));
    expect(
      result.messages.where((m) => m.startsWith('app/lib/l10n/')),
      isEmpty,
    );
  });

  test('passes code that uses the casing utility', () {
    final fixture = Fixture()
      ..write(
        'app/lib/features/a.dart',
        '// Never s.toUpperCase(): it ignores the language.\n'
            "final l = upper(locale, 'imzala');\n"
            "const tip = 'call toLowerCase()';\n",
      );
    expect(fixture.run(const S6CasingCheck(allowlist: [])), passes);
  });

  test('calls, tear-offs and interpolations', () {
    expect(_rules('s.toUpperCase()'), ['case']);
    expect(_rules('s .toLowerCase ()'), ['case']);
    expect(_rules('names.map((n) => n.toLowerCase())'), ['case']);
    expect(_rules(r"Text('${name.toUpperCase()}')"), ['case']);
    expect(_rules('final f = s.toUpperCase;'), ['case']);
    expect(_rules('s.toUpperCaseFirst()'), isEmpty);
    expect(_rules('toUpperCase(s)'), isEmpty);
  });

  test('accepts a reviewed entry for a machine string', () {
    final fixture = Fixture()
      ..write(
        'app/lib/features/open/file_kind.dart',
        "bool isPdf(String path) => path.toLowerCase().endsWith('.pdf');\n",
      );
    const allowlist = [
      S6Allowance(
        check: 's6_casing',
        path: 'app/lib/features/open/file_kind.dart',
        rule: 'case',
        contains: 'path.toLowerCase()',
        reason: 'a file extension compared case-insensitively, never shown',
      ),
    ];
    expect(fixture.run(const S6CasingCheck(allowlist: allowlist)), passes);
  });
}
