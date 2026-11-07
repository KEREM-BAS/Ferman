import 'dart:convert';

import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/stamps/comment_tool_menus.dart';
import 'package:ferman/features/stamps/create_stamp_dialog.dart';
import 'package:ferman/features/stamps/stamp_clock.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:ferman/features/stamps/stamp_library.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
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

/// A popover where its board draws it: until the comment row joins these, a
/// window golden has no button to hang it from.
Widget _shown(double start, Widget child) =>
    PositionedDirectional(top: 120, start: start, child: child);

/// a4-1's Shapes menu, a4-3's library and a4-3b's dialog in light and dark ×
/// en, tr and ar. Goldens run on Linux CI only.
Future<void> main() async {
  const screens = ['stamp_shapes_menu', 'stamp_library', 'stamp_create'];
  for (final screen in screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        OverlayEntry? entry;
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
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
          // A Dialog hides while tickers are muted.
          muteTickers: screen != 'stamp_create',
          cleanUp: (_) async => entry?.remove(),
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
              final added = OverlayEntry(
                builder: (context) => screen == 'stamp_library'
                    ? _shown(
                        700,
                        StampLibrary(yourName: _name, onChosen: (_) {}),
                      )
                    : _shown(
                        648,
                        SizedBox(
                          width: shapesMenuWidth,
                          child: Menu(
                            items: shapeMenuItems(
                              AppLocalizations.of(context),
                              container.read(commentToolMenusProvider),
                            ),
                          ),
                        ),
                      ),
              );
              entry = added;
              tester
                  .state<OverlayState>(find.byType(Overlay).first)
                  .insert(added);
            }
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
