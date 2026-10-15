import 'package:ferman/l10n/casing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// All 119 data lines of SpecialCasing-15.0.0.txt, copied verbatim and in
// file order (the comment-only lines are left out). Source: Unicode
// Character Database 15.0.0,
// https://www.unicode.org/Public/15.0.0/ucd/SpecialCasing.txt, "Date:
// 2022-02-02, 23:35:52 GMT", © 2022 Unicode®, Inc., Unicode License v3.
// Format: <code>; <lower>; <title>; <upper>; (<condition_list>;)?

/// The unconditional mappings: every language, no context.
const String _unconditional = '''
00DF; 00DF; 0053 0073; 0053 0053; # LATIN SMALL LETTER SHARP S
0130; 0069 0307; 0130; 0130; # LATIN CAPITAL LETTER I WITH DOT ABOVE
FB00; FB00; 0046 0066; 0046 0046; # LATIN SMALL LIGATURE FF
FB01; FB01; 0046 0069; 0046 0049; # LATIN SMALL LIGATURE FI
FB02; FB02; 0046 006C; 0046 004C; # LATIN SMALL LIGATURE FL
FB03; FB03; 0046 0066 0069; 0046 0046 0049; # LATIN SMALL LIGATURE FFI
FB04; FB04; 0046 0066 006C; 0046 0046 004C; # LATIN SMALL LIGATURE FFL
FB05; FB05; 0053 0074; 0053 0054; # LATIN SMALL LIGATURE LONG S T
FB06; FB06; 0053 0074; 0053 0054; # LATIN SMALL LIGATURE ST
0587; 0587; 0535 0582; 0535 0552; # ARMENIAN SMALL LIGATURE ECH YIWN
FB13; FB13; 0544 0576; 0544 0546; # ARMENIAN SMALL LIGATURE MEN NOW
FB14; FB14; 0544 0565; 0544 0535; # ARMENIAN SMALL LIGATURE MEN ECH
FB15; FB15; 0544 056B; 0544 053B; # ARMENIAN SMALL LIGATURE MEN INI
FB16; FB16; 054E 0576; 054E 0546; # ARMENIAN SMALL LIGATURE VEW NOW
FB17; FB17; 0544 056D; 0544 053D; # ARMENIAN SMALL LIGATURE MEN XEH
0149; 0149; 02BC 004E; 02BC 004E; # LATIN SMALL LETTER N PRECEDED BY APOSTROPHE
0390; 0390; 0399 0308 0301; 0399 0308 0301; # GREEK SMALL LETTER IOTA WITH DIALYTIKA AND TONOS
03B0; 03B0; 03A5 0308 0301; 03A5 0308 0301; # GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND TONOS
01F0; 01F0; 004A 030C; 004A 030C; # LATIN SMALL LETTER J WITH CARON
1E96; 1E96; 0048 0331; 0048 0331; # LATIN SMALL LETTER H WITH LINE BELOW
1E97; 1E97; 0054 0308; 0054 0308; # LATIN SMALL LETTER T WITH DIAERESIS
1E98; 1E98; 0057 030A; 0057 030A; # LATIN SMALL LETTER W WITH RING ABOVE
1E99; 1E99; 0059 030A; 0059 030A; # LATIN SMALL LETTER Y WITH RING ABOVE
1E9A; 1E9A; 0041 02BE; 0041 02BE; # LATIN SMALL LETTER A WITH RIGHT HALF RING
1F50; 1F50; 03A5 0313; 03A5 0313; # GREEK SMALL LETTER UPSILON WITH PSILI
1F52; 1F52; 03A5 0313 0300; 03A5 0313 0300; # GREEK SMALL LETTER UPSILON WITH PSILI AND VARIA
1F54; 1F54; 03A5 0313 0301; 03A5 0313 0301; # GREEK SMALL LETTER UPSILON WITH PSILI AND OXIA
1F56; 1F56; 03A5 0313 0342; 03A5 0313 0342; # GREEK SMALL LETTER UPSILON WITH PSILI AND PERISPOMENI
1FB6; 1FB6; 0391 0342; 0391 0342; # GREEK SMALL LETTER ALPHA WITH PERISPOMENI
1FC6; 1FC6; 0397 0342; 0397 0342; # GREEK SMALL LETTER ETA WITH PERISPOMENI
1FD2; 1FD2; 0399 0308 0300; 0399 0308 0300; # GREEK SMALL LETTER IOTA WITH DIALYTIKA AND VARIA
1FD3; 1FD3; 0399 0308 0301; 0399 0308 0301; # GREEK SMALL LETTER IOTA WITH DIALYTIKA AND OXIA
1FD6; 1FD6; 0399 0342; 0399 0342; # GREEK SMALL LETTER IOTA WITH PERISPOMENI
1FD7; 1FD7; 0399 0308 0342; 0399 0308 0342; # GREEK SMALL LETTER IOTA WITH DIALYTIKA AND PERISPOMENI
1FE2; 1FE2; 03A5 0308 0300; 03A5 0308 0300; # GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND VARIA
1FE3; 1FE3; 03A5 0308 0301; 03A5 0308 0301; # GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND OXIA
1FE4; 1FE4; 03A1 0313; 03A1 0313; # GREEK SMALL LETTER RHO WITH PSILI
1FE6; 1FE6; 03A5 0342; 03A5 0342; # GREEK SMALL LETTER UPSILON WITH PERISPOMENI
1FE7; 1FE7; 03A5 0308 0342; 03A5 0308 0342; # GREEK SMALL LETTER UPSILON WITH DIALYTIKA AND PERISPOMENI
1FF6; 1FF6; 03A9 0342; 03A9 0342; # GREEK SMALL LETTER OMEGA WITH PERISPOMENI
1F80; 1F80; 1F88; 1F08 0399; # GREEK SMALL LETTER ALPHA WITH PSILI AND YPOGEGRAMMENI
1F81; 1F81; 1F89; 1F09 0399; # GREEK SMALL LETTER ALPHA WITH DASIA AND YPOGEGRAMMENI
1F82; 1F82; 1F8A; 1F0A 0399; # GREEK SMALL LETTER ALPHA WITH PSILI AND VARIA AND YPOGEGRAMMENI
1F83; 1F83; 1F8B; 1F0B 0399; # GREEK SMALL LETTER ALPHA WITH DASIA AND VARIA AND YPOGEGRAMMENI
1F84; 1F84; 1F8C; 1F0C 0399; # GREEK SMALL LETTER ALPHA WITH PSILI AND OXIA AND YPOGEGRAMMENI
1F85; 1F85; 1F8D; 1F0D 0399; # GREEK SMALL LETTER ALPHA WITH DASIA AND OXIA AND YPOGEGRAMMENI
1F86; 1F86; 1F8E; 1F0E 0399; # GREEK SMALL LETTER ALPHA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI
1F87; 1F87; 1F8F; 1F0F 0399; # GREEK SMALL LETTER ALPHA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI
1F88; 1F80; 1F88; 1F08 0399; # GREEK CAPITAL LETTER ALPHA WITH PSILI AND PROSGEGRAMMENI
1F89; 1F81; 1F89; 1F09 0399; # GREEK CAPITAL LETTER ALPHA WITH DASIA AND PROSGEGRAMMENI
1F8A; 1F82; 1F8A; 1F0A 0399; # GREEK CAPITAL LETTER ALPHA WITH PSILI AND VARIA AND PROSGEGRAMMENI
1F8B; 1F83; 1F8B; 1F0B 0399; # GREEK CAPITAL LETTER ALPHA WITH DASIA AND VARIA AND PROSGEGRAMMENI
1F8C; 1F84; 1F8C; 1F0C 0399; # GREEK CAPITAL LETTER ALPHA WITH PSILI AND OXIA AND PROSGEGRAMMENI
1F8D; 1F85; 1F8D; 1F0D 0399; # GREEK CAPITAL LETTER ALPHA WITH DASIA AND OXIA AND PROSGEGRAMMENI
1F8E; 1F86; 1F8E; 1F0E 0399; # GREEK CAPITAL LETTER ALPHA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI
1F8F; 1F87; 1F8F; 1F0F 0399; # GREEK CAPITAL LETTER ALPHA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI
1F90; 1F90; 1F98; 1F28 0399; # GREEK SMALL LETTER ETA WITH PSILI AND YPOGEGRAMMENI
1F91; 1F91; 1F99; 1F29 0399; # GREEK SMALL LETTER ETA WITH DASIA AND YPOGEGRAMMENI
1F92; 1F92; 1F9A; 1F2A 0399; # GREEK SMALL LETTER ETA WITH PSILI AND VARIA AND YPOGEGRAMMENI
1F93; 1F93; 1F9B; 1F2B 0399; # GREEK SMALL LETTER ETA WITH DASIA AND VARIA AND YPOGEGRAMMENI
1F94; 1F94; 1F9C; 1F2C 0399; # GREEK SMALL LETTER ETA WITH PSILI AND OXIA AND YPOGEGRAMMENI
1F95; 1F95; 1F9D; 1F2D 0399; # GREEK SMALL LETTER ETA WITH DASIA AND OXIA AND YPOGEGRAMMENI
1F96; 1F96; 1F9E; 1F2E 0399; # GREEK SMALL LETTER ETA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI
1F97; 1F97; 1F9F; 1F2F 0399; # GREEK SMALL LETTER ETA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI
1F98; 1F90; 1F98; 1F28 0399; # GREEK CAPITAL LETTER ETA WITH PSILI AND PROSGEGRAMMENI
1F99; 1F91; 1F99; 1F29 0399; # GREEK CAPITAL LETTER ETA WITH DASIA AND PROSGEGRAMMENI
1F9A; 1F92; 1F9A; 1F2A 0399; # GREEK CAPITAL LETTER ETA WITH PSILI AND VARIA AND PROSGEGRAMMENI
1F9B; 1F93; 1F9B; 1F2B 0399; # GREEK CAPITAL LETTER ETA WITH DASIA AND VARIA AND PROSGEGRAMMENI
1F9C; 1F94; 1F9C; 1F2C 0399; # GREEK CAPITAL LETTER ETA WITH PSILI AND OXIA AND PROSGEGRAMMENI
1F9D; 1F95; 1F9D; 1F2D 0399; # GREEK CAPITAL LETTER ETA WITH DASIA AND OXIA AND PROSGEGRAMMENI
1F9E; 1F96; 1F9E; 1F2E 0399; # GREEK CAPITAL LETTER ETA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI
1F9F; 1F97; 1F9F; 1F2F 0399; # GREEK CAPITAL LETTER ETA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI
1FA0; 1FA0; 1FA8; 1F68 0399; # GREEK SMALL LETTER OMEGA WITH PSILI AND YPOGEGRAMMENI
1FA1; 1FA1; 1FA9; 1F69 0399; # GREEK SMALL LETTER OMEGA WITH DASIA AND YPOGEGRAMMENI
1FA2; 1FA2; 1FAA; 1F6A 0399; # GREEK SMALL LETTER OMEGA WITH PSILI AND VARIA AND YPOGEGRAMMENI
1FA3; 1FA3; 1FAB; 1F6B 0399; # GREEK SMALL LETTER OMEGA WITH DASIA AND VARIA AND YPOGEGRAMMENI
1FA4; 1FA4; 1FAC; 1F6C 0399; # GREEK SMALL LETTER OMEGA WITH PSILI AND OXIA AND YPOGEGRAMMENI
1FA5; 1FA5; 1FAD; 1F6D 0399; # GREEK SMALL LETTER OMEGA WITH DASIA AND OXIA AND YPOGEGRAMMENI
1FA6; 1FA6; 1FAE; 1F6E 0399; # GREEK SMALL LETTER OMEGA WITH PSILI AND PERISPOMENI AND YPOGEGRAMMENI
1FA7; 1FA7; 1FAF; 1F6F 0399; # GREEK SMALL LETTER OMEGA WITH DASIA AND PERISPOMENI AND YPOGEGRAMMENI
1FA8; 1FA0; 1FA8; 1F68 0399; # GREEK CAPITAL LETTER OMEGA WITH PSILI AND PROSGEGRAMMENI
1FA9; 1FA1; 1FA9; 1F69 0399; # GREEK CAPITAL LETTER OMEGA WITH DASIA AND PROSGEGRAMMENI
1FAA; 1FA2; 1FAA; 1F6A 0399; # GREEK CAPITAL LETTER OMEGA WITH PSILI AND VARIA AND PROSGEGRAMMENI
1FAB; 1FA3; 1FAB; 1F6B 0399; # GREEK CAPITAL LETTER OMEGA WITH DASIA AND VARIA AND PROSGEGRAMMENI
1FAC; 1FA4; 1FAC; 1F6C 0399; # GREEK CAPITAL LETTER OMEGA WITH PSILI AND OXIA AND PROSGEGRAMMENI
1FAD; 1FA5; 1FAD; 1F6D 0399; # GREEK CAPITAL LETTER OMEGA WITH DASIA AND OXIA AND PROSGEGRAMMENI
1FAE; 1FA6; 1FAE; 1F6E 0399; # GREEK CAPITAL LETTER OMEGA WITH PSILI AND PERISPOMENI AND PROSGEGRAMMENI
1FAF; 1FA7; 1FAF; 1F6F 0399; # GREEK CAPITAL LETTER OMEGA WITH DASIA AND PERISPOMENI AND PROSGEGRAMMENI
1FB3; 1FB3; 1FBC; 0391 0399; # GREEK SMALL LETTER ALPHA WITH YPOGEGRAMMENI
1FBC; 1FB3; 1FBC; 0391 0399; # GREEK CAPITAL LETTER ALPHA WITH PROSGEGRAMMENI
1FC3; 1FC3; 1FCC; 0397 0399; # GREEK SMALL LETTER ETA WITH YPOGEGRAMMENI
1FCC; 1FC3; 1FCC; 0397 0399; # GREEK CAPITAL LETTER ETA WITH PROSGEGRAMMENI
1FF3; 1FF3; 1FFC; 03A9 0399; # GREEK SMALL LETTER OMEGA WITH YPOGEGRAMMENI
1FFC; 1FF3; 1FFC; 03A9 0399; # GREEK CAPITAL LETTER OMEGA WITH PROSGEGRAMMENI
1FB2; 1FB2; 1FBA 0345; 1FBA 0399; # GREEK SMALL LETTER ALPHA WITH VARIA AND YPOGEGRAMMENI
1FB4; 1FB4; 0386 0345; 0386 0399; # GREEK SMALL LETTER ALPHA WITH OXIA AND YPOGEGRAMMENI
1FC2; 1FC2; 1FCA 0345; 1FCA 0399; # GREEK SMALL LETTER ETA WITH VARIA AND YPOGEGRAMMENI
1FC4; 1FC4; 0389 0345; 0389 0399; # GREEK SMALL LETTER ETA WITH OXIA AND YPOGEGRAMMENI
1FF2; 1FF2; 1FFA 0345; 1FFA 0399; # GREEK SMALL LETTER OMEGA WITH VARIA AND YPOGEGRAMMENI
1FF4; 1FF4; 038F 0345; 038F 0399; # GREEK SMALL LETTER OMEGA WITH OXIA AND YPOGEGRAMMENI
1FB7; 1FB7; 0391 0342 0345; 0391 0342 0399; # GREEK SMALL LETTER ALPHA WITH PERISPOMENI AND YPOGEGRAMMENI
1FC7; 1FC7; 0397 0342 0345; 0397 0342 0399; # GREEK SMALL LETTER ETA WITH PERISPOMENI AND YPOGEGRAMMENI
1FF7; 1FF7; 03A9 0342 0345; 03A9 0342 0399; # GREEK SMALL LETTER OMEGA WITH PERISPOMENI AND YPOGEGRAMMENI
''';

