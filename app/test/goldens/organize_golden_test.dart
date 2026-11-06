import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/combine.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/split_dialog.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Yüksek lisans tezi — Elif Şahin.pdf';

const OpenedDocument _document = OpenedDocument(
  id: 1,
  pages: [
    PageInfo(width: 595, height: 842, label: 'i'),
    PageInfo(width: 595, height: 842, label: 'ii'),
    PageInfo(width: 595, height: 842, label: '1'),
    PageInfo(width: 595, height: 842, label: '2'),
    PageInfo(width: 595, height: 842, label: '3'),
  ],
);

const SplitPreview _split = SplitPreview(
  files: [
    SplitFile(
      name: 'Yüksek lisans tezi — Özet ve içindekiler.pdf',
      first: 0,
      last: 1,
      bytes: 400000,
    ),
    SplitFile(
      name: 'Yüksek lisans tezi — 1. Giriş.pdf',
      first: 2,
      last: 3,
      bytes: 600000,
    ),
    SplitFile(
      name: 'Yüksek lisans tezi — 2. Bulgular.pdf',
      first: 4,
      last: 4,
      bytes: 1900000,
    ),
  ],
  bookmarks: 2,
);

/// a6-3's rows, with a locked one (G45) and a Word one (B175) in place of the
/// board's converted Excel file.
const CombineFiles _combine = CombineFiles(
  rows: [
    CombineRow(
      id: 1,
      path: '/Kira sözleşmesi.pdf',
      info: CombineFileInfo(
        status: CombineInputStatus.ready,
        pages: 3,
        selected: 3,
      ),
    ),
    CombineRow(id: 2, path: '/Ek-1 Demirbaş listesi.xlsx'),
    CombineRow(
      id: 3,
      path: '/Kimlik fotokopisi.pdf',
      range: '1',
      info: CombineFileInfo(
        status: CombineInputStatus.ready,
        pages: 2,
        selected: 1,
        signed: true,
      ),
    ),
    CombineRow(
      id: 4,
      path: '/Tapu fotokopisi.jpg',
      info: CombineFileInfo(
        status: CombineInputStatus.ready,
        image: true,
        pages: 1,
        selected: 1,
      ),
    ),
    CombineRow(
      id: 5,
      path: '/Hesap ekstresi Eylül 2026.pdf',
      info: CombineFileInfo(status: CombineInputStatus.passwordRequired),
    ),
  ],
  pages: 5,
  bytes: 3400000,
);

const List<BackgroundJob> _rows = [
  BackgroundJob(
    id: 1,
    kind: BackgroundJobKind.split,
    name: 'Yüksek lisans tezi.pdf',
    job: 1,
    value: 0.22,
    messageKey: 'jobPageOf',
    params: {'page': '14', 'pages': '64'},
  ),
  BackgroundJob(
    id: 2,
    kind: BackgroundJobKind.combine,
    name: 'Kira dosyası — tam.pdf',
    state: TaskState.done,
    output: '/Users/elif/Kira dosyası — tam.pdf',
  ),
  BackgroundJob(
    id: 3,
    kind: BackgroundJobKind.split,
    name: 'Tarama_0042.pdf',
    state: TaskState.done,
    output: '/Users/elif/a.pdf',
    params: {'files': '6'},
  ),
  BackgroundJob(
    id: 4,
    kind: BackgroundJobKind.create,
    name: 'Adsız.pdf',
    state: TaskState.error,
    error: EngineException(messageKey: 'errorInternal'),
  ),
];

class _SeededCombine extends CombineFilesNotifier {
  @override
  CombineFiles build() => _combine;
}

class _SeededJobs extends BackgroundJobsNotifier {
  @override
  BackgroundJobs build() => const BackgroundJobs(open: true, rows: _rows);
}

/// a6-2, a6-3, Create PDF and the drawer's rows of G45 in light and dark × en,
/// tr and ar. Goldens run on Linux CI only.
Future<void> main() async {
  for (final theme in GoldenTheme.values) {
    for (final language in GoldenLanguage.matrix) {
      final first = theme == GoldenTheme.light && language == GoldenLanguage.en;
      final settings = goldenSettings(
        theme: theme,
        language: language,
        onboardingCompleted: true,
      );
      FakeEngineService engine() =>
          FakeEngineService(documents: const {_path: _document})
            ..splitPreviewFound = _split;
      Future<void> opened(WidgetTester tester) async {
        await ProviderScope.containerOf(tester.element(find.byType(FermanApp)))
            .read(documentOpenerProvider.notifier)
            .open([_path]);
        await tester.pumpAndSettle();
      }

      ProviderContainer container(WidgetTester tester) =>
          ProviderScope.containerOf(tester.element(find.byType(FermanApp)));

      await windowGoldenTest(
        screen: 'organize_split',
        chrome: GoldenChrome.mac,
        theme: theme,
        language: language,
        board: first ? 'a6-2' : null,
        settings: settings,
        engine: engine(),
        muteTickers: false,
        open: (tester) async {
          await opened(tester);
          container(tester)
              .read(organizeDialogProvider.notifier)
              .show(const SplitDialog());
          await tester.pumpAndSettle();
        },
      );
      await windowGoldenTest(
        screen: 'organize_combine',
        chrome: GoldenChrome.mac,
        theme: theme,
        language: language,
        board: first ? 'a6-3' : null,
        settings: settings,
        engine: engine(),
        overrides: [combineFilesProvider.overrideWith(_SeededCombine.new)],
        open: (tester) async {
          await opened(tester);
          container(tester)
              .read(combineFilesProvider.notifier)
              .showTab('Combine files');
          await tester.pumpAndSettle();
        },
      );
      await windowGoldenTest(
        screen: 'organize_combine_empty',
        chrome: GoldenChrome.mac,
        theme: theme,
        language: language,
        settings: settings,
        engine: engine(),
        open: (tester) async {
          container(tester)
              .read(combineFilesProvider.notifier)
              .showTab('Combine files');
          await tester.pumpAndSettle();
        },
      );
      await windowGoldenTest(
        screen: 'organize_create',
        chrome: GoldenChrome.mac,
        theme: theme,
        language: language,
        settings: settings,
        engine: engine(),
        muteTickers: false,
        open: (tester) async {
          container(tester)
              .read(organizeDialogProvider.notifier)
              .show(const CreatePdfDialog());
          await tester.pumpAndSettle();
        },
      );
      await windowGoldenTest(
        screen: 'organize_task_rows',
        chrome: GoldenChrome.mac,
        theme: theme,
        language: language,
        settings: settings,
        engine: engine(),
        overrides: [backgroundJobsProvider.overrideWith(_SeededJobs.new)],
        // A running job's spinner never settles: the helper's settle follows.
        open: (tester) =>
            container(tester)
                .read(documentOpenerProvider.notifier)
                .open([_path]),
      );
    }
  }
}
