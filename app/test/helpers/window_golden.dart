import 'package:alchemist/alchemist.dart';
import 'package:ferman/app/app.dart';
import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'fonts.dart';
import 'golden_config.dart';
import 'traffic_lights.dart';

/// The size of every window golden: the boards' 1440 × 900, at a device
/// pixel ratio of 1, the size of the design references in
/// `build/design-refs/`.
const Size goldenWindowSize = Size(1440, 900);

/// The window chrome a golden is drawn with: Ferman's own title bar for the
/// system, the system's key conventions and its desktop behaviour.
enum GoldenChrome {
  /// macOS: the traffic lights (simulated, [SimulatedTrafficLights]) and
  /// ⌘ ⌥ ⇧ ⌃ in shortcut caps.
  mac(WindowPlatform.mac, TargetPlatform.macOS, ShortcutPlatform.mac),

  /// Windows: the caption buttons and Ctrl, Alt and Shift.
  win(WindowPlatform.win, TargetPlatform.windows, ShortcutPlatform.windows);

  new(this.window, this.targetPlatform, this.shortcuts);

  /// The title bar's controls.
  final WindowPlatform window;

  /// The platform the app runs as (`debugDefaultTargetPlatformOverride`):
  /// the desktop density and focus behaviour instead of flutter_test's
  /// Android.
  final TargetPlatform targetPlatform;

  /// The key conventions.
  final ShortcutPlatform shortcuts;
}

/// The theme of a golden, stored in the settings as the user's choice.
enum GoldenTheme {
  /// Light.
  light(AppThemeMode.light),

  /// Dark.
  dark(AppThemeMode.dark);

  new(this.mode);

  /// The stored theme setting.
  final AppThemeMode mode;
}

/// The UI language of a golden, with the system locale and the region the
/// goldens use for it (G34).
enum GoldenLanguage {
  /// English with the United Kingdom region, unless a board shows another:
  /// the English boards draw a 24-hour clock ("14:32" in FmWindow) and
  /// "100%", which the United Kingdom's formats give (G34).
  en(Locale('en', 'GB'), 'GB'),

  /// Turkish with the Türkiye region.
  tr(Locale('tr', 'TR'), 'TR'),

  /// Arabic with the Saudi Arabia region: the Arabic boards draw
  /// Arabic-Indic digits (G34).
  ar(Locale('ar', 'SA'), 'SA');

  new(this.systemLocale, this.regionCode);

  /// The operating system's locale in the golden.
  final Locale systemLocale;

  /// The region formats.
  final String regionCode;

  /// The app language's code.
  String get languageCode => name;
}

/// The settings a golden starts the app with: [theme] chosen, and [language]
/// and its region (or [regionCode]) chosen once first run is done
/// ([onboardingCompleted]). During first run nothing else is stored yet:
/// the language and region come from the system locale, as at a first
/// launch.
AppSettings goldenSettings({
  required GoldenTheme theme,
  required GoldenLanguage language,
  required bool onboardingCompleted,
  String? regionCode,
}) => onboardingCompleted
    ? AppSettings(
        themeMode: theme.mode,
        languageCode: language.languageCode,
        regionCode: regionCode ?? language.regionCode,
        onboardingCompleted: true,
      )
    : AppSettings(themeMode: theme.mode, regionCode: regionCode);

/// The golden file name of a window golden: `<screen>_<chrome>_<theme>_<lang>`
/// (the contract with `tools/design-refs`' comparison report).
String goldenFileName(
  String screen,
  GoldenChrome chrome,
  GoldenTheme theme,
  GoldenLanguage language,
) => '${screen}_${chrome.name}_${theme.name}_${language.name}';

