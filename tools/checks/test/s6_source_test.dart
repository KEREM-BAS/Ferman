import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  group('maskDart', () {
    test('blanks comments and keeps line breaks and length', () {
      const source =
          'a(); // Color(0xFF000000)\n'
          '/// SizedBox(width: 8)\n'
          'b(); /* x /* nested */ still */ c();\n';
      final masked = maskDart(source);
      expect(masked.length, source.length);
      expect(masked.split('\n').length, source.split('\n').length);
      expect(masked, isNot(contains('Color')));
      expect(masked, isNot(contains('SizedBox')));
      expect(masked, isNot(contains('nested')));
      expect(masked, isNot(contains('still')));
      expect(masked, contains('a();'));
      expect(masked, contains('c();'));
    });

    test('blanks string contents and keeps the quotes', () {
      final masked = maskDart(
        "x('Colors.red'); y(\"TabBar\"); z('it\\'s', r'\\d+');",
      );
      expect(masked, isNot(contains('Colors')));
      expect(masked, isNot(contains('TabBar')));
      expect(masked, isNot(contains('it')));
      expect(masked, isNot(contains(r'\d')));
      expect(masked, startsWith("x('"));
      expect(masked, contains('z('));
    });

    test('blanks triple-quoted strings across lines', () {
      final masked = maskDart("x = '''\nshowDialog(\n''';\nshowMenu();");
      expect(masked, isNot(contains('showDialog')));
      expect(masked, contains('showMenu();'));
      expect('\n'.allMatches(masked), hasLength(3));
    });

    test('keeps the code of interpolations', () {
      final masked = maskDart(
        r"""t('Hi ${name.toUpperCase()} and ${ {'a': 1}['a'] } $x end');""",
      );
      expect(masked, contains('name.toUpperCase()'));
      // Strings inside an interpolation are blanked too.
      expect(masked, contains(": 1}['"));
      expect(masked, isNot(contains('Hi')));
      expect(masked, isNot(contains('end')));
      expect(masked, isNot(contains(r'$x')));
    });

    test('does not treat raw strings as interpolating', () {
      final masked = maskDart(r"""a(r'${b.toUpperCase()}'); c();""");
      expect(masked, isNot(contains('toUpperCase')));
      expect(masked, contains('c();'));
    });

    test('recovers from an unterminated string at the line end', () {
      final masked = maskDart("a('oops\nshowDialog();");
      expect(masked, contains('showDialog();'));
    });
  });

  group('numberValue', () {
    test('reads numeric literals', () {
      expect(numberValue('8'), 8);
      expect(numberValue(' -2 '), -2);
      expect(numberValue('0.5'), 0.5);
      expect(numberValue('.5'), 0.5);
      expect(numberValue('1_000'), 1000);
      expect(numberValue('0xFF'), 255);
      expect(numberValue('0x00000000'), 0);
      expect(numberValue('1e3'), 1000);
      expect(numberValue('0'), 0);
      expect(numberValue('0.0'), 0);
    });

    test('rejects everything else', () {
      for (final expression in [
        'space',
        'space * 2',
        '8 + 1',
        'double.infinity',
        't.space2',
        '',
        '-',
        '8.',
      ]) {
        expect(numberValue(expression), isNull, reason: expression);
      }
    });
  });

  group('splitArguments', () {
    test('splits at top-level commas and names arguments', () {
      final arguments = splitArguments(
        'a, b: f(1, 2), c: [3, 4], d: x ? 1 : 2, e: {k: v},',
      );
      expect(arguments.map((a) => a.name), [null, 'b', 'c', 'd', 'e']);
      expect(arguments.map((a) => a.value), [
        'a',
        'f(1, 2)',
        '[3, 4]',
        'x ? 1 : 2',
        '{k: v}',
      ]);
    });

    test('keeps a conditional positional argument unnamed', () {
      final arguments = splitArguments('wide ? 8 : 4');
      expect(arguments.single.name, isNull);
    });

    test('reports literal kinds', () {
      final arguments = splitArguments('8, 0, x, -1.5');
      expect(arguments.map((a) => a.isNumber), [true, true, false, true]);
      expect(arguments.map((a) => a.isNonZeroNumber), [
        true,
        false,
        false,
        true,
      ]);
      expect(arguments.map((a) => a.isZero), [false, true, false, false]);
    });
  });

  group('DartSource', () {
    test('finds calls with their arguments', () {
      final source = DartSource(
        'app/lib/a.dart',
        'f(SizedBox(width: g(1), height: 2));\n// SizedBox(width: 3)\n'
            'SizedBox(\n  height: 4,\n);\n',
      );
      final calls = source.calls(r'\bSizedBox\s*\(').toList();
      expect(calls, hasLength(2));
      expect(calls.first.named('width')?.value, 'g(1)');
      expect(calls.first.named('height')?.isNonZeroNumber, isTrue);
      expect(source.lineOf(calls.last.offset), 3);
      expect(source.finding(calls.last.offset, 'r', 'm').source, 'SizedBox(');
    });

    test('reads import and export directives', () {
      final source = DartSource('app/lib/a.dart', '''
library;

import 'package:flutter/material.dart' hide Tooltip, Dialog;
import 'package:flutter/material.dart' as m show Tooltip;
import "package:flutter/cupertino.dart" show CupertinoColors;
export 'src/x.dart' if (dart.library.io) 'src/y.dart';
// import 'package:get/get.dart';
''');
      final directives = source.directives;
      expect(directives, hasLength(4));
      final hide = directives[0];
      expect(hide.uris, ['package:flutter/material.dart']);
      expect(hide.prefix, isNull);
      expect(hide.shown, isNull);
      expect(hide.hidden, {'Tooltip', 'Dialog'});
      expect(hide.showsUnprefixed('Tooltip'), isFalse);
      expect(hide.showsUnprefixed('SnackBar'), isTrue);
      final prefixed = directives[1];
      expect(prefixed.prefix, 'm');
      expect(prefixed.shown, {'Tooltip'});
      expect(prefixed.showsUnprefixed('Tooltip'), isFalse);
      final show = directives[2];
      expect(show.showsUnprefixed('CupertinoColors'), isTrue);
      expect(show.showsUnprefixed('showCupertinoDialog'), isFalse);
      final export = directives[3];
      expect(export.isExport, isTrue);
      expect(export.uris, ['src/x.dart', 'src/y.dart']);
      expect(source.lineOf(export.offset), 6);
    });
  });

  group('appSources', () {
    test('lists hand-written Dart files and skips generated ones', () {
      final fixture = Fixture()
        ..write('app/lib/main.dart', '')
        ..write('app/lib/app/router.dart', '')
        ..write('app/lib/app/router.g.dart', '')
        ..write('app/lib/x.freezed.dart', '')
        ..write('app/lib/bridge/frb_generated.dart', '')
        ..write('app/lib/l10n/gen/app_localizations.dart', '')
        ..write('app/lib/l10n/casing.dart', '')
        ..write('app/lib/assets/readme.md', '');
      final sources = appSources(fixture.context())!;
      expect(sources.map((s) => s.path), [
        'app/lib/app/router.dart',
        'app/lib/l10n/casing.dart',
        'app/lib/main.dart',
      ]);
      final filtered = appSources(
        fixture.context(),
        include: (path) => !path.startsWith('app/lib/l10n/'),
      )!;
      expect(filtered.map((s) => s.path), [
        'app/lib/app/router.dart',
        'app/lib/main.dart',
      ]);
    });

    test('is null without app/lib', () {
      expect(appSources(Fixture().context()), isNull);
    });

    test('isGenerated', () {
      expect(isGenerated('app/lib/design/tokens.g.dart'), isTrue);
      expect(isGenerated('app/lib/bridge/api.dart'), isTrue);
      expect(isGenerated('app/lib/l10n/gen/app_localizations_tr.dart'), isTrue);
      expect(isGenerated('app/lib/design/theme.dart'), isFalse);
      expect(isGenerated('app/lib/l10n/casing.dart'), isFalse);
    });
  });
}
