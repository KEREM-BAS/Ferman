import 'dart:io';

import 'package:ferman/design/theme.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const String _sans = 'IBM Plex Sans';
const String _arabic = 'IBM Plex Sans Arabic';
const String _hebrew = 'IBM Plex Sans Hebrew';
const String _devanagari = 'IBM Plex Sans Devanagari';

List<String> _chain(TextStyle style) => [
  ?style.fontFamily,
  ...?style.fontFamilyFallback,
];

List<TextStyle> _roles(FermanTypography t) => [
  t.body,
  t.bodyStrong,
  t.caption,
  t.dialogTitle,
  t.headline,
  t.label,
  t.mono,
  t.panelTitle,
  t.prose,
  t.wordmark,
];

void main() {
  // These tests check the app's own chains. flutter_test_config.dart appends
  // the system fonts it loaded for goldens (FermanFontFamilies
  // .debugExtraFallback); take them out before any typography is built in
  // this file, and put them back at the end.
  late List<String> testFallback;
  setUpAll(() {
    testFallback = FermanFontFamilies.debugExtraFallback;
    FermanFontFamilies.debugExtraFallback = const [];
  });
  tearDownAll(() => FermanFontFamilies.debugExtraFallback = testFallback);

  group('FermanScript.forLocale', () {
    test('maps UI languages to scripts', () {
      final cases = <Locale?, FermanScript>{
        null: FermanScript.standard,
        const Locale('en'): FermanScript.standard,
        const Locale('tr'): FermanScript.standard,
        const Locale('hi'): FermanScript.standard,
        const Locale('ru'): FermanScript.standard,
        const Locale('ar'): FermanScript.arabic,
        const Locale('fa'): FermanScript.arabic,
        const Locale('he'): FermanScript.hebrew,
        const Locale('ja'): FermanScript.japanese,
        const Locale('ko'): FermanScript.korean,
        const Locale('zh'): FermanScript.simplifiedChinese,
        const Locale('zh', 'CN'): FermanScript.simplifiedChinese,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'):
            FermanScript.simplifiedChinese,
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'):
            FermanScript.traditionalChinese,
        const Locale('zh', 'TW'): FermanScript.traditionalChinese,
        const Locale('zh', 'HK'): FermanScript.traditionalChinese,
        // The script subtag wins over the region.
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'HK',
        ): FermanScript.simplifiedChinese,
      };
      for (final MapEntry(key: locale, value: script) in cases.entries) {
        expect(FermanScript.forLocale(locale), script, reason: '$locale');
      }
    });

    test('only Japanese, Korean and Chinese are CJK', () {
      expect(
        [
          for (final script in FermanScript.values)
            if (script.isCjk) script,
        ],
        [
          FermanScript.japanese,
          FermanScript.korean,
          FermanScript.simplifiedChinese,
          FermanScript.traditionalChinese,
        ],
      );
    });
  });

  group('FermanFontFamilies.uiChain', () {
    test('standard is the design --font-ui stack', () {
      expect(FermanFontFamilies.uiChain(FermanScript.standard), [
        FermanTypeTokens.fontUi.family,
        ...FermanTypeTokens.fontUi.fallback,
      ]);
      expect(FermanFontFamilies.uiChain(FermanScript.standard), [
        _sans,
        _arabic,
        _hebrew,
        _devanagari,
      ]);
    });

    test('Arabic and Hebrew keep the --font-ui order, Plex Sans first', () {
      // The design's Arabic boards use --font-ui; a script font first breaks
      // Turkish and Vietnamese letters (script_coverage_golden_test.dart).
      for (final script in [FermanScript.arabic, FermanScript.hebrew]) {
        expect(FermanFontFamilies.uiChain(script), [
          _sans,
          _arabic,
          _hebrew,
          _devanagari,
        ]);
      }
    });

    test('CJK puts the system families of ADR 0013 after Plex Sans', () {
      expect(FermanFontFamilies.uiChain(FermanScript.japanese), [
        _sans,
        'Hiragino Sans',
        'Yu Gothic UI',
        'Noto Sans CJK JP',
        _arabic,
        _hebrew,
        _devanagari,
      ]);
      expect(FermanFontFamilies.uiChain(FermanScript.korean).sublist(1, 4), [
        'Apple SD Gothic Neo',
        'Malgun Gothic',
        'Noto Sans CJK KR',
      ]);
      expect(
        FermanFontFamilies.uiChain(FermanScript.simplifiedChinese)
            .sublist(1, 4),
        ['PingFang SC', 'Microsoft YaHei UI', 'Noto Sans CJK SC'],
      );
      expect(
        FermanFontFamilies.uiChain(FermanScript.traditionalChinese)
            .sublist(1, 4),
        ['PingFang TC', 'Microsoft JhengHei UI', 'Noto Sans CJK TC'],
      );
    });

    test('every chain keeps Plex Sans right after a script family', () {
      for (final script in FermanScript.values) {
        final chain = FermanFontFamilies.uiChain(script);
        expect(chain.toSet(), hasLength(chain.length), reason: '$script');
        final first = chain.first;
        if (first != _sans) {
          expect(chain[1], _sans, reason: '$script');
        }
      }
    });

    test('the test-only fallback is appended to every chain, once', () {
      addTearDown(() => FermanFontFamilies.debugExtraFallback = const []);
      final production = {
        for (final script in FermanScript.values)
          script: FermanFontFamilies.uiChain(script),
      };
      // Noto Sans CJK JP is already in the Japanese chain.
      FermanFontFamilies.debugExtraFallback = const [
        'Test Symbols',
        'Noto Sans CJK JP',
      ];
      for (final script in FermanScript.values) {
        final chain = FermanFontFamilies.uiChain(script);
        expect(chain.toSet(), hasLength(chain.length), reason: '$script');
        expect(chain, [
          ...?production[script],
          'Test Symbols',
          if (script != FermanScript.japanese) 'Noto Sans CJK JP',
        ], reason: '$script');
      }
      // Typography built while it is set carries it at the end of every
      // role's chain (Polish is built nowhere else in this file).
      final pl = FermanTypography.forLocale(const Locale('pl'));
      for (final role in _roles(pl)) {
        expect(_chain(role).sublist(_chain(role).length - 2), [
          'Test Symbols',
          'Noto Sans CJK JP',
        ]);
      }
    });

    test('the bundled families are declared in pubspec.yaml', () {
      // flutter test runs in app/.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final family in {
        for (final script in FermanScript.values)
          ...FermanFontFamilies.uiChain(script),
      }.where((family) => family.startsWith('IBM Plex'))) {
        expect(pubspec, contains('- family: $family\n'), reason: family);
      }
    });
  });

  group('FermanTypography.forLocale', () {
    test('null and English give the standard roles with no locale', () {
      final standard = FermanTypography.forLocale(null);
      expect(standard, same(FermanTypography.standard));
      expect(standard.locale, isNull);
      expect(standard.isCjk, isFalse);
      expect(standard.body.height, FermanTypeRoleTokens.standard.body.height);
      expect(_chain(standard.body), [_sans, _arabic, _hebrew, _devanagari]);
    });

    test('caches per locale', () {
      expect(
        FermanTypography.forLocale(const Locale('tr')),
        same(FermanTypography.forLocale(const Locale('tr'))),
      );
    });

    test('every role carries the UI locale', () {
      for (final locale in const [
        Locale('en'),
        Locale('tr'),
        Locale('ar'),
        Locale('ja'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]) {
        final typography = FermanTypography.forLocale(locale);
        expect(typography.locale, locale);
        for (final role in _roles(typography)) {
          expect(role.locale, locale, reason: '$locale');
        }
      }
    });

    test('keeps the token sizes, weights and leading for Latin', () {
      final tr = FermanTypography.forLocale(const Locale('tr'));
      const tokens = FermanTypeRoleTokens.standard;
      expect(tr.body.fontSize, tokens.body.fontSize);
      expect(tr.body.fontWeight, tokens.body.fontWeight);
      expect(tr.body.height, 18 / 13);
      expect(tr.body.leadingDistribution, TextLeadingDistribution.even);
      expect(tr.label.height, tokens.label.height);
      expect(tr.dialogTitle.fontWeight, FontWeight.w600);
    });

    test('Arabic and Persian use Plex Sans first, then Plex Sans Arabic', () {
      for (final code in ['ar', 'fa']) {
        final typography = FermanTypography.forLocale(Locale(code));
        expect(typography.script, FermanScript.arabic);
        expect(_chain(typography.body).take(2), [_sans, _arabic]);
        expect(typography.isCjk, isFalse);
      }
    });

    test('Hebrew uses Plex Sans first, with Plex Sans Hebrew in the chain', () {
      final he = FermanTypography.forLocale(const Locale('he'));
      expect(_chain(he.caption).first, _sans);
      expect(_chain(he.caption), contains(_hebrew));
    });

    test('CJK takes the CJK roles: taller leading on five roles', () {
      final ja = FermanTypography.forLocale(const Locale('ja'));
      expect(ja.isCjk, isTrue);
      expect(ja.body.height, 20 / 13);
      expect(ja.bodyStrong.height, 20 / 13);
      expect(ja.caption.height, 18 / 12);
      expect(ja.label.height, 16 / 11);
      expect(ja.panelTitle.height, 20 / 13);
      // The other roles keep the standard leading.
      expect(ja.prose.height, FermanTypeRoleTokens.standard.prose.height);
      expect(ja.headline.height, FermanTypeRoleTokens.standard.headline.height);
    });

    test('CJK keeps the token weights and is never italic', () {
      for (final locale in const [Locale('ja'), Locale('ko'), Locale('zh')]) {
        final typography = FermanTypography.forLocale(locale);
        final roles = _roles(typography);
        final tokens = [
          FermanTypeRoleTokens.cjk.body,
          FermanTypeRoleTokens.cjk.bodyStrong,
          FermanTypeRoleTokens.cjk.caption,
          FermanTypeRoleTokens.cjk.dialogTitle,
          FermanTypeRoleTokens.cjk.headline,
          FermanTypeRoleTokens.cjk.label,
          FermanTypeRoleTokens.cjk.mono,
          FermanTypeRoleTokens.cjk.panelTitle,
          FermanTypeRoleTokens.cjk.prose,
          FermanTypeRoleTokens.cjk.wordmark,
        ];
        for (var i = 0; i < roles.length; i++) {
          expect(roles[i].fontWeight, tokens[i].fontWeight);
          expect(roles[i].fontStyle, isNot(FontStyle.italic));
        }
      }
    });

    test('Traditional Chinese falls back to the TC families', () {
      final hant = FermanTypography.forLocale(const Locale('zh', 'TW'));
      expect(_chain(hant.body), contains('PingFang TC'));
      expect(_chain(hant.body), isNot(contains('PingFang SC')));
      final hans = FermanTypography.forLocale(const Locale('zh', 'CN'));
      expect(_chain(hans.body), contains('Noto Sans CJK SC'));
      expect(_chain(hans.body), isNot(contains('Noto Sans CJK TC')));
    });

    test('mono and wordmark keep their family and add the UI chain', () {
      final ja = FermanTypography.forLocale(const Locale('ja'));
      expect(ja.mono.fontFamily, 'IBM Plex Mono');
      expect(_chain(ja.mono), [
        'IBM Plex Mono',
        _sans,
        'Hiragino Sans',
        'Yu Gothic UI',
        'Noto Sans CJK JP',
        _arabic,
        _hebrew,
        _devanagari,
      ]);
      expect(ja.wordmark.fontFamily, 'IBM Plex Serif');
      expect(ja.wordmark.height, 1);
    });
  });

  group('FermanTypography value semantics', () {
    test('copyWith replaces only the given roles', () {
      final standard = FermanTypography.standard;
      const body = TextStyle(fontSize: 99);
      final copy = standard.copyWith(body: body);
      expect(copy.body, body);
      expect(copy.caption, standard.caption);
      expect(copy, isNot(standard));
      expect(standard.copyWith(), standard);
      expect(standard.copyWith().hashCode, standard.hashCode);
    });

    test('lerp interpolates sizes and switches the locale at 0.5', () {
      final en = FermanTypography.forLocale(const Locale('en'));
      final ja = FermanTypography.forLocale(const Locale('ja'));
      expect(en.lerp(en, 0.3), same(en));
      final quarter = en.lerp(ja, 0.25);
      expect(quarter.locale, const Locale('en'));
      expect(quarter.script, FermanScript.standard);
      expect(quarter.body.height, closeTo(18 / 13 + (2 / 13) * 0.25, 1e-9));
      final threeQuarters = en.lerp(ja, 0.75);
      expect(threeQuarters.locale, const Locale('ja'));
      expect(threeQuarters.isCjk, isTrue);
      expect(en.lerp(ja, 1), ja);
    });
  });
}
