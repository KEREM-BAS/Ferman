import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/organize/extract_pages_dialog.dart';
import 'package:ferman/features/organize/insert_blank_dialog.dart';
import 'package:ferman/features/organize/insert_file_dialog.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_labels_dialog.dart';
import 'package:ferman/features/organize/replace_pages_dialog.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Yüksek lisans tezi.pdf';

const OpenedDocument _document = OpenedDocument(
  id: 1,
  pages: [
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
  ],
);

/// a6-4, a6-5 and G45's four dialogs in light and dark × en, tr and ar.
/// Goldens run on Linux CI only.
Future<void> main() async {
  final dialogs = <String, Widget?>{
    'organize_labels': const PageLabelsDialog(document: _document),
    'organize_insert_blank': const InsertBlankDialog(
      document: _document,
      pages: [0],
    ),
    'organize_insert_file': const InsertFileDialog(
      document: _document,
      pages: [0],
    ),
    'organize_replace': const ReplacePagesDialog(
      document: _document,
      pages: [0],
    ),
    'organize_extract': const ExtractPagesDialog(
      document: _document,
      name: 'Yüksek lisans tezi.pdf',
      pages: [0],
    ),
    'organize_crop': null,
  };
  for (final MapEntry(key: screen, value: dialog) in dialogs.entries) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? switch (screen) {
                  'organize_labels' => 'a6-5',
                  'organize_crop' => 'a6-4',
                  _ => null,
                }
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          engine: FakeEngineService(documents: const {_path: _document}),
          open: (tester) async {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(FermanApp)),
            );
            await container.read(documentOpenerProvider.notifier).open([_path]);
            container
                .read(shellModeProvider.notifier)
                .select(FermanMode.organize);
            if (dialog == null) {
              container.read(organizeCropProvider.notifier).start(
                _document,
                const [0],
                RegionFormat.forRegion(Region.forCode('TR')),
              );
            } else {
              container.read(organizeDialogProvider.notifier).show(dialog);
            }
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
