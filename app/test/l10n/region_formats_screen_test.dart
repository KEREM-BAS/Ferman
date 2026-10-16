import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/onboarding/welcome_step.dart';
import 'package:ferman/features/settings/language_region_pane.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../features/onboarding/ferman_app_harness.dart';
import '../helpers/m1_screens.dart';

/// U+00A0 NO-BREAK SPACE, between a number and its unit.
const String _nbsp = '\u00A0';

/// U+202F NARROW NO-BREAK SPACE, before "PM" in CLDR's US time.
const String _nnbsp = '\u202F';

/// [text] without the first-strong and pop isolates of `bidiIsolate`.
String _unisolated(String text) =>
    text.replaceAll(RegExp('[\u2068\u2069]'), '');

/// The value beside [label] in the examples box of Settings › Language and
/// region (a11-1b), as the screen shows it, isolates included.
String _example(WidgetTester tester, String label) {
  final row = find.ancestor(
    of: find.descendant(
      of: find.byType(RegionExamples),
      matching: find.text(label),
    ),
    matching: find.byType(Row),
  );
  final texts = tester.widgetList<Text>(
    find.descendant(of: row.first, matching: find.byType(Text)),
  );
  return texts.last.data!;
}

/// The four examples of a11-1b: date, time, number and font size, without
/// their isolates.
({String date, String time, String number, String size}) _examples(
  WidgetTester tester,
) {
  final l10n = AppLocalizations.of(tester.element(find.byType(RegionExamples)));
  return (
    date: _unisolated(_example(tester, l10n.regionExampleDate)),
    time: _unisolated(_example(tester, l10n.regionExampleTime)),
    number: _unisolated(_example(tester, l10n.regionExampleNumber)),
    size: _unisolated(_example(tester, l10n.regionExampleFontSize)),
  );
}

/// The label of the General pane's 100% zoom option, without isolates.
String _zoom100(WidgetTester tester) {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(Select<String>).first),
  );
  final zoom = tester.widget<Select<String>>(
    find.byWidgetPredicate(
      (widget) => widget is Select<String> && widget.label == l10n.settingsZoom,
    ),
  );
  return _unisolated(
    zoom.options.firstWhere((option) => option.value == 'actual').label,
  );
}

Future<void> _open(
  WidgetTester tester,
  M1Screen screen, {
  required String languageCode,
  required String regionCode,
}) async {
  await pumpFermanApp(
    tester,
    settings: screen.settings(
      languageCode: languageCode,
      regionCode: regionCode,
    ),
  );
  await screen.open(tester);
}

void main() {
  group('ROADMAP §5 step 10: formats follow the region, never the UI '
      'language (G34)', () {
    testWidgets('an English UI with the Türkiye region sees "13.10.2026 · '
        '14:32" and "10,5 pt" in Settings › Language and region', (
      tester,
    ) async {
      await _open(
        tester,
        M1Screen.settingsLanguage,
        languageCode: 'en',
        regionCode: 'TR',
      );
      expect(localeOf(tester, find.byType(RegionExamples)), const Locale('en'));
      final shown = _examples(tester);
      expect('${shown.date} · ${shown.time}', '13.10.2026 · 14:32');
      expect(shown.number, '18.500,50');
      expect(shown.size, '10,5${_nbsp}pt');
    });

    testWidgets('the same English UI writes 100% as Türkiye does', (
      tester,
    ) async {
      await _open(
        tester,
        M1Screen.settingsGeneral,
        languageCode: 'en',
        regionCode: 'TR',
      );
      expect(_zoom100(tester), '%100');
    });

    testWidgets('an Arabic UI with the United States region sees US formats', (
      tester,
    ) async {
      await _open(
        tester,
        M1Screen.settingsLanguage,
        languageCode: 'ar',
        regionCode: 'US',
      );
      expect(localeOf(tester, find.byType(RegionExamples)), const Locale('ar'));
      expect(
        directionOf(tester, find.byType(RegionExamples)),
        TextDirection.rtl,
      );
      final shown = _examples(tester);
      expect('${shown.date} · ${shown.time}', '10/13/2026 · 2:32${_nnbsp}PM');
      expect(shown.number, '18,500.50');
      expect(shown.size, '10.5${_nbsp}pt');
    });

    testWidgets('the Arabic UI with the United States region writes 100% as '
        'the United States does', (tester) async {
      await _open(
        tester,
        M1Screen.settingsGeneral,
        languageCode: 'ar',
        regionCode: 'US',
      );
      expect(_zoom100(tester), '100%');
    });

    testWidgets('the Arabic UI with the United States region counts first-run '
        'steps in Latin digits', (tester) async {
      await _open(
        tester,
        M1Screen.privacyStep,
        languageCode: 'ar',
        regionCode: 'US',
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(WelcomeStep)),
      );
      expect(find.text(l10n.onboardingStep('1', '2')), findsOneWidget);
    });

    testWidgets('an English UI with the Saudi Arabia region gets Arabic-Indic '
        'digits', (tester) async {
      await _open(
        tester,
        M1Screen.settingsLanguage,
        languageCode: 'en',
        regionCode: 'SA',
      );
      final shown = _examples(tester);
      expect(shown.date, '١٣\u200F/١٠\u200F/٢٠٢٦');
      expect(shown.size, '١٠٫٥${_nbsp}pt');
      expect(find.text('Region formats'), findsOneWidget);
    });

    testWidgets('a Turkish UI with the United States region keeps US formats', (
      tester,
    ) async {
      await _open(
        tester,
        M1Screen.settingsLanguage,
        languageCode: 'tr',
        regionCode: 'US',
      );
      final shown = _examples(tester);
      expect(shown.date, '10/13/2026');
      expect(shown.number, '18,500.50');
      expect(shown.size, '10.5${_nbsp}pt');
    });
  });
}
