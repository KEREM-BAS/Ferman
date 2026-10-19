import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/features/onboarding/free_step.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/component_host.dart';

void main() {
  test('every feature names a BACKLOG row', () {
    for (final feature in Feature.values) {
      expect(
        feature.backlog,
        matches(RegExp(r'^B\d{3}$')),
        reason: feature.name,
      );
    }
  });

  for (final (locale, reason) in [
    (const Locale('en'), 'Available in a future version'),
    (const Locale('tr'), 'Gelecek bir sürümde sunulacak'),
    (const Locale('ar'), 'متاح في إصدار قادم'),
  ]) {
    testWidgets('every feature gives the future-version reason in '
        '${locale.languageCode}', (tester) async {
      final reasons = <Feature, String>{};
      await tester.pumpWidget(
        componentHost(
          Builder(
            builder: (context) {
              for (final feature in Feature.values) {
                reasons[feature] = feature.disabledReason(context);
              }
              return const SizedBox.shrink();
            },
          ),
          locale: locale,
        ),
      );
      expect(reasons, hasLength(Feature.values.length));
      for (final feature in Feature.values) {
        expect(reasons[feature], reason, reason: feature.name);
      }
    });
  }

  test('a first-run tile is included only once none of its features is '
      'in the registry', () {
    for (final tile in WelcomeFeature.values) {
      expect(tile.shipped, tile.features.isEmpty, reason: tile.name);
    }
    expect(WelcomeFeature.languages.shipped, isTrue);
    // "Edit text and images" waits for images (P2) after text (M3), G12.
    expect(WelcomeFeature.editing.features, {
      Feature.editingText,
      Feature.addingImages,
    });
  });

  test('a Settings pane is built only without a registry feature', () {
    for (final pane in SettingsPane.values) {
      expect(pane.available, pane.feature == null, reason: pane.name);
    }
    expect(
      [
        for (final pane in SettingsPane.values)
          if (pane.available) pane,
      ],
      [SettingsPane.general, SettingsPane.language, SettingsPane.privacy],
    );
  });
}
