import 'package:ferman/app/app.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/platform/open_requests.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';

/// The size of the design's boards (`1440 × 900`).
const Size boardSize = Size(1440, 900);

/// Runs the whole app ([FermanApp], with its router) on [settings], stored
/// in a [MemorySettingsStore] that is returned, in a [size] window with the
/// system locales [systemLocales]. The view and locales are reset after
/// the test. A [store] given replaces the memory store for saving (the
/// returned one then only holds [settings]).
///
/// The app has no title bar of its own here (`NoDesktopWindow`), so the
/// screens fill the view. The engine is [engine]: by default a fake with
/// PDFium loaded. The open panel is [picker] and the system's open requests
/// are [openRequests]: fakes by default that open nothing.
Future<MemorySettingsStore> pumpFermanApp(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboardingCompleted: true),
  Size size = boardSize,
  List<Locale> systemLocales = const [Locale('en', 'US')],
  SettingsStore? store,
  EngineService? engine,
  FilePickerService? picker,
  OpenRequests openRequests = const NoOpenRequests(),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = systemLocales;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final memory = MemorySettingsStore(settings);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(store ?? memory),
        initialSettingsProvider.overrideWithValue(settings),
        engineServiceProvider.overrideWithValue(engine ?? FakeEngineService()),
        filePickerServiceProvider.overrideWithValue(
          picker ?? FakeFilePickerService(),
        ),
        openRequestsProvider.overrideWithValue(openRequests),
      ],
      child: const FermanApp(),
    ),
  );
  await tester.pumpAndSettle();
  return memory;
}

/// The text direction around [finder]'s widget.
TextDirection directionOf(WidgetTester tester, Finder finder) =>
    Directionality.of(tester.element(finder));

/// The UI locale around [finder]'s widget.
Locale localeOf(WidgetTester tester, Finder finder) =>
    Localizations.localeOf(tester.element(finder));

/// The semantics hint of the control that [finder] finds: the reason a
/// control is disabled (G10).
String? hintOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).hint;
