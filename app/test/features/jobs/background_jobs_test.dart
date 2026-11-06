import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/jobs/task_drawer.dart';
import 'package:ferman/features/save/closing_dialogs.dart';
import 'package:ferman/features/save/document_closer.dart';
import 'package:ferman/features/shell/shell_canvas.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations_en.dart';
import 'package:ferman/l10n/gen/app_localizations_tr.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/fake_desktop_window.dart';
import '../../helpers/recording_file_access.dart';
import '../shell/shell_host.dart';

const String _output = '/Users/elif/Kopya.pdf';

/// A container with [engine] and [access].
ProviderContainer _container(
  FakeEngineService engine,
  RecordingFileAccess access,
) {
  final container = ProviderContainer.test(
    overrides: [
      engineServiceProvider.overrideWithValue(engine),
      fileAccessProvider.overrideWithValue(access),
    ],
  );
  return container;
}

/// Starts the copy job, as job 1, and lets its first update arrive.
Future<BackgroundJobsNotifier> _started(ProviderContainer container) async {
  final jobs = container.read(backgroundJobsProvider.notifier);
  await jobs.copyDocument(7, 'Kira.pdf', _output);
  await pumpEventQueue();
  return jobs;
}

BackgroundJob _row(ProviderContainer container) =>
    container.read(backgroundJobsProvider).rows.single;

const JobUpdate _done = JobUpdate(
  job: 1,
  state: JobState.done,
  outputs: [JobOutputFile(path: _output)],
  revision: 0,
);

