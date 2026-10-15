import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  const check = ArbParityCheck();
  const en = '''
{
  "@@locale": "en",
  "appTitle": "Ferman",
  "@appTitle": {"description": "The app name."},
  "openFile": "Open file"
}
''';
  const tr = '''
{
  "@@locale": "tr",
  "appTitle": "Ferman",
  "openFile": "Dosya aç"
}
''';

  Fixture withFiles({String? english = en, String? turkish = tr, String? ar}) {
    final fixture = Fixture();
    if (english != null) fixture.write('app/lib/l10n/app_en.arb', english);
    if (turkish != null) fixture.write('app/lib/l10n/app_tr.arb', turkish);
    if (ar != null) fixture.write('app/lib/l10n/app_ar.arb', ar);
    return fixture;
  }

  test('skips without app_en.arb or app_tr.arb', () {
    expect(withFiles(english: null).run(check), skips);
    expect(withFiles(turkish: null).run(check), skips);
  });

  test('labels each listed key and summarises the rest unlabelled', () {
    final keys = [for (var i = 0; i < 22; i++) 'key${i + 10}'];
    final english = '{${[for (final key in keys) '"$key": "x"'].join(', ')}}';
    final messages = withFiles(
      english: english,
      turkish: '{}',
    ).run(check).messages;
    expect(messages, hasLength(21));
    expect(messages.first, 'app_tr.arb is missing key10');
    expect(
      messages.take(20),
      everyElement(startsWith('app_tr.arb is missing ')),
    );
    expect(messages.last, '... and 2 more');
  });

  test('passes when Turkish has the English keys and Arabic a subset', () {
    final fixture = withFiles(ar: '{"@@locale": "ar", "openFile": "فتح"}');
    expect(fixture.run(check), passes);
  });

  test('fails when Turkish misses a key or has an extra one', () {
    final fixture = withFiles(
      turkish: '{"@@locale": "tr", "appTitle": "Ferman", "closeFile": "Kapat"}',
    );
    expect(
      fixture.run(check),
      failsWith([
        'app_tr.arb is missing openFile',
        'app_tr.arb has closeFile, which app_en.arb does not',
      ]),
    );
  });

  test('fails when Arabic has a key English does not', () {
    final fixture = withFiles(ar: '{"saveFile": "حفظ"}');
    expect(
      fixture.run(check),
      failsWith(['app_ar.arb has saveFile, which app_en.arb does not']),
    );
  });

  test('fails on a file that is not a JSON object', () {
    expect(
      withFiles(turkish: '["appTitle"]').run(check),
      failsWith(['app/lib/l10n/app_tr.arb: not a JSON object']),
    );
    expect(
      withFiles(turkish: '{"appTitle": ').run(check),
      failsWith(['app/lib/l10n/app_tr.arb:']),
    );
  });

  test('messageKeys ignores metadata', () {
    expect(ArbParityCheck.messageKeys(en), {'appTitle', 'openFile'});
  });
}
