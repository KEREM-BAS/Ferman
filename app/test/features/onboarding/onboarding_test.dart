import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/onboarding/free_step.dart';
import 'package:ferman/features/onboarding/language_picker.dart';
import 'package:ferman/features/onboarding/onboarding_link.dart';
import 'package:ferman/features/onboarding/onboarding_screen.dart';
import 'package:ferman/features/onboarding/privacy_step.dart';
import 'package:ferman/features/onboarding/welcome_step.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/isolated_fallback.g.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import 'ferman_app_harness.dart';

const _firstRun = AppSettings();

void main() {
  group('first run', () {
    testWidgets('the router shows first run instead of the start screen', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(LanguagePicker), findsOneWidget);
      expect(find.byType(FmStart), findsNothing);
    });

    testWidgets('a finished first run opens the start screen directly', (
      tester,
    ) async {
      await pumpFermanApp(tester);
      expect(find.byType(FmStart), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });

  group('language picker (a1-1)', () {
    testWidgets('lists the 21 languages by their own names', (tester) async {
      await pumpFermanApp(tester, settings: _firstRun);
      expect(find.text('Choose a language'), findsOneWidget);
      for (final language in AppLanguage.values) {
        expect(
          find.text(language.endonym),
          findsOneWidget,
          reason: language.tag,
        );
      }
      // English is the system language here and selected.
      expect(find.text('System language'), findsOneWidget);
      expect(
        find.text(
          'English is selected because it’s your system language. You can '
          'change it any time in Settings › Language and region.',
        ),
        findsOneWidget,
      );
      // The 18 languages without a translation say so (G20).
      expect(find.text('Not translated yet'), findsNWidgets(18));
      // The English names stand beside the others.
      expect(find.text('Turkish'), findsOneWidget);
      expect(find.text('Chinese, Traditional'), findsOneWidget);
    });

    testWidgets('marks the system language and selects it', (tester) async {
      await pumpFermanApp(
        tester,
        settings: _firstRun,
        systemLocales: const [Locale('tr', 'TR')],
      );
      expect(localeOf(tester, find.byType(LanguagePicker)), const Locale('tr'));
      final row = find.ancestor(
        of: find.text('Türkçe'),
        matching: find.byType(Semantics),
      );
      expect(
        tester.getSemantics(row.first),
        matchesSemantics(
          // The UI is Turkish: "Sistem dili" is "System language".
          label: 'Türkçe, Sistem dili',
          isChecked: true,
          hasCheckedState: true,
          isInMutuallyExclusiveGroup: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('choosing Türkçe switches the UI at once and stores it', (
      tester,
    ) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      await tester.tap(find.text('Türkçe'));
      await tester.pumpAndSettle();
      expect(localeOf(tester, find.byType(LanguagePicker)), const Locale('tr'));
      expect((await store.load()).languageCode, 'tr');
      // The subtitle, now in Turkish, no longer says it is the system
      // language.
      expect(
        find.text(
          'Bunu istediğiniz zaman Ayarlar › Dil ve bölge bölümünden '
          'değiştirebilirsiniz.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('choosing العربية mirrors the whole UI at once', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      expect(
        directionOf(tester, find.byType(LanguagePicker)),
        TextDirection.ltr,
      );
      final englishRowStart = tester.getTopLeft(find.text('English')).dx;
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(
        directionOf(tester, find.byType(LanguagePicker)),
        TextDirection.rtl,
      );
      // The first column now sits on the right.
      expect(
        tester.getTopLeft(find.text('English')).dx,
        greaterThan(englishRowStart),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('choosing a language without a translation keeps English', (
      tester,
    ) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, 'de');
      expect(localeOf(tester, find.byType(LanguagePicker)), const Locale('en'));
    });

    testWidgets('the search filters in any script', (tester) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await tester.enterText(find.byType(EditableText), 'deu');
      await tester.pumpAndSettle();
      expect(find.text('Deutsch'), findsOneWidget);
      expect(find.text('Türkçe'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'العر');
      await tester.pumpAndSettle();
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('Deutsch'), findsNothing);
      await tester.enterText(find.byType(EditableText), 'klingon');
      await tester.pumpAndSettle();
      expect(find.text('No language matches “klingon”.'), findsOneWidget);
    });

    testWidgets('arrow keys move through the list; Enter continues', (
      tester,
    ) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      // From the search field, one Tab into the list.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final english = Focus.of(tester.element(find.text('English')));
      expect(english.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Türkçe'))).hasFocus, isTrue);
      // Up from the first row wraps to the last.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.text('Tiếng Việt'))).hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, 'tr');
      expect(find.byType(WelcomeStep), findsOneWidget);
    });

    testWidgets('Help translate Ferman is disabled until the project exists', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      expect(
        hintOf(tester, find.text('Help translate Ferman')),
        'Available in a future version',
      );
      expect(
        tester.getSemantics(find.text('Help translate Ferman')),
        isSemantics(isLink: true, isButton: false),
      );
    });

    testWidgets('the search field has focus at once: typing filters and '
        'Enter keeps the system language', (tester) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      expect(_hasFocus(tester, find.byType(EditableText)), isTrue);
      tester.testTextInput.enterText('deu');
      await tester.pumpAndSettle();
      expect(find.text('Deutsch'), findsOneWidget);
      expect(find.text('Türkçe'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeStep), findsOneWidget);
      // The system's language stays in force, stored as no choice.
      expect((await store.load()).languageCode, isNull);
    });

    testWidgets('Enter in the search field continues without a filter too', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeStep), findsOneWidget);
    });

    testWidgets('the list is one Tab stop, on the selected language', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(languageCode: 'de'),
      );
      // Search field → the selected Deutsch → the footer link → Continue.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_hasFocus(tester, find.text('Deutsch')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_hasFocus(tester, find.text('Help translate Ferman')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_hasFocus(tester, find.text('Continue')), isTrue);
    });

    testWidgets('the Tab stop follows the arrow keys and the filter', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_hasFocus(tester, find.text('Türkçe')), isTrue);
      // On to the footer, and back into the list where focus left it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_hasFocus(tester, find.text('Help translate Ferman')), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(_hasFocus(tester, find.text('Türkçe')), isTrue);
      // A filter that hides the selected English puts the stop on the
      // first match.
      await tester.enterText(find.byType(EditableText), 'deu');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_hasFocus(tester, find.text('Deutsch')), isTrue);
    });

    testWidgets('Space selects the focused language and stays', (tester) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      for (var i = 0; i < 2; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();
      expect(_hasFocus(tester, find.text('Deutsch')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, 'de');
      expect(find.byType(LanguagePicker), findsOneWidget);
    });

    testWidgets('screen readers hear one radio group of the 21 languages', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpFermanApp(tester, settings: _firstRun);
      final group = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.role == SemanticsRole.radioGroup,
      );
      expect(group, findsOneWidget);
      expect(tester.widget<Semantics>(group).properties.label, 'App language');
      final radios = <SemanticsNode>[];
      void collect(SemanticsNode node) {
        if (node
            .getSemanticsData()
            .flagsCollection
            .isInMutuallyExclusiveGroup) {
          radios.add(node);
        }
        node.visitChildren((child) {
          collect(child);
          return true;
        });
      }

      collect(tester.getSemantics(group));
      expect(radios, hasLength(21));
      expect(
        tester.getSemantics(
          find
              .ancestor(
                of: find.text('Deutsch'),
                matching: find.byType(Semantics),
              )
              .first,
        ),
        isSemantics(label: 'Deutsch, German, Not translated yet'),
      );
      handle.dispose();
    });

    testWidgets('a mouse click selects without the focus ring', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final store = await pumpFermanApp(tester, settings: _firstRun);
      FocusRing ringOf(String name) => tester.widget<FocusRing>(
        find.ancestor(of: find.text(name), matching: find.byType(FocusRing)),
      );
      await tester.tap(find.text('Deutsch'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, 'de');
      expect(_hasFocus(tester, find.text('Deutsch')), isFalse);
      expect(ringOf('Deutsch').visible, isFalse);
      // Keyboard focus on the clicked language (the list's Tab stop now)
      // shows the ring there.
      for (var i = 0; i < 3 && !_hasFocus(tester, find.text('Deutsch')); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(_hasFocus(tester, find.text('Deutsch')), isTrue);
      expect(ringOf('Deutsch').visible, isTrue);
    });

    for (final (endonym, tag) in const [('فارسی', 'fa'), ('עברית', 'he')]) {
      testWidgets('choosing $endonym mirrors the UI, with English strings '
          '(G20)', (tester) async {
        final store = await pumpFermanApp(tester, settings: _firstRun);
        await tester.tap(find.text(endonym));
        await tester.pumpAndSettle();
        expect((await store.load()).languageCode, tag);
        expect(
          directionOf(tester, find.byType(LanguagePicker)),
          TextDirection.rtl,
        );
        expect(
          localeOf(tester, find.byType(LanguagePicker)),
          const Locale('en'),
        );
        // The English strings come in left-to-right isolates (G93).
        expect(
          find.text(IsolatedFallbackLocalizations.isolate('Choose a language')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('choosing the system’s language again follows the system', (
      tester,
    ) async {
      final store = await pumpFermanApp(
        tester,
        settings: _firstRun,
        systemLocales: const [Locale('tr', 'TR')],
      );
      await tester.tap(find.text('English').first);
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, 'en');
      await tester.tap(find.text('Türkçe'));
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, isNull);
      expect(localeOf(tester, find.byType(LanguagePicker)), const Locale('tr'));
    });
  });

  group('privacy step (a1-2b)', () {
    Future<void> openPrivacy(WidgetTester tester) async {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the facts and the four network uses (G24)', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Everything stays on your device'), findsOneWidget);
      for (final title in [
        'Files stay on this device',
        'Works offline',
        'No account',
        'No telemetry',
        'One optional check for updates',
        'OCR language packs',
        'AI assistant',
        'Signature timestamps',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(
        find.text(
          'Once a day, sending only the version number and platform. You can '
          'turn it off.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Off until you use it.'), findsNWidgets(3));
      expect(find.textContaining('revoked'), findsNothing);
    });

    testWidgets('announces the step as "Step 1 of 2" (a1-2a note)', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      expect(_stepLabel('Step 1 of 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 2'), findsOneWidget);
    });

    testWidgets('every fact row is as tall as the board draws it, the line '
        'below added to its padding, the last row too', (tester) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      final rows = find.descendant(
        of: find.byType(PrivacyFacts),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.padding ==
                  const EdgeInsetsDirectional.symmetric(
                    horizontal: PrivacyFacts.rowPaddingX,
                    vertical: PrivacyFacts.rowPaddingY,
                  ),
        ),
      );
      expect(rows, findsNWidgets(8));
      for (final element in rows.evaluate()) {
        final row = element.widget as Container;
        final border = (row.decoration! as BoxDecoration).border! as Border;
        expect(border.bottom.width, 1);
        final box = element.renderObject! as RenderBox;
        final content = tester.getSize(
          find.descendant(
            of: find.byWidget(row),
            matching: find.byType(MergeSemantics),
          ),
        );
        // 16 + content + 16 + the 1 px line.
        expect(box.size.height, content.height + 2 * 16 + 1);
      }
    });

    testWidgets('the settings link is a link for screen readers', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      expect(
        tester.getSemantics(
          find.text('See every connection in Settings › Privacy'),
        ),
        isSemantics(isLink: true, isButton: false, hasTapAction: true),
      );
    });

    testWidgets('the settings link ends in an arrow, as a1-2b draws it', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      final link = find.ancestor(
        of: find.text('See every connection in Settings › Privacy'),
        matching: find.byType(OnboardingLink),
      );
      final arrow = tester.widget<Icon>(
        find.descendant(of: link, matching: find.byType(Icon)),
      );
      expect(arrow.name, IconName.arrowRight);
      expect(arrow.size, OnboardingLink.trailingIconSize);
      // After the text: to its right in left-to-right English.
      expect(
        tester.getTopLeft(find.byWidget(arrow)).dx,
        greaterThan(
          tester
              .getTopRight(
                find.text('See every connection in Settings › Privacy'),
              )
              .dx,
        ),
      );
    });

    testWidgets('links to Settings › Privacy and comes back to the step', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      await tester.tap(find.text('See every connection in Settings › Privacy'));
      await tester.pumpAndSettle();
      expect(find.byType(FmSettings), findsOneWidget);
      expect(find.text('Ferman collects nothing.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FmSettings), findsNothing);
      expect(find.text('Everything stays on your device'), findsOneWidget);
    });

    testWidgets('Back returns to the language picker', (tester) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePicker), findsOneWidget);
    });

    testWidgets('Skip finishes first run', (tester) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(FmStart), findsOneWidget);
      expect((await store.load()).onboardingCompleted, isTrue);
    });

    testWidgets('Esc finishes first run', (tester) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      await openPrivacy(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FmStart), findsOneWidget);
      expect((await store.load()).onboardingCompleted, isTrue);
    });

    testWidgets('Esc does nothing on the language picker', (tester) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePicker), findsOneWidget);
      expect((await store.load()).onboardingCompleted, isFalse);
    });
  });

  group('free step (a1-2c)', () {
    Future<void> openFree(WidgetTester tester) async {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    testWidgets('says Apache-2.0 and never marks later features Included', (
      tester,
    ) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openFree(tester);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Free forever, nothing locked'), findsOneWidget);
      expect(find.textContaining('Apache-2.0'), findsOneWidget);
      expect(find.textContaining('GPL'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      // G12: only the interface languages have shipped.
      expect(find.text('3 interface languages'), findsOneWidget);
      expect(
        find.bySemanticsLabel('3 interface languages. Included'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'\. Available in a future version$')),
        findsNWidgets(WelcomeFeature.values.length - 1),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Redaction\. Included')),
        findsNothing,
      );
      expect(
        hintOf(tester, find.text('Source code')),
        'Available in a future version',
      );
      // Only the shipped feature carries the green check (G12).
      expect(
        find.descendant(
          of: find.byType(FeatureGrid),
          matching: find.byWidgetPredicate(
            (widget) => widget is Icon && widget.name == IconName.check,
          ),
        ),
        findsOneWidget,
      );
      expect(_stepLabel('Step 2 of 2'), findsOneWidget);
      // The licence links are links for screen readers (the board's <a>).
      for (final link in ['Source code', 'Support the project']) {
        expect(
          tester.getSemantics(find.text(link)),
          isSemantics(isLink: true, isButton: false),
          reason: link,
        );
      }
    });

    testWidgets('Esc on the last step finishes first run', (tester) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      await openFree(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FmStart), findsOneWidget);
      expect((await store.load()).onboardingCompleted, isTrue);
    });

    testWidgets('Start using Ferman finishes first run', (tester) async {
      final store = await pumpFermanApp(tester, settings: _firstRun);
      await openFree(tester);
      await tester.tap(find.text('Start using Ferman'));
      await tester.pumpAndSettle();
      expect(find.byType(FmStart), findsOneWidget);
      expect((await store.load()).onboardingCompleted, isTrue);
    });

    testWidgets('Back returns to the privacy step', (tester) async {
      await pumpFermanApp(tester, settings: _firstRun);
      await openFree(tester);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Everything stays on your device'), findsOneWidget);
    });

    testWidgets('the counter follows the region’s digits (G34)', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(languageCode: 'ar', regionCode: 'SA'),
      );
      await _advance(tester, 2);
      // The Arabic step counter's numbers are the Saudi region's
      // Arabic-Indic digits.
      expect(find.text('٢ من ٢'), findsOneWidget);
    });
  });

  group('every step in en, tr and ar', () {
    for (final (code, direction) in const [
      ('en', TextDirection.ltr),
      ('tr', TextDirection.ltr),
      ('ar', TextDirection.rtl),
    ]) {
      for (final size in const [boardSize, Size(1024, 680)]) {
        final name = '$code at ${size.width.toInt()} × ${size.height.toInt()}';
        testWidgets(name, (tester) async {
          await pumpFermanApp(
            tester,
            settings: AppSettings(languageCode: code),
            size: size,
          );
          expect(localeOf(tester, find.byType(LanguagePicker)), Locale(code));
          expect(directionOf(tester, find.byType(LanguagePicker)), direction);
          expect(tester.takeException(), isNull);
          for (var step = 1; step <= 2; step++) {
            await _advance(tester, 1);
            expect(find.byType(WelcomeStep), findsOneWidget);
            expect(
              tester.widget<WelcomeStep>(find.byType(WelcomeStep)).step,
              step,
            );
            expect(directionOf(tester, find.byType(WelcomeStep)), direction);
            expect(tester.takeException(), isNull);
            // The headline column leads: at the right in right to left.
            final shown = tester.widget<WelcomeStep>(find.byType(WelcomeStep));
            final headline = tester.getRect(find.text(shown.title));
            final aside = tester.getRect(find.byWidget(shown.aside));
            if (direction == TextDirection.rtl) {
              expect(headline.left, greaterThan(aside.left));
            } else {
              expect(headline.left, lessThan(aside.left));
            }
          }
        });
      }
    }
  });
}

/// Whether the focus node around [finder]'s widget has focus.
bool _hasFocus(WidgetTester tester, Finder finder) =>
    Focus.of(tester.element(finder)).hasFocus;

/// The step dots' screen-reader label, "Step 1 of 2" (a1-2a note).
Finder _stepLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

/// Moves first run on by [steps] steps through its own buttons' callbacks,
/// whatever the language of their labels.
Future<void> _advance(WidgetTester tester, int steps) async {
  for (var i = 0; i < steps; i++) {
    final picker = find.byType(LanguagePicker);
    if (picker.evaluate().isNotEmpty) {
      tester.widget<LanguagePicker>(picker).onContinue();
    } else {
      tester.widget<WelcomeStep>(find.byType(WelcomeStep)).onNext();
    }
    await tester.pumpAndSettle();
  }
}
