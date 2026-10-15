import 'package:ferman/app/app.dart';
import 'package:ferman/app/licenses.dart';
import 'package:ferman/app/window_setup.dart';
import 'package:ferman/l10n/format.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registers the bundled licence texts, initialises intl's region formats
/// and the platform window, and runs the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerLicenses();
  // Before the localization delegates load (ADR 0014, format.dart).
  initializeRegionFormats();
  await setUpWindow();
  runApp(const ProviderScope(child: FermanApp()));
}
