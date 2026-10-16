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
        final directives = file.readAsLinesSync().where(
          (line) => RegExp(r'^\s*(import|export)\s').hasMatch(line),
        );
        for (final directive in directives) {
          for (final uri in forbidden) {
            expect(
              directive.contains("'$uri"),
              isFalse,
              reason: '${file.path}: $directive',
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
