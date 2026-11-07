import 'dart:async';

import 'package:ferman/app/app.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_palette.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcut_sheet.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Kira sözleşmesi.pdf';

const OpenedDocument _document = OpenedDocument(
  id: 1,
  pages: [
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
  ],
  outline: [
    OutlineEntry(title: 'Taraflar', page: 0),
    OutlineEntry(title: 'İmzalar', page: 2),
  ],
);

/// The command palette with a11-2's query "imza", the cheat sheet (a11-3)
/// and Settings › Keyboard shortcuts (a11-1j), in light and dark × en, tr
/// and ar. Goldens run on Linux CI only.
Future<void> main() async {
  const boards = {
    'command_palette': 'a11-2',
    'shortcut_sheet': 'a11-3',
    'settings_shortcuts': 'a11-1j',
  };
  for (final MapEntry(key: screen, value: board) in boards.entries) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? board
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          engine: FakeEngineService(documents: const {_path: _document}),
          // The palette and the sheet hide while tickers are muted.
          muteTickers: false,
          open: (tester) async {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(FermanApp)),
            );
            if (screen == 'settings_shortcuts') {
              unawaited(
                container
                    .read(routerProvider)
                    .push<void>(
                      Routes.settingsPane(SettingsPane.shortcuts.path),
                    ),
              );
              await tester.pumpAndSettle();
              return;
            }
            await container.read(documentOpenerProvider.notifier).open([_path]);
            container.read(shellModeProvider.notifier).select(FermanMode.edit);
            await tester.pumpAndSettle();
            final dialogs = container.read(organizeDialogProvider.notifier);
            if (screen == 'shortcut_sheet') {
              dialogs.show(const ShortcutSheet());
              await tester.pumpAndSettle();
              return;
            }
            dialogs.show(const ShellPalette());
            await tester.pumpAndSettle();
            await tester.enterText(
              find.descendant(
                of: find.byType(CommandPalette),
                matching: find.byType(EditableText),
              ),
              'imza',
            );
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
