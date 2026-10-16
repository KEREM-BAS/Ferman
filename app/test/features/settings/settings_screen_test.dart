import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/settings/language_region_pane.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/isolated_fallback.g.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/ferman_app_harness.dart';

const _future = 'Available in a future version';

/// Opens Settings on [pane] from the start screen, as the a1-2b link and
/// the shortcut do.
Future<void> _openAndSettle(WidgetTester tester, [String? pane]) async {
  final context = tester.element(find.byType(FmStart));
  // The push completes only when Settings closes.
  unawaited(
    GoRouter.of(context)
        .push<void>(pane == null ? Routes.settings : Routes.settingsPane(pane)),
  );
  await tester.pumpAndSettle();
}

/// The app-language select (the one with the `languages` icon).
final Finder _languageSelect = find.byWidgetPredicate(
  (widget) => widget is Select && widget.icon == IconName.languages,
);

Finder _navRow(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(FermanInteractive),
);

/// A store whose saves fail while [failing] is set.
final class _FlakyStore implements SettingsStore {
  bool failing = true;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {
    if (failing) throw const SettingsStoreException('disk full');
  }
}

/// The region select (the Select of region codes).
final Finder _regionSelect = find.byType(Select<String>);

void main() {
  group('Settings (a11-1)', () {
    testWidgets('lists the 11 panes; only the built ones are enabled', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester);
      expect(find.byType(FmSettings), findsOneWidget);
      for (final label in [
        'Language and region',
        'Editing',
        'Fonts',
        'Signatures and certificates',
        'Text recognition (OCR)',
        'AI assistant',
        'Privacy',
        'Updates',
        'Keyboard shortcuts',
        'Advanced',
      ]) {
        expect(_navRow(label), findsOneWidget, reason: label);
      }
      // General is both the row and the heading.
      expect(find.text('General'), findsNWidgets(2));
      const labels = [
        'General',
        'Language and region',
        'Editing',
        'Fonts',
        'Signatures and certificates',
        'Text recognition (OCR)',
        'AI assistant',
        'Privacy',
        'Updates',
        'Keyboard shortcuts',
        'Advanced',
      ];
      for (final (index, pane) in SettingsPane.values.indexed) {
        final row = tester.widget<FermanInteractive>(_navRow(labels[index]));
        expect(row.onPressed != null, pane.available, reason: pane.name);
        expect(row.disabledReason, pane.available ? null : _future);
      }
      expect(
        SettingsPane.values.where((pane) => !pane.available),
        hasLength(8),
      );
    });

    testWidgets('the search is disabled with the reason', (tester) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.disabled, isTrue);
      expect(field.disabledReason, _future);
    });

    testWidgets('switches panes', (tester) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester);
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Ferman collects nothing.'), findsOneWidget);
      await tester.tap(find.text('Language and region'));
      await tester.pumpAndSettle();
      expect(find.text('Region formats'), findsOneWidget);
      // A pane not built yet stays where it was.
      await tester.tap(find.text('Fonts'));
      await tester.pumpAndSettle();
      expect(find.text('Region formats'), findsOneWidget);
    });

    testWidgets('a route names the pane; unbuilt panes open General', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester, 'privacy');
      expect(find.text('Ferman collects nothing.'), findsOneWidget);
      expect(SettingsPane.fromPath('editing'), SettingsPane.general);
      expect(SettingsPane.fromPath('language'), SettingsPane.language);
      expect(SettingsPane.fromPath(null), SettingsPane.general);
    });

    testWidgets('Esc, Ctrl+W and the close button return to the start', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FmSettings), findsNothing);
      expect(find.byType(FmStart), findsOneWidget);

      await _openAndSettle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(FmSettings), findsNothing);

      await _openAndSettle(tester);
      await tester.tap(find.bySemanticsLabel('Close settings'));
      await tester.pumpAndSettle();
      expect(find.byType(FmSettings), findsNothing);
      expect(find.byType(FmStart), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('⌘W closes Settings on macOS, from the shortcut table', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(FmSettings), findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(find.byType(FmSettings), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    for (final (code, direction) in const [
      ('en', TextDirection.ltr),
      ('ar', TextDirection.rtl),
    ]) {
      testWidgets('Tab goes through the pane list, then the pane ($code)', (
        tester,
      ) async {
        await pumpFermanApp(
          tester,
          settings: AppSettings(onboardingCompleted: true, languageCode: code),
        );
        await _openAndSettle(tester);
        final navEdge = direction == TextDirection.ltr
            ? FmSettings.navWidth
            : boardSize.width - FmSettings.navWidth;
        bool inNav(Rect rect) => direction == TextDirection.ltr
            ? rect.right <= navEdge
            : rect.left >= navEdge;
        final order = <bool>[];
        for (var i = 0; i < 20; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          order.add(inNav(FocusManager.instance.primaryFocus!.rect));
        }
        final firstPane = order.indexOf(false);
        // The search field and the 11 panes come first, all of them …
        expect(firstPane, 12, reason: '$order');
        // … then the pane's controls, not back and forth.
        expect(order.sublist(firstPane, firstPane + 6), everyElement(isFalse));
      });
    }

    testWidgets('a change that cannot be saved still applies, and a warning '
        'says so until a change is saved again', (tester) async {
      final store = _FlakyStore();
      await pumpFermanApp(tester, store: store);
      await _openAndSettle(tester);
      expect(find.byType(Banner), findsNothing);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(FmSettings)).ferman.isDark, isTrue);
      final banner = tester.widget<Banner>(find.byType(Banner));
      expect(banner.tone, BannerTone.warning);
      expect(banner.title, 'Your settings couldn’t be saved.');
      expect(
        find.text('This change applies until you close Ferman.'),
        findsOneWidget,
      );
      // It stays while another pane shows; a stored change clears it.
      await tester.tap(find.text('Language and region'));
      await tester.pumpAndSettle();
      expect(find.byType(Banner), findsOneWidget);
      store.failing = false;
      tester.widget<Select<String>>(_regionSelect).onChanged!('TR');
      await tester.pumpAndSettle();
      expect(find.byType(Banner), findsNothing);
      // A failure again, then Dismiss hides it.
      store.failing = true;
      tester.widget<Select<String>>(_regionSelect).onChanged!('DE');
      await tester.pumpAndSettle();
      expect(find.byType(Banner), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(Banner), findsNothing);
    });
  });

  group('General', () {
    testWidgets('the theme switches at once and persists', (tester) async {
      final store = await pumpFermanApp(tester);
      await _openAndSettle(tester);
      expect(tester.element(find.byType(FmSettings)).ferman.isDark, isFalse);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(FmSettings)).ferman.isDark, isTrue);
      expect((await store.load()).themeMode, AppThemeMode.dark);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect((await store.load()).themeMode, AppThemeMode.light);
      await tester.tap(find.text('Match system'));
      await tester.pumpAndSettle();
      expect((await store.load()).themeMode, AppThemeMode.system);
    });

    testWidgets('the stored theme is there after a restart', (tester) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          themeMode: AppThemeMode.dark,
        ),
      );
      expect(tester.element(find.byType(FmStart)).ferman.isDark, isTrue);
      await _openAndSettle(tester);
      final control = tester.widget<SegmentedControl<AppThemeMode>>(
        find.byType(SegmentedControl<AppThemeMode>),
      );
      expect(control.value, AppThemeMode.dark);
    });

    testWidgets('later options are drawn and disabled', (tester) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester);
      for (final radio in tester.widgetList<Radio<Object?>>(
        find.byWidgetPredicate((widget) => widget is Radio),
      )) {
        expect(radio.disabled, isTrue);
        expect(radio.disabledReason, _future);
      }
      final selects = tester.widgetList<Select<String>>(
        find.byType(Select<String>),
      );
      expect(selects, hasLength(2));
      for (final select in selects) {
        expect(select.disabledReason, _future);
      }
      expect(
        tester.widget<Switch>(find.byType(Switch)).disabledReason,
        _future,
      );
      expect(
        tester
            .widget<FermanInteractive>(
              _navRow('Make Ferman the default…').first,
            )
            .disabledReason,
        _future,
      );
      expect(
        find.text(
          'Ferman can be the app that opens when you double-click a PDF.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the zoom option writes 100% as the region does (G34)', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          regionCode: 'TR',
        ),
      );
      await _openAndSettle(tester);
      final zoom = tester.widget<Select<String>>(
        find.byWidgetPredicate(
          (widget) => widget is Select<String> && widget.label == 'Zoom',
        ),
      );
      expect(zoom.options.last.label, bidiIsolate('%100'));
    });

    testWidgets('on Windows the default-app line names Windows Settings '
        '(a11-1w, G16)', (tester) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester);
      expect(
        find.text(
          'Ferman can be the app that opens when you double-click a PDF. '
          'Windows lets you choose it in Settings › Default apps.',
        ),
        findsOneWidget,
      );
      expect(find.text('Make Ferman the default…'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });

  group('Language and region (a11-1b)', () {
    testWidgets('choosing Türkçe switches the app at once', (tester) async {
      final store = await pumpFermanApp(tester);
      await _openAndSettle(tester, 'language');
      await tester.tap(_languageSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Türkçe').last);
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, 'tr');
      expect(localeOf(tester, find.byType(FmSettings)), const Locale('tr'));
      expect(find.text('Ayarlar'), findsOneWidget);
      // Back to the system's English: no choice is stored, so the app
      // follows the system again.
      tester
          .widget<Select<AppLanguage>>(find.byType(Select<AppLanguage>))
          .onChanged!(AppLanguage.english);
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, isNull);
      expect(localeOf(tester, find.byType(FmSettings)), const Locale('en'));
    });

    testWidgets('choosing فارسی mirrors the settings, in English', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester, 'language');
      tester
          .widget<Select<AppLanguage>>(find.byType(Select<AppLanguage>))
          .onChanged!(AppLanguage.persian);
      await tester.pumpAndSettle();
      expect(directionOf(tester, find.byType(FmSettings)), TextDirection.rtl);
      expect(localeOf(tester, find.byType(FmSettings)), const Locale('en'));
      // The English strings come in left-to-right isolates (G93).
      expect(
        find.text(IsolatedFallbackLocalizations.isolate('Settings')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing العربية mirrors the settings', (tester) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester, 'language');
      final navStart = tester.getCenter(find.text('Settings')).dx;
      await tester.tap(_languageSelect);
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية').last);
      await tester.pumpAndSettle();
      expect(directionOf(tester, find.byType(FmSettings)), TextDirection.rtl);
      // The pane list moves to the right (a12-2c).
      expect(
        tester.getCenter(find.text('الإعدادات')).dx,
        greaterThan(navStart),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists the 21 languages, untranslated ones marked (G20)', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester, 'language');
      final select = tester.widget<Select<Object?>>(_languageSelect);
      expect(select.options, hasLength(21));
      expect(
        select.options.where((o) => o.label.endsWith(' · Not translated yet')),
        hasLength(18),
      );
      expect(
        select.options.map((o) => o.label),
        contains('Deutsch · Not translated yet'),
      );
    });

    testWidgets('own names take their own Han forms: languages and regions', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          regionCode: 'TW',
        ),
      );
      await _openAndSettle(tester, 'language');
      final languages = tester.widget<Select<Object?>>(_languageSelect);
      Locale? localeOf(Select<Object?> select, bool Function(String) label) =>
          select.options.firstWhere((o) => label(o.label)).locale;
      expect(
        localeOf(languages, (l) => l.startsWith('繁體中文')),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(
        localeOf(languages, (l) => l.startsWith('日本語')),
        const Locale('ja'),
      );
      expect(localeOf(languages, (l) => l == 'English'), const Locale('en'));
      final regions = tester.widget<Select<String>>(_regionSelect);
      Locale? regionLocale(String code) =>
          regions.options.firstWhere((o) => o.value == code).locale;
      expect(regionLocale('TW'), const Locale('zh', 'TW'));
      // Only the regions that write their names in Han carry a locale.
      expect(regionLocale('TR'), isNull);
    });

    testWidgets('examples follow the region, not the UI language (G34)', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          regionCode: 'TR',
        ),
      );
      await _openAndSettle(tester, 'language');
      expect(find.text('Türkiye'), findsOneWidget);
      expect(find.text(bidiIsolate('13.10.2026')), findsOneWidget);
      expect(find.text(bidiIsolate('14:32')), findsOneWidget);
      expect(find.text(bidiIsolate('18.500,50')), findsOneWidget);
      expect(find.text(bidiIsolate('10,5\u00A0pt')), findsOneWidget);
      expect(find.text('EXAMPLES'), findsOneWidget);
    });

    testWidgets('choosing a region changes the examples and defaults', (
      tester,
    ) async {
      final store = await pumpFermanApp(tester);
      await _openAndSettle(tester, 'language');
      expect(find.text(bidiIsolate('10/13/2026')), findsOneWidget);
      final region = find.byType(Select<String>);
      tester.widget<Select<String>>(region).onChanged!('TR');
      await tester.pumpAndSettle();
      expect((await store.load()).regionCode, 'TR');
      expect(find.text(bidiIsolate('13.10.2026')), findsOneWidget);
      final paper = tester.widget<SegmentedControl<PaperSize>>(
        find.byType(SegmentedControl<PaperSize>),
      );
      expect(paper.value, PaperSize.a4);
    });

    testWidgets('paper, units and week store overrides only when they differ', (
      tester,
    ) async {
      final store = await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          regionCode: 'TR',
        ),
      );
      await _openAndSettle(tester, 'language');
      await tester.tap(find.text('Letter'));
      await tester.pumpAndSettle();
      expect((await store.load()).paperSize, PaperSize.letter);
      await tester.tap(find.text('A4'));
      await tester.pumpAndSettle();
      expect((await store.load()).paperSize, isNull);
      await tester.tap(find.text('in'));
      await tester.pumpAndSettle();
      expect((await store.load()).lengthUnit, LengthUnit.inch);
      tester
          .widget<Select<FirstDayOfWeek>>(find.byType(Select<FirstDayOfWeek>))
          .onChanged!(FirstDayOfWeek.sunday);
      await tester.pumpAndSettle();
      expect((await store.load()).firstDayOfWeek, FirstDayOfWeek.sunday);
      tester
          .widget<Select<FirstDayOfWeek>>(find.byType(Select<FirstDayOfWeek>))
          .onChanged!(FirstDayOfWeek.monday);
      await tester.pumpAndSettle();
      expect((await store.load()).firstDayOfWeek, isNull);
    });

    testWidgets('offers Friday where the region starts the week on it', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          regionCode: 'MV',
        ),
      );
      await _openAndSettle(tester, 'language');
      final week = tester.widget<Select<FirstDayOfWeek>>(
        find.byType(Select<FirstDayOfWeek>),
      );
      expect(week.options.map((o) => o.value), contains(FirstDayOfWeek.friday));
      expect(week.value, FirstDayOfWeek.friday);
    });

    testWidgets('document languages are drawn and disabled: the region’s '
        'language, then English', (tester) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          regionCode: 'TR',
        ),
      );
      await _openAndSettle(tester, 'language');
      expect(find.text('Document languages'), findsOneWidget);
      // a11-1b: Turkish and English with the Türkiye region.
      expect(find.widgetWithText(Badge, 'Turkish'), findsOneWidget);
      expect(find.widgetWithText(Badge, 'English'), findsOneWidget);
      final add = tester.widget<Button>(find.widgetWithText(Button, 'Add'));
      expect(add.disabledReason, _future);
      // The badges sit at the top of the row, as the board's flex row
      // leaves them, not centred on the 26 px button.
      expect(
        tester.getTopLeft(find.widgetWithText(Badge, 'Turkish')).dy,
        tester.getTopLeft(find.widgetWithText(Button, 'Add')).dy,
      );
    });

    testWidgets('a region whose language has no name shows English only', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester, 'language');
      expect(find.byType(Badge), findsOneWidget);
      expect(find.widgetWithText(Badge, 'English'), findsOneWidget);
    });

    testWidgets('document languages in Arabic match a12-2c', (tester) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'ar',
          regionCode: 'TR',
        ),
      );
      await _openAndSettle(tester, 'language');
      expect(find.widgetWithText(Badge, 'التركية'), findsOneWidget);
      expect(find.widgetWithText(Badge, 'الإنجليزية'), findsOneWidget);
      expect(find.widgetWithText(Badge, 'العربية'), findsNothing);
    });

    testWidgets('the system’s region stays on offer, under its name, and '
        'choosing it follows the system again', (tester) async {
      final store = await pumpFermanApp(
        tester,
        systemLocales: const [Locale('nl', 'BE')],
      );
      await _openAndSettle(tester, 'language');
      List<SelectOption<String>> options() =>
          tester.widget<Select<String>>(_regionSelect).options;
      expect(
        options().where((o) => o.value == 'BE').single.label,
        'Belgium (België)',
      );
      tester.widget<Select<String>>(_regionSelect).onChanged!('TR');
      await tester.pumpAndSettle();
      expect((await store.load()).regionCode, 'TR');
      expect(options().map((o) => o.value), contains('BE'));
      tester.widget<Select<String>>(_regionSelect).onChanged!('BE');
      await tester.pumpAndSettle();
      expect((await store.load()).regionCode, isNull);
    });

    testWidgets('the regions are in the UI language’s alphabetical order', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'tr',
        ),
      );
      await _openAndSettle(tester, 'language');
      final labels = [
        for (final option
            in tester.widget<Select<String>>(_regionSelect).options)
          option.label,
      ];
      final czechia = labels.indexOf('Çekya (Česko)');
      expect(czechia, greaterThan(labels.indexOf('Brezilya (Brasil)')));
      expect(czechia, lessThan(labels.indexOf('Danimarka (Danmark)')));
    });

    testWidgets('right to left keeps each example in its own order', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'ar',
          regionCode: 'TR',
        ),
      );
      await _openAndSettle(tester, 'language');
      expect(find.text('تركيا (Türkiye)'), findsOneWidget);
      expect(find.text(bidiIsolate('10,5\u00A0pt')), findsOneWidget);
      expect(find.byType(RegionExamples), findsOneWidget);
    });
  });

  group('Privacy (a11-1h)', () {
    testWidgets('lists the network uses, each off and disabled', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      await _openAndSettle(tester, 'privacy');
      for (final title in [
        'Check for updates',
        'Signature checks',
        'Timestamps',
        'Downloads you start',
        'Your AI provider',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      expect(switches, hasLength(5));
      for (final control in switches) {
        expect(control.value, isFalse);
        expect(control.disabled, isTrue);
        expect(control.disabledReason, _future);
      }
      expect(
        tester
            .widget<Button>(
              find.widgetWithText(Button, 'Show network activity…'),
            )
            .disabledReason,
        _future,
      );
    });
  });

  group('every pane in en, tr and ar', () {
    for (final (code, direction) in const [
      ('en', TextDirection.ltr),
      ('tr', TextDirection.ltr),
      ('ar', TextDirection.rtl),
    ]) {
      for (final pane in SettingsPane.values.where((pane) => pane.available)) {
        for (final size in const [boardSize, Size(1024, 680)]) {
          final name =
              '$code ${pane.path} at '
              '${size.width.toInt()} × ${size.height.toInt()}';
          testWidgets(name, (tester) async {
            await pumpFermanApp(
              tester,
              settings: AppSettings(
                onboardingCompleted: true,
                languageCode: code,
                regionCode: 'TR',
              ),
              size: size,
            );
            await _openAndSettle(tester, pane.path);
            expect(tester.takeException(), isNull);
            expect(directionOf(tester, find.byType(FmSettings)), direction);
            expect(localeOf(tester, find.byType(FmSettings)), Locale(code));
          });
        }
      }
    }
  });
}
