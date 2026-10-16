import 'dart:convert';
import 'dart:io';

import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/gen/app_localizations_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ARB files, from the app package (where `flutter test` runs).
const String _l10nDir = 'lib/l10n';

Map<String, Object?> _arb(String code) =>
    (jsonDecode(File('$_l10nDir/app_$code.arb').readAsStringSync()) as Map)
        .cast<String, Object?>();

Set<String> _keys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

/// The URIs of every `import` and `export` directive in [source]: whole
/// directives up to their `;`, so the URIs of a conditional directive's
/// later lines count too, single or double quoted.
List<String> _directiveUris(String source) => [
  for (final directive in RegExp(
    r'^\s*(import|export)\b[^;]*;',
    multiLine: true,
  ).allMatches(source))
    for (final uri in RegExp('''['"]([^'"]*)['"]''').allMatches(directive[0]!))
      uri[1]!,
];

/// The placeholder names in [message], in the order they appear.
Set<String> _placeholdersIn(String message) => {
  for (final match in RegExp(r'\{(\w+)[,}]').allMatches(message))
    match.group(1)!,
};

/// The message keys whose Arabic is the English text on purpose: the same
/// list (and reasons) as `tools/checks` `ArbParityCheck.repositorySameInTurkish`.
const Set<String> _sameInArabic = {
  'appName', // the product name, never translated
  'shellMoreDocumentsBadge', // a plus sign and a count ("+3")
  'shellToolEimza', // e-imza, the Turkish name of the electronic signature
  'shellConvertWord', // a file format named after its product
  'shellConvertExcel',
  'shellConvertPowerPoint',
  'shellConvertHtml', // file formats
  'shellConvertMarkdown',
  'regionPaperA4', // the ISO paper size name
  'regionPaperLetter', // the paper size name, as a12-2c writes it
};