/// The conditional mappings, with their language and context conditions.
const String _conditional = '''
03A3; 03C2; 03A3; 03A3; Final_Sigma; # GREEK CAPITAL LETTER SIGMA
0307; 0307; ; ; lt After_Soft_Dotted; # COMBINING DOT ABOVE
0049; 0069 0307; 0049; 0049; lt More_Above; # LATIN CAPITAL LETTER I
004A; 006A 0307; 004A; 004A; lt More_Above; # LATIN CAPITAL LETTER J
012E; 012F 0307; 012E; 012E; lt More_Above; # LATIN CAPITAL LETTER I WITH OGONEK
00CC; 0069 0307 0300; 00CC; 00CC; lt; # LATIN CAPITAL LETTER I WITH GRAVE
00CD; 0069 0307 0301; 00CD; 00CD; lt; # LATIN CAPITAL LETTER I WITH ACUTE
0128; 0069 0307 0303; 0128; 0128; lt; # LATIN CAPITAL LETTER I WITH TILDE
0130; 0069; 0130; 0130; tr; # LATIN CAPITAL LETTER I WITH DOT ABOVE
0130; 0069; 0130; 0130; az; # LATIN CAPITAL LETTER I WITH DOT ABOVE
0307; ; 0307; 0307; tr After_I; # COMBINING DOT ABOVE
0307; ; 0307; 0307; az After_I; # COMBINING DOT ABOVE
0049; 0131; 0049; 0049; tr Not_Before_Dot; # LATIN CAPITAL LETTER I
0049; 0131; 0049; 0049; az Not_Before_Dot; # LATIN CAPITAL LETTER I
0069; 0069; 0130; 0130; tr; # LATIN SMALL LETTER I
0069; 0069; 0130; 0130; az; # LATIN SMALL LETTER I
''';

