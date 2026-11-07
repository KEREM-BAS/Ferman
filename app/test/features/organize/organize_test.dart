import 'dart:io';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/combine.dart';
import 'package:ferman/features/organize/combine_tab.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/split_dialog.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations_en.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/fake_file_picker.dart';
import '../../helpers/recording_file_access.dart';
import '../onboarding/ferman_app_harness.dart';

const String _path = '/Users/elif/Tez.pdf';

const OpenedDocument _document = OpenedDocument(
  id: 1,
  pages: [
    PageInfo(width: 100, height: 200, label: 'i'),
    PageInfo(width: 100, height: 200, label: 'ii'),
    PageInfo(width: 100, height: 200, label: '1'),
  ],
);

const CombineFileInfo _ready = CombineFileInfo(
  status: CombineInputStatus.ready,
  pages: 3,
  selected: 3,
  bytes: 3000,
);

({
  ProviderContainer container,
  FakeEngineService engine,
  FakeFilePickerService picker,
  RecordingFileAccess access,
})
_setUp() {
  final engine = FakeEngineService(documents: {_path: _document});
  final picker = FakeFilePickerService();
  final access = RecordingFileAccess();
  final container = ProviderContainer.test(
    overrides: [
      engineServiceProvider.overrideWithValue(engine),
      filePickerServiceProvider.overrideWithValue(picker),
      fileAccessProvider.overrideWithValue(access),
    ],
  );
  return (container: container, engine: engine, picker: picker, access: access);
}

