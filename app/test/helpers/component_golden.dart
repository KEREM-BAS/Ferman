import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:ferman/design/components/feedback/progress_bar.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import 'component_host.dart';
import 'fonts.dart';
import 'golden_config.dart';
import 'window_golden.dart';

/// The width of every component golden: the samples wrap as they do in a
/// gallery 1200 px wide, and the height is the content's.
const double componentGoldenWidth = 1200;

/// The inset around the samples, the gallery list's side padding
/// (`--space-6`).
const double componentGoldenInset = 24;

/// Declares a golden of [builder]'s samples (a gallery section,
/// `GalleryEntry.builder`) previewed as [preview] says, written to
/// `goldens/linux/<fileName>.png` next to the test.
///
/// The samples sit in the gallery's own preview ([GalleryPreviewScope]:
/// the theme, the UI language and its direction, the region formats and
/// the panel background) with macOS key caps, at desktop density
/// (`debugDefaultTargetPlatformOverride` is macOS while the golden is
/// drawn), [componentGoldenWidth] wide and as tall as they are, at a
/// device pixel ratio of 1, with no frame around them
/// ([fermanWindowAlchemistConfig]).
///
/// Determinism, as in [windowGoldenTest]: animations that end run to their
/// end; the spinners and indeterminate progress bars, which never end, are
/// captured 4.8 s after their first frame (six whole turns of a [Spinner],
/// and the progress sweep in the middle of the track), a spinner of another
/// period (the loading `Button`'s) turned on to the start of a turn, and
/// every ticker is then stopped with [TickerMode], so nothing moves while
/// the image is taken; carets never blink (a stopped [TickerMode] holds
/// `TextCaret` solid, and [EditableText.debugDeterministicCursor] always
/// shows the text field caret). The same run gives the same bytes.
///
/// Text uses the bundled fonts, the system fonts that stand in for the
/// system fallback ([useSystemFallbackFonts]) and the stand-ins for the
/// system fonts the samples name ([loadSystemFontStandIns], which the test
/// file awaits first). A golden that shows text in a family tests do not
/// have, or a macOS key symbol or CJK text without its fallback font, fails
/// instead of recording boxes.
Future<void> componentGoldenTest({
  required String description,
  required String fileName,
  required GalleryPreview preview,
  required WidgetBuilder builder,
}) {
  late ValueNotifier<bool> tickers;
  return AlchemistConfig.runWithConfig(
    config: fermanWindowAlchemistConfig,
    run: () => goldenTest(
      description,
      fileName: fileName,
      skip: !isGoldenHost,
      constraints: const BoxConstraints.tightFor(width: componentGoldenWidth),
      builder: () {
        tickers = ValueNotifier(true);
        return ValueListenableBuilder<bool>(
          valueListenable: tickers,
          builder: (context, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: componentHost(
            SizedBox(
              width: componentGoldenWidth,
              child: GalleryPreviewScope(
                preview: preview,
                shortcuts: ShortcutPlatform.mac,
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(
                    componentGoldenInset,
                  ),
                  child: Builder(builder: builder),
                ),
              ),
            ),
            brightness: preview.theme.brightness,
            locale: preview.language.uiLocale,
            textDirection: preview.direction,
            size: const Size(componentGoldenWidth, 900),
          ),
        );
      },
      pumpWidget: (tester, widget) async {
        addTearDown(() => tickers.dispose());
        addTearDown(_resetDebugValues);
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        EditableText.debugDeterministicCursor = true;
        await tester.pumpWidget(widget);
      },
      pumpBeforeTest: (tester) async {
        await _settle(tester);
        await _alignSpinners(tester);
        final running = tester.binding.transientCallbackCount;
        tickers.value = false;
        await tester.pump();
        // What stays registered is the layout tracking of the open
        // popovers and tooltips (`OverlayPortal.overlayChildLayoutBuilder`
        // follows its anchor every frame), which never asks for a frame.
        final tracking = tester.binding.transientCallbackCount;
        expect(
          running - tracking,
          _endlessAnimations(tester),
          reason:
              'only spinners and indeterminate progress bars still animate '
              'after settling',
        );
        // The frame that stopped the tickers was asked for by their last
        // tick; the next one asks for none.
        await tester.pump();
        expect(
          tester.binding.hasScheduledFrame,
          isFalse,
          reason: 'every ticker is stopped before the capture',
        );
        _expectRealGlyphs(tester, fileName);
      },
      // Not an interaction: the debug values set for the golden are reset
      // once it has been compared, before flutter_test checks them.
      whilePerforming: (tester) async =>
          () async => _resetDebugValues(),
    ),
  );
}

void _resetDebugValues() {
  debugDefaultTargetPlatformOverride = null;
  EditableText.debugDeterministicCursor = false;
}

/// The number of frames [_settle] pumps, [_frame] apart: 4.8 s in all,
/// longer than any token animation, six whole turns of a [Spinner] and
/// three and three sevenths sweeps of an indeterminate [ProgressBar] that
/// started in the first frame, which puts its fill in the middle of the
/// track instead of outside it.
const int _frames = 48;
const Duration _frame = Duration(milliseconds: 100);

/// Lets every animation that ends run to its end. `pumpAndSettle` would
/// never return while a spinner turns.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < _frames; i++) {
    await tester.pump(_frame);
  }
}

