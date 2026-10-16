import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/icons/icon_painter.dart';
import 'package:ferman/features/onboarding/free_step.dart';
import 'package:ferman/features/onboarding/privacy_step.dart';
import 'package:ferman/features/onboarding/welcome_step.dart';
import 'package:ferman/features/settings/general_pane.dart';
import 'package:ferman/features/settings/language_region_pane.dart';
import 'package:ferman/features/settings/privacy_pane.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../features/onboarding/ferman_app_harness.dart';
import '../helpers/m1_screens.dart';

/// The app languages checked, with their direction: English as the
/// left-to-right control; Arabic with its own strings; Persian and Hebrew,
/// which mirror the UI with English strings (G20, G93).
const List<(String, TextDirection)> _languages = [
  ('en', TextDirection.ltr),
  ('ar', TextDirection.rtl),
  ('fa', TextDirection.rtl),
  ('he', TextDirection.rtl),
];

/// Opens [screen] in the app language [code] with the Türkiye region.
Future<void> _pump(WidgetTester tester, M1Screen screen, String code) async {
  await pumpFermanApp(
    tester,
    settings: screen.settings(languageCode: code, regionCode: 'TR'),
  );
  await screen.open(tester);
}

/// The strings of the screen.
AppLocalizations _l10n(WidgetTester tester, M1Screen screen) =>
    AppLocalizations.of(tester.element(find.byType(screen.widgetType)));

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder.first);

/// [first] is before [second] in reading order: nearer the start side.
void _expectBefore(
  WidgetTester tester,
  Finder first,
  Finder second, {
  required TextDirection direction,
  required String reason,
}) {
  final a = _rect(tester, first).center.dx;
  final b = _rect(tester, second).center.dx;
  expect(
    a,
    direction == TextDirection.rtl ? greaterThan(b) : lessThan(b),
    reason: '$reason (${direction.name})',
  );
}

/// The [IconPainter] the [Icon] at [element] paints with.
IconPainter _painterOf(Element element) {
  IconPainter? found;
  void visit(Element child) {
    if (found != null) return;
    final widget = child.widget;
    if (widget is CustomPaint && widget.painter is IconPainter) {
      found = widget.painter! as IconPainter;
      return;
    }
    child.visitChildren(visit);
  }

  element.visitChildren(visit);
  return found!;
}

/// Checks that exactly the directional icons ([IconName.directional])
/// mirror in right to left and none mirrors in left to right; returns how
/// many directional icons the screen shows.
int _expectIconMirroring(WidgetTester tester, TextDirection direction) {
  final wrong = <String>[];
  var directional = 0;
  for (final element in find.byType(Icon).evaluate()) {
    final icon = element.widget as Icon;
    if (icon.name.directional) directional++;
    final expected = direction == TextDirection.rtl && icon.name.directional;
    if (_painterOf(element).mirror != expected) {
      wrong.add('${icon.name.id} ${expected ? 'not ' : ''}mirrored');
    }
  }
  expect(wrong, isEmpty, reason: direction.name);
  return directional;
}

/// The global rectangle of each onstage text that appears exactly once.
Map<String, Rect> _uniqueTexts(WidgetTester tester) {
  final rects = <String, Rect>{};
  final repeated = <String>{};
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    if (text.trim().isEmpty) continue;
    if (rects.containsKey(text)) repeated.add(text);
    rects[text] = MatrixUtils.transformRect(
      paragraph.getTransformTo(null),
      Offset.zero & paragraph.size,
    );
  }
  return {
    for (final MapEntry(:key, :value) in rects.entries)
      if (!repeated.contains(key)) key: value,
  };
}

/// The global rectangle of each icon, by glyph and order on screen; the
/// language picker's check, which marks the chosen language, is left out.
Map<String, Rect> _icons(WidgetTester tester) {
  final counts = <IconName, int>{};
  final rects = <String, Rect>{};
  for (final element in find.byType(Icon).evaluate()) {
    final name = (element.widget as Icon).name;
    if (name == IconName.check) continue;
    final count = counts.update(name, (n) => n + 1, ifAbsent: () => 1);
    rects['${name.id} #$count'] = tester.getRect(
      find.byElementPredicate((e) => e == element),
    );
  }
  return rects;
}

/// Whether the characters of the text at [finder] from [from] to [to] (code
/// unit offsets) read from left to right on screen.
bool _readsLeftToRight(WidgetTester tester, Finder finder, int from, int to) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText)),
  );
  double left(int offset) => paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + 1),
      )
      .first
      .left;
  return left(from) < left(to);
}