void main() {
  group('parsePageRange', () {
    test('reads pages and ranges, in the order typed', () {
      expect(parsePageRange('1–3, 5'), [0, 1, 2, 4]);
      expect(parsePageRange('5,1'), [4, 0]);
      expect(parsePageRange(' 2 - 3 '), [1, 2]);
      expect(parsePageRange('٢،٣'), [1, 2]);
    });

    test('refuses what cannot be pages', () {
      expect(parsePageRange('abc'), isNull);
      expect(parsePageRange('0'), isNull);
      expect(parsePageRange('3-1'), isNull);
      expect(parsePageRange('1,,2'), isNull);
      expect(parsePageRange('1-999999999'), isNull);
    });
  });

  group('the Combine tab', () {
    test('is not reopened at the next launch', () async {
      final s = _setUp();
      const list = ShellDocumentList(
        documents: [
          ShellDocument(name: 'Combine', path: ShellDocument.combinePath),
        ],
      );
      await s.container.read(documentOpenerProvider.notifier).recordOpen(list);
      expect(s.container.read(settingsProvider).lastDocuments, isEmpty);
    });

    test('asks only about rows it can use, each in its place', () async {
      final s = _setUp();
      s.engine.combinePreviewFound = const CombinePreview(
        files: [_ready],
        pages: 3,
        bytes: 3000,
      );
      final files = s.container.read(combineFilesProvider.notifier)
        ..add(['/rapor.docx', '/a.pdf']);
      await pumpEventQueue();
      final rows = s.container.read(combineFilesProvider).rows;
      expect(rows[0].office, isTrue);
      expect(rows[0].info, isNull);
      expect(rows[1].info, _ready);
      expect(rows[1].stem, 'a');
      // A Word row is not skipped silently: it holds Combine back.
      expect(s.container.read(combineFilesProvider).canCombine, isFalse);

      files.remove(rows[0].id);
      await pumpEventQueue();
      expect(s.container.read(combineFilesProvider).canCombine, isTrue);
      expect(s.container.read(combineFilesProvider).pages, 3);

      files.setRange(rows[1].id, 'abc');
      await pumpEventQueue();
      final bad = s.container.read(combineFilesProvider).rows.single;
      expect(bad.badRange, isTrue);
      expect(s.container.read(combineFilesProvider).canCombine, isFalse);
    });

    test('moves a row before the one at an index', () async {
      final s = _setUp();
      final files = s.container.read(combineFilesProvider.notifier)
        ..add(['/a.pdf', '/b.pdf', '/c.pdf']);
      await pumpEventQueue();
      List<String> order() => [
        for (final row in s.container.read(combineFilesProvider).rows) row.name,
      ];
      final id = s.container.read(combineFilesProvider).rows.first.id;
      files.move(id, 2);
      expect(order(), ['b.pdf', 'a.pdf', 'c.pdf']);
      files.move(id, 3);
      expect(order(), ['b.pdf', 'c.pdf', 'a.pdf']);
      files.move(id, 0);
      expect(order(), ['a.pdf', 'b.pdf', 'c.pdf']);
    });

    test('a locked row becomes usable with its password', () async {
      final s = _setUp();
      s.engine.combinePreviewFound = const CombinePreview(
        files: [CombineFileInfo(status: CombineInputStatus.passwordRequired)],
      );
      final files = s.container.read(combineFilesProvider.notifier)
        ..add(['/a.pdf']);
      await pumpEventQueue();
      expect(s.container.read(combineFilesProvider).canCombine, isFalse);

      s.engine.combinePreviewFound = const CombinePreview(
        files: [_ready],
        pages: 3,
      );
      files.setPassword(
        s.container.read(combineFilesProvider).rows.single.id,
        's3',
      );
      await pumpEventQueue();
      final row = s.container.read(combineFilesProvider).rows.single;
      expect(row.password, 's3');
      expect(row.ready, isTrue);
    });

    test('writes through the save panel as a job with a row', () async {
      final s = _setUp();
      s.engine.combinePreviewFound = const CombinePreview(files: [_ready]);
      final dir = Directory.systemTemp.createTempSync('combine');
      addTearDown(() => dir.deleteSync(recursive: true));
      final files = s.container.read(combineFilesProvider.notifier)
        ..add(['/a.pdf']);
      await pumpEventQueue();

      // Cancelled: nothing runs.
      await files.combine(name: 'Tam');
      expect(s.picker.saves, ['Tam.pdf']);
      expect(s.engine.assembleJobs, isEmpty);

      s.picker.saveTo = '${dir.path}/Tam.pdf';
      await files.combine(name: 'Tam.pdf');
      await pumpEventQueue();
      expect(s.engine.assembleJobs.single, 'combine 1 ${dir.path}/Tam.pdf');
      final row = s.container.read(backgroundJobsProvider).rows.single;
      expect(row.kind, BackgroundJobKind.combine);
      expect(row.name, 'Tam.pdf');
    });

    test('never overwrites: a name that is taken gets a toast', () async {
      final s = _setUp();
      s.engine.combinePreviewFound = const CombinePreview(files: [_ready]);
      final dir = Directory.systemTemp.createTempSync('combine');
      addTearDown(() => dir.deleteSync(recursive: true));
      final taken = File('${dir.path}/Var.pdf')..writeAsStringSync('x');
      s.picker.saveTo = taken.path;
      final files = s.container.read(combineFilesProvider.notifier)
        ..add(['/a.pdf']);
      await pumpEventQueue();
      await files.combine(name: 'Var.pdf');
      expect(s.engine.assembleJobs, isEmpty);
      expect(s.container.read(toastNoticesProvider), hasLength(1));
      expect(s.container.read(backgroundJobsProvider).rows, isEmpty);
    });
  });

  group('the rows of the drawer', () {
    test('name split, combine and create in each state', () {
      final l10n = AppLocalizationsEn();
      final format = RegionFormat.forRegion(Region.turkiye);
      String titled(BackgroundJobKind kind, TaskState state) =>
          BackgroundJob(id: 1, kind: kind, name: 'x', state: state).title(l10n);
      expect(
        titled(BackgroundJobKind.split, TaskState.running),
        contains('Splitting'),
      );
      expect(
        titled(BackgroundJobKind.combine, TaskState.done),
        contains('Combined'),
      );
      expect(
        titled(BackgroundJobKind.create, TaskState.error),
        contains('create'),
      );
      expect(
        const BackgroundJob(
          id: 1,
          kind: BackgroundJobKind.split,
          name: 'x',
          state: TaskState.done,
          params: {'files': '6'},
        ).detail(l10n, format),
        '6 files',
      );
      expect(
        const BackgroundJob(
          id: 1,
          kind: BackgroundJobKind.extractPages,
          name: 'x',
          state: TaskState.done,
          output: '/a.pdf',
          params: {'files': '5'},
        ).detail(l10n, format),
        '5 files',
      );
      expect(
        const BackgroundJob(
          id: 1,
          kind: BackgroundJobKind.extractPages,
          name: 'x',
          state: TaskState.done,
          output: '/a.pdf',
          params: {'files': '1'},
        ).detail(l10n, format),
        contains('a.pdf'),
      );
    });

    test('a split counts its files', () async {
      final s = _setUp();
      s.container.read(backgroundJobsProvider.notifier).split(
        1,
        'Tez.pdf',
        const [
          SplitFile(name: 'a.pdf', first: 0, last: 1),
          SplitFile(name: 'b.pdf', first: 2, last: 2),
        ],
        '/out',
      );
      await pumpEventQueue();
      expect(s.engine.assembleJobs.single, 'split 2 /out');
      s.engine.endJob(
        const JobUpdate(
          job: 1,
          state: JobState.done,
          outputs: [
            JobOutputFile(path: '/out/a.pdf'),
            JobOutputFile(path: '/out/b.pdf'),
          ],
        ),
      );
      await pumpEventQueue();
      final row = s.container.read(backgroundJobsProvider).rows.single;
      expect(row.params['files'], '2');
      expect(row.output, '/out/a.pdf');
    });
  });

  group('the screens', () {
    Future<void> pump(
      WidgetTester tester,
      ProviderContainer container,
      Widget child,
    ) async {
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: componentHost(
            SizedBox(width: 1000, height: 800, child: child),
            size: const Size(1100, 900),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Combine shows its rows, result and action', (tester) async {
      final s = _setUp();
      s.engine.combinePreviewFound = const CombinePreview(
        files: [
          _ready,
          CombineFileInfo(
            status: CombineInputStatus.ready,
            image: true,
            selected: 1,
            encrypted: true,
          ),
        ],
        pages: 4,
        bytes: 3400000,
      );
      s.container.read(combineFilesProvider.notifier).add([
        '/Kira.pdf',
        '/Tapu.jpg',
      ]);
      await pump(tester, s.container, const CombineTab());
      expect(find.text('Kira.pdf'), findsOneWidget);
      expect(find.text('PDF · 3 pages'), findsOneWidget);
      expect(find.text('Image · converted to 1 page'), findsOneWidget);
      expect(find.text('2 files · 4 pages'), findsOneWidget);
      expect(find.text('RESULT · 4 PAGES'), findsOneWidget);
      expect(find.textContaining('About'), findsOneWidget);
      expect(
        find.text('The new file won’t have this file’s password.'),
        findsOneWidget,
      );
      expect(
        tester.widget<Button>(find.widgetWithText(Button, 'Combine 2 files')),
        isA<Button>().having((b) => b.disabled, 'disabled', isFalse),
      );
    });

    testWidgets('Combine is empty before any file', (tester) async {
      final s = _setUp();
      await pump(tester, s.container, const CombineTab());
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No files yet'), findsOneWidget);
    });

    testWidgets('a locked row asks in place', (tester) async {
      final s = _setUp();
      s.engine.combinePreviewFound = const CombinePreview(
        files: [CombineFileInfo(status: CombineInputStatus.passwordRequired)],
      );
      s.container.read(combineFilesProvider.notifier).add(['/Kilitli.pdf']);
      await pump(tester, s.container, const CombineTab());
      expect(
        find.text('Locked: enter its password to add it.'),
        findsOneWidget,
      );
      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('fits a phone: the list over the result, the range below', (
      tester,
    ) async {
      const phone = Size(375, 812);
      tester.view
        ..physicalSize = phone
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = _setUp();
      addTearDown(s.container.dispose);
      s.container.read(combineFilesProvider.notifier).add(['/a.pdf']);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: s.container,
          child: componentHost(
            const SizedBox(width: 375, height: 812, child: CombineTab()),
            size: phone,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('a Word row is disabled with the future-version reason', (
      tester,
    ) async {
      final s = _setUp();
      s.container.read(combineFilesProvider.notifier).add(['/Rapor.docx']);
      await pump(tester, s.container, const CombineTab());
      expect(find.text('Word or Excel'), findsOneWidget);
      final range = tester.widget<TextField>(
        find
            .descendant(
              of: find.byType(CombineTab),
              matching: find.byType(TextField),
            )
            .first,
      );
      expect(range.disabled, isTrue);
      expect(range.disabledReason, 'Available in a future version');
    });

    testWidgets('dragging a row by its grip reorders', (tester) async {
      final s = _setUp();
      s.container.read(combineFilesProvider.notifier).add(['/a.pdf', '/b.pdf']);
      await pump(tester, s.container, const CombineTab());
      final grips = find.byType(Draggable<int>);
      final gesture = await tester.startGesture(tester.getCenter(grips.first));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveTo(
        tester.getBottomLeft(find.text('b.pdf')) + const Offset(0, 20),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(s.container.read(combineFilesProvider).rows.first.name, 'b.pdf');
    });

    Future<ProviderContainer> app(
      WidgetTester tester,
      ({
        ProviderContainer container,
        FakeEngineService engine,
        FakeFilePickerService picker,
        RecordingFileAccess access,
      })
      s, {
      bool open = false,
    }) async {
      addTearDown(s.container.dispose);
      await pumpFermanApp(
        tester,
        engine: s.engine,
        picker: s.picker,
        fileAccess: s.access,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FmStart)),
      );
      if (open) {
        await container.read(documentOpenerProvider.notifier).open([_path]);
        await tester.pumpAndSettle();
      }
      return container;
    }

    testWidgets('Start opens one Combine tab in Organize; closing empties it', (
      tester,
    ) async {
      final container = await app(tester, _setUp());
      await tester.tap(find.text('Combine files'));
      await tester.pumpAndSettle();
      expect(find.byType(CombineTab), findsOneWidget);
      final list = container.read(shellDocumentsProvider);
      expect(list.documents, hasLength(1));
      expect(list.active!.combine, isTrue);
      expect(list.active!.loading, isFalse);
      expect(container.read(shellModeProvider), FermanMode.organize);
      expect(find.byType(FmSidebar), findsNothing);

      container.read(combineFilesProvider.notifier)
        ..add(['/a.pdf'])
        ..showTab('Combine files');
      expect(container.read(shellDocumentsProvider).documents, hasLength(1));
      expect(container.read(combineFilesProvider).rows, hasLength(1));

      container
          .read(documentOpenerProvider.notifier)
          .close(ShellDocument.combinePath);
      await tester.pumpAndSettle();
      expect(container.read(combineFilesProvider).rows, isEmpty);
      expect(find.byType(FmStart), findsOneWidget);
    });

    testWidgets('the tab closes the sidebar like Organize, and keeps to it', (
      tester,
    ) async {
      final s = _setUp();
      final container = await app(tester, s, open: true);
      final mode = container.read(shellModeProvider.notifier)
        ..select(FermanMode.convert);
      await tester.pumpAndSettle();
      expect(container.read(shellSidebarOpenProvider), isTrue);

      container.read(combineFilesProvider.notifier).showTab('Combine files');
      await tester.pumpAndSettle();
      expect(container.read(shellModeProvider), FermanMode.organize);
      expect(container.read(shellSidebarOpenProvider), isFalse);
      mode.select(FermanMode.view);
      expect(container.read(shellModeProvider), FermanMode.organize);

      container.read(shellDocumentsProvider.notifier).activate(0);
      await tester.pumpAndSettle();
      expect(container.read(shellSidebarOpenProvider), isFalse);
      mode.select(FermanMode.view);
      expect(container.read(shellModeProvider), FermanMode.view);
      expect(container.read(shellSidebarOpenProvider), isTrue);
    });

    testWidgets('a created file opens once written', (tester) async {
      final s = _setUp();
      final container = await app(tester, s);
      final dir = Directory.systemTemp.createTempSync('create');
      addTearDown(() => dir.deleteSync(recursive: true));
      final output = '${dir.path}/Yeni.pdf';
      s.engine.documents[output] = _document;
      await container
          .read(backgroundJobsProvider.notifier)
          .combine(
            const [CombineInput.blank(595, 842)],
            keepForms: true,
            output: output,
            kind: BackgroundJobKind.create,
          );
      await tester.pump();
      s.engine.endJob(
        JobUpdate(
          job: 1,
          state: JobState.done,
          outputs: [JobOutputFile(path: output)],
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(shellDocumentsProvider).active?.path, output);
    });

    testWidgets('Split lists its files and starts a job', (tester) async {
      final s = _setUp();
      s.engine.splitPreviewFound = const SplitPreview(
        files: [
          SplitFile(name: 'Tez — a.pdf', first: 0, last: 1, bytes: 400000),
          SplitFile(name: 'Tez — b.pdf', first: 2, last: 2, bytes: 600000),
        ],
        bookmarks: 1,
      );
      final container = await app(tester, s, open: true);
      container.read(shellModeProvider.notifier).select(FermanMode.organize);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Split'));
      await tester.pumpAndSettle();
      expect(find.byType(SplitDialog), findsOneWidget);
      expect(find.text('2 files'), findsOneWidget);
      expect(find.text('Tez — a.pdf'), findsOneWidget);
      expect(find.textContaining('i–ii · 2 pages'), findsOneWidget);
      expect(find.textContaining('1 · 1 page'), findsOneWidget);
      await tester.tap(find.text('Split into 2 files'));
      await tester.pump();
      await tester.pump();
      expect(s.engine.assembleJobs.single, 'split 2 /Users/elif');
      expect(container.read(organizeDialogProvider), isNull);
      expect(
        container.read(backgroundJobsProvider).rows.single.kind,
        BackgroundJobKind.split,
      );
    });

    testWidgets('Split with no bookmarks starts on Every few pages', (
      tester,
    ) async {
      final s = _setUp();
      s.engine.splitPreviewFound = const SplitPreview(
        files: [SplitFile(name: 'a.pdf', first: 0, last: 2)],
      );
      final container = await app(tester, s, open: true);
      container.read(organizeDialogProvider.notifier).show(const SplitDialog());
      await tester.pumpAndSettle();
      expect(find.text('This document has no bookmarks.'), findsOneWidget);
      expect(find.text('Pages per file'), findsOneWidget);
    });

    testWidgets('Split under the sandbox asks for the folder', (tester) async {
      final s = _setUp();
      s.access.stagingDirectory = '/tmp/staging';
      s.picker.folder = '/Users/elif/Bölünmüş';
      s.engine.splitPreviewFound = const SplitPreview(
        files: [SplitFile(name: 'a.pdf', first: 0, last: 2)],
        bookmarks: 1,
      );
      final container = await app(tester, s, open: true);
      container.read(organizeDialogProvider.notifier).show(const SplitDialog());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Split into 1 file'));
      await tester.pump();
      await tester.pump();
      expect(s.engine.assembleJobs.single, 'split 1 /Users/elif/Bölünmüş');
    });

    testWidgets('Create PDF: the clipboard is disabled, files reach the tab', (
      tester,
    ) async {
      final s = _setUp();
      s.picker.picked = ['/a.pdf'];
      final container = await app(tester, s);
      await tester.tap(find.text('Create PDF'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Button>(find.widgetWithText(Button, 'From the clipboard'))
            .disabledReason,
        'Available in a future version',
      );
      await tester.tap(find.text('From files…'));
      await tester.pumpAndSettle();
      final files = container.read(combineFilesProvider);
      expect(files.rows.single.name, 'a.pdf');
      expect(files.opensResult, isTrue);
      expect(container.read(organizeDialogProvider), isNull);
      expect(find.byType(CombineTab), findsOneWidget);
    });

    testWidgets("New blank PDF writes one page on the region's paper", (
      tester,
    ) async {
      final s = _setUp();
      final dir = Directory.systemTemp.createTempSync('blank');
      addTearDown(() => dir.deleteSync(recursive: true));
      s.picker.saveTo = '${dir.path}/Adsız.pdf';
      await app(tester, s);
      await tester.tap(find.text('New blank PDF'));
      await tester.pumpAndSettle();
      expect(s.picker.saves, ['Untitled.pdf']);
      expect(s.engine.assembleJobs.single, startsWith('combine 1 '));
    });
  });
}
