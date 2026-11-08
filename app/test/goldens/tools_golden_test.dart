import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/tools/print_dialog.dart';
import 'package:ferman/features/tools/tools_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Kira sözleşmesi.pdf';

const List<PageInfo> _pages = [
  PageInfo(width: 595, height: 842, handle: 1),
  PageInfo(width: 595, height: 842, handle: 2),
  PageInfo(width: 595, height: 842, handle: 3),
];

/// a9-8's versions, with fixed times: the rows show their dates.
final List<VersionInfo> _versions = [
  VersionInfo(
    id: 5,
    kind: VersionKind.saved,
    time: DateTime(2026, 10, 14, 14, 32).millisecondsSinceEpoch,
    size: 2400000,
    edits: 3,
    names: const ['Madde 4', 'Madde 6', 'Madde 7'],
  ),
  VersionInfo(
    id: 4,
    kind: VersionKind.saved,
    time: DateTime(2026, 10, 14, 14, 5).millisecondsSinceEpoch,
    size: 2390000,
    edits: 1,
    names: const ['Madde 6'],
  ),
  VersionInfo(
    id: 3,
    kind: VersionKind.signed,
    time: DateTime(2026, 10, 13, 11, 4).millisecondsSinceEpoch,
    size: 2380000,
    edits: 1,
  ),
  VersionInfo(
    id: 2,
    kind: VersionKind.opened,
    time: DateTime(2026, 10, 11, 9, 30).millisecondsSinceEpoch,
    size: 2300000,
  ),
];

/// The engine with [_path], its compress analysis and its versions.
FakeEngineService _engine() =>
    FakeEngineService(
        documents: const {_path: OpenedDocument(id: 1, pages: _pages)},
      )
      ..compressAnalysisFound = const CompressAnalysis(
        before: 24600000,
        estimates: [
          CompressEstimate(preset: CompressPreset.highQuality, after: 14200000),
          CompressEstimate(
            preset: CompressPreset.balanced,
            after: 6800000,
            sampled: 40,
          ),
          CompressEstimate(preset: CompressPreset.smallest, after: 3100000),
        ],
        images: 1842,
        duplicateFonts: 6,
        thumbnails: 3,
      )
      ..versionLists[1] = _versions
      ..versionDocuments[3] = const OpenedDocument(id: 9, pages: _pages);

/// Compress (a9-1), Version history with a version previewed (a9-8) and
/// Print (a9-6) in light and dark × en, tr and ar. Goldens run on Linux CI
/// only.
Future<void> main() async {
  const screens = {
    'tools_compress': 'a9-1',
    'tools_versions': 'a9-8',
    'tools_print': 'a9-6',
  };
  for (final MapEntry(key: screen, value: board) in screens.entries) {
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
          engine: _engine(),
          // The print dialog is modal.
          muteTickers: screen != 'tools_print',
          open: (tester) async {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(FermanApp)),
            );
            await container.read(documentOpenerProvider.notifier).open([_path]);
            await tester.pump();
            container.read(shellModeProvider.notifier).select(FermanMode.tools);
            switch (screen) {
              case 'tools_compress':
                container
                    .read(toolsPanelProvider.notifier)
                    .show(ToolsPanel.compress);
                container.read(shellPanelOpenProvider.notifier).open();
              case 'tools_versions':
                container
                    .read(toolsPanelProvider.notifier)
                    .show(ToolsPanel.versions);
                await tester.pump();
                await container
                    .read(versionPreviewProvider.notifier)
                    .select(1, 3);
              case 'tools_print':
                final document = container.read(openDocumentProvider);
                if (document != null) {
                  container
                      .read(organizeDialogProvider.notifier)
                      .show(PrintDialog(document));
                }
            }
          },
        );
      }
    }
  }
}
