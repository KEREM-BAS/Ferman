import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/onboarding/free_step.dart';
import 'package:ferman/features/onboarding/language_picker.dart';
import 'package:ferman/features/onboarding/onboarding_link.dart';
import 'package:ferman/features/onboarding/welcome_step.dart';
import 'package:ferman/features/phone/fm_phone.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/m1_screens.dart';
import '../../helpers/phone_golden.dart';
import '../../helpers/text_fit.dart';
import 'ferman_app_harness.dart';

/// Tall enough that nothing scrolls, so every text is on screen to measure.
const double _tall = 3000;

Future<void> _open(
  WidgetTester tester,
  M1Screen screen, {
  String languageCode = 'en',
  Size size = goldenPhoneSize,
}) async {
  await pumpFermanApp(
    tester,
    settings: screen.settings(languageCode: languageCode),
    size: size,
  );
  await screen.open(tester);
}

Size _sizeOf(WidgetTester tester, Element element) =>
    (element.renderObject! as RenderBox).size;

void main() {
  group('every step at phone width', () {
    for (final screen in const [
      M1Screen.languagePicker,
      M1Screen.privacyStep,
      M1Screen.freeStep,
    ]) {
      for (final languageCode in const ['en', 'tr', 'ar']) {
        for (final width in const [320.0, 393.0, 767.0]) {
          testWidgets(
            '${screen.name} $languageCode at $width px: nothing cut',
            (tester) async {
              await _open(
                tester,
                screen,
                languageCode: languageCode,
                size: Size(width, _tall),
              );
              expect(find.byType(FmPhone), findsOneWidget);
              expect(textFitProblems(tester), isEmpty);
            },
          );
        }

        testWidgets('${screen.name} $languageCode: targets of 44 px', (
          tester,
        ) async {
          await _open(
            tester,
            screen,
            languageCode: languageCode,
            size: const Size(393, _tall),
          );
          for (final element in find.byType(FermanInteractive).evaluate()) {
            final size = _sizeOf(tester, element);
            expect(size.width, greaterThanOrEqualTo(44));
            expect(size.height, greaterThanOrEqualTo(44));
          }
        });
      }

      testWidgets('${screen.name} keeps the desktop layout at 768 px', (
        tester,
      ) async {
        await _open(tester, screen, size: const Size(768, 1000));
        expect(find.byType(FmPhone), findsNothing);
      });

      testWidgets('${screen.name}: the footer is on a small screen', (
        tester,
      ) async {
        await _open(tester, screen, size: const Size(320, 480));
        final label = screen == M1Screen.languagePicker
            ? 'Continue'
            : screen == M1Screen.privacyStep
            ? 'Next'
            : 'Start using Ferman';
        final bottom = tester.getBottomLeft(find.text(label)).dy;
        expect(bottom, lessThan(480));
      });
    }
  });

  group('the language step (a13-1b)', () {
    testWidgets('is one column of every language, in its own direction', (
      tester,
    ) async {
      await _open(
        tester,
        M1Screen.languagePicker,
        size: const Size(393, _tall),
      );
      final starts = {
        for (final language in AppLanguage.values)
          tester
              .getTopLeft(
                find
                    .ancestor(
                      of: find.text(language.endonym),
                      matching: find.byType(FocusableActionDetector),
                    )
                    .first,
              )
              .dx,
      };
      expect(starts, hasLength(1));
      for (final language in AppLanguage.values) {
        expect(
          tester.widget<Text>(find.text(language.endonym)).textDirection,
          language.textDirection,
        );
      }
    });

    testWidgets('rows are at least 44 px', (tester) async {
      await _open(
        tester,
        M1Screen.languagePicker,
        size: const Size(393, _tall),
      );
      final row = find.bySemanticsLabel(RegExp('^Türkçe'));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
    });

    testWidgets('a touch on Arabic mirrors the screen at once', (tester) async {
      await _open(
        tester,
        M1Screen.languagePicker,
        size: const Size(393, _tall),
      );
      await tester.tap(
        find.text(
          AppLanguage.values
              .firstWhere((language) => language.tag == 'ar')
              .endonym,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        directionOf(tester, find.byType(LanguagePicker)),
        TextDirection.rtl,
      );
      expect(textFitProblems(tester), isEmpty);
    });

    testWidgets('the search waits for a tap: no keyboard over the list', (
      tester,
    ) async {
      await _open(tester, M1Screen.languagePicker);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isFalse,
      );
    });

    testWidgets('a search with no match has its message', (tester) async {
      await _open(tester, M1Screen.languagePicker);
      await tester.enterText(find.byType(EditableText), 'qqqq');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Türkçe')), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('Continue stays above the on-screen keyboard', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await _open(tester, M1Screen.languagePicker);
      expect(
        tester.getBottomLeft(find.text('Continue')).dy,
        lessThan(goldenPhoneSize.height - 300),
      );
    });

    testWidgets('the list scrolls to its last language', (tester) async {
      await _open(tester, M1Screen.languagePicker);
      final last = find.text(AppLanguage.values.last.endonym);
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the welcome steps (a13-1)', () {
    testWidgets('touch goes through the steps, Back and Skip', (tester) async {
      await _open(tester, M1Screen.privacyStep);
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      // The last step drops Skip (a1-2c note).
      expect(find.text('Skip'), findsNothing);
      expect(find.byType(FeatureGrid), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguagePicker), findsOneWidget);
    });

    testWidgets('Skip finishes first run', (tester) async {
      await _open(tester, M1Screen.privacyStep);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeStep), findsNothing);
      expect(find.byType(FmStart), findsOneWidget);
    });

    testWidgets('the tiles are one column', (tester) async {
      await _open(tester, M1Screen.freeStep, size: const Size(393, _tall));
      final starts = {
        for (final element
            in find
                .descendant(
                  of: find.byType(FeatureGrid),
                  matching: find.byType(IntrinsicHeight),
                )
                .evaluate())
          (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx,
      };
      expect(starts, hasLength(1));
      expect(find.byType(IntrinsicHeight), findsNWidgets(10));
    });

    testWidgets('a touch on a future tile says so', (tester) async {
      await _open(tester, M1Screen.freeStep, size: const Size(393, _tall));
      const reason = 'Available in a future version';
      expect(find.text(reason), findsNothing);
      await tester.tap(find.byType(Tooltip).first);
      await tester.pump();
      expect(find.text(reason), findsOneWidget);
      await tester.pump(Tooltip.touchHold);
      await tester.pumpAndSettle();
    });

    testWidgets('the links stay visible and disabled with the reason', (
      tester,
    ) async {
      await _open(tester, M1Screen.freeStep, size: const Size(393, _tall));
      final links = find.byType(OnboardingLink);
      expect(links, findsNWidgets(2));
      for (final link in tester.widgetList<OnboardingLink>(links)) {
        expect(link.onPressed, isNull);
        expect(link.disabledReason, 'Available in a future version');
      }
    });

    testWidgets('Skip is the accent link of a13-1, at 44 px', (tester) async {
      await _open(tester, M1Screen.privacyStep);
      final skip = find.text('Skip');
      final text = tester.widget<Text>(skip);
      expect(text.style?.color, tester.element(skip).ferman.colors.textAccent);
      expect(text.style?.fontSize, WelcomeStep.phoneSkipSize);
      final target = find
          .ancestor(of: skip, matching: find.byType(FermanInteractive))
          .first;
      expect(tester.getSize(target).height, greaterThanOrEqualTo(44));
    });

    testWidgets('no line of the licence note ends in a separator', (
      tester,
    ) async {
      await _open(tester, M1Screen.freeStep, languageCode: 'tr');
      final support = tester.getCenter(find.text('Projeyi destekleyin'));
      final separator = tester.getCenter(find.text(' · ').last);
      expect(separator.dy, support.dy);
    });
  });
}
