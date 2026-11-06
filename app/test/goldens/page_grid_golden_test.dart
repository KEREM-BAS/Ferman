import 'dart:ui' show PointerDeviceKind;

import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/phone_golden.dart';
import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Yüksek lisans tezi.pdf';

/// tez-tr's front matter and first pages (`tabsTez`, `grid`).
final OpenedDocument _tez = OpenedDocument(
  id: 1,
  pages: [
    for (var i = 0; i < 64; i++)
      PageInfo(
        width: 595,
        height: 842,
        handle: 100 + i,
        label: i < 3 ? const ['i', 'ii', 'iii'][i] : '${i - 2}',
      ),
  ],
);

Finder _page(int number) => find.byWidgetPredicate(
  (widget) => widget is PageThumbnail && widget.page == number,
);

/// Opens the thesis in Organize with its pages 4 to 6 selected.
Future<void> _selected(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FermanApp)),
  );
  await container.read(documentOpenerProvider.notifier).open([_path]);
  await tester.pumpAndSettle();
  container.read(shellModeProvider.notifier).select(FermanMode.organize);
  await tester.pumpAndSettle();
  container.read(pageSelectionProvider.notifier)
    ..only(103)
    ..toggle(104)
    ..toggle(105);
  await tester.pumpAndSettle();
}

/// Page grid goldens (a6-1, a6-1b) in light and dark × en, tr and ar: the
/// selection with its panel and its menu and the drag, in the window; the
/// grid in a phone-wide one. Goldens run on Linux CI only.
Future<void> main() async {
  TestGesture? held;
  final screens = <String, Future<void> Function(WidgetTester)>{
    'organize_grid': _selected,
    'organize_menu': (tester) async {
      await _selected(tester);
      await tester.tap(
        _page(5),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
    },
    'organize_drag': (tester) async {
      await _selected(tester);
      held = await tester.startGesture(
        tester.getCenter(_page(5)),
        kind: PointerDeviceKind.mouse,
      );
      await held!.moveBy(const Offset(30, 0));
      await tester.pump();
      await held!.moveTo(tester.getTopLeft(_page(3)) + const Offset(2, 60));
      await tester.pumpAndSettle();
    },
  };
  const boards = {'organize_grid': 'a6-1', 'organize_drag': 'a6-1b'};
  for (final MapEntry(key: screen, value: open) in screens.entries) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? boards[screen]
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          engine: FakeEngineService(documents: {_path: _tez}),
          open: open,
          cleanUp: (tester) async {
            await held?.up();
            held = null;
          },
        );
      }
    }
  }
  for (final theme in GoldenTheme.values) {
    for (final language in GoldenLanguage.matrix) {
      await appGoldenTest(
        fileName: phoneGoldenFileName('organize_grid', theme, language),
        size: goldenPhoneSize,
        platform: null,
        targetPlatform: TargetPlatform.android,
        shortcuts: ShortcutPlatform.windows,
        language: language,
        settings: goldenSettings(
          theme: theme,
          language: language,
          onboardingCompleted: true,
        ),
        engine: FakeEngineService(documents: {_path: _tez}),
        open: _selected,
      );
    }
  }
}
