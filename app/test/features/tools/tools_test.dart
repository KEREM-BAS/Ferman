import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/tools/print_dialog.dart';
import 'package:ferman/features/tools/tools_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations_en.dart';
import 'package:ferman/l10n/region.dart';
import 'package:ferman/platform/print_service.dart';
import 'package:flutter/services.dart';
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

/// The system's printing as a test sees it.
final class _Printer implements PrintService {
  /// What `begin` answers: the system dialog's Print or Cancel.
  bool accept = true;

  /// What each call asked, in order: "begin 2 fit", "page 0", "end", "abort".
  final List<String> calls = [];

  @override
  Future<bool> begin({
    required String name,
    required int pages,
    required bool fit,
  }) async {
    calls.add('begin $pages ${fit ? 'fit' : 'actual'}');
    return accept;
  }

  @override
  Future<bool> page(PrintPage page) async {
    calls.add('page ${page.index}');
    return true;
  }

  @override
  Future<void> end() async => calls.add('end');

  @override
  Future<void> abort() async => calls.add('abort');
}

void main() {
  late FakeEngineService engine;
  late FakeFilePickerService picker;
  late _Printer printer;

  /// The shell on [_path] in Tools; [prepare] sets the engine up first.
  Future<ProviderContainer> open(
    WidgetTester tester, {
    void Function(FakeEngineService)? prepare,
  }) async {
    engine = FakeEngineService(
      documents: {_path: const OpenedDocument(id: 1, pages: _pages)},
    );
    prepare?.call(engine);
    picker = FakeFilePickerService(picked: [_path]);
    printer = _Printer();
    await pumpFermanApp(
      tester,
      engine: engine,
      home: '/home/elif',
      picker: picker,
      overrides: [printServiceProvider.overrideWithValue(printer)],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FmStart)),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    picker.picked = [];
    container.read(shellModeProvider.notifier).select(FermanMode.tools);
    await settle(tester);
    return container;
  }

  Finder tool(String label) => find.widgetWithText(ToolButton, label);

  group('Compress (a9-1)', () {
    testWidgets('the presets show their sizes, and the chosen one runs as a '
        'job', (tester) async {
      final container = await open(tester);
      await tester.tap(tool('Compress'));
      await settle(tester);
      expect(container.read(toolsPanelProvider), ToolsPanel.compress);
      for (final text in ['High quality', 'Balanced', 'Smallest', 'Custom…']) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('What Balanced does'), findsOneWidget);

      await tester.tap(find.text('Smallest'));
      await settle(tester);
      expect(find.text('What Smallest does'), findsOneWidget);
      picker.saveTo = '/Belgeler/Tez, compressed.pdf';
      await tester.tap(find.text('Compress and save as…'));
      await settle(tester);
      expect(engine.compressJobs, ['smallest /Belgeler/Tez, compressed.pdf']);
      final row = container.read(backgroundJobsProvider).rows.single;
      expect(row.kind, BackgroundJobKind.compress);
      expect(row.name, 'Tez.pdf');
    });

    testWidgets('a signed document says so first, and passes the warning', (
      tester,
    ) async {
      final container = await open(tester);
      engine
        ..signed.add(1)
        ..compressAnalysisFound = const CompressAnalysis(
          before: 1000,
          estimates: [
            CompressEstimate(preset: CompressPreset.balanced, after: 600),
          ],
          signed: true,
        );
      await tester.tap(tool('Compress'));
      await settle(tester);
      expect(find.text('This document is signed'), findsOneWidget);
      picker.saveTo = '/Belgeler/Küçük.pdf';
      await tester.tap(find.text('Compress and save as…'));
      await settle(tester);
      // The fake refuses a signed document without the warning.
      expect(engine.compressJobs, ['balanced /Belgeler/Küçük.pdf']);
      expect(
        container.read(backgroundJobsProvider).rows.single.state,
        TaskState.running,
      );
    });

    test('a done row says the sizes, or that nothing was written', () {
      final l10n = AppLocalizationsEn();
      final format = RegionFormat.forRegion(Region.turkiye);
      const row = BackgroundJob(
        id: 1,
        kind: BackgroundJobKind.compress,
        name: 'Tez.pdf',
        state: TaskState.done,
        params: {'before': '2000000', 'after': '500000', 'written': 'true'},
      );
      expect(row.title(l10n), contains('Compressed'));
      expect(
        row.detail(l10n, format),
        '${format.fileSize(2000000)} → ${format.fileSize(500000)}',
      );
      final kept = row.copyWith(
        params: {'before': '2000', 'after': '2400', 'written': 'false'},
      );
      expect(kept.detail(l10n, format), l10n.jobCompressNotSmaller);
    });
  });

  group('Print (a9-6)', () {
    testWidgets('the chosen pages go through the system dialog one by one', (
      tester,
    ) async {
      final container = await open(tester);
      await tester.tap(tool('Print'));
      await settle(tester);
      expect(container.read(organizeDialogProvider), isA<PrintDialog>());
      // The system dialog sets these (question 3).
      for (final label in ['Printer', 'Both sides']) {
        final select = tester.widget<Select<String>>(
          find.widgetWithText(Select<String>, label),
        );
        expect(select.disabled, isTrue, reason: label);
        expect(select.disabledReason, futureVersion, reason: label);
      }
      await tester.enterText(find.widgetWithText(TextField, 'Pages'), '2–3');
      await settle(tester);
      await tester.tap(find.widgetWithText(Button, 'Print'));
      await settle(tester);
      expect(container.read(organizeDialogProvider), isNull);
      expect(printer.calls, ['begin 2 fit', 'page 0', 'page 1', 'end']);
      final (document, pages, comments) = engine.prints.last;
      expect((document, comments), (1, true));
      expect(pages, [2, 3]);
      expect(
        container.read(toastNoticesProvider).single.tone,
        ToastTone.success,
      );
    });

    testWidgets('a cancelled system dialog prints nothing', (tester) async {
      final container = await open(tester);
      printer.accept = false;
      await tester.tap(tool('Print'));
      await settle(tester);
      final before = engine.prints.length;
      await tester.tap(find.text('Use system dialog…'));
      await settle(tester);
      expect(printer.calls, ['begin 3 fit']);
      expect(engine.prints, hasLength(before));
      expect(container.read(toastNoticesProvider), isEmpty);
    });

    testWidgets('a document that forbids printing says why (B121)', (
      tester,
    ) async {
      await open(
        tester,
        prepare: (engine) =>
            engine.opGates[(1, DocumentOp.print)] = OpGate.forbidden,
      );
      final print = tester.widget<ToolButton>(tool('Print'));
      expect(print.disabled, isTrue);
      expect(print.disabledReason, 'The author doesn’t allow printing');
    });

    testWidgets('a refusal on the way drops the print and says so', (
      tester,
    ) async {
      final container = await open(tester);
      await tester.tap(tool('Print'));
      await settle(tester);
      engine.printForbidden = true;
      await tester.tap(find.widgetWithText(Button, 'Print'));
      await settle(tester);
      expect(printer.calls, ['begin 3 fit', 'abort']);
      expect(
        container.read(toastNoticesProvider).single.tone,
        ToastTone.danger,
      );
    });
  });

  group('Save as (B138)', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
    }

    testWidgets('without comments the file is a copy, never its own', (
      tester,
    ) async {
      await open(tester);
      await openSheet(tester);
      expect(
        find.textContaining('stay in the file and can be recovered'),
        findsOneWidget,
      );
      await tester.tap(find.text('Include comments and markup'));
      await settle(tester);
      await tester.tap(find.widgetWithText(Button, 'Save').last);
      await settle(tester);
      expect(find.textContaining('already there'), findsOneWidget);
      expect(engine.saveOptions, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextField, 'File name'),
        'Tez yorumsuz',
      );
      await tester.tap(find.widgetWithText(Button, 'Save').last);
      await settle(tester);
      expect(engine.copies, [(1, '/Belgeler/Tez yorumsuz.pdf')]);
      expect(engine.saveOptions.single.includeComments, isFalse);
    });

    testWidgets('Remove edit history rewrites the file it saves as', (
      tester,
    ) async {
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.text('Remove edit history from the file'));
      await settle(tester);
      expect(find.textContaining('without earlier revisions'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'File name'),
        'Tez temiz',
      );
      await tester.tap(find.widgetWithText(Button, 'Save').last);
      await settle(tester);
      expect(engine.saves.last, (1, '/Belgeler/Tez temiz.pdf'));
      expect(engine.saveOptions.single.removeHistory, isTrue);
    });
  });

  group('Version history (a9-8)', () {
    testWidgets('a version previews read-only and restores after asking', (
      tester,
    ) async {
      final container = await open(tester);
      final today = DateTime.now().millisecondsSinceEpoch;
      engine
        ..versionLists[1] = [
          VersionInfo(
            id: 5,
            kind: VersionKind.saved,
            time: today,
            size: 900,
            edits: 3,
            names: const ['Madde 4', 'Madde 6'],
          ),
          VersionInfo(id: 2, kind: VersionKind.opened, time: today, size: 800),
        ]
        ..versionDocuments[5] = const OpenedDocument(id: 9, pages: _pages);
      await tester.tap(tool('Version history'));
      await settle(tester);
      expect(find.text('2 versions'), findsOneWidget);
      expect(find.text('3 edits · Madde 4, Madde 6'), findsOneWidget);
      expect(find.text('The file as it was opened'), findsOneWidget);

      await tester.tap(find.text('Saved'));
      await settle(tester);
      expect(find.text('Back to current'), findsOneWidget);
      expect(container.read(versionPreviewProvider)?.document?.id, 9);
      final compare = tester.widget<Button>(
        find.widgetWithText(Button, 'Compare with current'),
      );
      expect(compare.disabledReason, futureVersion);

      await tester.tap(find.widgetWithText(Button, 'Restore…'));
      await settle(tester);
      expect(engine.restores, isEmpty);
      await tester.tap(find.widgetWithText(Button, 'Restore'));
      await settle(tester);
      expect(engine.restores, [(1, 5)]);
      expect(container.read(versionPreviewProvider), isNull);
    });

    testWidgets('no versions yet says so', (tester) async {
      await open(tester);
      await tester.tap(tool('Version history'));
      await settle(tester);
      expect(
        find.text('No versions yet. Each save keeps one.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Kept for 30 days on this device. Change in Settings › Editing.',
        ),
        findsOneWidget,
      );
    });
  });
}
