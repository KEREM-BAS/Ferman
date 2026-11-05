import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/save/closing_dialogs.dart';
import 'package:ferman/features/save/document_closer.dart';
import 'package:ferman/features/save/document_recovery.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/save/save_dialogs.dart';
import 'package:ferman/features/settings/editing_pane.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';
import '../viewer/text_layer_test.dart' show block;

const OpenedDocument kira = OpenedDocument(
  id: 9,
  pages: [PageInfo(width: 595, height: 842)],
);
const OpenedDocument ekstre = OpenedDocument(
  id: 12,
  pages: [PageInfo(width: 595, height: 842)],
);
const OpenedDocument signedKira = OpenedDocument(
  id: 9,
  pages: [PageInfo(width: 595, height: 842)],
  signed: true,
  signatures: [Signature(field: 'S', signed: true, signer: 'Mert Kaya')],
);

/// The engine whose saves wait for [gate].
class _GatedSaves extends FakeEngineService {
  new(this.gate, {super.documents, super.pageBlocks});

  final Completer<void> gate;

  @override
  Future<void> save(int document, {bool overChange = false}) async {
    await gate.future;
    await super.save(document, overChange: overChange);
  }
}

void main() {
  late FakeEngineService engine;
  late ProviderContainer container;

  ShellDocumentList documents() => container.read(shellDocumentsProvider);

  /// The app with the files at [paths] open, unsaved, the last one shown.
  Future<void> pumpOpen(
    WidgetTester tester, {
    Map<String, OpenedDocument> files = const {
      '/docs/kira.pdf': kira,
      '/docs/ekstre.pdf': ekstre,
    },
    List<String> unsaved = const ['/docs/kira.pdf', '/docs/ekstre.pdf'],
    Map<int, PageBlocks> pageBlocks = const {},
    List<String>? picked,
    Completer<void>? gate,
  }) async {
    engine = gate == null
        ? FakeEngineService(documents: files, pageBlocks: pageBlocks)
        : _GatedSaves(gate, documents: files, pageBlocks: pageBlocks);
    await pumpFermanApp(
      tester,
      engine: engine,
      picker: FakeFilePickerService(picked: picked ?? files.keys.toList()),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(FmStart)));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    for (final path in unsaved) {
      final tab = documents().documents.firstWhere((t) => t.path == path);
      container
          .read(shellDocumentsProvider.notifier)
          .replace(path, tab.withSave(SaveState.unsaved, editCount: 3));
    }
    await tester.pumpAndSettle();
  }

  DocumentCloser closer() => container.read(documentCloserProvider.notifier);

  group('a1-10b', () {
    testWidgets('a clean tab closes at once', (tester) async {
      await pumpOpen(tester, unsaved: const []);
      await closer().close('/docs/kira.pdf');
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedCloseDialog), findsNothing);
      expect(documents().documents.map((t) => t.path), ['/docs/ekstre.pdf']);
      expect(engine.closed, [kira.id]);
    });

    testWidgets('Cancel keeps the tab; Save saves and closes it', (
      tester,
    ) async {
      await pumpOpen(tester);
      unawaited(closer().close('/docs/ekstre.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Save changes to “\u2068ekstre.pdf\u2069”?'), findsOne);
      expect(find.textContaining('3 edits'), findsOne);

      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(documents().documents, hasLength(2));
      expect(engine.saves, isEmpty);

      unawaited(closer().close('/docs/ekstre.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(UnsavedCloseDialog),
          matching: find.widgetWithText(Button, 'Save'),
        ),
      );
      await tester.pumpAndSettle();
      expect(engine.saves, [(ekstre.id, null)]);
      expect(documents().documents.map((t) => t.path), ['/docs/kira.pdf']);
    });

    testWidgets('a failed save keeps the tab and shows its error', (
      tester,
    ) async {
      await pumpOpen(tester);
      engine.failNextSave(EngineErrorKind.diskFull);
      unawaited(closer().close('/docs/ekstre.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(UnsavedCloseDialog),
          matching: find.widgetWithText(Button, 'Save'),
        ),
      );
      await tester.pumpAndSettle();
      expect(documents().documents, hasLength(2));
      expect(find.byType(SaveFailureDialog), findsOne);
      expect(engine.closed, isEmpty);
    });

    testWidgets('Don’t save closes it and deletes the recovery files', (
      tester,
    ) async {
      await pumpOpen(tester);
      unawaited(closer().close('/docs/ekstre.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Don’t save'));
      await tester.pumpAndSettle();
      expect(engine.closedDiscarding, [ekstre.id]);
      expect(documents().documents.map((t) => t.path), ['/docs/kira.pdf']);
    });

    testWidgets('⌘W or Ctrl+W asks about an unsaved tab', (tester) async {
      await pumpOpen(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedCloseDialog), findsOne);
      expect(documents().documents, hasLength(2));
    });

    testWidgets('Close other documents asks about each unsaved tab in turn', (
      tester,
    ) async {
      await pumpOpen(tester);
      unawaited(closer().closeOthers('/docs/ekstre.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Save changes to “\u2068kira.pdf\u2069”?'), findsOne);
      await tester.tap(find.widgetWithText(Button, 'Don’t save'));
      await tester.pumpAndSettle();
      expect(documents().documents.map((t) => t.path), ['/docs/ekstre.pdf']);
    });
  });

  group('while a save runs', () {
    testWidgets('closing a saving tab waits for it and asks if it failed', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pumpOpen(tester, gate: gate, unsaved: const ['/docs/ekstre.pdf']);
      engine.failNextSave(EngineErrorKind.permissionDenied);
      final saving = container
          .read(documentSaverProvider.notifier)
          .saveTab(documents().active!);
      await tester.pump();
      expect(documents().active?.saveState, SaveState.saving);
      unawaited(closer().close('/docs/ekstre.pdf'));
      await tester.pump();
      expect(find.byType(UnsavedCloseDialog), findsNothing);
      expect(documents().active?.path, '/docs/ekstre.pdf');
      gate.complete();
      await saving;
      await tester.pumpAndSettle();
      expect(documents().active?.path, '/docs/ekstre.pdf');
      expect(container.read(documentCloserProvider).asking, isNotNull);
    });

    testWidgets('a quit during a tab’s save still asks about the others', (
      tester,
    ) async {
      final gate = Completer<void>();
      await pumpOpen(tester, gate: gate);
      await closer().close('/docs/kira.pdf');
      await tester.pumpAndSettle();
      unawaited(closer().save());
      await tester.pump();
      var answered = false;
      final answer = closer().quit();
      unawaited(answer.then((_) => answered = true));
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(answered, isFalse);
      expect(engine.saves, [(kira.id, null)]);
      expect(documents().documents.map((tab) => tab.path), [
        '/docs/ekstre.pdf',
      ]);
      expect(find.byType(UnsavedCloseDialog), findsOne);
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('a quit takes back a tab’s question', (tester) async {
      await pumpOpen(tester);
      await closer().close('/docs/kira.pdf');
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedCloseDialog), findsOne);
      final answer = closer().quit();
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedCloseDialog), findsNothing);
      expect(find.byType(QuitReviewDialog), findsOne);
      closer().cancel();
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('a background tab that fails to save comes forward', (
      tester,
    ) async {
      await pumpOpen(tester);
      engine.changedOnDisk.add(kira.id);
      await closer().closeOthers('/docs/ekstre.pdf');
      await tester.pumpAndSettle();
      await closer().save();
      await tester.pumpAndSettle();
      expect(documents().active?.path, '/docs/kira.pdf');
      expect(find.byType(FileChangedBar), findsOne);
    });
  });

  group('quitting (a11-7e)', () {
    testWidgets('the window asks before it closes', (tester) async {
      final window = FakeDesktopWindow(WindowPlatform.mac);
      addTearDown(window.dispose);
      engine = FakeEngineService();
      await pumpFermanApp(tester, engine: engine, window: window);
      expect(await window.closeGuard!(), isTrue);
    });

    testWidgets('nothing unsaved quits without asking', (tester) async {
      await pumpOpen(tester, unsaved: const []);
      expect(await closer().quit(), isTrue);
    });

    testWidgets('one document asks a1-10b; Cancel stays', (tester) async {
      await pumpOpen(tester, unsaved: const ['/docs/kira.pdf']);
      final answer = closer().quit();
      await tester.pumpAndSettle();
      expect(find.byType(UnsavedCloseDialog), findsOne);
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('several ask once; unchecked ones are discarded', (
      tester,
    ) async {
      await pumpOpen(tester);
      final answer = closer().quit();
      await tester.pumpAndSettle();
      expect(
        find.text('Save changes to 2 documents before quitting?'),
        findsOne,
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Save and quit'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
      expect(engine.saves, [(ekstre.id, null)]);
      expect(engine.closedDiscarding, [kira.id]);
      // The tabs stay, for the next launch to reopen.
      expect(documents().documents, hasLength(2));
      // A confirmed quit does not ask again when the system's quit follows.
      expect(await closer().quit(), isTrue);
    });

    testWidgets('a failed save stops the quit and shows its tab and error', (
      tester,
    ) async {
      await pumpOpen(tester);
      engine.failNextSave(EngineErrorKind.permissionDenied);
      final answer = closer().quit();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Save and quit'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
      expect(documents().active?.path, '/docs/kira.pdf');
      expect(find.byType(SaveFailureDialog), findsOne);
      expect(engine.closedDiscarding, isEmpty);
    });

    testWidgets('Quit without saving discards everything', (tester) async {
      await pumpOpen(tester);
      final answer = closer().quit();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Quit without saving'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
      expect(engine.closedDiscarding, unorderedEquals([kira.id, ekstre.id]));
      expect(engine.saves, isEmpty);
    });
  });

  group('recovery (a1-12, a11-7f)', () {
    const clean = RecoverableDocument(
      session: 's',
      document: 'a',
      original: '/docs/kira.pdf',
      changes: 6,
    );
    const changed = RecoverableDocument(
      session: 's',
      document: 'b',
      original: '/docs/fatura.pdf',
      originalChanged: true,
      changes: 2,
    );
    const locked = RecoverableDocument(
      session: 's',
      document: 'c',
      original: '/docs/bordro.pdf',
      changes: 1,
      encrypted: true,
    );

    Future<void> pumpRecovering(
      WidgetTester tester,
      List<RecoverableDocument> found,
    ) async {
      engine = FakeEngineService()
        ..recoveryRoot = '/recovery'
        ..recoverable.addAll(found)
        ..recoveredDocuments.addAll({'a': kira, 'b': ekstre, 'c': kira})
        ..recoveryPasswords['c'] = 'gizli';
      await pumpFermanApp(tester, engine: engine, home: '/docs');
      container = ProviderScope.containerOf(
        tester.element(find.byType(FmStart)),
      );
    }

    testWidgets('nothing to restore shows nothing', (tester) async {
      await pumpRecovering(tester, const []);
      expect(find.byType(RecoveryDialog), findsNothing);
    });

    testWidgets('opens the checked ones as unsaved, discards the rest', (
      tester,
    ) async {
      await pumpRecovering(tester, const [clean, changed]);
      expect(find.text('Ferman restored 2 documents'), findsOne);
      expect(find.text('6 edits · ~'), findsOne);
      expect(find.text('Changed on disk'), findsOne);
      expect(find.widgetWithText(Button, 'Open 2 documents'), findsOne);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Open 1 document'));
      await tester.pumpAndSettle();
      expect(engine.recoverable, isEmpty);
      final tab = documents().active;
      expect(tab?.path, '/docs/fatura (recovered).pdf');
      expect(tab?.unsaved, isTrue);
      expect(tab?.editCount, 2);
    });

    testWidgets('takes the place of the tab its file reopened in', (
      tester,
    ) async {
      await pumpOpen(
        tester,
        files: const {'/docs/kira.pdf': kira},
        unsaved: const [],
      );
      engine
        ..recoveryRoot = '/recovery'
        ..recoverable.add(clean)
        ..recoveredDocuments['a'] = ekstre;
      await container.read(documentRecoveryProvider.notifier).check();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Open 1 document'));
      await tester.pumpAndSettle();
      final tabs = documents().documents;
      expect(tabs.map((tab) => tab.path), ['/docs/kira.pdf']);
      expect(tabs.single.document?.id, ekstre.id);
      expect(tabs.single.unsaved, isTrue);
      expect(engine.closed, contains(kira.id));
    });

    testWidgets('Discard deletes every copy', (tester) async {
      await pumpRecovering(tester, const [clean, changed]);
      await tester.tap(find.widgetWithText(Button, 'Discard'));
      await tester.pumpAndSettle();
      expect(engine.recoverable, isEmpty);
      expect(documents().documents, isEmpty);
    });

    testWidgets('an encrypted one asks for its password until it is right', (
      tester,
    ) async {
      await pumpRecovering(tester, const [locked]);
      await tester.tap(find.widgetWithText(Button, 'Open 1 document'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'yanlış');
      await tester.tap(find.widgetWithText(Button, 'Open'));
      await tester.pumpAndSettle();
      expect(documents().documents, isEmpty);
      await tester.enterText(find.byType(EditableText), 'gizli');
      await tester.tap(find.widgetWithText(Button, 'Open'));
      await tester.pumpAndSettle();
      expect(documents().active?.path, '/docs/bordro.pdf');
    });

    testWidgets('Cancel at the password keeps its copy', (tester) async {
      await pumpRecovering(tester, const [locked]);
      await tester.tap(find.widgetWithText(Button, 'Open 1 document'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(engine.recoverable, [locked]);
    });
  });

  group('signed documents (a3-16a, a3-16b)', () {
    final text = block(1, const Rect.fromLTRB(72, 100, 300, 112), ['Madde 3']);

    Future<void> pumpSigned(WidgetTester tester) async {
      await pumpOpen(
        tester,
        files: const {
          '/docs/kira.pdf': signedKira,
          '/docs/kira (copy).pdf': ekstre,
        },
        unsaved: const [],
        picked: const ['/docs/kira.pdf'],
        pageBlocks: {
          0: PageBlocks(blocks: [text]),
        },
      );
      engine.signed.add(signedKira.id);
      container.read(shellDocumentsProvider.notifier).focus('/docs/kira.pdf');
      await tester.pumpAndSettle();
    }

    Future<void> click(WidgetTester tester) async {
      await container
          .read(documentEditorProvider.notifier)
          .open(0, text, caret: 0, name: 'Edited');
      await tester.pumpAndSettle();
    }

    testWidgets('asks before the first change; Cancel opens nothing', (
      tester,
    ) async {
      await pumpSigned(tester);
      await click(tester);
      expect(find.byType(SignedEditDialog), findsOne);
      expect(find.text('Edit a signed document?'), findsOne);
      expect(container.read(documentEditorProvider).active, isNull);
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(SignedEditDialog), findsNothing);
      expect(engine.confirmations, isEmpty);
    });

    testWidgets('Edit anyway confirms and opens the block, once', (
      tester,
    ) async {
      await pumpSigned(tester);
      await click(tester);
      await tester.tap(find.widgetWithText(Button, 'Edit anyway'));
      await tester.pumpAndSettle();
      expect(engine.confirmations.keys, [signedKira.id]);
      expect(container.read(documentEditorProvider).active, isNotNull);
      await click(tester);
      expect(find.byType(SignedEditDialog), findsNothing);
    });

    testWidgets('Edit a copy writes it unsigned and opens it', (tester) async {
      await pumpSigned(tester);
      await click(tester);
      await tester.tap(find.widgetWithText(Button, 'Edit a copy'));
      // Looking for a free name reads the disk.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(engine.unsignedCopies, [(signedKira.id, '/docs/kira (copy).pdf')]);
      expect(documents().active?.path, '/docs/kira (copy).pdf');
      expect(engine.confirmations, isEmpty);
    });

    testWidgets('a save the engine refuses asks, then goes on', (tester) async {
      await pumpSigned(tester);
      final tab = documents().active!;
      unawaited(container.read(documentSaverProvider.notifier).saveTab(tab));
      await tester.pumpAndSettle();
      expect(find.byType(SignedEditDialog), findsOne);
      await tester.tap(find.widgetWithText(Button, 'Edit anyway'));
      await tester.pumpAndSettle();
      expect(engine.saves, [(signedKira.id, null)]);
    });

    testWidgets('after a change the bar stays and the history says so', (
      tester,
    ) async {
      await pumpSigned(tester);
      await click(tester);
      await tester.tap(find.widgetWithText(Button, 'Edit anyway'));
      await tester.pumpAndSettle();
      final editor = container.read(documentEditorProvider.notifier)
        ..type('Madde 4');
      await editor.finish();
      await tester.pumpAndSettle();
      expect(find.byType(SignatureInvalidBar), findsOne);
      expect(
        find.text('The signature in this document is no longer valid.'),
        findsOne,
      );
      expect(find.textContaining('Mert Kaya'), findsOne);
      await editor.undo();
      await tester.pumpAndSettle();
      expect(find.byType(SignatureInvalidBar), findsNothing);
    });
  });

  group('Settings › Editing (a11-1c)', () {
    testWidgets('the recovery switch reaches the engine and is stored', (
      tester,
    ) async {
      engine = FakeEngineService()..recoveryRoot = '/recovery';
      await pumpFermanApp(tester, engine: engine);
      container = ProviderScope.containerOf(
        tester.element(find.byType(FmStart)),
      );
      // The engine follows from the moment the editor state exists.
      final _ = container.read(documentEditorProvider);
      unawaited(
        container
            .read(routerProvider)
            .push(Routes.settingsPane(SettingsPane.editing.path)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditingPane), findsOne);
      expect(find.text('/recovery'), findsOne);
      await tester.tap(
        find.widgetWithText(Switch, 'Save a recovery copy every minute'),
      );
      await tester.pumpAndSettle();
      expect(container.read(settingsProvider).recoveryCopies, isFalse);
      expect(engine.recoveryEnabled, isFalse);
    });
  });
}
