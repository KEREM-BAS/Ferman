import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

const String _material = "import 'package:flutter/material.dart';\n";

List<S6Finding> _findings(String code, {String path = 'app/lib/a.dart'}) =>
    S6ForbiddenApiCheck.findings(DartSource(path, code));

List<String> _rules(String code) => [
  for (final finding in _findings(code)) finding.rule,
];

void main() {
  test('skips when app/lib does not exist', () {
    expect(Fixture().run(const S6ForbiddenApiCheck()), skips);
  });

  test('fails on Material dialogs anywhere, the design system included', () {
    final fixture = Fixture()
      ..write(
        'app/lib/design/components/dialog_host.dart',
        '${_material}void open(BuildContext c) => showDialog(context: c, '
            'builder: (_) => const AlertDialog());\n',
      )
      ..write('app/lib/features/ok.dart', 'void ok() {}\n');
    final result = fixture.run(const S6ForbiddenApiCheck(allowlist: []));
    const expected =
        'app/lib/design/components/dialog_host.dart:2: showDialog '
        '(Material/Cupertino) is forbidden';
    expect(result, failsWith([expected]));
    expect(result, failsWith(['AlertDialog (Material/Cupertino)']));
  });

  test('passes code without forbidden APIs', () {
    final fixture = Fixture()
      ..write('app/lib/features/a.dart', '''
import 'package:flutter/widgets.dart';

// showDialog is never used; see ADR 0011.
const label = 'SnackBar';
''');
    expect(fixture.run(const S6ForbiddenApiCheck(allowlist: [])), passes);
  });

  group('api', () {
    test('every forbidden name when Material is imported', () {
      for (final api in S6ForbiddenApiCheck.forbidden.keys) {
        expect(_rules('${_material}final x = $api;'), ['api'], reason: api);
      }
    });

    test('Cupertino and Material sub-libraries count too', () {
      expect(
        _rules(
          "import 'package:flutter/cupertino.dart';\n"
          'f() => showCupertinoDialog(context: c, builder: b);',
        ),
        ['api'],
      );
      expect(
        _rules(
          "import 'package:flutter/src/material/tooltip.dart';\n"
          "f() => Tooltip(message: 'x');",
        ),
        ['api'],
      );
    });

    test('the adaptive dialog and the Cupertino sheet', () {
      expect(
        _rules(
          '${_material}f() => showAdaptiveDialog(context: c, builder: b);',
        ),
        ['api'],
      );
      expect(
        _rules(
          "import 'package:flutter/cupertino.dart';\n"
          'f() => showCupertinoSheet(context: c, builder: b);',
        ),
        ['api'],
      );
    });

    test('through an import prefix', () {
      expect(
        _rules(
          "import 'package:flutter/material.dart' as m;\n"
          "f() => m.Tooltip(message: 'x');",
        ),
        ['api'],
      );
    });

    test('not the names a hide or show keeps out', () {
      expect(
        _rules(
          "import 'package:flutter/material.dart' hide Tooltip, Dialog;\n"
          "f() => Tooltip(message: 'x'); g() => const Dialog();",
        ),
        isEmpty,
      );
      expect(
        _rules(
          "import 'package:flutter/material.dart' show Theme, ThemeData;\n"
          'f() => const TabBar();',
        ),
        isEmpty,
      );
      expect(
        _rules(
          "import 'package:flutter/material.dart' as m show Theme;\n"
          "f() => m.Tooltip(message: 'x');",
        ),
        isEmpty,
      );
    });

    test("not Ferman's own Tooltip, Dialog or a showMenu flag", () {
      expect(
        _rules(
          "import 'package:ferman/design/components/tooltip.dart';\n"
          "f() => Tooltip(message: 'x');\n"
          'final showMenu = true;',
        ),
        isEmpty,
      );
    });

    test('not members, longer names, comments or strings', () {
      expect(
        _rules(
          '$_material'
          'f() => controller.showMenu();\n'
          'g() => TabBarTheme.of(c);\n'
          'final h = SnackBarAction;\n'
          '// showDialog(context: c)\n'
          "final s = 'AlertDialog';",
        ),
        isEmpty,
      );
    });
  });

  group('getx', () {
    test('imports of GetX', () {
      expect(_rules("import 'package:get/get.dart';"), ['getx']);
      expect(_rules("import 'package:get_storage/get_storage.dart';"), [
        'getx',
      ]);
      expect(_rules("import 'package:get_it/get_it.dart';"), isEmpty);
      expect(_rules("// import 'package:get/get.dart';"), isEmpty);
    });
  });

  test('accepts a reviewed allow-list entry and flags a stale one', () {
    final fixture = Fixture()
      ..write(
        'app/lib/design/components/legacy.dart',
        '${_material}final t = Tooltip;\n',
      );
    const entry = S6Allowance(
      check: 's6_forbidden_api',
      path: 'app/lib/design/components/legacy.dart',
      rule: 'api',
      contains: 'Tooltip',
      reason: 'test entry',
    );
    expect(fixture.run(const S6ForbiddenApiCheck(allowlist: [entry])), passes);
    fixture.write('app/lib/design/components/legacy.dart', 'final t = 1;\n');
    expect(
      fixture.run(const S6ForbiddenApiCheck(allowlist: [entry])),
      failsWith(['stale allow-list entry (matches nothing)']),
    );
  });
}
