import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

void main() {
  // The fixture keeps the product name in both files, as the app does.
  const check = ArbParityCheck(sameInTurkish: {'appTitle': 'the app name'});
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

  test('fails on an engine message key without its sentence', () {
    final fixture = withFiles()
      ..write(
        'crates/ferman-api/src/facade/error.rs',
        'pub const A: Self = Self("openFile");\n'
            'pub const B: Self = Self("errorDamaged");\n',
      );
    expect(fixture.run(check).messages, [
      'app_en.arb is missing the engine message errorDamaged '
          '(crates/ferman-api/src/facade/error.rs)',
    ]);
  });

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
    ).run(const ArbParityCheck(sameInTurkish: {})).messages;
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

  test('fails when Turkish repeats the English text of a key', () {
    final fixture = withFiles(
      turkish:
          '{"@@locale": "tr", "appTitle": "Ferman", "openFile": '
          '"Open file"}',
    );
    expect(
      fixture.run(check),
      failsWith(['app_tr.arb repeats the English text of openFile']),
    );
  });

  test('a listed key may keep the English text; a stale entry fails', () {
    // appTitle is listed and equal: passes (the default fixture).
    expect(withFiles().run(check), passes);
    // Listed but translated now, or no longer in English: both fail.
    const stale = ArbParityCheck(
      sameInTurkish: {'openFile': 'test', 'gone': 'test'},
    );
    final messages = withFiles(
      turkish:
          '{"@@locale": "tr", "appTitle": "Ferman", "openFile": '
          '"Dosya aç"}',
    ).run(stale).messages;
    expect(
      messages,
      containsAll([
        contains('lists gone, which app_en.arb does not have'),
        contains('lists openFile, whose Turkish now differs'),
        contains('repeats the English text of appTitle'),
      ]),
    );
  });

  test('the repository list names a reason for every key', () {
    for (final reason in ArbParityCheck.repositorySameInTurkish.values) {
      expect(reason.trim(), isNotEmpty);
    }
  });
}
