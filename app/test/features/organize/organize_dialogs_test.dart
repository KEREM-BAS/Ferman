import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/crop_overlay.dart';
import 'package:ferman/features/organize/crop_panel.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_labels_dialog.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';
import '../shell/shell_host.dart';

const String _path = '/Belgeler/Tez.pdf';

const List<PageInfo> _pages = [
  PageInfo(width: 595, height: 842, handle: 1),
  PageInfo(width: 595, height: 842, handle: 2),
  PageInfo(width: 595, height: 842, handle: 3),
];

void main() {
  late FakeEngineService engine;
  late FakeFilePickerService picker;

  /// The shell in Organize on [_path], its Organize tools showing.
  Future<ProviderContainer> open(WidgetTester tester) async {
    engine = FakeEngineService(
      documents: {_path: const OpenedDocument(id: 1, pages: _pages)},
    );
    picker = FakeFilePickerService(picked: [_path]);
    await pumpFermanApp(
      tester,
      engine: engine,
      home: '/home/elif',
      picker: picker,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FmStart)),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    picker.picked = [];
    container.read(shellModeProvider.notifier).select(FermanMode.organize);
    await settle(tester);
    return container;
  }

  int pageCount(ProviderContainer container) =>
      container.read(shellDocumentsProvider).active!.document!.pages.length;

  Finder tool(String label) => find.widgetWithText(ToolButton, label);

  testWidgets('Insert blank page inserts as one step', (tester) async {
    final container = await open(tester);
    await tester.tap(tool('Insert'));
    await settle(tester);
    await tester.tap(find.text('Blank page'));
    await settle(tester);
    expect(find.text('Insert blank page'), findsOneWidget);
    await tester.tap(find.text('Insert 1 page'));
    await settle(tester);
    expect(pageCount(container), 4);
    expect(container.read(organizeDialogProvider), isNull);
  });

  testWidgets('the scanner stays disabled in Insert', (tester) async {
    await open(tester);
    await tester.tap(tool('Insert'));
    await settle(tester);
    final row = tester
        .widget<Menu>(find.byType(Menu))
        .items
        .firstWhere((item) => item.id == 'scan');
    expect(row.disabled, isTrue);
    expect(row.disabledReason, futureVersion);
  });

  testWidgets('Insert from a file waits for a file it can read', (
    tester,
  ) async {
    final container = await open(tester);
    await tester.tap(tool('Insert'));
    await settle(tester);
    await tester.tap(find.text('Pages from a file…'));
    await settle(tester);
    Button primary() =>
        tester.widget<Button>(find.widgetWithText(Button, 'Insert pages'));
    expect(primary().onPressed, isNull);

    picker.picked = ['/Belgeler/Ek.pdf'];
    engine.combinePreviewFound = const CombinePreview(
      files: [CombineFileInfo(status: CombineInputStatus.passwordRequired)],
    );
    await tester.tap(find.text('Choose file…'));
    await settle(tester);
    expect(find.text('Password'), findsOneWidget);
    expect(primary().onPressed, isNull);

    engine.combinePreviewFound = const CombinePreview(
      files: [CombineFileInfo(status: CombineInputStatus.ready, pages: 2)],
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'parola',
    );
    await tester.tap(find.text('Unlock'));
    await settle(tester);
    expect(primary().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(Button, 'Insert pages'));
    await settle(tester);
    expect(engine.assembleJobs.single, startsWith('insert'));
    final row = container.read(backgroundJobsProvider).rows.single;
    expect(row.kind, BackgroundJobKind.insertPages);
    expect(row.name, 'Ek.pdf');
    expect(container.read(organizeDialogProvider), isNull);
  });

  testWidgets('a job that read its file commits the change', (tester) async {
    final container = await open(tester);
    container
        .read(backgroundJobsProvider.notifier)
        .pagesFromFile(
          BackgroundJobKind.insertPages,
          1,
          'Ek.pdf',
          engine.insertPagesJob(
            1,
            path: '/Belgeler/Ek.pdf',
            after: 1,
            paper: ImagePaper.a4,
            name: 'Insert',
          ),
        );
    await tester.pump();
    engine.endJob(const JobUpdate(job: 1, state: JobState.done));
    await settle(tester);
    expect(pageCount(container), greaterThan(_pages.length));
    expect(
      container.read(backgroundJobsProvider).rows.last.state,
      TaskState.done,
    );
  });

  testWidgets('Replace names its pages and warns of a different count', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(tool('Replace'));
    await settle(tester);
    expect(find.text('Replace 1 page'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Pages in this document'),
      '1-3',
    );
    await tester.pump();
    expect(find.text('Replace 3 pages'), findsOneWidget);

    picker.picked = ['/Belgeler/Ek.pdf'];
    engine.combinePreviewFound = const CombinePreview(
      files: [CombineFileInfo(status: CombineInputStatus.ready, pages: 2)],
    );
    await tester.tap(find.text('Choose file…'));
    await settle(tester);
    expect(find.textContaining('fewer pages'), findsOneWidget);

    await tester.tap(find.text('Replace 3 pages'));
    await settle(tester);
    expect(engine.assembleJobs.single, 'replace 3 /Belgeler/Ek.pdf');
  });

  testWidgets('Extract asks where, and a cancelled panel keeps the dialog', (
    tester,
  ) async {
    final container = await open(tester);
    await tester.tap(tool('Extract'));
    await settle(tester);
    await tester.tap(find.text('Extract…'));
    await settle(tester);
    expect(picker.saves.single, 'Tez pages 1.pdf');
    expect(container.read(organizeDialogProvider), isNotNull);
    expect(engine.assembleJobs, isEmpty);

    picker.saveTo = '/Belgeler/Parça.pdf';
    await tester.tap(find.text('Extract…'));
    await settle(tester);
    expect(engine.assembleJobs.single, 'extract 1 /Belgeler/Parça.pdf');
    expect(container.read(organizeDialogProvider), isNull);
  });

  testWidgets('one file per page takes the plan for its pages', (tester) async {
    await open(tester);
    await tester.tap(tool('Extract'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '1, 3');
    await tester.tap(find.text('One file per page'));
    await settle(tester);
    picker.folder = '/Belgeler/Parçalar';
    engine.splitPreviewFound = const SplitPreview(
      files: [
        SplitFile(name: 'a.pdf', first: 0, last: 0),
        SplitFile(name: 'b.pdf', first: 1, last: 1),
        SplitFile(name: 'c.pdf', first: 2, last: 2),
      ],
    );
    await tester.tap(find.text('Extract…'));
    await settle(tester);
    expect(engine.assembleJobs.single, 'split 2 /Belgeler/Parçalar');
  });

  testWidgets('Extract cannot delete every page', (tester) async {
    await open(tester);
    await tester.tap(tool('Extract'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '1-3');
    await tester.pump();
    final delete = tester.widget<Checkbox>(
      find.widgetWithText(Checkbox, 'Delete these pages afterwards'),
    );
    expect(delete.disabled, isTrue);
  });

  testWidgets('Page labels loads, previews and applies', (tester) async {
    final container = await open(tester);
    await tester.tap(tool('Page labels'));
    await settle(tester);
    expect(find.byType(PageLabelsDialog), findsOneWidget);
    expect(find.textContaining('1 2 3'), findsOneWidget);
    final print = tester.widget<Checkbox>(
      find.widgetWithText(Checkbox, 'Also print the numbers on the pages'),
    );
    expect(print.disabled, isTrue);
    expect(print.disabledReason, futureVersion);

    await tester.enterText(find.byType(TextField).first, '1–2');
    await tester.pump();
    expect(find.textContaining('Page 3 is in no range'), findsOneWidget);
    expect(
      tester
          .widget<Button>(find.widgetWithText(Button, 'Apply labels'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).first, '1–3');
    await tester.pump();
    await tester.tap(find.text('Apply labels'));
    await settle(tester);
    final ranges = await engine.pageLabelRanges(1);
    expect(ranges.single.start, 0);
    expect(container.read(organizeDialogProvider), isNull);
  });

  group('the crop tool', () {
    testWidgets('opens with its overlay and panel, and Cancel leaves', (
      tester,
    ) async {
      final container = await open(tester);
      expect(find.byType(CropOverlay), findsNothing);
      await tester.tap(tool('Crop'));
      await settle(tester);
      expect(find.byType(CropOverlay), findsOneWidget);
      expect(find.byType(CropPanel), findsOneWidget);
      expect(find.text('Crop and page size'), findsOneWidget);
      // Nothing to do yet.
      expect(
        tester
            .widget<Button>(find.widgetWithText(Button, 'Crop 3 pages'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await settle(tester);
      expect(container.read(organizeCropProvider), isNull);
      expect(find.byType(CropOverlay), findsNothing);
    });

    testWidgets('Esc closes it', (tester) async {
      final container = await open(tester);
      await tester.tap(tool('Crop'));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(container.read(organizeCropProvider), isNull);
    });

    testWidgets('Remove white margins crops each page with Undo', (
      tester,
    ) async {
      final container = await open(tester);
      await tester.tap(tool('Crop'));
      await settle(tester);
      await tester.tap(find.text('Remove white margins'));
      await settle(tester);
      expect(container.read(organizeCropProvider)!.detected, hasLength(3));
      await tester.tap(find.text('Crop 3 pages'));
      await settle(tester);
      final page = container
          .read(shellDocumentsProvider)
          .active!
          .document!
          .pages
          .first;
      // FakeEngineService.whiteMarginsFound.
      expect(page.width, 595 - 25 - 25);
      expect(page.height, 842 - 20 - 30);
      expect(find.text('3 pages cropped'), findsOneWidget);
      expect(find.textContaining('hidden, not removed'), findsOneWidget);
      expect(container.read(organizeCropProvider), isNull);
    });

    testWidgets('no content says so and crops nothing', (tester) async {
      final container = await open(tester);
      engine.whiteMarginsFound = null;
      await tester.tap(tool('Crop'));
      await settle(tester);
      await tester.tap(find.text('Remove white margins'));
      await settle(tester);
      expect(find.textContaining('no content'), findsOneWidget);
      expect(container.read(organizeCropProvider)!.detected, isNull);
    });

    testWidgets('a corner handle moves two margins', (tester) async {
      final container = await open(tester);
      await tester.tap(tool('Crop'));
      await settle(tester);
      final overlay = find.byType(CropOverlay);
      final handles = find.descendant(
        of: overlay,
        matching: find.byType(GestureDetector),
      );
      // Top left comes first.
      await tester.drag(handles.first, const Offset(40, 30));
      await settle(tester);
      final margins = container.read(organizeCropProvider)!.margins;
      expect(margins.left, greaterThan(0));
      expect(margins.top, greaterThan(0));
      expect(margins.right, 0);
      expect(margins.bottom, 0);
    });
  });
}