/// Declares a golden of the whole app window: [FermanApp] with its router
/// and Ferman's own title bar for [chrome], [goldenWindowSize] at a device
/// pixel ratio of 1, written to
/// `goldens/linux/<screen>_<chrome>_<theme>_<lang>.png`
/// next to the test.
///
/// The app starts on [settings] with the system locale of [language], at
/// [initialLocation] (the router's start, `/`, when null), and [open] moves
/// it to the screen (`M1Screen.open` for first run's steps and Settings).
/// [overrides] replace further providers (the shell's mode).
///
/// Determinism: animations that end are run to their end; the spinners,
/// which never end, are brought to the start of a turn (the design
/// references show them at their start, `tools/design-refs`) and every
/// ticker is then stopped with [TickerMode] before the capture, so nothing
/// moves while the image is taken; the caret never blinks
/// ([EditableText.debugDeterministicCursor]: always shown, as in the
/// references). Times come from the placeholder data, never the clock.
/// Text uses the bundled fonts, plus the system fonts that stand in for the
/// app's system fallback ([useSystemFallbackFonts]): DejaVu Sans Mono for
/// the macOS key symbols (G87) and Noto Sans CJK JP for the language
/// picker's CJK names; a golden that shows such a character fails when its
/// font is missing instead of recording boxes.
///
/// macOS goldens paint the native traffic lights where the window would
/// place them ([SimulatedTrafficLights]).
Future<void> windowGoldenTest({
  required String screen,
  required GoldenChrome chrome,
  required GoldenTheme theme,
  required GoldenLanguage language,
  required AppSettings settings,
  String? board,
  String? initialLocation,
  Future<void> Function(WidgetTester tester)? open,
  List<Override> overrides = const [],
}) {
  final fileName = goldenFileName(screen, chrome, theme, language);
  late ValueNotifier<bool> tickers;
  late GoldenDesktopWindow window;
  return AlchemistConfig.runWithConfig(
    config: fermanWindowAlchemistConfig,
    run: () => goldenTest(
      board == null ? fileName : '$fileName ($board)',
      fileName: fileName,
      skip: !isGoldenHost,
      builder: () {
        tickers = ValueNotifier(true);
        window = GoldenDesktopWindow(chrome.window);
        // A container of the test's own (disposed after it), as the app's
        // root scope.
        final Widget app = UncontrolledProviderScope(
          container: ProviderContainer.test(
            overrides: [
              settingsStoreProvider.overrideWithValue(
                MemorySettingsStore(settings),
              ),
              initialSettingsProvider.overrideWithValue(settings),
              desktopWindowProvider.overrideWithValue(window),
              shortcutPlatformProvider.overrideWithValue(chrome.shortcuts),
              ...overrides,
            ],
          ),
          child: const FermanApp(),
        );
        return ValueListenableBuilder<bool>(
          valueListenable: tickers,
          builder: (context, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: SizedBox.fromSize(
            size: goldenWindowSize,
            child: chrome == GoldenChrome.mac
                ? SimulatedTrafficLights(layout: window.layout, child: app)
                : app,
          ),
        );
      },
      pumpWidget: (tester, widget) async {
        addTearDown(() {
          window.dispose();
          tickers.dispose();
        });
        addTearDown(_resetDebugValues);
        tester.view
          ..physicalSize = goldenWindowSize
          ..devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(goldenWindowSize);
        tester.platformDispatcher.localesTestValue = [language.systemLocale];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        if (initialLocation != null) {
          tester.platformDispatcher.defaultRouteNameTestValue = initialLocation;
          addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
        }
        debugDefaultTargetPlatformOverride = chrome.targetPlatform;
        EditableText.debugDeterministicCursor = true;
        await tester.pumpWidget(widget);
      },
      pumpBeforeTest: (tester) async {
        await _settle(tester);
        if (open != null) {
          await open(tester);
          await _settle(tester);
        }
        await _alignSpinners(tester);
        _expectOnlySpinnersRun(tester);
        tickers.value = false;
        await tester.pump();
        expect(
          tester.binding.transientCallbackCount,
          0,
          reason: 'every ticker is stopped before the capture',
        );
        _expectSystemFallbackFonts(tester, fileName);
        if (chrome == GoldenChrome.mac) {
          expect(
            window.layout.value,
            isNotNull,
            reason: 'the title bar placed the traffic lights',
          );
        }
      },
      // Not an interaction: the debug values set for the golden are reset
      // once it has been compared, before flutter_test checks them.
      whilePerforming: (tester) async =>
          () async => _resetDebugValues(),
    ),
  );
}

/// [fermanAlchemistConfig] without the 8 px inset around the scenario: a
/// window golden is exactly [goldenWindowSize].
final AlchemistConfig fermanWindowAlchemistConfig = fermanAlchemistConfig
    .copyWith(
      goldenTestTheme: GoldenTestTheme(
        backgroundColor: fermanAlchemistConfig.goldenTestTheme!.backgroundColor,
        borderColor: fermanAlchemistConfig.goldenTestTheme!.borderColor,
        nameTextStyle: fermanAlchemistConfig.goldenTestTheme!.nameTextStyle,
      ),
    );

void _resetDebugValues() {
  debugDefaultTargetPlatformOverride = null;
  EditableText.debugDeterministicCursor = false;
}

/// The number of frames [_settle] pumps, [_frame] apart: 3.2 s in all,
/// longer than any token animation, and four whole turns of a [Spinner]
/// that started in the first frame.
const int _frames = 32;
const Duration _frame = Duration(milliseconds: 100);

/// Lets every animation that ends run to its end. `pumpAndSettle` would
/// never return while a spinner turns.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < _frames; i++) {
    await tester.pump(_frame);
  }
}

