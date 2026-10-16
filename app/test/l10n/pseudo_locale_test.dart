/// **Proposed** (ROADMAP §5 step 10): every M1 screen renders in a
/// pseudo-locale with strings 40% longer without clipping or overflow
/// errors. It stands in for the German boards a12-2b and a12-2d. The
/// pseudo-locale is test-only (`test/helpers/pseudo_locale.dart`); the app
/// has no such locale.
library;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/l10n/region_names.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../features/onboarding/ferman_app_harness.dart';
import '../helpers/fake_desktop_window.dart';
import '../helpers/m1_screens.dart';
import '../helpers/pseudo_locale.dart';
import '../helpers/text_fit.dart';

/// Texts the design truncates too: the value of a select and the text of
/// an input, which the boards draw as one-line `<select>` and `<input>`
/// elements that clip what does not fit.
bool _truncatesInDesign(Element text) =>
    hasAncestor(text, (widget) => widget is Select || widget is TextField);

/// Pumps [screen] with [pump], collecting the framework's errors, then
/// fails on any of them (a RenderFlex overflow) and on any text that does
/// not fit its box.
Future<void> _expectFits(
  WidgetTester tester,
  M1Screen screen,
  Future<void> Function() pump,
) async {
  final errors = await collectFlutterErrors(() async {
    await pump();
    await screen.open(tester);
  });
  expect(describeErrors(errors), isEmpty, reason: 'overflow errors');
  expect(
    textFitProblems(tester, allowed: _truncatesInDesign).map((p) => '$p'),
    isEmpty,
    reason: 'texts that do not fit',
  );
}

/// The plain text of every onstage text, sorted.
List<String> _texts(WidgetTester tester) => [
  for (final element in find.byType(RichText).evaluate())
    (element.renderObject! as RenderParagraph).text.toPlainText(
      includeSemanticsLabels: false,
    ),
]..sort();

/// Text on an M1 screen that is data, not a message: the languages' own
/// and English names (a1-1 draws them in every UI language), region names
/// (CLDR), unit symbols, key caps and formatted values.
bool _isData(String text) {
  final bare = text.replaceAll(RegExp('[\u2066-\u2069]'), '');
  final keyCap = RegExp(r'^(Ctrl|Alt|Shift|Esc|[A-Z0-9,⌘⌥⇧⌃])(\+\S+)*$');
  return {
        for (final language in AppLanguage.values) ...[
          language.endonym,
          language.englishName,
        ],
        for (final unit in LengthUnit.values) unit.symbol,
        for (final region in Region.all) regionDisplayName(region.code, 'en'),
      }.contains(bare) ||
      keyCap.hasMatch(bare) ||
      RegExp(r'\d').hasMatch(bare);
}