/// Each Arabic string the design's Arabic boards draw for M1, by the ARB
/// key that holds it: a12-2a (the start screen, FmStart `lang="ar"` in
/// FmWindow's home header) and a12-2c (Settings › Language and region,
/// FmSettings `pane="language" lang="ar"`). The strings are the `ar` data
/// of `design/FmStart.dc.html` (`ST.ar`), `design/FmSettings.dc.html`
/// (`L.ar`) and, for the home header, `design/FmWindow.dc.html` (`FM_S.ar`).
/// FmStart's empty state (a1-5's drop zone, the M1 start screen) comes from
/// the same `ST.ar` data.
///
/// Left out, with the reason:
///
/// - FmStart `openSub` ("…وExcel والصور لتحويلها"): it promises conversion;
///   until conversion ships the card says "PDF files" (G11,
///   `startOpenFileDescription`).
/// - FmStart `drop` and `dropSub`: the drop strip above pinned and recent
///   files, which shows only once there are recent files (M2); M1's start
///   screen is the empty state with its drop zone. `dropSub` also promises
///   conversion (G11).
/// - FmStart `pinned`, `unpin`, `recent`, `searchRecent`, `view`, `grid`,
///   `list`, `sort`, `name`, `where`, `pagesH`, `opened`, `footer`, `clear`,
///   `pages` and the file badges: pinned and recent files (M2).
/// - FmStart `dropN`, `dropHow`, `dropTabs`, `dropTabsSub`, `dropCombine`
///   and `dropCombineSub`: dropping several files at once (M2).
/// - FmSettings `regions` ("تركيا (Türkiye)") and `appLangs`: region and
///   language names come from the region and language tables (CLDR names
///   and each language's own name), not from ARB messages.
/// - FmWindow's document tabs: the start screen opens no document before
///   M2 (G88), and file names are data.
const Map<String, String> _arabicBoardStrings = {
  // a12-2a: the home header (FmWindow `FM_S.ar`).
  'shellHome': 'الرئيسية',
  'shellOpenDocuments': 'المستندات المفتوحة',
  'shellOpenFile': 'فتح ملف',
  'shellSearch': 'بحث',
  'shellSettings': 'الإعدادات',
  // a12-2a: the action cards and quick tools (FmStart `ST.ar`).
  'startOpenFile': 'فتح ملف…',
  'startCreatePdf': 'إنشاء PDF',
  'startCreatePdfDescription': 'من صفحة فارغة أو ملفات أو الحافظة',
  'startCombineFiles': 'دمج الملفات',
  'startCombineFilesDescription': 'دمج عدة ملفات في ملف PDF واحد',
  'startScanToPdf': 'مسح ضوئي إلى PDF',
  'startScanToPdfDescription': 'من ماسح ضوئي أو كاميرا الهاتف',
  'startQuickTools': 'أدوات سريعة',
  'startToolCompress': 'ضغط',
  'startToolConvert': 'تحويل',
  'startToolSign': 'توقيع',
  'startToolOcr': 'التعرّف على النص (OCR)',
  'startToolProtect': 'حماية',
  'startToolCompare': 'مقارنة',
  // The empty state (FmStart `emptyTitle`, `emptySub`, `emptyFoot`).
  'startDropTitle': 'أفلت ملف PDF هنا',
  'startDropSubtitle': 'أو افتح ملفًا من جهازك.',
  'startDropFootnote': 'تبقى الملفات على هذا الجهاز.',
  // a12-2c: the window, its search and the pane list (FmSettings `L.ar`).
  'settingsTitle': 'الإعدادات',
  'settingsSearch': 'البحث في الإعدادات',
  'settingsPaneGeneral': 'عام',
  'settingsPaneLanguage': 'اللغة والمنطقة',
  'settingsPaneEditing': 'التحرير',
  'settingsPaneFonts': 'الخطوط',
  'settingsPaneSignatures': 'التوقيعات والشهادات',
  'settingsPaneOcr': 'التعرّف على النص (OCR)',
  'settingsPaneAi': 'المساعد الذكي',
  'settingsPanePrivacy': 'الخصوصية',
  'settingsPaneUpdates': 'التحديثات',
  'settingsPaneShortcuts': 'اختصارات لوحة المفاتيح',
  'settingsPaneAdvanced': 'متقدّم',
  // a12-2c: the Language and region pane.
  'languageAppLanguage': 'لغة التطبيق',
  'settingsAppLanguageHint': 'يتغيّر Ferman فورًا دون إعادة تشغيل.',
  'settingsDocumentLanguages': 'لغات المستندات',
  'settingsDocumentLanguagesHint':
      'تُستخدم للتعرّف على النص والتدقيق الإملائي والوصل بشرطة عندما لا يحدّد '
      'المستند لغته.',
  'languageNameTurkish': 'التركية',
  'languageNameEnglish': 'الإنجليزية',
  'settingsAddDocumentLanguage': 'إضافة',
  'regionFormats': 'تنسيقات المنطقة',
  'regionPaperSize': 'حجم الورق',
  'regionUnits': 'الوحدات',
  'regionFirstDay': 'أول أيام الأسبوع',
  'regionMonday': 'الاثنين',
  'regionSunday': 'الأحد',
  'regionSaturday': 'السبت',
  'regionExamples': 'أمثلة',
  'regionExampleDate': 'التاريخ',
  'regionExampleTime': 'الوقت',
  'regionExampleNumber': 'الرقم',
  'regionExampleFontSize': 'حجم الخط',
};

