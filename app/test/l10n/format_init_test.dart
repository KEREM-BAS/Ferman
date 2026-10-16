import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'cldr_formats.dart';

// Its own file, so intl's global date data starts empty (each test file
// runs in a fresh isolate).
void main() {
  testWidgets('region formats work after flutter_localizations loaded its own '
      'date data first', (tester) async {
    // The app's delegates load first, as they would if bootstrap did not
    // call initializeRegionFormats: flutter_localizations then fills
    // intl's date data with its own locales only, and a later
    // initializeDateFormatting() does nothing.
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('tr'),
        delegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        child: const SizedBox.shrink(),
      ),
    );
    expect(DateFormat.localeExists('tr'), isTrue);
    // flutter_localizations has no Egyptian Arabic, which Saudi Arabia
    // formats with.
    expect(DateFormat.localeExists('ar_EG'), isFalse);

    final saudiArabia = RegionFormat.forRegion(Region.forCode('SA'));
    final date = DateTime(2026, 10, 13, 14, 32);
    expect(DateFormat.localeExists('ar_EG'), isTrue);
    expect(saudiArabia.date(date).substring(0, 2), '١٣');
    expect(RegionFormat.forRegion(Region.turkiye).date(date), '13.10.2026');
    expect(
      RegionFormat.forRegion(Region.unitedStates).date(date),
      '10/13/2026',
    );
    // flutter_localizations' `ar` has Arabic-Indic digits; CLDR's ar-AE
    // writes Latin ones.
    expect(
      RegionFormat.forRegion(Region.forCode('AE')).date(date),
      '13\u200F/10\u200F/2026',
    );
    expectCldrFormats();
  });

  test('initializeRegionFormats can run again', () {
    initializeRegionFormats();
    initializeRegionFormats();
    expect(DateFormat.localeExists('fa'), isTrue);
  });
}