void main() {
  final pseudo = PseudoLocalizations.fromArb();

  group('the pseudo-locale (Proposed)', () {
    test('every message is at least 40% longer and framed, its placeholder '
        'values unchanged', () {
      final arb = readArb(englishArbPath);
      final plain = PseudoLocalizations(
        arb,
        expansion: 1,
        accents: false,
        markers: false,
      );
      for (final key in pseudo.keys) {
        final meta = arb['@$key'] as Map<String, Object?>?;
        final placeholders =
            (meta?['placeholders'] as Map<String, Object?>?) ?? const {};
        final arguments = [
          for (final MapEntry(key: name, :value) in placeholders.entries)
            if ((value! as Map)['type'] == 'int') 3 else '«$name·Deutsch»',
        ];
        final english = plain.message(key, arguments);
        final text = pseudo.message(key, arguments);
        expect(text, startsWith(pseudoStart), reason: key);
        expect(text, endsWith(pseudoEnd), reason: key);
        expect(
          text.length,
          greaterThanOrEqualTo(
            (english.length * 1.4).ceil().clamp(english.length + 2, 1 << 30),
          ),
          reason: '$key: "$english" → "$text"',
        );
        for (final argument in arguments.whereType<String>()) {
          expect(text, contains(argument), reason: key);
        }
      }
    });

    test('accents keep the letters, in both cases', () {
      const lower = 'abcdefghijklmnopqrstuvwxyz';
      const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      expect(accentLetters('Settings › Privacy'), 'Šéţţîñĝš › Þŕîváçý');
      // Locale-aware casing maps the accented forms onto each other, so an
      // upper-cased pseudo string stays in the set IBM Plex Sans covers.
      expect(
        LocaleCasing.root.upper(accentLetters(lower)),
        accentLetters(upper),
      );
      expect(
        LocaleCasing.root.lower(accentLetters(upper)),
        accentLetters(lower),
      );
    });

    test('formats plural messages as gen-l10n does', () {
      expect(
        formatMessage(
          '{count, plural, =1{{formatted} interface language} '
          'other{{formatted} interface languages}}',
          {'count': 1, 'formatted': '1'},
          (text) => text,
        ),
        '1 interface language',
      );
      expect(
        formatMessage(
          '{count, plural, =1{{formatted} item} other{{formatted} items}}',
          {'count': 3, 'formatted': '٣'},
          accentLetters,
        ),
        '٣ îţémš',
      );
    });

    for (final screen in M1Screen.values) {
      testWidgets('unexpanded, it shows the English texts of '
          '${screen.description}', (tester) async {
        // The real app in English …
        await pumpFermanApp(tester, settings: screen.settings());
        await screen.open(tester);
        final english = _texts(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        // … and the pseudo-locale's app with its strings unchanged.
        await pumpPseudoApp(
          tester,
          localizations: PseudoLocalizations.fromArb(
            expansion: 1,
            accents: false,
            markers: false,
          ),
          settings: screen.settings(),
        );
        await screen.open(tester);
        expect(_texts(tester), english);
      });
    }
  });

  group('every M1 screen in the pseudo-locale fits (Proposed)', () {
    for (final screen in M1Screen.values) {
      for (final size in m1WindowSizes) {
        for (final platform in [null, WindowPlatform.mac, WindowPlatform.win]) {
          final chrome = platform == null ? 'no title bar' : platform.name;
          testWidgets('${screen.description} at ${sizeName(size)}, $chrome', (
            tester,
          ) async {
            final window = platform == null
                ? null
                : FakeDesktopWindow(platform);
            if (window != null) addTearDown(window.dispose);
            await _expectFits(
              tester,
              screen,
              () => pumpPseudoApp(
                tester,
                localizations: pseudo,
                settings: screen.settings(regionCode: 'TR'),
                size: size,
                window: window,
              ),
            );
            // The pseudo-locale is in force …
            expect(find.textContaining(pseudoStart), findsWidgets);
            // … and every other text is data, not a hard-coded message.
            expect(
              _texts(tester).where(
                (text) =>
                    !text.contains(pseudoStart) &&
                    RegExp('[A-Za-z]').hasMatch(text) &&
                    !_isData(text),
              ),
              isEmpty,
            );
          });
        }
      }
    }
  });

  group('every M1 screen in en, tr and ar fits', () {
    for (final code in ['en', 'tr', 'ar']) {
      for (final screen in M1Screen.values) {
        for (final size in m1WindowSizes) {
          testWidgets('$code: ${screen.description} at ${sizeName(size)}', (
            tester,
          ) async {
            await _expectFits(
              tester,
              screen,
              () => pumpFermanApp(
                tester,
                settings: screen.settings(languageCode: code, regionCode: 'TR'),
                size: size,
              ),
            );
          });
        }
      }
    }
  });

  group('the fit check', () {
    Future<List<TextFitProblem>> problemsOf(
      WidgetTester tester,
      Widget child,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: DefaultTextStyle(
              style: const TextStyle(fontFamily: 'IBM Plex Sans', fontSize: 13),
              child: child,
            ),
          ),
        ),
      );
      return textFitProblems(tester);
    }

    // Every word fits 60 px; the whole text does not.
    const long = 'Fill and sign the forms you get';

    testWidgets('finds an ellipsis', (tester) async {
      final problems = await problemsOf(
        tester,
        const SizedBox(
          width: 60,
          child: Text(long, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
      expect(problems.single.kind, TextFitKind.truncated);
      expect(problems.single.missing, greaterThan(100));
    });

    testWidgets('finds a text taller than its box', (tester) async {
      final problems = await problemsOf(
        tester,
        const SizedBox(width: 60, height: 20, child: Text(long)),
      );
      expect(problems.single.kind, TextFitKind.tooTall);
    });

    testWidgets('finds a word wider than its box', (tester) async {
      final problems = await problemsOf(
        tester,
        const SizedBox(width: 30, child: Text('Erişilebilirlikdenetleyicisi')),
      );
      expect(problems.single.kind, TextFitKind.tooWide);
    });

    testWidgets('finds a line that does not wrap', (tester) async {
      final problems = await problemsOf(
        tester,
        const SizedBox(
          width: 60,
          child: Text(long, softWrap: false, overflow: TextOverflow.clip),
        ),
      );
      expect(problems.single.kind, TextFitKind.tooWide);
    });

    testWidgets('passes text that wraps in its box', (tester) async {
      expect(
        await problemsOf(tester, const SizedBox(width: 60, child: Text(long))),
        isEmpty,
      );
    });

    testWidgets('collects overflow errors', (tester) async {
      final errors = await collectFlutterErrors(() async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 10,
                child: Row(children: [SizedBox(width: 30, height: 10)]),
              ),
            ),
          ),
        );
      });
      expect(describeErrors(errors).single, contains('RenderFlex overflowed'));
    });
  });
}
