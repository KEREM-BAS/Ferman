import 'dart:io';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/save/save_as_sheet.dart';
import 'package:ferman/features/save/save_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../../helpers/recording_file_access.dart';
import '../onboarding/ferman_app_harness.dart';
import '../shell/shell_host.dart' show futureVersion;

const OpenedDocument kira = OpenedDocument(
  id: 9,
  pages: [PageInfo(width: 595, height: 842)],
);

const OpenedDocument repaired = OpenedDocument(
  id: 4,
  pages: [PageInfo(width: 595, height: 842)],
  readOnly: ReadOnlyReason.repaired,
  repairs: [RepairFix(kind: RepairKind.crossReferenceRebuilt, count: 3)],
);

/// [text] in the isolates `bidiIsolate` puts around a name.
String iso(String text) => '\u2068$text\u2069';

void main() {
  late FakeEngineService engine;
  late FakeFilePickerService picker;
  late ProviderContainer container;

  Future<void> pumps(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The app with [path] opened as [document], [state] as its save state.
  Future<void> pumpSaved(
    WidgetTester tester, {
    SaveState state = SaveState.unsaved,
    String path = '/docs/kira.pdf',
    OpenedDocument document = kira,
    FileAccess fileAccess = const NoFileAccess(),
  }) async {
    engine = FakeEngineService(
      documents: {
        path: document,
        '/docs/kira-fixed.pdf': const OpenedDocument(
          id: 12,
          pages: [PageInfo(width: 595, height: 842)],
        ),
      },
    );
    picker = FakeFilePickerService(picked: [path]);
    await pumpFermanApp(
      tester,
      engine: engine,
      picker: picker,
      fileAccess: fileAccess,
    );
    container = ProviderScope.containerOf(tester.element(find.byType(FmStart)));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    container
        .read(shellDocumentsProvider.notifier)
        .replace(
          path,
          container.read(shellDocumentsProvider).active!.withSave(state),
        );
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester _) => container;

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  /// The sheet's Save button.
  Finder sheetSave() => find.descendant(
    of: find.byType(SaveAsSheet),
    matching: find.widgetWithText(Button, 'Save'),
  );

  ShellDocument tab(WidgetTester tester) =>
      containerOf(tester).read(shellDocumentsProvider).active!;

  Future<void> control(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumps(tester);
  }

  testWidgets('a save on a full disk shows a11-7; Try again saves, and the '
      'document stays unsaved until then (G41)', (tester) async {
    await pumpSaved(tester);
    engine.failNextSave(EngineErrorKind.diskFull);
    await control(tester, LogicalKeyboardKey.keyS);
    expect(find.text('Couldn’t save “${iso('kira.pdf')}”'), findsOne);
    expect(
      find.text(
        'The disk is full. Free some space or save somewhere else. Your '
        'edits are kept.',
      ),
      findsOne,
    );
    expect(find.text('Save somewhere else…'), findsOne);
    expect(tab(tester).saveState, SaveState.error);
    expect(engine.saves, isEmpty);

    await tester.tap(find.text('Try again'));
    await pumps(tester);
    expect(find.byType(SaveFailureDialog), findsNothing);
    expect(engine.saves, [(kira.id, null)]);
    expect(tab(tester).saveState, SaveState.saved);
  });

  group('under the macOS App Sandbox (ADR 0008)', () {
    late RecordingFileAccess access;

    Future<void> pumpStaged(
      WidgetTester tester, {
      OpenedDocument document = kira,
    }) async {
      access = RecordingFileAccess()..stagingDirectory = '/replacement';
      await pumpSaved(tester, fileAccess: access, document: document);
    }

    testWidgets('Save stages the file, swaps it in, then counts as saved', (
      tester,
    ) async {
      await pumpStaged(tester);
      await control(tester, LogicalKeyboardKey.keyS);
      expect(access.swapped, [('/replacement/staged.pdf', '/docs/kira.pdf')]);
      expect(engine.saves, [(kira.id, null)]);
      expect(tab(tester).saveState, SaveState.saved);
    });

    testWidgets('a failed swap keeps the edits and shows the failure; Try '
        'again saves', (tester) async {
      await pumpStaged(tester);
      access.swapFailure = SwapFailure.permission;
      await control(tester, LogicalKeyboardKey.keyS);
      expect(engine.saves, isEmpty, reason: 'not recorded by the engine');
      expect(tab(tester).saveState, SaveState.error);
      expect(find.byType(SaveFailureDialog), findsOne);
      expect(find.textContaining('You don’t have permission'), findsOne);
      expect(find.text('Save as…'), findsOne);

      access.swapFailure = null;
      await tester.tap(find.text('Try again'));
      await pumps(tester);
      expect(engine.saves, [(kira.id, null)]);
      expect(tab(tester).saveState, SaveState.saved);
    });

    testWidgets('a save the engine refuses leaves no staging directory', (
      tester,
    ) async {
      await pumpStaged(tester);
      engine.saveFailure = const EngineException(
        kind: EngineErrorKind.fileChangedOnDisk,
        messageKey: 'errorFileWrite',
      );
      await control(tester, LogicalKeyboardKey.keyS);
      expect(access.swapped, isEmpty);
      expect(access.discarded, ['/replacement']);
      expect(tab(tester).unsaved, isTrue);
    });

    testWidgets('a Save right behind a Save as swaps over the new file', (
      tester,
    ) async {
      await pumpStaged(tester);
      final saver = container.read(documentSaverProvider.notifier)..openSheet();
      final saveAs = saver.saveTo('/docs/other.pdf', copy: false);
      final save = saver.save();
      await Future.wait([saveAs, save]);
      await pumps(tester);
      expect(access.swapped.map((swap) => swap.$2), [
        '/docs/other.pdf',
        '/docs/other.pdf',
      ]);
    });

    testWidgets('every failed swap has its message', (tester) async {
      await pumpStaged(tester);
      for (final (failure, text) in [
        (SwapFailure.diskFull, 'The disk is full'),
        (SwapFailure.locked, 'Another app has the file open'),
        (SwapFailure.volumeGone, 'no longer connected'),
        (SwapFailure.other, 'couldn’t put it in place'),
      ]) {
        access.swapFailure = failure;
        await control(tester, LogicalKeyboardKey.keyS);
        expect(find.textContaining(text), findsOne, reason: '$failure');
        container.read(documentSaverProvider.notifier).dismissFailure();
        await pumps(tester);
      }
    });

    testWidgets('a failed swap says when no recovery copy exists', (
      tester,
    ) async {
      await pumpStaged(tester);
      engine.recoveryWriteFailed = true;
      access.swapFailure = SwapFailure.other;
      await control(tester, LogicalKeyboardKey.keyS);
      expect(find.textContaining('No recovery copy exists'), findsOne);
    });

    testWidgets('Save as, a copy and Optimize and clean go the same way', (
      tester,
    ) async {
      await pumpStaged(tester);
      final saver = container.read(documentSaverProvider.notifier)..openSheet();
      await saver.saveTo('/docs/other.pdf', copy: false);
      await pumps(tester);
      expect(engine.saves, [(kira.id, '/docs/other.pdf')]);
      expect(tab(tester).path, '/docs/other.pdf');

      saver.openSheet(copy: true);
      await saver.saveTo('/docs/copy.pdf', copy: true);
      await pumps(tester);
      expect(engine.copies, [(kira.id, '/docs/copy.pdf')]);

      await saver.optimizeAndClean();
      await pumps(tester);
      expect(engine.optimized, [kira.id]);
      expect(access.swapped.map((swap) => swap.$2), [
        '/docs/other.pdf',
        '/docs/copy.pdf',
        '/docs/other.pdf',
      ]);
    });

    testWidgets('a failed Save as stays on the old file', (tester) async {
      await pumpStaged(tester);
      access.swapFailure = SwapFailure.permission;
      final saver = container.read(documentSaverProvider.notifier)..openSheet();
      await saver.saveTo('/docs/other.pdf', copy: false);
      await pumps(tester);
      expect(tab(tester).path, '/docs/kira.pdf');
      expect(engine.saves, isEmpty);
      expect(find.byType(SaveFailureDialog), findsOne);
    });

    testWidgets('the repaired copy goes the same way', (tester) async {
      await pumpStaged(tester, document: repaired);
      picker.saveTo = '/docs/kira-fixed.pdf';
      final saver = container.read(documentSaverProvider.notifier);
      await saver.saveRepairedCopy(tab(tester));
      await pumps(tester);
      expect(engine.repairedCopies, [
        (repaired.id, '/docs/kira-fixed.pdf', false),
      ]);
      expect(access.swapped.single.$2, '/docs/kira-fixed.pdf');
    });

    test("the channel's reply names the failure", () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('test/swap');
      Object? reply;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(channel, (_) async => reply);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const files = PlatformFileAccess(channel);
      Future<SwapFailure?> swap() => files.swapIn('/s', '/p');
      reply = true;
      expect(await swap(), isNull);
      reply = 'locked';
      expect(await swap(), SwapFailure.locked);
      reply = false;
      expect(await swap(), SwapFailure.other);
      reply = 'nonsense';
      expect(await swap(), SwapFailure.other);
    });
  });

  testWidgets('a failure says when no recovery copy exists (ARCHITECTURE '
      '§7.8)', (tester) async {
    await pumpSaved(tester);
    engine.saveFailure = const EngineException(
      kind: EngineErrorKind.diskFull,
      messageKey: 'errorFileWrite',
      offersSaveAs: true,
      noRecoveryCopy: true,
    );
    await control(tester, LogicalKeyboardKey.keyS);
    expect(
      find.text(
        'The disk is full. Free some space or save somewhere else. Your '
        'edits are kept. No recovery copy exists: Ferman couldn’t write one '
        'either, so until you save, these edits are only in this window.',
      ),
      findsOne,
    );
  });

  testWidgets('each failure of a11-7d says what happened; closing the dialog '
      'leaves the f4 toast, whose Save as… opens the sheet', (tester) async {
    await pumpSaved(tester);
    for (final (kind, text) in [
      (EngineErrorKind.permissionDenied, 'You don’t have permission'),
      (EngineErrorKind.fileLocked, 'Another app has the file open'),
      (EngineErrorKind.renameFailed, 'Ferman wrote your changes'),
      (EngineErrorKind.volumeGone, 'The drive with this file'),
      (EngineErrorKind.hardLinked, 'This file has other links'),
      (EngineErrorKind.notOwner, 'This file belongs to someone else'),
    ]) {
      engine.failNextSave(kind);
      await control(tester, LogicalKeyboardKey.keyS);
      final dialog = tester.widget<Dialog>(
        find.descendant(
          of: find.byType(SaveFailureDialog),
          matching: find.byType(Dialog),
        ),
      );
      expect(dialog.description, startsWith(text), reason: kind.name);
      expect(dialog.description, contains('edits are kept.'));
      expect(find.text('Save as…'), findsOne);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await pumps(tester);
      expect(find.byType(SaveFailureDialog), findsNothing);
      expect(find.byType(SaveFailureToast), findsOne);
    }
    expect(find.text('Couldn’t save'), findsWidgets);
    expect(
      find.text('Your edits are kept. Try again, or save somewhere else.'),
      findsOne,
    );
    await tester.tap(find.text('Save as…'));
    await pumps(tester);
    expect(find.byType(SaveFailureToast), findsNothing);
    expect(find.byType(SaveAsSheet), findsOne);
  });

  testWidgets('Save as checks the name, adds .pdf, writes in the '
      "document's folder, and the tab shows the new file", (tester) async {
    await pumpSaved(tester);
    await control(tester, LogicalKeyboardKey.keyS, shift: true);
    expect(find.byType(SaveAsSheet), findsOne);
    expect(find.text('Save as'), findsOne);
    // The formats: PDF works, the others wait (G111).
    final radios = tester.widgetList<Radio<int>>(find.byType(Radio<int>));
    expect([for (final r in radios) r.disabled], [false, true, true]);
    expect(
      [for (final r in radios) r.disabledReason],
      [null, futureVersion, futureVersion],
    );
    final field = find.byType(EditableText);
    expect(tester.widget<EditableText>(field).controller.text, 'kira.pdf');

    await tester.enterText(field, 'a/b');
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(find.text(r'A file name can’t contain / or \.'), findsOne);
    await tester.enterText(field, '  ');
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(find.text('Enter a file name.'), findsOne);
    expect(engine.saves, isEmpty);

    await tester.enterText(field, 'Kira son');
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(find.byType(SaveAsSheet), findsNothing);
    expect(engine.saves, [(kira.id, '/docs/Kira son.pdf')]);
    expect(tab(tester).path, '/docs/Kira son.pdf');
    expect(tab(tester).name, 'Kira son.pdf');
    expect(tab(tester).saveState, SaveState.saved);
  });

  testWidgets('Save as never replaces a file unasked in a drawn folder', (
    tester,
  ) async {
    final folder = Directory.systemTemp.createTempSync('ferman_save');
    addTearDown(() => folder.deleteSync(recursive: true));
    File('${folder.path}/taken.pdf').writeAsStringSync('%PDF-1.7');
    await pumpSaved(tester, path: '${folder.path}/kira.pdf');
    await control(tester, LogicalKeyboardKey.keyS, shift: true);
    await tester.enterText(find.byType(EditableText), 'taken');
    await tester.runAsync(() async {
      await tester.tap(sheetSave());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumps(tester);
    expect(find.textContaining('A file with this name is already'), findsOne);
    expect(engine.saves, isEmpty);
  }, skip: Platform.isWindows);

  testWidgets('Other location… hands off to the system save panel; the '
      'sheet shows its folder, and Save as a copy writes there', (
    tester,
  ) async {
    await pumpSaved(tester);
    picker.saveTo = '/elsewhere/Projeler/2026/kopya.pdf';
    await control(tester, LogicalKeyboardKey.keyS, shift: true);
    await tester.tap(find.text('docs'));
    await pumps(tester);
    await tester.tap(find.text('Other location…').last);
    await pumps(tester);
    expect(picker.saves, ['kira.pdf']);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'kopya.pdf',
    );
    expect(find.text('Projeler › 2026'), findsOne);
    await tester.tap(find.text('Save as a copy'));
    await pumps(tester);
    expect(
      find.text(
        '“${iso('kira.pdf')}” stays open and unchanged; the copy is saved '
        'in ${iso('Projeler › 2026')}.',
      ),
      findsOne,
    );
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(engine.copies, [(kira.id, '/elsewhere/Projeler/2026/kopya.pdf')]);
    expect(engine.saves, isEmpty);
    expect(tab(tester).path, '/docs/kira.pdf');
    expect(tab(tester).saveState, SaveState.unsaved);
  });

  testWidgets("a copy onto the document's own file saves it", (tester) async {
    await pumpSaved(tester);
    containerOf(tester)
        .read(documentSaverProvider.notifier)
        .openSheet(copy: true);
    await pumps(tester);
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(engine.saves, [(kira.id, null)]);
    expect(engine.copies, isEmpty);
    expect(tab(tester).saveState, SaveState.saved);
  });

  testWidgets('Save a copy opens the sheet with its option checked', (
    tester,
  ) async {
    await pumpSaved(tester, state: SaveState.saved);
    containerOf(tester)
        .read(documentSaverProvider.notifier)
        .openSheet(copy: true);
    await pumps(tester);
    final copy = tester.widget<Checkbox>(
      find.widgetWithText(Checkbox, 'Save as a copy'),
    );
    expect(copy.checked, isTrue);
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await pumps(tester);
    expect(find.byType(SaveAsSheet), findsNothing);
    expect(engine.copies, isEmpty);
  });

  testWidgets("a file changed on disk shows a11-7b's bar at Save and when "
      'the window regains focus; Keep mine saves over it, Reload opens it '
      'again', (tester) async {
    final folder = Directory.systemTemp.createTempSync('ferman_reload');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = File('${folder.path}/kira.pdf')..writeAsStringSync('%PDF-1.7');
    await pumpSaved(tester, path: file.path);
    engine.changedOnDisk.add(kira.id);
    await control(tester, LogicalKeyboardKey.keyS);
    expect(find.text('“${iso('kira.pdf')}” changed on disk.'), findsOne);
    expect(find.byType(SaveFailureDialog), findsNothing);
    expect(tab(tester).saveState, SaveState.unsaved);
    final compare = tester.widget<Button>(
      find.widgetWithText(Button, 'Compare'),
    );
    expect(compare.disabledReason, futureVersion);

    await tester.tap(find.text('Keep mine'));
    await pumps(tester);
    expect(find.byType(FileChangedBar), findsNothing);
    expect(engine.saves, [(kira.id, null)]);
    expect(tab(tester).saveState, SaveState.saved);

    engine.changedOnDisk.add(kira.id);
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumps(tester);
    expect(find.byType(FileChangedBar), findsOne);

    await tester.tap(find.text('Reload'));
    await pumps(tester);
    await settle(tester);
    expect(find.byType(FileChangedBar), findsNothing);
    expect(containerOf(tester).read(shellDocumentsProvider).documents, [
      isA<ShellDocument>().having((t) => t.path, 'path', file.path),
    ]);
  });

  testWidgets('Reload keeps the document and its edits when the file is gone', (
    tester,
  ) async {
    await pumpSaved(tester, path: '/nowhere/kira.pdf');
    engine.changedOnDisk.add(kira.id);
    await control(tester, LogicalKeyboardKey.keyS);
    await tester.tap(find.text('Reload'));
    await pumps(tester);
    expect(tab(tester).document?.id, kira.id);
    expect(tab(tester).saveState, SaveState.unsaved);
    expect(find.byType(FileChangedBar), findsOne);
    expect(find.textContaining('The file isn’t there any more'), findsOne);
  });

  testWidgets('a later save that works takes the f4 toast away', (
    tester,
  ) async {
    await pumpSaved(tester);
    engine.failNextSave(EngineErrorKind.diskFull);
    await control(tester, LogicalKeyboardKey.keyS);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(find.byType(SaveFailureToast), findsOne);
    await control(tester, LogicalKeyboardKey.keyS);
    expect(find.byType(SaveFailureToast), findsNothing);
    expect(tab(tester).saveState, SaveState.saved);
  });

  testWidgets('a Save as that fails leaves a document without edits saved', (
    tester,
  ) async {
    await pumpSaved(tester, state: SaveState.saved);
    await control(tester, LogicalKeyboardKey.keyS, shift: true);
    engine.failNextSave(EngineErrorKind.permissionDenied);
    await tester.enterText(find.byType(EditableText), 'elsewhere');
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(find.byType(SaveFailureDialog), findsOne);
    expect(tab(tester).path, '/docs/kira.pdf');
    expect(tab(tester).saveState, SaveState.saved);
  });

  testWidgets("Save as takes away the changed file's bar", (tester) async {
    await pumpSaved(tester);
    engine.changedOnDisk.add(kira.id);
    await control(tester, LogicalKeyboardKey.keyS);
    expect(find.byType(FileChangedBar), findsOne);
    engine.changedOnDisk.clear();
    await control(tester, LogicalKeyboardKey.keyS, shift: true);
    await tester.enterText(find.byType(EditableText), 'mine');
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(tab(tester).path, '/docs/mine.pdf');
    expect(find.byType(FileChangedBar), findsNothing);
  });

  testWidgets("the toast's Save as… writes the document that failed, not the "
      'one shown since', (tester) async {
    await pumpSaved(tester);
    engine.failNextSave(EngineErrorKind.diskFull);
    await control(tester, LogicalKeyboardKey.keyS);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    await containerOf(tester)
        .read(documentOpenerProvider.notifier)
        .open(['/docs/kira-fixed.pdf']);
    await settle(tester);
    expect(tab(tester).document?.id, 12);

    await tester.tap(find.text('Save as…'));
    await pumps(tester);
    await tester.enterText(find.byType(EditableText), 'moved');
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(engine.saves, [(kira.id, '/docs/moved.pdf')]);
    expect(
      [
        for (final t in containerOf(
          tester,
        ).read(shellDocumentsProvider).documents)
          t.path,
      ],
      ['/docs/moved.pdf', '/docs/kira-fixed.pdf'],
    );
  });

  testWidgets('Save as refuses the file of another open tab', (tester) async {
    await pumpSaved(tester);
    final opener = containerOf(tester).read(documentOpenerProvider.notifier);
    await opener.open(['/docs/kira-fixed.pdf']);
    await settle(tester);
    await opener.open(['/docs/kira.pdf']);
    await settle(tester);
    await control(tester, LogicalKeyboardKey.keyS, shift: true);
    await tester.enterText(find.byType(EditableText), 'kira-fixed');
    await tester.tap(sheetSave());
    await pumps(tester);
    expect(find.textContaining('open in another tab'), findsOne);
    expect(engine.saves, isEmpty);
    expect(engine.copies, isEmpty);
  });

  testWidgets(
    "a1-9d: a file no one may write opens read-only, and the banner's Save a "
    'copy… opens the sheet with its option checked',
    (tester) async {
      final folder = Directory.systemTemp.createTempSync('ferman_read_only');
      addTearDown(() => folder.deleteSync(recursive: true));
      final file = File('${folder.path}/kira.pdf')
        ..writeAsStringSync('%PDF-1.7');
      Process.runSync('chmod', ['a-w', file.path]);
      engine = FakeEngineService(documents: {file.path: kira});
      picker = FakeFilePickerService(picked: [file.path]);
      await pumpFermanApp(tester, engine: engine, picker: picker);
      container = ProviderScope.containerOf(
        tester.element(find.byType(FmStart)),
      );
      await control(tester, LogicalKeyboardKey.keyO);
      await settle(tester);
      expect(tab(tester).saveState, SaveState.readOnly);
      expect(tab(tester).icon, IconName.lock);
      expect(find.text('“${iso('kira.pdf')}” is read-only.'), findsOne);
      expect(
        find.text(
          'Ferman can’t save changes to this file. To keep your changes, save '
          'a copy.',
        ),
        findsOne,
      );

      await tester.tap(find.text('Save a copy…'));
      await pumps(tester);
      expect(
        tester
            .widget<Checkbox>(find.widgetWithText(Checkbox, 'Save as a copy'))
            .checked,
        isTrue,
      );
      expect(
        find.text(
          '“${iso('kira.pdf')}” stays open and unchanged; the copy is saved '
          'alongside it.',
        ),
        findsOne,
      );
      await tester.enterText(find.byType(EditableText), 'kopya');
      await tester.tap(sheetSave());
      await pumps(tester);
      expect(engine.copies, [(kira.id, '${folder.path}/kopya.pdf')]);
      expect(tab(tester).saveState, SaveState.readOnly);
    },
    skip: Platform.isWindows,
  );

  testWidgets('Optimize and clean warns first on a signed document, and '
      'rewrites an unsigned one at once (G35)', (tester) async {
    await pumpSaved(tester, state: SaveState.saved);
    final saver = containerOf(tester).read(documentSaverProvider.notifier);
    engine.signed.add(kira.id);
    await saver.optimizeAndClean();
    await pumps(tester);
    expect(find.text('Optimize and clean “${iso('kira.pdf')}”?'), findsOne);
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await pumps(tester);
    expect(engine.optimized, isEmpty);

    await saver.optimizeAndClean();
    await pumps(tester);
    await tester.tap(find.widgetWithText(Button, 'Optimize and clean'));
    await pumps(tester);
    expect(engine.optimized, [kira.id]);

    engine.signed.clear();
    await saver.optimizeAndClean();
    await pumps(tester);
    expect(find.byType(OptimizeWarningDialog), findsNothing);
    expect(engine.optimized, [kira.id, kira.id]);
  });

  testWidgets('Save repaired copy… writes the repaired document where the '
      'panel says and opens the copy (B103)', (tester) async {
    await pumpSaved(
      tester,
      state: SaveState.readOnly,
      path: '/docs/kira-tr-damaged.pdf',
      document: repaired,
    );
    await tester.tap(find.text('Save repaired copy…'));
    await pumps(tester);
    // Cancelled: nothing written.
    expect(picker.saves, ['kira-tr-damaged.pdf']);
    expect(engine.repairedCopies, isEmpty);

    picker.saveTo = '/docs/kira-fixed.pdf';
    await tester.tap(find.text('Save repaired copy…'));
    await pumps(tester);
    await settle(tester);
    expect(engine.repairedCopies, [
      (repaired.id, '/docs/kira-fixed.pdf', false),
    ]);
    expect(
      [
        for (final t in containerOf(
          tester,
        ).read(shellDocumentsProvider).documents)
          t.path,
      ],
      ['/docs/kira-tr-damaged.pdf', '/docs/kira-fixed.pdf'],
    );

    // Never over the file of another open tab.
    containerOf(tester).read(shellDocumentsProvider.notifier).activate(0);
    await settle(tester);
    await tester.tap(find.text('Save repaired copy…'));
    await pumps(tester);
    expect(find.byType(SaveFailureDialog), findsOne);
    expect(engine.repairedCopies, hasLength(1));
    containerOf(tester).read(documentSaverProvider.notifier).dismissFailure();
    await pumps(tester);

    // Its own file only with the panel's confirmation to replace it.
    picker.saveTo = '/docs/kira-tr-damaged.pdf';
    await tester.tap(find.text('Save repaired copy…'));
    await pumps(tester);
    expect(engine.repairedCopies.last, (
      repaired.id,
      '/docs/kira-tr-damaged.pdf',
      true,
    ));
  });

  group('file names', () {
    test('validFileName refuses empty names and folder separators', () {
      expect(validFileName(null), isFalse);
      expect(validFileName(''), isFalse);
      expect(validFileName('  '), isFalse);
      expect(validFileName('..'), isFalse);
      expect(validFileName('a/b'), isFalse);
      expect(validFileName(r'a\b'), isFalse);
      expect(validFileName('a\u0000b'), isFalse);
      expect(validFileName('a\nb'), isFalse);
      expect(validFileName('Kira sözleşmesi'), isTrue);
    });

    test('validFileName refuses what Windows reserves, only there', () {
      expect(validFileName('a:b'), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final name in ['a:b', 'a*', 'a?', 'a"b', 'a<b', 'a>b', 'a|b']) {
        expect(validFileName(name), isFalse, reason: name);
      }
      expect(validFileName('Kira sözleşmesi'), isTrue);
    });

    test('pdfFileName adds .pdf once', () {
      expect(pdfFileName(' kira '), 'kira.pdf');
      expect(pdfFileName('kira.PDF'), 'kira.PDF');
    });

    test('folderOf and folderLabel', () {
      expect(folderOf('/Users/k/Belgeler/Ev/kira.pdf'), '/Users/k/Belgeler/Ev');
      expect(folderOf('/kira.pdf'), '');
      expect(folderLabel('/Users/k/Belgeler/Ev'), 'Belgeler › Ev');
      expect(folderLabel('/docs'), 'docs');
      expect(folderLabel(''), '/');
    });
  });
}
