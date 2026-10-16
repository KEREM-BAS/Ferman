import 'package:ferman/app/app.dart';
import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/licenses.dart';
import 'package:ferman/app/window_setup.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/engine_start.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_start.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Registers the bundled licence texts, initialises intl's region formats,
/// loads the settings, starts the engine and the platform window (with
/// Ferman's own title bar on the desktop), and runs the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerLicenses();
  // Before the localization delegates load (ADR 0014, format.dart).
  initializeRegionFormats();
  final settingsStore = await openSettingsStore();
  final settings = await settingsStore.load();
  final engine = await _startEngine();
  await setUpWindow();
  final window = await _startDesktopWindow();
  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(settingsStore),
        initialSettingsProvider.overrideWithValue(settings),
        engineServiceProvider.overrideWithValue(engine),
        desktopWindowProvider.overrideWithValue(window),
      ],
      child: const FermanApp(),
    ),
  );
}

/// Starts the engine, or returns a service that explains why it could not
/// start, so the app still opens.
Future<EngineService> _startEngine() async {
  try {
    return await startEngine();
  } on EngineUnavailableException catch (error) {
    return UnavailableEngineService(error);
  }
}

/// Hides the system title bar on the desktop so Ferman draws its own and
/// asks for the shell's minimum window size, or returns a window without a
/// title bar of its own on the web and mobile.
Future<DesktopWindow> _startDesktopWindow() async {
  final window = WindowManagerDesktopWindow.forCurrentPlatform();
  if (window == null) return NoDesktopWindow();
  await window.start();
  await applyWindowLimits(window);
  return window;
}
