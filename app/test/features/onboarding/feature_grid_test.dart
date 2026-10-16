import 'package:ferman/features/onboarding/free_step.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/m1_screens.dart';
import '../../helpers/text_fit.dart';
import 'ferman_app_harness.dart';

/// The ten tiles of the grid, in order.
Finder get _tiles => find.descendant(
  of: find.byType(FeatureGrid),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.constraints ==
            const BoxConstraints(minHeight: FeatureGrid.tileHeight),
  ),
);

List<double> _tileHeights(WidgetTester tester) => [
  for (final element in _tiles.evaluate())
    (element.renderObject! as RenderBox).size.height,
];

Future<void> _openFreeStep(
  WidgetTester tester, {
  required String languageCode,
  required Size size,
}) async {
  await pumpFermanApp(
    tester,
    settings: M1Screen.freeStep.settings(languageCode: languageCode),
    size: size,
  );
  await M1Screen.freeStep.open(tester);
}

void main() {
  group('feature grid (a1-2c)', () {
    testWidgets('every tile is 44 px tall in English at the board size', (
      tester,
    ) async {
      await _openFreeStep(tester, languageCode: 'en', size: boardSize);
      expect(_tiles, findsNWidgets(WelcomeFeature.values.length));
      expect(_tileHeights(tester), everyElement(FeatureGrid.tileHeight));
    });

    testWidgets('a label too long for its tile wraps, as the board’s span '
        'does, instead of being cut off; two lines keep the 44 px tile', (
      tester,
    ) async {
      // Turkish at the board size: "Office’e ve Office’ten dönüştürme" is
      // wider than its tile.
      await _openFreeStep(tester, languageCode: 'tr', size: boardSize);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(FeatureGrid)),
      );
      final label = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text(l10n.onboardingFeatureConvert),
          matching: find.byType(RichText),
        ),
      );
      expect(label.didExceedMaxLines, isFalse);
      expect(label.size.height, greaterThan(label.text.style!.fontSize! * 2));
      expect(_tileHeights(tester), everyElement(FeatureGrid.tileHeight));
      expect(textFitProblems(tester), isEmpty);
    });

    testWidgets('a label longer than two lines makes its row taller, both '
        'tiles alike', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialSettingsProvider.overrideWithValue(
              const AppSettings(regionCode: 'TR'),
            ),
          ],
          child: componentHost(
            // Every word fits a label; several labels need three lines.
            const SizedBox(width: 330, child: FeatureGrid()),
          ),
        ),
      );
      final heights = _tileHeights(tester);
      expect(heights, hasLength(WelcomeFeature.values.length));
      expect(heights.reduce((a, b) => a > b ? a : b), greaterThan(44));
      for (var i = 0; i < heights.length; i += 2) {
        expect(heights[i], heights[i + 1], reason: 'row ${i ~/ 2 + 1}');
        expect(heights[i], greaterThanOrEqualTo(FeatureGrid.tileHeight));
      }
      expect(textFitProblems(tester), isEmpty);
    });
  });
}
