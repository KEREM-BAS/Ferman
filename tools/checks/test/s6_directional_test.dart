import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

List<String> _rules(String code) => [
  for (final finding in S6DirectionalCheck.findings(
    DartSource('app/lib/design/components/a.dart', code),
  ))
    finding.rule,
];

void main() {
  test('skips when app/lib does not exist', () {
    expect(Fixture().run(const S6DirectionalCheck()), skips);
  });

  test('fails in feature code and in the design system', () {
    final fixture = Fixture()
      ..write(
        'app/lib/design/components/button.dart',
        'final p = EdgeInsets.only(left: x);\n',
      )
      ..write(
        'app/lib/features/shell/title_bar.dart',
        'final a = Alignment.centerLeft;\n',
      )
      ..write('app/lib/l10n/gen/x.dart', 'final a = Alignment.centerLeft;\n');
    final result = fixture.run(const S6DirectionalCheck(allowlist: []));
    const expected1 =
        'app/lib/design/components/button.dart:1: EdgeInsets.only with '
        'left/right; use EdgeInsetsDirectional [insets]';
    expect(result, failsWith([expected1]));
    const expected2 =
        'app/lib/features/shell/title_bar.dart:1: Alignment.centerLeft; use '
        'AlignmentDirectional [alignment]';
    expect(result, failsWith([expected2]));
    expect(result.messages.where((m) => m.contains('/gen/')), isEmpty);
  });

  test('passes directional code', () {
    final fixture = Fixture()
      ..write('app/lib/features/a.dart', '''
final a = Padding(padding: EdgeInsetsDirectional.only(start: s, end: e));
final b = Align(alignment: AlignmentDirectional.centerStart);
final c = PositionedDirectional(start: 0, top: 0, child: x);
final d = Text(label, textAlign: TextAlign.start);
final e = BorderRadiusDirectional.only(topStart: r);
final f = BorderDirectional(start: side);
final g = EdgeInsets.symmetric(vertical: v);
final h = EdgeInsets.only(top: t, bottom: b);
final i = Alignment.center;
final j = Positioned.fill(child: x);
final k = Positioned(top: 0, bottom: 0, child: x);
final l = Alignment(0, -1);
final m = BorderRadius.vertical(top: r);
''');
    expect(fixture.run(const S6DirectionalCheck(allowlist: [])), passes);
  });

  test('insets', () {
    expect(_rules('EdgeInsets.only(left: 4)'), ['insets']);
    expect(_rules('EdgeInsets.only(top: 2, right: 4)'), ['insets']);
    expect(_rules('EdgeInsets.fromLTRB(0, 4, 0, 4)'), ['insets']);
    expect(_rules('EdgeInsets.symmetric(horizontal: h)'), ['insets']);
    expect(_rules('EdgeInsets.symmetric(vertical: 2)'), isEmpty);
    expect(_rules('EdgeInsets.all(8)'), isEmpty);
    expect(_rules('EdgeInsetsDirectional.only(start: 4)'), isEmpty);
  });

  test('alignment', () {
    for (final name in [
      'topLeft',
      'topRight',
      'centerLeft',
      'centerRight',
      'bottomLeft',
      'bottomRight',
    ]) {
      expect(_rules('Alignment.$name'), ['alignment'], reason: name);
      expect(_rules('FractionalOffset.$name'), ['alignment'], reason: name);
    }
    expect(_rules('Alignment(-1, 0)'), ['alignment']);
    expect(_rules('Alignment(x, 0)'), ['alignment']);
    expect(_rules('Alignment(0.0, 1)'), isEmpty);
    expect(_rules('Alignment.topCenter'), isEmpty);
    expect(_rules('AlignmentDirectional.topStart'), isEmpty);
    expect(_rules('AlignmentDirectional(-1, 0)'), isEmpty);
  });

  test('positioned', () {
    expect(_rules('Positioned(left: 8, child: x)'), ['positioned']);
    expect(_rules('Positioned(left: 0, right: 0, child: x)'), ['positioned']);
    expect(_rules('Positioned.fill(right: 4, child: x)'), ['positioned']);
    expect(_rules('Positioned.fromRect(rect: r, child: x)'), ['positioned']);
    expect(_rules('Positioned.fromRelativeRect(rect: r, child: x)'), [
      'positioned',
    ]);
    expect(
      _rules('Positioned.directional(textDirection: d, start: 0)'),
      isEmpty,
    );
    expect(_rules('PositionedDirectional(end: 8, child: x)'), isEmpty);
  });

  test('text-align', () {
    expect(_rules('TextAlign.left'), ['text-align']);
    expect(_rules('TextAlign.right'), ['text-align']);
    expect(_rules('TextAlign.start'), isEmpty);
    expect(_rules('TextAlign.center'), isEmpty);
  });

  test('border-radius and border', () {
    expect(_rules('BorderRadius.only(topLeft: r)'), ['border-radius']);
    expect(_rules('BorderRadius.horizontal(left: r)'), ['border-radius']);
    expect(_rules('BorderRadius.only()'), isEmpty);
    expect(_rules('BorderRadius.circular(r)'), isEmpty);
    expect(_rules('Border(left: side)'), ['border']);
    expect(_rules('Border(top: side)'), isEmpty);
    expect(_rules('Border.all(color: c)'), isEmpty);
    expect(_rules('BorderSide(color: c)'), isEmpty);
  });

  test('ignores comments and strings', () {
    expect(
      _rules("// Alignment.centerLeft\nfinal s = 'TextAlign.left';"),
      isEmpty,
    );
  });

  test('a folder allow-list entry covers the never-mirrored canvas', () {
    final fixture = Fixture()
      ..write(
        'app/lib/features/viewer/canvas/page_layer.dart',
        'final p = Positioned(left: x, top: y, child: page);\n',
      )
      ..write(
        'app/lib/features/viewer/canvas/tile_layer.dart',
        'final p = Positioned(left: x, top: y, child: tile);\n',
      );
    const allowlist = [
      S6Allowance(
        check: 's6_directional',
        path: 'app/lib/features/viewer/canvas/',
        rule: 'positioned',
        reason: 'the PDF canvas is never mirrored (ARCHITECTURE §11.4)',
      ),
    ];
    expect(
      fixture.run(const S6DirectionalCheck(allowlist: allowlist)),
      hasResult(Status.pass, ['2 findings accepted by the allow-list']),
    );
  });
}