void main() {
  final en = _arb('en');
  final tr = _arb('tr');
  final ar = _arb('ar');

  group('ROADMAP §5 step 10: Arabic exists for every M1 string', () {
    test('app_ar.arb has every key of app_en.arb and no other', () {
      expect(_keys(en).difference(_keys(ar)), isEmpty, reason: 'missing');
      expect(_keys(ar).difference(_keys(en)), isEmpty, reason: 'extra');
      expect(ar['@@locale'], 'ar');
    });

    test('Arabic and Turkish use the placeholders of the English message', () {
      for (final key in _keys(en)) {
        final english = _placeholdersIn(en[key]! as String);
        for (final (code, arb) in [('ar', ar), ('tr', tr)]) {
          expect(
            _placeholdersIn(arb[key]! as String),
            english,
            reason: '$key in app_$code.arb',
          );
        }
      }
    });

    test('Arabic repeats the English text only for names, symbols and '
        'formats', () {
      final same = {
        for (final key in _keys(en))
          if (ar[key] == en[key]) key,
      };
      expect(same, _sameInArabic);
    });

    test('Arabic is the design’s own text where the Arabic boards draw it '
        '(a12-2a, a12-2c)', () {
      expect(_keys(en), containsAll(_arabicBoardStrings.keys));
      for (final MapEntry(:key, value: design) in _arabicBoardStrings.entries) {
        expect(ar[key], design, reason: key);
      }
    });

    test('gen-l10n found no untranslated Arabic or Turkish message', () {
      // l10n.yaml: `untranslated-messages-file: build/l10n_untranslated.json`.
      // gen-l10n generates the English text for a message an ARB file lacks
      // (the fallback) and lists it there; `flutter test` runs gen-l10n
      // first (`generate: true`).
      final file = File('build/l10n_untranslated.json');
      if (!file.existsSync()) {
        markTestSkipped('gen-l10n has not written ${file.path} yet');
        return;
      }
      final untranslated = jsonDecode(file.readAsStringSync()) as Map;
      expect(untranslated, isEmpty);
    });

    test('languages without a translation show the English strings', () {
      final english = AppLocalizationsEn();
      for (final language in AppLanguage.values.where((l) => !l.translated)) {
        expect(language.uiLocale, const Locale('en'), reason: language.tag);
        final strings = lookupAppLocalizations(language.uiLocale);
        expect(strings, isA<AppLocalizationsEn>(), reason: language.tag);
        expect(strings.settingsTitle, english.settingsTitle);
      }
      // Arabic and Turkish have their own.
      expect(
        lookupAppLocalizations(const Locale('ar')).settingsTitle,
        isNot(english.settingsTitle),
      );
      expect(
        lookupAppLocalizations(const Locale('tr')).settingsTitle,
        isNot(english.settingsTitle),
      );
    });
  });

  group('ROADMAP §5 step 10: ready for translators (Weblate)', () {
    test('every English message has a description for translators', () {
      bool described(Object? meta) =>
          meta is Map &&
          meta['description'] is String &&
          (meta['description']! as String).trim().isNotEmpty;
      expect([
        for (final key in _keys(en))
          if (!described(en['@$key'])) key,
      ], isEmpty);
    });

    test('every placeholder is declared, with its type', () {
      for (final key in _keys(en)) {
        final used = _placeholdersIn(en[key]! as String);
        if (used.isEmpty) continue;
        final meta = en['@$key']! as Map<String, Object?>;
        final declared = (meta['placeholders']! as Map).cast<String, Object?>();
        expect(declared.keys.toSet(), used, reason: key);
        for (final MapEntry(key: name, :value) in declared.entries) {
          expect((value! as Map)['type'], isNotNull, reason: '$key.$name');
        }
      }
    });

    test('gen-l10n requires the metadata of every message', () {
      final config = File('l10n.yaml').readAsLinesSync();
      expect(config, contains('required-resource-attributes: true'));
      expect(config, contains('template-arb-file: app_en.arb'));
    });
  });

  group('ROADMAP §5 step 10 and G52: UI translations are bundled', () {
    test('the generated localizations are app code, one file per ARB file', () {
      final config = File('l10n.yaml').readAsLinesSync();
      expect(config, contains('output-dir: lib/l10n/gen'));
      // Deferred loading would split each language into a separate file
      // that the web build fetches on demand.
      expect(config.where((line) => line.contains('deferred')), isEmpty);
      for (final code in ['en', 'tr', 'ar']) {
        expect(
          File('$_l10nDir/gen/app_localizations_$code.dart').existsSync(),
          isTrue,
          reason: code,
        );
      }
      expect(
        AppLocalizations.supportedLocales,
        unorderedEquals(const [Locale('en'), Locale('tr'), Locale('ar')]),
      );
    });

    test('each language loads at once, from the app itself', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final loading = AppLocalizations.delegate.load(locale);
        // Nothing to wait for: no file, asset or network read.
        expect(loading, isA<SynchronousFuture<AppLocalizations>>());
      }
    });

    test('no localization or formatting code can reach the network or '
        'the file system', () {
      // intl can load its date data over HTTP or from files
      // (date_symbol_data_http_request, date_symbol_data_file); Ferman uses
      // the data compiled into the app (date_symbol_data_local).
      const forbidden = [
        'dart:io',
        'dart:html',
        'dart:js_interop',
        'package:http/',
        'package:web/',
        'package:intl/date_symbol_data_http_request.dart',
        'package:intl/date_symbol_data_file.dart',
      ];
      final files = Directory(_l10nDir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final file in files) {
        for (final uri in _directiveUris(file.readAsStringSync())) {
          for (final prefix in forbidden) {
            expect(
              uri.startsWith(prefix),
              isFalse,
              reason: '${file.path}: $uri',
            );
          }
        }
      }
      // And nowhere in the app does intl's date data come from outside.
      final everywhere = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in everywhere) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('date_symbol_data_http_request')));
        expect(text, isNot(contains('date_symbol_data_file')));
      }
    });
  });
}