/// The start and end positions of the key parts of [screen].
void _expectLayout(
  WidgetTester tester,
  M1Screen screen,
  TextDirection direction,
) {
  final l10n = _l10n(tester, screen);
  void before(Finder first, Finder second, String reason) => _expectBefore(
    tester,
    first,
    second,
    direction: direction,
    reason: reason,
  );
  Finder icon(IconName name) =>
      find.byWidgetPredicate((widget) => widget is Icon && widget.name == name);

  switch (screen) {
    case M1Screen.languagePicker:
      // The first column (Türkçe) at the start, the second (فارسی) at the
      // end; in each row the own name first, the English name after it.
      before(find.text('Türkçe'), find.text('فارسی'), 'columns');
      before(find.text('Deutsch'), find.text('German'), 'name, English name');
      before(
        find.text(l10n.appName),
        find.text(l10n.onboardingContinue),
        'wordmark, Continue',
      );
      before(
        icon(IconName.search),
        find.text(l10n.onboardingLanguageSearchPlaceholder),
        'search icon, placeholder',
      );
      before(
        icon(IconName.languages),
        find.text(l10n.onboardingLanguageMissing),
        'footer icon, text',
      );
    case M1Screen.privacyStep || M1Screen.freeStep:
      final step = tester.widget<WelcomeStep>(find.byType(WelcomeStep));
      before(find.text(step.title), find.byWidget(step.aside), 'columns');
      before(
        find.text(l10n.onboardingBack),
        find.text(step.nextLabel),
        'Back, Next',
      );
      if (screen == M1Screen.privacyStep) {
        before(
          find.text(l10n.onboardingSkip),
          find.text(l10n.onboardingBack),
          'Skip, Back',
        );
        // The arrow follows Next's label (and points the way on).
        before(find.text(step.nextLabel), icon(IconName.arrowRight), 'arrow');
        before(
          find.descendant(
            of: find.byType(PrivacyFacts),
            matching: icon(IconName.hardDrive),
          ),
          find.text(l10n.onboardingPrivacyFilesTitle),
          'fact icon, title',
        );
      } else {
        before(
          icon(IconName.filePenLine),
          icon(IconName.scanText),
          'first tile, second tile',
        );
        before(
          icon(IconName.filePenLine),
          find.text(l10n.onboardingFeatureEditing),
          'tile icon, label',
        );
        before(
          find.text(l10n.onboardingFeatureEditing),
          find.descendant(
            of: find.byType(FeatureGrid),
            matching: icon(IconName.clock),
          ),
          'tile label, state',
        );
      }
    case M1Screen.start:
      before(
        find.text(l10n.startOpenFile),
        find.text(l10n.startScanToPdf),
        'first card, last card',
      );
      before(
        icon(IconName.folderOpen),
        find.text(l10n.startOpenFile),
        'card icon, title',
      );
      before(
        find.text(l10n.startQuickTools),
        find.text(l10n.startToolCompress),
        'quick tools label, first tool',
      );
      before(
        find.text(l10n.startToolCompress),
        find.text(l10n.startToolCompare),
        'first tool, last tool',
      );
    case M1Screen.settingsGeneral ||
        M1Screen.settingsLanguage ||
        M1Screen.settingsPrivacy:
      final pane = find.byType(switch (screen) {
        M1Screen.settingsGeneral => GeneralPane,
        M1Screen.settingsLanguage => LanguageRegionPane,
        _ => PrivacyPane,
      });
      // The pane list at the start (a12-2c), the close button at the end.
      before(find.text(l10n.settingsTitle), pane, 'pane list, pane');
      before(pane, icon(IconName.x), 'pane, close button');
      before(
        icon(IconName.settings),
        find.text(l10n.settingsPaneGeneral).first,
        'pane list icon, name',
      );
      switch (screen) {
        case M1Screen.settingsGeneral:
          before(
            find.text(l10n.settingsThemeSystem),
            find.text(l10n.settingsThemeDark),
            'theme segments',
          );
          before(
            find.text(GeneralPane.defaultAppText(l10n)),
            find.text(l10n.settingsMakeDefault),
            'default-app text, button',
          );
        case M1Screen.settingsLanguage:
          before(
            find.text(l10n.regionPaperSize),
            find.byType(RegionExamples),
            'formats, examples',
          );
          before(
            find.text(l10n.regionExampleDate),
            find.text(bidiIsolate('13.10.2026')),
            'example name, value',
          );
        case _:
          before(
            find.text(l10n.settingsNetUpdates),
            find.byType(Switch),
            'network use, switch',
          );
      }
  }
}