/// One line of SpecialCasing.txt.
final class _Entry {
  const new(
    this.code,
    this.lower,
    this.title,
    this.upper,
    this.language,
    this.context,
  );

  factory parse(String line) {
    final fields = line.split('#').first.split(';').map((f) => f.trim());
    final [code, lower, title, upper, ...rest] = fields.toList();
    final conditions = rest.isEmpty ? <String>[] : rest.first.split(' ');
    String? language;
    String? context;
    for (final condition in conditions.where((c) => c.isNotEmpty)) {
      if (RegExp(r'^[a-z]{2,3}$').hasMatch(condition)) {
        language = condition;
      } else {
        context = condition;
      }
    }
    return _Entry(
      _chars(code),
      _chars(lower),
      _chars(title),
      _chars(upper),
      language,
      context,
    );
  }

  final String code;
  final String lower;
  final String title;
  final String upper;
  final String? language;
  final String? context;

  LocaleCasing get casing => LocaleCasing.forLanguage(language ?? 'en');

  @override
  String toString() => '${_hex(code)} ${language ?? ''} ${context ?? ''}';
}

/// A context that satisfies a SpecialCasing condition: the text around the
/// code point and what that text becomes in lower, title and upper case.
final class _Context {
  const new({
    this.before = '',
    this.after = '',
    this.lowerBefore = '',
    this.lowerAfter = '',
    this.titleBefore = '',
    this.titleAfter = '',
    this.upperBefore = '',
    this.upperAfter = '',
  });