void main() {
  group('the jobs', () {
    late FakeEngineService engine;
    late RecordingFileAccess access;
    late ProviderContainer container;

    setUp(() {
      engine = FakeEngineService();
      access = RecordingFileAccess();
      container = _container(engine, access);
    });

    test('a row follows its job from the first update to Show', () async {
      final jobs = await _started(container);
      expect(engine.copyJobs.single, (7, _output, null));
      expect(_row(container).job, 1);
      expect(_row(container).state, TaskState.running);

      engine.reportJob(
        const JobUpdate(
          job: 1,
          state: JobState.running,
          progress: 0.25,
          messageKey: 'jobPageOf',
          params: {'page': '14', 'pages': '64'},
        ),
      );
      await pumpEventQueue();
      expect(_row(container).value, 0.25);

      await jobs.pause(_row(container));
      await pumpEventQueue();
      expect(_row(container).state, TaskState.paused);
      expect(_row(container).value, 0.25, reason: 'a pause keeps the bar');
      await jobs.resume(_row(container));
      await pumpEventQueue();
      expect(_row(container).state, TaskState.running);
      expect(engine.jobCalls, ['pause 1', 'resume 1']);

      engine.endJob(_done);
      await pumpEventQueue();
      expect(_row(container).state, TaskState.done);
      expect(_row(container).output, _output);
      await jobs.show(_row(container));
      expect(access.shown, [_output]);

      jobs.dismiss(_row(container).id);
      expect(container.read(backgroundJobsProvider).rows, isEmpty);
    });

    test('cancelling asks first, and the cancelled row goes', () async {
      final jobs = await _started(container);
      jobs
        ..askCancel(_row(container))
        ..keepRunning();
      expect(engine.jobCalls, isEmpty);
      expect(container.read(backgroundJobsProvider).cancelling, isNull);

      jobs.askCancel(_row(container));
      expect(container.read(backgroundJobsProvider).cancelling, isNotNull);
      await jobs.confirmCancel();
      await pumpEventQueue();
      expect(engine.jobCalls, ['cancel 1']);
      expect(container.read(backgroundJobsProvider).rows, isEmpty);
      expect(container.read(backgroundJobsProvider).cancelling, isNull);
    });

    test('a failed job stays as a row with its error', () async {
      await _started(container);
      engine.endJob(
        const JobUpdate(
          job: 1,
          state: JobState.failed,
          error: EngineException(
            kind: EngineErrorKind.diskFull,
            messageKey: 'errorInternal',
          ),
        ),
      );
      await pumpEventQueue();
      final row = _row(container);
      expect(row.state, TaskState.error);
      final l10n = AppLocalizationsEn();
      final format = RegionFormat.forRegion(Region.turkiye);
      expect(row.title(l10n), contains('Kira.pdf'));
      expect(row.detail(l10n, format), l10n.jobFailedDiskFull);
    });

    test('a staged output is swapped in', () async {
      access.stagingDirectory = '/staging';
      await _started(container);
      expect(engine.copyJobs.single.$3, '/staging');
      engine.endJob(
        const JobUpdate(
          job: 1,
          state: JobState.done,
          outputs: [JobOutputFile(path: _output, staged: '/staging/1')],
        ),
      );
      await pumpEventQueue();
      expect(access.swapped, [('/staging/1', _output)]);
      expect(_row(container).state, TaskState.done);
      expect(access.discarded, isEmpty);
    });

    test('a failed swap fails the row', () async {
      access
        ..stagingDirectory = '/staging'
        ..swapFailure = SwapFailure.locked;
      await _started(container);
      engine.endJob(
        const JobUpdate(
          job: 1,
          state: JobState.done,
          outputs: [JobOutputFile(path: _output, staged: '/staging/1')],
        ),
      );
      await pumpEventQueue();
      expect(_row(container).state, TaskState.error);
      expect(_row(container).error?.kind, EngineErrorKind.fileLocked);
    });

    test(
      'a job that stages nothing gives its staging directory back',
      () async {
        access.stagingDirectory = '/staging';
        final jobs = await _started(container);
        await jobs.pause(_row(container));
        await engine.cancelJob(1);
        await pumpEventQueue();
        expect(access.discarded, ['/staging']);
      },
    );

    test('a quit with nothing running does not ask', () async {
      final jobs = container.read(backgroundJobsProvider.notifier);
      expect(await jobs.confirmQuit(), isTrue);
    });

    test('a quit asks about the running jobs', () async {
      final jobs = await _started(container);
      final no = jobs.confirmQuit();
      await pumpEventQueue();
      expect(container.read(backgroundJobsProvider).quitting, hasLength(1));
      jobs.answerQuit(quit: false);
      expect(await no, isFalse);
      expect(container.read(backgroundJobsProvider).quitting, isEmpty);
      expect(engine.jobCalls, isEmpty);

      final yes = jobs.confirmQuit();
      await pumpEventQueue();
      jobs.answerQuit(quit: true);
      expect(await yes, isTrue);
      expect(engine.jobCalls, ['cancel 1']);
      expect(container.read(backgroundJobsProvider).rows, isEmpty);
    });

    test('quitting goes through the question', () async {
      await _started(container);
      final closer = container.read(documentCloserProvider.notifier);
      final quit = closer.quit();
      await pumpEventQueue();
      container.read(backgroundJobsProvider.notifier).answerQuit(quit: false);
      expect(await quit, isFalse);
    });

    test('the place reads in the region and the language', () {
      const row = BackgroundJob(
        id: 1,
        kind: BackgroundJobKind.copyDocument,
        name: 'Kira.pdf',
        messageKey: 'jobPageOf',
        params: {'page': '1400', 'pages': '2400'},
      );
      final format = RegionFormat.forRegion(Region.turkiye);
      final tr = AppLocalizationsTr();
      expect(
        row.detail(tr, format),
        tr.jobPageOf(format.integer(1400), format.integer(2400)),
      );
      expect(
        row.copyWith(state: TaskState.paused).detail(tr, format),
        tr.jobPausedAtPage(format.integer(1400)),
      );
    });
  });

  testWidgets('a finished row goes after an hour', (tester) async {
    final engine = FakeEngineService();
    final container = _container(engine, RecordingFileAccess());
    addTearDown(container.dispose);
    await container
        .read(backgroundJobsProvider.notifier)
        .copyDocument(7, 'Kira.pdf', _output);
    await tester.pump();
    engine.endJob(_done);
    await tester.pump();
    await tester.pump();
    expect(_row(container).state, TaskState.done);
    await tester.pump(const Duration(minutes: 59));
    expect(container.read(backgroundJobsProvider).rows, hasLength(1));
    await tester.pump(const Duration(minutes: 1));
    expect(container.read(backgroundJobsProvider).rows, isEmpty);
  });

  test('without an engine a job fails as every call does', () async {
    const service = UnavailableEngineService(
      EngineUnavailableException(EngineUnavailableReason.libraryMissing),
    );
    await expectLater(
      service.copyDocumentJob(1, _output),
      emitsError(isA<EngineUnavailableException>()),
    );
    await expectLater(
      service.pauseJob(1),
      throwsA(isA<EngineUnavailableException>()),
    );
    await expectLater(
      service.resumeJob(1),
      throwsA(isA<EngineUnavailableException>()),
    );
    await expectLater(
      service.cancelJob(1),
      throwsA(isA<EngineUnavailableException>()),
    );
  });

  group('the drawer', () {
    Future<ProviderContainer> pumpDrawer(
      WidgetTester tester,
      BackgroundJobs seeded, {
      Locale locale = const Locale('en'),
    }) async {
      final container = ProviderContainer.test(
        overrides: [
          backgroundJobsProvider.overrideWith(() => _Seeded(seeded)),
          engineServiceProvider.overrideWithValue(FakeEngineService()),
          fileAccessProvider.overrideWithValue(RecordingFileAccess()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: componentHost(
            const SizedBox(width: 500, height: 600, child: TaskDrawer()),
            locale: locale,
          ),
        ),
      );
      return container;
    }

    testWidgets('has an empty state', (tester) async {
      await pumpDrawer(tester, const BackgroundJobs(open: true));
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No background tasks'), findsOneWidget);
      expect(find.text('Background tasks'), findsOneWidget);
    });

    testWidgets('is 400 wide and shows each state with its actions', (
      tester,
    ) async {
      final container = await pumpDrawer(tester, _seeded);
      expect(tester.getSize(find.byType(TaskProgress).first).width, 380);
      expect(find.byType(TaskProgress), findsNWidgets(4));
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Dismiss'), findsNWidgets(2));
      expect(find.text('Page 14 of 64', findRichText: true), findsOneWidget);

      await tester.tap(find.text('Dismiss').first);
      await tester.pump();
      expect(container.read(backgroundJobsProvider).rows, hasLength(3));

      await tester.tap(find.bySemanticsLabel('Cancel').first);
      await tester.pump();
      expect(container.read(backgroundJobsProvider).cancelling?.id, 1);

      await tester.tap(find.bySemanticsLabel('Close drawer'));
      await tester.pump();
      expect(container.read(backgroundJobsProvider).open, isFalse);
    });

    testWidgets('sits at the bottom end, mirrored in right to left', (
      tester,
    ) async {
      await pumpDrawer(tester, _seeded, locale: const Locale('ar'));
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(TaskDrawer),
              matching: find.byType(Container),
            )
            .first,
      );
      final area = tester.getRect(find.byType(TaskDrawer));
      expect(box.left, area.left);
      expect(box.bottom, area.bottom);
      expect(box.width, TaskDrawer.width);
    });

    testWidgets('scrolls many rows in a short canvas', (tester) async {
      await pumpDrawer(
        tester,
        BackgroundJobs(
          open: true,
          rows: [
            for (var id = 1; id < 20; id++)
              BackgroundJob(
                id: id,
                kind: BackgroundJobKind.copyDocument,
                name: 'Kira.pdf',
              ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('the shell', () {
    Future<ProviderContainer> pumpShell(
      WidgetTester tester,
      BackgroundJobs seeded,
    ) async {
      tester.view
        ..physicalSize = artboard
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        shellHost(
          window: FakeDesktopWindow(WindowPlatform.linux),
          overrides: [
            backgroundJobsProvider.overrideWith(() => _Seeded(seeded)),
            engineServiceProvider.overrideWithValue(FakeEngineService()),
            fileAccessProvider.overrideWithValue(RecordingFileAccess()),
          ],
        ),
      );
      await tester.pump();
      return ProviderScope.containerOf(
        tester.element(find.byType(ShellStatusBar)),
      );
    }

    Finder inBar(Finder finder) =>
        find.descendant(of: find.byType(ShellStatusBar), matching: finder);

    testWidgets('no job shows no task', (tester) async {
      await pumpShell(tester, const BackgroundJobs());
      expect(inBar(find.byType(TaskDrawerOpener)), findsNothing);
      expect(find.byType(TaskDrawer), findsNothing);
    });

    testWidgets('the status bar opens the drawer on the canvas', (
      tester,
    ) async {
      final container = await pumpShell(
        tester,
        const BackgroundJobs(rows: [_running]),
      );
      expect(inBar(find.byType(TaskDrawerOpener)), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(TaskDrawerOpener),
          matching: find.byType(Spinner),
        ),
      );
      await tester.pump();
      expect(container.read(backgroundJobsProvider).open, isTrue);
      expect(
        find.descendant(
          of: find.byType(ShellCanvas),
          matching: find.byType(TaskDrawer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('several jobs share the one line', (tester) async {
      await pumpShell(
        tester,
        const BackgroundJobs(
          rows: [
            _running,
            BackgroundJob(
              id: 2,
              kind: BackgroundJobKind.copyDocument,
              name: 'Fatura.pdf',
            ),
          ],
        ),
      );
      expect(
        inBar(find.text('2 tasks running', findRichText: true)),
        findsOneWidget,
      );
    });

    testWidgets('a finished job stays as the way to its row', (tester) async {
      await pumpShell(
        tester,
        const BackgroundJobs(
          rows: [
            BackgroundJob(
              id: 1,
              kind: BackgroundJobKind.copyDocument,
              name: 'Kira.pdf',
              state: TaskState.done,
              output: _output,
            ),
          ],
        ),
      );
      expect(inBar(find.byType(TaskDrawerOpener)), findsOneWidget);
      expect(inBar(find.byIcon2(IconName.circleCheck)), findsOneWidget);
    });
  });

  group('the questions', () {
    Future<void> pumpQuestions(WidgetTester tester, BackgroundJobs seeded) {
      final container = ProviderContainer.test(
        overrides: [
          backgroundJobsProvider.overrideWith(() => _Seeded(seeded)),
          engineServiceProvider.overrideWithValue(FakeEngineService()),
          fileAccessProvider.overrideWithValue(RecordingFileAccess()),
        ],
      );
      return tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: componentHost(
            const SizedBox(
              width: 800,
              height: 600,
              child: ClosingOverlays(child: SizedBox.expand()),
            ),
          ),
        ),
      );
    }

    testWidgets('cancelling a task is confirmed', (tester) async {
      await pumpQuestions(
        tester,
        const BackgroundJobs(rows: [_running], cancelling: _running),
      );
      expect(find.byType(CancelTaskDialog), findsOneWidget);
      expect(find.text('Keep running'), findsOneWidget);
      expect(find.text('Cancel task'), findsOneWidget);
    });

    testWidgets('quitting lists the running jobs', (tester) async {
      await pumpQuestions(
        tester,
        const BackgroundJobs(rows: [_running], quitting: [_running]),
      );
      expect(find.byType(QuitTasksDialog), findsOneWidget);
      expect(find.text('A background task is still running'), findsOneWidget);
      expect(find.textContaining('Kira.pdf'), findsOneWidget);
      expect(find.text('Cancel tasks and quit'), findsOneWidget);
    });
  });
}

extension on CommonFinders {
  /// The Ferman [Icon] of [name].
  Finder byIcon2(IconName name) =>
      find.byWidgetPredicate((widget) => widget is Icon && widget.name == name);
}

const BackgroundJob _running = BackgroundJob(
  id: 1,
  kind: BackgroundJobKind.copyDocument,
  name: 'Kira.pdf',
  job: 1,
  value: 0.22,
  messageKey: 'jobPageOf',
  params: {'page': '14', 'pages': '64'},
);

/// The four rows a11-6b draws.
const BackgroundJobs _seeded = BackgroundJobs(
  open: true,
  rows: [
    _running,
    BackgroundJob(
      id: 2,
      kind: BackgroundJobKind.copyDocument,
      name: 'Fatura.pdf',
      job: 2,
      state: TaskState.paused,
      value: 0.43,
      messageKey: 'jobPageOf',
      params: {'page': '18', 'pages': '42'},
    ),
    BackgroundJob(
      id: 3,
      kind: BackgroundJobKind.copyDocument,
      name: 'Rapor.pdf',
      state: TaskState.done,
      output: _output,
    ),
    BackgroundJob(
      id: 4,
      kind: BackgroundJobKind.copyDocument,
      name: 'Tarama.pdf',
      state: TaskState.error,
      error: EngineException(messageKey: 'errorDamagedTruncated'),
    ),
  ],
);

/// Starts with [seeded], and no timer or engine behind it.
class _Seeded extends BackgroundJobsNotifier {
  new(this.seeded);

  final BackgroundJobs seeded;

  @override
  BackgroundJobs build() => seeded;
}