/// Every spinner on screen ([SpinRotation]): its turns, in [0, 1), and the
/// time of one turn (a [Spinner]'s and a loading `Button`'s differ).
List<({double turns, Duration period})> _spinners(WidgetTester tester) => [
  for (final element in find.byType(SpinRotation).evaluate())
    (
      turns:
          tester
              .widget<RotationTransition>(
                find
                    .descendant(
                      of: find.byElementPredicate((e) => e == element),
                      matching: find.byType(RotationTransition),
                    )
                    .first,
              )
              .turns
              .value %
          1,
      period: (element.widget as SpinRotation).period,
    ),
];

bool _atTurnStart(double turns) => turns < 1e-6 || turns > 1 - 1e-6;

/// Brings every spinner to the start of a turn, as the design references
/// show them ([windowGoldenTest]): one that is not there yet is turned on
/// to its next whole turn, and so on until all are, which spinners of
/// different periods in one section may never reach.
Future<void> _alignSpinners(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    final behind = _spinners(tester).where((s) => !_atTurnStart(s.turns));
    if (behind.isEmpty) return;
    final spinner = behind.first;
    await tester.pump(spinner.period * (1 - spinner.turns));
  }
  expect(
    _spinners(tester).every((s) => _atTurnStart(s.turns)),
    isTrue,
    reason: 'every spinner is at the start of a turn',
  );
}

/// The animations that never end: one per spinner and one per
/// indeterminate progress bar on screen.
int _endlessAnimations(WidgetTester tester) =>
    find.byType(SpinRotation).evaluate().length +
    find
        .byWidgetPredicate(
          (widget) => widget is ProgressBar && widget.indeterminate,
        )
        .evaluate()
        .length;

/// Whether [rune] is CJK: kana, Hangul or a Han ideograph.
bool _isCjk(int rune) =>
    (rune >= 0x3040 && rune <= 0x30FF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0xAC00 && rune <= 0xD7AF);

/// The text on screen: every paragraph's and every text field's.
Iterable<InlineSpan> _texts(WidgetTester tester) sync* {
  for (final object in tester.allRenderObjects) {
    if (object is RenderParagraph) yield object.text;
    if (object is RenderEditable) {
      if (object.text case final text?) yield text;
    }
  }
}

/// The font families that [span] and its children name, first families
/// and fallbacks.
Set<String> _families(InlineSpan span) {
  final families = <String>{};
  span.visitChildren((child) {
    final style = child.style;
    if (style?.fontFamily case final family?) families.add(family);
    families.addAll(style?.fontFamilyFallback ?? const []);
    return true;
  });
  return families;
}

/// Fails a golden that would record boxes: text in a font family that tests
/// do not have (`flutter test` draws a family it does not know in its test
/// font, a box for every glyph), and a macOS key symbol or CJK text when the
/// system font that draws it in tests is missing
/// ([useSystemFallbackFonts]).
void _expectRealGlyphs(WidgetTester tester, String fileName) {
  final known = {
    ...loadedAppFontFamilies,
    ...systemFallbackFamilies,
    ...loadedSystemFontStandIns,
  };
  final symbols = macKeySymbols.runes.toSet();
  for (final span in _texts(tester)) {
    final text = span.toPlainText();
    final unknown = _families(span).difference(known);
    if (unknown.isNotEmpty) {
      // A family with a stand-in is unknown only when its file was not
      // loaded: name the file, so the fix is the package, not the code.
      final standIns = {
        for (final family in unknown) ?systemFontStandIns[family],
      };
      final fix = standIns.isEmpty
          ? 'Bundle the family or give it a stand-in (systemFontStandIns).'
          : 'Its stand-in ${standIns.join(', ')} was not loaded '
                '(loadSystemFontStandIns): install fonts-dejavu-core.';
      fail(
        '$fileName shows "$text" in ${unknown.join(', ')}, which tests do '
        'not have, so it would draw boxes. $fix',
      );
    }
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

/// DejaVu Serif as Debian and Ubuntu install it with `fonts-dejavu-core`,
/// the package that also brings the key-symbol fallback
/// ([dejaVuSansMonoPath]).
const String dejaVuSerifPath =
    '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf';

/// The system fonts the gallery's samples name and the system file that
/// draws each in tests: the FontPicker lists Georgia and Times New Roman
/// under "On this device", each name in its own font. On a desktop they
/// come from the system; `flutter test` has none, so DejaVu Serif stands
/// in for both.
const Map<String, String> systemFontStandIns = {
  'Georgia': dejaVuSerifPath,
  'Times New Roman': dejaVuSerifPath,
};

/// The families of [systemFontStandIns] that [loadSystemFontStandIns]
/// loaded.
final Set<String> loadedSystemFontStandIns = {};

/// Loads each of [systemFontStandIns] under its family name when its file
/// exists (Linux with `fonts-dejavu-core`, as on the CI runner). When a file
/// is missing its family stays unknown, and a component golden that shows
/// it fails instead of recording boxes.
Future<void> loadSystemFontStandIns() async {
  for (final MapEntry(key: family, value: path) in systemFontStandIns.entries) {
    if (loadedSystemFontStandIns.contains(family)) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    loadedSystemFontStandIns.add(family);
  }
}
