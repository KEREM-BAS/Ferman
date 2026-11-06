import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/settings/language_region_pane.dart';
import 'package:ferman/features/settings/phone_settings.dart';
import 'package:ferman/features/settings/privacy_pane.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/phone_golden.dart';
import '../../helpers/text_fit.dart';
import '../onboarding/ferman_app_harness.dart';

const _future = 'Available in a future version';

Finder _row(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(PhoneSettingsRow),
);

Future<void> _open(WidgetTester tester, [SettingsPane? pane]) async {
  expect(tester.takeException(), isNull);
  final context = tester.element(find.byType(FmStart));
  // The push completes only when Settings closes.
  unawaited(
    GoRouter.of(context).push<void>(
      pane == null ? Routes.settings : Routes.settingsPane(pane.path),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls [finder] on screen and taps it.
Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Back on the start screen; see [_open].
void _leftStart(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(FmSettings), findsNothing);
  expect(find.byType(FmStart), findsOneWidget);
}

void main() {
  group('the list (a13-15)', () {
    testWidgets('lists every pane; the built ones open', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester);
      expect(find.byType(PhoneSettingsList), findsOneWidget);
      // The desktop's search is not on the phone boards.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('DOCUMENTS'), findsOneWidget);
      expect(find.text('PRIVACY'), findsOneWidget);
      expect(find.text('No data collected'), findsOneWidget);
      expect(find.byType(PhoneSettingsRow), findsNWidgets(12));
      final disabled = [
        for (final pane in SettingsPane.values)
          if (!pane.available) pane.path,
      ];
      expect(disabled, hasLength(8));
      for (final element in find.byType(PhoneSettingsRow).evaluate()) {
        final row = element.widget as PhoneSettingsRow;
        expect(row.onPressed == null, row.disabledReason == _future);
      }
      expect(
        tester.widget<PhoneSettingsRow>(_row('About and licence')).onPressed,
        isNull,
      );
    });

    testWidgets('Turkish capitals are locale-aware', (tester) async {
      await pumpFermanApp(
        tester,
        settings: const AppSettings(
          onboardingCompleted: true,
          languageCode: 'tr',
        ),
        size: goldenPhoneSize,
      );
      await _open(tester);
      expect(find.text('GİZLİLİK'), findsOneWidget);
    });

    testWidgets('a pane goes back to the list, and the list closes', (
      tester,
    ) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester);
      await _scrollAndTap(tester, _row('Privacy'));
      expect(find.byType(PhoneSettingsList), findsNothing);
      expect(find.text('Privacy'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneSettingsList), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      _leftStart(tester);
    });

    testWidgets('Esc goes back one level too', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester);
      await _scrollAndTap(tester, _row('General'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PhoneSettingsList), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      _leftStart(tester);
    });

    testWidgets('rotated wide, one close leaves the list and the pane', (
      tester,
    ) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester);
      await _scrollAndTap(tester, _row('Privacy'));
      tester.view.physicalSize = const Size(852, 393);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      _leftStart(tester);
    });

    testWidgets('rotated back, the pane chosen while wide stays', (
      tester,
    ) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester);
      await _scrollAndTap(tester, _row('Privacy'));
      tester.view.physicalSize = const Size(1024, 700);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language and region'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = goldenPhoneSize;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(LanguageRegionPane), findsOneWidget);
      expect(find.byType(PrivacyPane), findsNothing);
    });

    testWidgets('a pane opened directly goes back to the list', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      expect(tester.takeException(), isNull);
      GoRouter.of(tester.element(find.byType(FmStart)))
          .go(Routes.settingsPane('privacy'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneSettingsList), findsOneWidget);
    });

    testWidgets('the navigation bar goes home', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      _leftStart(tester);
    });

    testWidgets('a disabled row says why under touch', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester);
      await tester.tap(_row('Editing'));
      await tester.pump();
      expect(find.text(_future), findsOneWidget);
      expect(find.byType(PhoneSettingsList), findsOneWidget);
      await tester.pump(Tooltip.touchHold);
      await tester.pumpAndSettle();
    });
  });

  group('the panes', () {
    testWidgets('General stores a theme through a touch beside a segment', (
      tester,
    ) async {
      final store = await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester, SettingsPane.general);
      final segment = find.text('Dark');
      await tester.ensureVisible(segment);
      await tester.pumpAndSettle();
      final band = find
          .ancestor(of: segment, matching: find.byType(PhoneHitTarget))
          .first;
      expect(tester.getSize(band).height, greaterThanOrEqualTo(44));
      // The band's very top edge, outside the 38 px segment.
      final at = Offset(
        tester.getCenter(segment).dx,
        tester.getTopLeft(band).dy + 1,
      );
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect((await store.load()).themeMode.name, 'dark');
    });

    testWidgets('General leaves out the default-app row', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester, SettingsPane.general);
      expect(find.text('Make default'), findsNothing);
    });

    testWidgets('Language and region stacks and switches the language', (
      tester,
    ) async {
      final store = await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester, SettingsPane.language);
      for (final head in ['App', 'Documents', 'Region']) {
        expect(find.text(head), findsOneWidget, reason: head);
      }
      final language = find.byWidgetPredicate(
        (widget) => widget is Select && widget.icon == IconName.languages,
      );
      await tester.tap(language);
      await tester.pumpAndSettle();
      final option = find.text(
        AppLanguage.values
            .firstWhere((language) => language.tag == 'tr')
            .endonym,
      );
      // The open list's rows are finger-sized too.
      final row = find
          .ancestor(of: option, matching: find.byType(GestureDetector))
          .first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect((await store.load()).languageCode, 'tr');
      expect(find.text('Dil ve bölge'), findsOneWidget);
    });

    testWidgets('Privacy keeps its switches disabled with the reason', (
      tester,
    ) async {
      await pumpFermanApp(tester, size: goldenPhoneSize);
      await _open(tester, SettingsPane.privacy);
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(5));
      for (final element in switches.evaluate()) {
        final control = element.widget as Switch;
        expect(control.disabled, isTrue);
        expect(control.disabledReason, _future);
      }
    });
  });

  // pumpFermanApp fails on any overflow, so walking each screen also proves
  // no control is clipped by its column.
  group('nothing is clipped and every target is 44 px', () {
    for (final (code, width) in const [
      ('en', 393.0),
      ('tr', 393.0),
      ('ar', 393.0),
      ('en', 320.0),
      ('tr', 320.0),
      ('ar', 320.0),
    ]) {
      for (final pane in <SettingsPane?>[
        null,
        SettingsPane.general,
        SettingsPane.language,
        SettingsPane.privacy,
      ]) {
        testWidgets('${pane?.path ?? 'list'} in $code at $width', (
          tester,
        ) async {
          // Tall enough that every row is built and laid out.
          await pumpFermanApp(
            tester,
            settings: AppSettings(
              onboardingCompleted: true,
              languageCode: code,
            ),
            size: Size(width, 2000),
          );
          await _open(tester, pane);
          expect(textFitProblems(tester), isEmpty);
          final view = tester.view.physicalSize.width;
          for (final element in find.byType(FermanInteractive).evaluate()) {
            final box = element.renderObject! as RenderBox;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(view));
            // The hit area: the control's, or the band around it.
            final band = element
                .findAncestorRenderObjectOfType<RenderPhoneHitTarget>();
            final height = band?.size.height ?? box.size.height;
            expect(
              height,
              greaterThanOrEqualTo(44),
              reason: element.widget.toStringShort(),
            );
          }
        });
      }
    }
  });

  group('a phone on its side', () {
    for (final width in const [768.0, 800.0, 844.0, 852.0, 900.0, 915.0]) {
      for (final code in const ['en', 'tr', 'ar']) {
        testWidgets('Language and region fits $width px in $code', (
          tester,
        ) async {
          await pumpFermanApp(
            tester,
            settings: AppSettings(
              onboardingCompleted: true,
              languageCode: code,
            ),
            size: Size(width, 393),
          );
          await _open(tester, SettingsPane.language);
          expect(textFitProblems(tester), isEmpty);
        });
      }
    }
  });

  group('a segment takes a finger in both directions', () {
    for (final width in const [320.0, 393.0]) {
      for (final (pane, labels) in const [
        (SettingsPane.general, ['Match system', 'Light', 'Dark']),
        (SettingsPane.language, ['A4', 'Letter', 'in', 'cm', 'mm', 'pt']),
      ]) {
        testWidgets('${pane.path} at $width', (tester) async {
          await pumpFermanApp(tester, size: Size(width, 2000));
          await _open(tester, pane);
          for (final label in labels) {
            final segment = find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(FermanInteractive),
                )
                .first;
            expect(
              tester.getSize(segment).width,
              greaterThanOrEqualTo(44),
              reason: label,
            );
          }
        });
      }
    }
  });
}
