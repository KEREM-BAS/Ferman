import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

/// The findings of the literal check for [code] in a feature file.
List<S6Finding> _findings(String code) =>
    S6LiteralsCheck.findings(DartSource('app/lib/features/x.dart', code));

List<String> _rules(String code) => [
  for (final finding in _findings(code)) finding.rule,
];

void main() {
  test('skips when app/lib does not exist', () {
    expect(Fixture().run(const S6LiteralsCheck()), skips);
  });

  test('fails on literals in feature code and passes in the design system', () {
    const widget = '''
import 'package:flutter/widgets.dart';

Widget build() => const SizedBox(width: 8, child: ColoredBox(color: Color(0xFF112233)));
''';
    final fixture = Fixture()
      ..write('app/lib/features/start/start_screen.dart', widget)
      ..write('app/lib/design/components/button.dart', widget)
      ..write('app/lib/app/router.g.dart', widget);
    final result = fixture.run(const S6LiteralsCheck(allowlist: []));
    expect(
      result,
      failsWith([
        'app/lib/features/start/start_screen.dart:3: size literal (width)',
        '[size]',
      ]),
    );
    expect(result, failsWith(['start_screen.dart:3: colour literal']));
    expect(
      result.messages.where(
        (m) => m.startsWith('app/lib/design/') || m.contains('.g.dart'),
      ),
      isEmpty,
    );
  });

  test('passes clean code', () {
    final fixture = Fixture()
      ..write('app/lib/features/a.dart', '''
Widget build(BuildContext context) {
  final t = context.ferman;
  return Padding(
    padding: EdgeInsetsDirectional.only(start: t.space.space2, top: 0),
    child: SizedBox(width: t.size.panelW, height: double.infinity),
  );
}
''');
    expect(fixture.run(const S6LiteralsCheck(allowlist: [])), passes);
  });

  group('color', () {
    test('Color literals, zero included, in any form', () {
      expect(_rules('const c = Color(0xFF000000);'), ['color']);
      expect(_rules('const c = ui.Color(0x00000000);'), ['color']);
      expect(_rules('Color.fromARGB(255, 1, 2, 3)'), ['color']);
      expect(_rules('Color.fromRGBO(1, 2, 3, 0.5)'), ['color']);
      expect(_rules('Color.from(alpha: 1, red: 0, green: 0, blue: 0)'), [
        'color',
      ]);
    });

    test('not colours from variables, tokens or comments', () {
      expect(_rules('Color(value)'), isEmpty);
      expect(_rules('Color.lerp(a, b, 0.5)'), isEmpty);
      expect(_rules('ColorFilter.matrix(m)'), isEmpty);
      expect(_rules('// Color(0xFF000000)'), isEmpty);
      expect(_rules("Text('Color(0xFF000000)')"), isEmpty);
      expect(_rules('MyColor(0xFF000000)'), isEmpty);
    });

    test('Material and Cupertino colour constants', () {
      expect(_rules('Colors.red'), ['material-color']);
      expect(_rules('Colors.transparent'), ['material-color']);
      expect(_rules('CupertinoColors.systemBlue'), ['material-color']);
      expect(_rules('BrandColors.red'), isEmpty);
    });
  });

  group('duration', () {
    test('non-zero literal units', () {
      expect(_rules('Duration(milliseconds: 200)'), ['duration']);
      expect(_rules('const Duration(seconds: 1, milliseconds: 0)'), [
        'duration',
      ]);
    });

    test('not zero, Duration.zero or token durations', () {
      expect(_rules('Duration.zero'), isEmpty);
      expect(_rules('Duration(milliseconds: 0)'), isEmpty);
      expect(_rules('t.motion.durFast'), isEmpty);
      expect(
        _rules('Duration(milliseconds: t.motion.durFast.inMs * 2)'),
        isEmpty,
      );
    });
  });

  group('radius', () {
    test('circular and elliptical radius literals', () {
      expect(_rules('BorderRadius.circular(6)'), ['radius']);
      expect(_rules('BorderRadiusDirectional.circular(4)'), ['radius']);
      expect(_rules('BorderRadius.all(Radius.circular(8))'), ['radius']);
      expect(_rules('Radius.elliptical(4, 2)'), ['radius']);
    });

    test('not tokens or zero', () {
      expect(_rules('BorderRadius.circular(t.radius.radiusMd)'), isEmpty);
      expect(_rules('Radius.circular(0)'), isEmpty);
      expect(_rules('BorderRadius.zero'), isEmpty);
    });
  });

  group('insets', () {
    test('any EdgeInsets constructor with a non-zero literal', () {
      expect(_rules('EdgeInsets.all(8)'), ['insets']);
      expect(_rules('EdgeInsets.symmetric(vertical: 4)'), ['insets']);
      expect(_rules('EdgeInsetsDirectional.only(start: 12)'), ['insets']);
      expect(_rules('EdgeInsetsDirectional.fromSTEB(t.a, 2, 0, 0)'), [
        'insets',
      ]);
      expect(_rules('EdgeInsets.fromLTRB(-1, 0, 0, 0)'), ['insets']);
    });

    test('not zero or tokens', () {
      expect(_rules('EdgeInsets.zero'), isEmpty);
      expect(_rules('EdgeInsetsDirectional.only(start: 0)'), isEmpty);
      expect(_rules('EdgeInsetsDirectional.all(t.space.space3)'), isEmpty);
      expect(_rules('EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0)'), isEmpty);
    });
  });

  group('size', () {
    test('SizedBox width, height and dimension literals', () {
      expect(_rules('SizedBox(height: 12)'), ['size']);
      expect(_rules('SizedBox(width: 1.5, child: x)'), ['size']);
      expect(_rules('SizedBox.square(dimension: 16)'), ['size']);
      expect(_rules('SizedBox(width: 8, height: 8)'), ['size', 'size']);
    });

    test('size arguments of any widget or painting class', () {
      expect(_rules('Container(width: 200, height: t.size.x)'), ['size']);
      expect(_rules('BoxConstraints(maxWidth: 320)'), ['size']);
      expect(_rules('BoxConstraints.tightFor(minHeight: 28)'), ['size']);
      expect(_rules('BorderSide(color: c, width: 2)'), ['size']);
      expect(_rules('Border.all(width: 1)'), ['size']);
      expect(_rules('Icon(IconName.x, size: 16)'), ['size']);
      expect(_rules('Row(spacing: 4, children: c)'), ['size']);
      expect(_rules('BoxShadow(blurRadius: 12, color: c)'), ['size']);
      expect(_rules('TextStyle(letterSpacing: 0.2)'), ['size']);
      expect(_rules('ListView(itemExtent: 32)'), ['size']);
      expect(_rules('Icon(\n  name,\n  size: 16,\n)'), ['size']);
    });

    test('Size constructors', () {
      expect(_rules('const Size(1280, 800)'), ['size']);
      expect(_rules('ui.Size(t.a, 40)'), ['size']);
      expect(_rules('Size.square(16)'), ['size']);
      expect(_rules('Size.fromWidth(240)'), ['size']);
      expect(_rules('Size.fromHeight(32)'), ['size']);
      expect(_rules('Size.fromRadius(4)'), ['size']);
    });

    test('not zero, infinity, tokens or shrink', () {
      expect(_rules('SizedBox(width: 0)'), isEmpty);
      expect(_rules('SizedBox(width: double.infinity)'), isEmpty);
      expect(_rules('SizedBox(width: t.size.sidebarW)'), isEmpty);
      expect(_rules('SizedBox.shrink()'), isEmpty);
      expect(_rules('SizedBox.expand(child: x)'), isEmpty);
      expect(_rules('Container(width: t.size.panelW, height: 0)'), isEmpty);
      expect(_rules('Icon(name, size: t.density.iconMd)'), isEmpty);
      expect(_rules('Size(t.size.panelW, t.density.barH)'), isEmpty);
      expect(_rules('Size.zero'), isEmpty);
      expect(_rules('PaperSize(210, 297)'), isEmpty);
      expect(_rules('MediaQuery.sizeOf(context)'), isEmpty);
    });

    test('not a ternary, a comment or a string', () {
      expect(_rules('final w = wide ? size : 16;'), isEmpty);
      expect(_rules('// SizedBox(width: 8)'), isEmpty);
      expect(_rules("Text('width: 8')"), isEmpty);
      expect(_rules('mySize(width: t.x)'), isEmpty);
    });
  });

  group('font-size', () {
    test('literal font sizes', () {
      expect(_rules('TextStyle(fontSize: 14)'), ['font-size']);
      expect(_rules('style.copyWith(fontSize: 11, color: c)'), ['font-size']);
    });

    test('not role sizes or zero', () {
      expect(_rules('TextStyle(fontSize: t.typeScale.sizeMd)'), isEmpty);
      expect(_rules('TextStyle(fontSize: 0)'), isEmpty);
    });
  });

  group('theme-bypass', () {
    test('a varying token set read from its constant', () {
      expect(_rules('final c = FermanColorTokens.light.textPrimary;'), [
        'theme-bypass',
      ]);
      expect(_rules('FermanMotionTokens.standard.durFast'), ['theme-bypass']);
      expect(_rules('FermanDensityTokens . touch'), ['theme-bypass']);
      expect(_rules('FermanTypeRoleTokens.standard.body'), ['theme-bypass']);
      expect(_rules('FermanElevationTokens.dark'), ['theme-bypass']);
      expect(_rules('FermanFocusTokens.light'), ['theme-bypass']);
      expect(_rules('FermanPageFilterTokens.dim'), ['theme-bypass']);
      expect(_rules('FermanTheme.dark.colors'), ['theme-bypass']);
      expect(_rules('FermanTheme.forBrightness(b)'), ['theme-bypass']);
    });

    test('names the bypass in the message', () {
      expect(
        _findings('FermanColorTokens.dark.accent').single.message,
        startsWith('FermanColorTokens.dark bypasses the theme'),
      );
    });

    test('not context.ferman, the constant sets, types or comments', () {
      expect(_rules('context.ferman.colors.textPrimary'), isEmpty);
      expect(_rules('FermanTheme.of(context)'), isEmpty);
      expect(_rules('FermanTheme.motionFor(reduceMotion: r)'), isEmpty);
      expect(_rules('FermanSpaceTokens.space2'), isEmpty);
      expect(_rules('FermanTypeTokens.fontUi'), isEmpty);
      expect(_rules('final FermanColorTokens colors;'), isEmpty);
      expect(_rules('// FermanColorTokens.light'), isEmpty);
      expect(_rules('MyFermanColorTokens.light'), isEmpty);
    });
  });

  test('skips the design system and the engine services', () {
    const code = '''
final d = Duration(seconds: 30);
final c = FermanColorTokens.light;
''';
    final fixture = Fixture()
      ..write('app/lib/design/components/a.dart', code)
      ..write('app/lib/engine/document_service.dart', code)
      ..write('app/lib/features/engine/b.dart', code);
    final result = fixture.run(const S6LiteralsCheck(allowlist: []));
    expect(result, failsWith(['app/lib/features/engine/b.dart:1:']));
    expect(
      result.messages.where(
        (m) =>
            m.startsWith('app/lib/design/') || m.startsWith('app/lib/engine/'),
      ),
      isEmpty,
    );
  });

  test('reports each finding with its line and source', () {
    final findings = _findings('a();\nfinal c = Color(0xFF000000);\n');
    expect(findings.single.line, 2);
    expect(findings.single.source, 'final c = Color(0xFF000000);');
    expect(
      '${findings.single}',
      'app/lib/features/x.dart:2: colour literal; use a token from '
          'context.ferman (ADR 0012) [color]: final c = Color(0xFF000000);',
    );
  });

  test('accepts a reviewed allow-list entry', () {
    final fixture = Fixture()
      ..write('app/lib/features/a.dart', 'final d = Duration(seconds: 30);\n');
    const allowlist = [
      S6Allowance(
        check: 's6_literals',
        path: 'app/lib/features/a.dart',
        rule: 'duration',
        contains: 'seconds: 30',
        reason: 'a network timeout, not motion',
      ),
    ];
    expect(
      fixture.run(const S6LiteralsCheck(allowlist: allowlist)),
      hasResult(Status.pass, ['1 finding accepted by the allow-list']),
    );
  });
}
