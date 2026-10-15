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
  testWidgets('region formats survive flutter_localizations loading after '
      'bootstrap', (tester) async {
    // bootstrap() order: intl's data for every locale first, then the app's
    // delegates, which replace the date symbols of flutter_localizations'
    // own locales (its `ar` has Arabic-Indic digits, CLDR's ar-AE has not).
    initializeRegionFormats();
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('ar'),
        delegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        child: const SizedBox.shrink(),
      ),
    );
    // The replacement happened: a plain DateFormat now writes Arabic-Indic
    // digits for `ar`.
    expect(DateFormat.yMd('ar').format(DateTime(2026, 10, 2)), startsWith('٢'));

    expectCldrFormats();
    final value = DateTime(2026, 10, 2, 14, 32);
    final emirates = RegionFormat.forRegion(Region.forCode('AE'));
    expect(emirates.date(value), '2‏/10‏/2026');
    expect(emirates.time(value), '2:32 م');
    expect(
      RegionFormat.forRegion(Region.forCode('TW')).dateTime(value),
      '2026/10/2 下午2:32',
    );
  });
}