/// The turns of every spinner on screen ([SpinRotation]), each in [0, 1).
List<double> _spinnerTurns(WidgetTester tester) => [
  for (final element
      in find
          .descendant(
            of: find.byType(SpinRotation),
            matching: find.byType(RotationTransition),
          )
          .evaluate())
    (element.widget as RotationTransition).turns.value % 1,
];

bool _atTurnStart(double turns) => turns < 1e-6 || turns > 1 - 1e-6;

/// Brings every spinner to the start of a turn, as the design references
/// show it: a spinner that started after the first frame is turned on to
/// its next whole turn.
Future<void> _alignSpinners(WidgetTester tester) async {
  final turns = _spinnerTurns(tester);
  if (turns.isEmpty || turns.every(_atTurnStart)) return;
  final first = turns.firstWhere((t) => !_atTurnStart(t));
  await tester.pump(Spinner.period * (1 - first));
  expect(
    _spinnerTurns(tester).every(_atTurnStart),
    isTrue,
    reason: 'every spinner is at the start of a turn',
  );
}

/// Every animation still running is a spinner's turn: nothing else is
/// stopped mid-flight by [TickerMode].
void _expectOnlySpinnersRun(WidgetTester tester) {
  expect(
    tester.binding.transientCallbackCount,
    _spinnerTurns(tester).length,
    reason: 'only spinners still animate after settling',
  );
}

/// Whether [rune] is CJK: kana, Hangul or a Han ideograph.
bool _isCjk(int rune) =>
    (rune >= 0x3040 && rune <= 0x30FF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0xAC00 && rune <= 0xD7AF);

/// Fails a golden that shows a macOS key symbol or CJK text when the
/// system font that draws it in tests is missing, so it never records
/// boxes ([useSystemFallbackFonts]).
void _expectSystemFallbackFonts(WidgetTester tester, String fileName) {
  final symbols = macKeySymbols.runes.toSet();
  for (final element in find.byType(RichText).evaluate()) {
    final text = (element.renderObject! as RenderParagraph).text.toPlainText();
    if (!keySymbolFallbackLoaded && text.runes.any(symbols.contains)) {
      fail(
        '$fileName shows a macOS key symbol in "$text", but '
        '$dejaVuSansMonoPath is missing, so it would draw a box. Install '
        'fonts-dejavu-core (G87).',
      );
    }
    if (!cjkFallbackLoaded && text.runes.any(_isCjk)) {
      fail(
        '$fileName shows CJK text in "$text", but $notoSansCjkPath is '
        'missing, so it would draw boxes. Install fonts-noto-cjk.',
      );
    }
  }
}