void main() {
  group('ROADMAP §5 step 10: right to left', () {
    for (final (code, direction) in _languages) {
      for (final screen in M1Screen.values) {
        testWidgets('$code: ${screen.description} lays out from the '
            '${direction == TextDirection.rtl ? 'right' : 'left'}, '
            'directional icons mirrored', (tester) async {
          await _pump(tester, screen, code);
          expect(tester.takeException(), isNull);
          expect(
            directionOf(tester, find.byType(screen.widgetType)),
            direction,
          );
          _expectLayout(tester, screen, direction);
          final directional = _expectIconMirroring(tester, direction);
          if (screen == M1Screen.privacyStep) {
            // Next's arrow-right: the one directional glyph of M1's screens.
            expect(directional, 1);
          }
        });
      }
    }

    // Persian and Hebrew show the English strings (G20), so their screens
    // are the English ones, mirrored around the window's centre line.
    for (final code in ['fa', 'he']) {
      for (final screen in M1Screen.values) {
        testWidgets('$code: ${screen.description} is the English screen '
            'mirrored (G93)', (tester) async {
          await _pump(tester, screen, 'en');
          final english = _uniqueTexts(tester);
          final englishIcons = _icons(tester);
          final width =
              tester.view.physicalSize.width / tester.view.devicePixelRatio;
          // A fresh app (a new provider scope) for the second language.
          await tester.pumpWidget(const SizedBox.shrink());
          await _pump(tester, screen, code);
          final mirrored = _uniqueTexts(tester);
          final mirroredIcons = _icons(tester);

          // Only the horizontal place is compared: a string that differs
          // (the picker's line about the system language) can move what is
          // below it. A pixel absorbs a reordered full stop's kerning.
          final compared = <String>[];
          final wrong = <String>[];
          void compare(Map<String, Rect> ltr, Map<String, Rect> rtl) {
            for (final MapEntry(key: name, value: rect) in ltr.entries) {
              final other = rtl[name];
              if (other == null) continue;
              compared.add(name);
              final expectedCentre = width - rect.center.dx;
              if ((other.center.dx - expectedCentre).abs() > 1 ||
                  (other.width - rect.width).abs() > 1.5) {
                wrong.add(
                  '"$name": ${other.left}–${other.right}, mirrored English '
                  '${width - rect.right}–${width - rect.left}',
                );
              }
            }
          }

          compare(english, mirrored);
          compare(englishIcons, mirroredIcons);
          expect(wrong, isEmpty);
          // Nearly every text and icon is the same in both.
          expect(compared.length, greaterThan(english.length ~/ 2));
        });
      }
    }
  });

  group(
    'ROADMAP §5 step 10: values keep their own direction (bidiIsolate)',
    () {
      for (final code in ['ar', 'fa', 'he']) {
        testWidgets('$code: the region examples read left to right', (
          tester,
        ) async {
          await _pump(tester, M1Screen.settingsLanguage, code);
          for (final value in [
            '13.10.2026',
            '14:32',
            '18.500,50',
            '10,5\u00A0pt',
          ]) {
            final text = find.descendant(
              of: find.byType(RegionExamples),
              matching: find.text(bidiIsolate(value)),
            );
            expect(text, findsOneWidget, reason: value);
            // Inside the isolates (offset 1 to the last character), the
            // value's first character is at the left of its last.
            expect(
              _readsLeftToRight(tester, text, 1, value.length),
              isTrue,
              reason: value,
            );
          }
        });

        testWidgets('$code: the 100% zoom option is isolated', (tester) async {
          await _pump(tester, M1Screen.settingsGeneral, code);
          final l10n = _l10n(tester, M1Screen.settingsGeneral);
          final zoom = tester.widget<Select<String>>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Select<String> && widget.label == l10n.settingsZoom,
            ),
          );
          expect(
            zoom.options.map((option) => option.label),
            contains(bidiIsolate('%100')),
          );
        });
      }

      testWidgets(
        'without isolates, "10,5 pt" would show as "pt 10,5" in right '
        'to left',
        (tester) async {
          // The reason for bidiIsolate, measured with the bundled font.
          await tester.pumpWidget(
            const Directionality(
              textDirection: TextDirection.rtl,
              child: Center(child: Text('10,5\u00A0pt')),
            ),
          );
          expect(_readsLeftToRight(tester, find.byType(Text), 0, 5), isFalse);
        },
      );
    },
  );
}