  final String before;
  final String after;
  final String lowerBefore;
  final String lowerAfter;
  final String titleBefore;
  final String titleAfter;
  final String upperBefore;
  final String upperAfter;
}

/// A satisfying context for every condition of the file. A new condition
/// in a later Unicode version fails the table test until it is added here
/// and to `casing.dart`.
const Map<String?, _Context> _contexts = {
  null: _Context(),
  // A cased letter (Greek capital alpha) before, nothing cased after.
  'Final_Sigma': _Context(
    before: '\u0391',
    lowerBefore: '\u03B1',
    titleBefore: '\u0391',
    upperBefore: '\u0391',
  ),
  // A soft-dotted i before the dot.
  'After_Soft_Dotted': _Context(
    before: 'i',
    lowerBefore: 'i',
    titleBefore: 'I',
    upperBefore: 'I',
  ),
  // A grave accent (combining class 230) after the letter.
  'More_Above': _Context(
    after: '\u0300',
    lowerAfter: '\u0300',
    titleAfter: '\u0300',
    upperAfter: '\u0300',
  ),
  // A capital I before the dot; before a dot it lowercases to i.
  'After_I': _Context(
    before: 'I',
    lowerBefore: 'i',
    titleBefore: 'I',
    upperBefore: 'I',
  ),
  // Nothing after the I.
  'Not_Before_Dot': _Context(),
};

