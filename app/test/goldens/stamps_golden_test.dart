import 'dart:convert';

import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/stamps/comment_tool_menus.dart';
import 'package:ferman/features/stamps/create_stamp_dialog.dart';
import 'package:ferman/features/stamps/stamp_clock.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Kira sözleşmesi.pdf';
const String _name = 'Av. Deniz Aksoy';

const OpenedDocument _document = OpenedDocument(
  id: 1,
  pages: [PageInfo(width: 595, height: 842)],
);

const StampDesign _mine = StampDesign(
  label: 'İncelendi',
  tone: StampTone.ink,
  language: StampLanguage.turkish,
  name: _name,
  withName: true,
);

/// a4-1's Shapes menu, a4-3's library and a4-3b's dialog in light and dark ×
/// en, tr and ar. Goldens run on Linux CI only.
Future<void> main() async {
  const screens = ['stamp_shapes_menu', 'stamp_library', 'stamp_create'];
  for (final screen in screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? const {
                  'stamp_shapes_menu': 'a4-1',
                  'stamp_library': 'a4-3',
                }[screen]
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ).copyWith(myStamps: [jsonEncode(_mine.toJson())]),
          engine: FakeEngineService(documents: const {_path: _document}),
          overrides: [
            stampClockProvider.overrideWithValue(
              () => DateTime(2026, 10, 13, 14, 36),
            ),
          ],
          // A Dialog and a popover hide while tickers are muted.
          muteTickers: false,
          open: (tester) async {
            final context = tester.element(find.byType(FermanApp));
            final container = ProviderScope.containerOf(context);
            await container.read(documentOpenerProvider.notifier).open([_path]);
            container
                .read(shellModeProvider.notifier)
                .select(FermanMode.comment);
            final menus = container.read(commentToolMenusProvider.notifier);
            if (screen == 'stamp_create') {
              container
                  .read(organizeDialogProvider.notifier)
                  .show(const CreateStampDialog(yourName: _name));
            } else {
              menus.chooseStamp(turkishStamps.first);
              final tool = screen == 'stamp_library'
                  ? AnnotationTool.stamp
                  : AnnotationTool.shapes;
              container.read(commentToolProvider.notifier).pick(tool);
              await tester.pumpAndSettle();
              menus.show(tool);
            }
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
