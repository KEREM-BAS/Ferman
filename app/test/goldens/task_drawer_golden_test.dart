import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_models.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Kira sözleşmesi.pdf';

const List<PageInfo> _pages = [
  PageInfo(width: 595, height: 842),
  PageInfo(width: 595, height: 842),
  PageInfo(width: 595, height: 842),
];

const BackgroundJob _running = BackgroundJob(
  id: 1,
  kind: BackgroundJobKind.copyDocument,
  name: 'Yüksek lisans tezi.pdf',
  job: 1,
  value: 0.22,
  messageKey: 'jobPageOf',
  params: {'page': '14', 'pages': '64'},
);

const List<BackgroundJob> _rows = [
  _running,
  BackgroundJob(
    id: 2,
    kind: BackgroundJobKind.copyDocument,
    name: 'Arşiv.pdf',
    job: 2,
    state: TaskState.paused,
    value: 0.43,
    messageKey: 'jobPageOf',
    params: {'page': '18', 'pages': '42'},
  ),
  BackgroundJob(
    id: 3,
    kind: BackgroundJobKind.copyDocument,
    name: 'İmar planı açıklama raporu.pdf',
    state: TaskState.done,
    output: '/Users/elif/Belgeler/İmar planı açıklama raporu kopya.pdf',
  ),
  BackgroundJob(
    id: 4,
    kind: BackgroundJobKind.copyDocument,
    name: 'Tarama_0042.pdf',
    state: TaskState.error,
    error: EngineException(messageKey: 'errorDamagedTruncated'),
  ),
];

/// The drawer's state in a golden, with no job behind it.
class _Seeded extends BackgroundJobsNotifier {
  new(this.seeded);

  final BackgroundJobs seeded;

  @override
  BackgroundJobs build() => seeded;
}

/// The task drawer (a11-6b), its empty state and its two questions (G49) in
/// light and dark × en, tr and ar. Goldens run on Linux CI only.
Future<void> main() async {
  const screens = {
    'task_drawer': BackgroundJobs(open: true, rows: _rows),
    'task_drawer_empty': BackgroundJobs(open: true),
    'task_cancel': BackgroundJobs(rows: _rows, cancelling: _running),
    'task_quit': BackgroundJobs(rows: _rows, quitting: [_running]),
  };
  for (final MapEntry(key: screen, value: seeded) in screens.entries) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board:
              screen == 'task_drawer' &&
                  theme == GoldenTheme.light &&
                  language == GoldenLanguage.en
              ? 'a11-6b'
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ),
          engine: FakeEngineService(
            documents: const {_path: OpenedDocument(id: 1, pages: _pages)},
          ),
          overrides: [
            backgroundJobsProvider.overrideWith(() => _Seeded(seeded)),
          ],
          muteTickers: seeded.cancelling == null && seeded.quitting.isEmpty,
          // A running job's spinner never settles: the helper's settle follows.
          open: (tester) =>
              ProviderScope.containerOf(tester.element(find.byType(FermanApp)))
                  .read(documentOpenerProvider.notifier)
                  .open([_path]),
        );
      }
    }
  }
}