String _chars(String hex) => String.fromCharCodes([
  for (final unit in hex.split(' ').where((u) => u.isNotEmpty))
    int.parse(unit, radix: 16),
]);

String _hex(String text) => text.runes
    .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
    .join(' ');

List<_Entry> _entries(String block) => [
  for (final line in block.split('\n'))
    if (line.trim().isNotEmpty) _Entry.parse(line),
];

void main() {
  const tr = Locale('tr');
  const az = Locale('az');
  const en = Locale('en');
  final turkish = LocaleCasing.forLocale(tr);
  final english = LocaleCasing.forLocale(en);

  group('ROADMAP §5 step 10', () {
    test('Turkish upper and lower case', () {
      expect(turkish.upper('imzala'), 'İMZALA');
      expect(turkish.upper('ılık'), 'ILIK');
      expect(turkish.lower('İSTANBUL'), 'istanbul');
      expect(turkish.lower('I'), 'ı');
    });

    test('English keeps i and I as a pair', () {
      expect(english.upper('imzala'), 'IMZALA');
      expect(english.upper('i'), 'I');
      expect(english.lower('I'), 'i');
      expect(english.lower('ISTANBUL'), 'istanbul');
    });
  });

  group('Turkish and Azerbaijani', () {
    for (final locale in [tr, az]) {
      final casing = LocaleCasing.forLocale(locale);
      test('${locale.languageCode}: every dotted and dotless letter', () {
        expect(casing.upper('ı i ğ ü ş ö ç'), 'I İ Ğ Ü Ş Ö Ç');
        expect(casing.lower('I İ Ğ Ü Ş Ö Ç'), 'ı i ğ ü ş ö ç');
        expect(casing.upper('ayşe'), 'AYŞE');
        expect(casing.upper('istanbul'), 'İSTANBUL');
        expect(casing.lower('DİYARBAKIR'), 'diyarbakır');
      });

      test('${locale.languageCode}: words survive a round trip', () {
        for (final word in ['imzala', 'ılık', 'kira sözleşmesi', 'ığdır']) {
          expect(casing.lower(casing.upper(word)), word);
        }
      });

      test('${locale.languageCode}: I with a combining dot above', () {
        expect(casing.lower('I\u0307'), 'i');
        expect(casing.lower('I\u0307STANBUL'), 'istanbul');
        // A below mark (class 220) may sit between I and the dot.
        expect(casing.lower('I\u0323\u0307'), 'i\u0323');
        // An above mark (class 230) blocks the rule.
        expect(casing.lower('I\u0301\u0307'), 'ı\u0301\u0307');
        expect(casing.lower('a\u0307'), 'a\u0307');
      });

      test('${locale.languageCode}: capitalize uses dotted İ', () {
        expect(casing.capitalize('istanbul'), 'İstanbul');
        expect(casing.capitalize('ılık'), 'Ilık');
        expect(casing.capitalize('«ilk»'), '«İlk»');
      });
    }

    test('az gives the same results as tr', () {
      final azerbaijani = LocaleCasing.forLocale(az);
      const sample = 'İi Iı Iİ\u0307 ğüşöçə ƏĞÜŞÖÇ';
      expect(azerbaijani.upper(sample), turkish.upper(sample));
      expect(azerbaijani.lower(sample), turkish.lower(sample));
      expect(azerbaijani.capitalize('ilk'), turkish.capitalize('ilk'));
    });
  });

  group('SpecialCasing-15.0.0.txt', () {
    test('every unconditional mapping, in every language', () {
      final entries = _entries(_unconditional);
      expect(entries, hasLength(103));
      for (final entry in entries) {
        // U+0130 has Turkish and Azerbaijani overrides; the rest apply in
        // every language.
        final casings = entry.code == 'İ'
            ? [LocaleCasing.root, LocaleCasing.lithuanian]
            : [LocaleCasing.root, LocaleCasing.turkic, LocaleCasing.lithuanian];
        for (final casing in casings) {
          expect(casing.lower(entry.code), entry.lower, reason: '$entry');
          expect(casing.upper(entry.code), entry.upper, reason: '$entry');
          expect(casing.capitalize(entry.code), entry.title, reason: '$entry');
        }
      }
    });

    test('every conditional mapping, with its context', () {
      final entries = _entries(_conditional);
      expect(entries, hasLength(16));
      for (final entry in entries) {
        final context = _contexts[entry.context];
        expect(context, isNotNull, reason: 'no context for $entry');
        if (context == null) continue;
        final casing = entry.casing;
        final input = '${context.before}${entry.code}${context.after}';
        expect(
          casing.lower(input),
          '${context.lowerBefore}${entry.lower}${context.lowerAfter}',
          reason: 'lower $entry',
        );
        expect(
          casing.upper(input),
          '${context.upperBefore}${entry.upper}${context.upperAfter}',
          reason: 'upper $entry',
        );
        expect(
          casing.capitalize(input),
          '${context.titleBefore}${entry.title}${context.titleAfter}',
          reason: 'title $entry',
        );
      }
    });

    test('a language rule does not apply in other languages', () {
      // Each language-specific line exists because it differs from the
      // default mapping in at least one of lower, title and upper case.
      for (final entry in _entries(_conditional)) {
        if (entry.language == null) continue;
        final context = _contexts[entry.context] ?? const _Context();
        final input = '${context.before}${entry.code}${context.after}';
        final other = entry.language == 'lt'
            ? LocaleCasing.turkic
            : LocaleCasing.lithuanian;
        for (final casing in [LocaleCasing.root, other]) {
          final results = [
            casing.lower(input),
            casing.capitalize(input),
            casing.upper(input),
          ];
          final expected = [
            '${context.lowerBefore}${entry.lower}${context.lowerAfter}',
            '${context.titleBefore}${entry.title}${context.titleAfter}',
            '${context.upperBefore}${entry.upper}${context.upperAfter}',
          ];
          expect(results, isNot(expected), reason: '$entry under $casing');
        }
      }
      expect(LocaleCasing.root.lower('I\u0300'), 'i\u0300');
      expect(LocaleCasing.root.upper('i\u0307'), 'I\u0307');
      expect(LocaleCasing.root.lower('I\u0307'), 'i\u0307');
    });

    test('Final_Sigma is false without a cased letter before', () {
      const root = LocaleCasing.root;
      expect(root.lower('Σ'), 'σ');
      expect(root.lower('ΣΑ'), 'σα');
      expect(root.lower(' Σ '), ' σ ');
    });

    test('Final_Sigma skips case-ignorable characters', () {
      const root = LocaleCasing.root;
      expect(root.lower('ΟΔΟΣ'), 'οδος');
      expect(root.lower('ΟΔΟΣ ΣΑΣ.'), 'οδος σας.');
      // A combining acute and an apostrophe are case-ignorable.
      expect(root.lower('ΑΣ\u0301'), 'ας\u0301');
      expect(root.lower('ΑΣ\u0301Α'), 'ασ\u0301α');
      expect(root.lower("ΑΣ'Α"), "ασ'α");
      expect(root.lower("ΑΣ'"), "ας'");
    });

    test('lt: More_Above looks past marks below', () {
      const lt = LocaleCasing.lithuanian;
      expect(lt.lower('I'), 'i');
      expect(lt.lower('I\u0328'), 'i\u0328');
      expect(lt.lower('I\u0328\u0301'), 'i\u0307\u0328\u0301');
      expect(lt.lower('Į\u0303'), 'į\u0307\u0303');
      expect(lt.lower('ÌÍĨ'), 'i\u0307\u0300i\u0307\u0301i\u0307\u0303');
    });

    test('lt: upper and title case drop the dot after i and j', () {
      const lt = LocaleCasing.lithuanian;
      expect(lt.upper('i\u0307'), 'I');
      expect(lt.upper('j\u0307'), 'J');
      expect(lt.upper('į\u0307'), 'Į');
      expect(lt.upper('i\u0323\u0307'), 'I\u0323');
      expect(lt.upper('a\u0307'), 'A\u0307');
      expect(lt.upper('i\u0301\u0307'), 'I\u0301\u0307');
      expect(lt.capitalize('i\u0307\u0301sti'), 'I\u0301sti');
      expect(lt.lower(lt.upper('i\u0307\u0301')), 'i\u0307\u0301');
    });
  });

  group('default mapping', () {
    const root = LocaleCasing.root;

    test('full mappings that the Dart VM lacks', () {
      expect(root.upper('Straße'), 'STRASSE');
      expect(root.upper('ﬁle'), 'FILE');
      expect(root.capitalize('ßa'), 'Ssa');
      expect(root.lower('İ'), 'i\u0307');
    });

    test('case pairs newer than the Dart VM tables', () {
      // Cherokee (Unicode 8.0).
      expect(root.lower('Ꭰ'), 'ꭰ');
      expect(root.upper('ꭰ'), 'Ꭰ');
      // Georgian Mtavruli (Unicode 11.0): upper case only, no title case.
      expect(root.upper('აბ'), 'ᲐᲑ');
      expect(root.lower('Ა'), 'ა');
      expect(root.capitalize('აბ'), 'აბ');
      // Cyrillic (Unicode 7.0) and Latin Extended-D (Unicode 8.0).
      expect(root.lower('Ԩ'), 'ԩ');
      expect(root.upper('ԩ'), 'Ԩ');
      expect(root.upper('ꞵ'), 'Ꞵ');
      expect(root.lower('Ꞵ'), 'ꞵ');
      // Adlam (Unicode 9.0), outside the BMP.
      expect(root.lower('\u{1E900}'), '\u{1E922}');
      expect(root.upper('\u{1E922}'), '\u{1E900}');
    });

    test('code points outside the BMP and lone surrogates', () {
      expect(root.lower('\u{10400}x'), '\u{10428}x');
      expect(root.upper('a\uD800b'), 'A\uD800B');
      expect(root.upper('a\uDC00b'), 'A\uDC00B');
    });

    test('Latin digraphs take their title-case form', () {
      expect(root.capitalize('ǆemal'), 'ǅemal');
      expect(root.capitalize('Ǆemal'), 'ǅemal');
      expect(root.upper('ǆemal'), 'ǄEMAL');
      expect(root.capitalize('ǉ ǌ'), 'ǈ ǌ');
    });

    test('text without case is unchanged', () {
      for (final text in [
        '',
        '123',
        'العربية',
        '日本語',
        'עברית',
        'हिन\u094Dदी',
      ]) {
        expect(root.upper(text), text);
        expect(root.lower(text), text);
        expect(root.capitalize(text), text);
      }
    });
  });

  group('capitalize', () {
    const root = LocaleCasing.root;

    test('changes only the first letter', () {
      expect(root.capitalize('kira sözleşmesi'), 'Kira sözleşmesi');
      expect(root.capitalize('PDF dosyası'), 'PDF dosyası');
      expect(root.capitalize('a'), 'A');
    });

    test('skips leading spaces and punctuation', () {
      expect(root.capitalize('¿qué?'), '¿Qué?');
      expect(root.capitalize('  hello'), '  Hello');
      expect(root.capitalize('“quoted”'), '“Quoted”');
      expect(root.capitalize('…und'), '…Und');
      expect(root.capitalize(' ,.'), ' ,.');
    });

    test('stops at a digit or a letter without case', () {
      expect(root.capitalize('3 sayfa'), '3 sayfa');
      expect(root.capitalize('ملف pdf'), 'ملف pdf');
    });
  });

  group('choosing the rules', () {
    test('by language, ignoring script, region and case', () {
      expect(LocaleCasing.forLanguage('tr'), same(LocaleCasing.turkic));
      expect(LocaleCasing.forLanguage('tr-TR'), same(LocaleCasing.turkic));
      expect(LocaleCasing.forLanguage('TUR'), same(LocaleCasing.turkic));
      expect(LocaleCasing.forLanguage('az_Latn'), same(LocaleCasing.turkic));
      expect(LocaleCasing.forLanguage('aze'), same(LocaleCasing.turkic));
      expect(LocaleCasing.forLanguage('lt'), same(LocaleCasing.lithuanian));
      expect(LocaleCasing.forLanguage('lit'), same(LocaleCasing.lithuanian));
      for (final other in ['en', 'de', 'ar', 'fa', 'el', 'nl', '']) {
        expect(LocaleCasing.forLanguage(other), same(LocaleCasing.root));
      }
    });

    test('by locale', () {
      expect(
        LocaleCasing.forLocale(const Locale('tr', 'TR')),
        same(LocaleCasing.turkic),
      );
      expect(
        LocaleCasing.forLocale(
          const Locale.fromSubtags(languageCode: 'az', scriptCode: 'Cyrl'),
        ),
        same(LocaleCasing.turkic),
      );
      expect(
        LocaleCasing.forLocale(const Locale('en', 'US')),
        same(LocaleCasing.root),
      );
    });

    testWidgets('from the UI locale of a context', (tester) async {
      late LocaleCasing casing;
      await tester.pumpWidget(
        Localizations(
          locale: tr,
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              casing = LocaleCasing.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(casing, same(LocaleCasing.turkic));
      expect(casing.upper('imzala'), 'İMZALA');
    });
  });
}
