import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/ai_clients/ai_clients.dart';
import 'package:ferman/features/editor/block_editor.dart';
import 'package:ferman/features/editor/edit_history_panel.dart';
import 'package:ferman/features/editor/edit_marks.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import '../viewer/text_layer_test.dart' show block;

const OpenedDocument document = OpenedDocument(
  id: 9,
  pages: [PageInfo(width: 595, height: 842)],
);

/// A heading and a two-line paragraph.
final PageBlocks page = PageBlocks(
  blocks: [
    block(1, const Rect.fromLTRB(72, 100, 300, 112), ['Madde 3']),
    block(3, const Rect.fromLTRB(72, 300, 400, 324), [
      'Birinci satır',
      'İkinci satır',
    ]),
  ],
);

void main() {
  late FakeDesktopWindow window;
  late FakeEngineService engine;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<void> pumpEditor(
    WidgetTester tester, {
    FakeEngineService? fake,
  }) async {
    engine =
        fake ??
        FakeEngineService(
          documents: {'/kira.pdf': document},
          pageBlocks: {0: page},
        );
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        samples: false,
        overrides: [engineServiceProvider.overrideWithValue(engine)],
      ),
    );
    containerOf(tester)
        .read(shellDocumentsProvider.notifier)
        .add(
          const ShellDocument(
            name: 'kira.pdf',
            path: '/kira.pdf',
            document: document,
            saveState: SaveState.saved,
            pageCount: 1,
          ),
        );
    containerOf(tester)
        .read(shellModeProvider.notifier)
        .select(FermanMode.edit);
    await settle(tester);
  }

  Offset onScreen(WidgetTester tester, Offset point) {
    final view = containerOf(tester).read(viewerProvider)!;
    final rect = view.placement.rects.first!;
    return tester.getTopLeft(find.byType(DocumentView)) +
        rect.topLeft -
        view.offset +
        point * view.scale;
  }

  /// Clicks page space's [point]; the first click over a page brings its
  /// blocks, so the pointer goes there first.
  Future<void> click(WidgetTester tester, Offset point) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getTopLeft(find.byType(DocumentView)),
    );
    await mouse.moveTo(onScreen(tester, point));
    await tester.pump();
    await tester.pump();
    await mouse.down(onScreen(tester, point));
    await mouse.up();
    await mouse.removePointer();
    await pumps(tester);
  }

  ShellDocument tab(WidgetTester tester) =>
      containerOf(tester).read(shellDocumentsProvider).active!;

  EditorState editor(WidgetTester tester) =>
      containerOf(tester).read(documentEditorProvider);

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await pumps(tester);
  }

  Future<void> control(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pumps(tester);
  }

  testWidgets('the editing frame hugs its block on the canvas', (tester) async {
    await pumpEditor(tester);
    await click(tester, const Offset(72, 106));
    // The field starts within a pixel of the block's own corner (a3-1b).
    final field = tester.getTopLeft(find.byType(EditableText));
    final corner = onScreen(tester, const Offset(72, 100));
    expect((field - corner).distance, lessThanOrEqualTo(1.5));
  });

  group('f1', () {
    const page = Rect.fromLTWH(0, 0, 600, 800);
    MetaPlacement place(Rect frame, [List<Rect> others = const []]) =>
        metaPlacementFor(frame: frame, page: page, others: others, room: 20);
    const frame = Rect.fromLTWH(50, 100, 200, 40);
    const line = Rect.fromLTRB(50, 80, 250, 90);

    test('above when the room above the frame is free', () {
      expect(place(frame), MetaPlacement.above);
      // Clear of the 20 px band: the frame's outer edge is at 96.
      expect(
        place(frame, [const Rect.fromLTRB(50, 60, 250, 75)]),
        MetaPlacement.above,
      );
    });

    test('below when text or the page edge is directly above', () {
      expect(place(frame, [line]), MetaPlacement.below);
      expect(place(const Rect.fromLTWH(50, 10, 200, 40)), MetaPlacement.below);
    });

    test('the margin when neither side is free', () {
      expect(
        place(frame, [line, const Rect.fromLTRB(50, 150, 250, 160)]),
        MetaPlacement.margin,
      );
      // The page's bottom edge counts as much as text does.
      expect(
        place(const Rect.fromLTWH(50, 770, 200, 20), [
          const Rect.fromLTRB(50, 750, 250, 760),
        ]),
        MetaPlacement.margin,
      );
    });

    test('moving the frame recalculates', () {
      expect(place(frame, [line]), MetaPlacement.below);
      expect(
        place(const Rect.fromLTWH(50, 130, 200, 40), [line]),
        MetaPlacement.above,
      );
    });
  });

  testWidgets('the editor places its label from the page’s other blocks', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      fake: FakeEngineService(
        documents: {'/kira.pdf': document},
        pageBlocks: {
          0: PageBlocks(
            blocks: [
              block(1, const Rect.fromLTRB(72, 100, 300, 112), ['Madde 3']),
              block(2, const Rect.fromLTRB(72, 114, 300, 126), ['Kira']),
              block(3, const Rect.fromLTRB(72, 128, 300, 140), ['Bedel']),
            ],
          ),
        },
      ),
    );
    await click(tester, const Offset(100, 120));
    expect(
      tester.widget<BlockEditor>(find.byType(BlockEditor)).metaPlacement,
      MetaPlacement.margin,
    );
  });

  testWidgets('holding Alt frames every editable block (a3-1a)', (
    tester,
  ) async {
    await pumpEditor(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await pumps(tester);
    expect(find.byType(TextEditBox), findsNWidgets(2));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await pumps(tester);
    expect(find.byType(TextEditBox), findsNothing);
  });

  testWidgets('a click opens the block in a multi-line text field, and Esc '
      'commits the typing as one step', (tester) async {
    await pumpEditor(tester);
    await click(tester, const Offset(72, 106));
    final field = find.byType(EditableText);
    expect(field, findsOneWidget);
    expect(find.byType(BlockEditor), findsOneWidget);
    expect(
      tester.widget<TextEditBox>(find.byType(TextEditBox)).state,
      TextEditBoxState.editing,
    );
    final editable = tester.widget<EditableText>(field);
    expect(editable.controller.text, 'Madde 3');
    // The caret sits where the click was: before the first character.
    expect(editable.controller.selection.baseOffset, 0);
    expect(editable.focusNode.hasFocus, isTrue);
    // The field's own node, inside the editing frame's.
    final node = tester.getSemantics(
      find.descendant(
        of: field,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_Editable',
        ),
      ),
    );
    expect(
      node,
      isSemantics(
        isTextField: true,
        isMultiline: true,
        isFocused: true,
        value: 'Madde 3',
      ),
    );

    await tester.enterText(field, 'Madde 4');
    await tester.pump();
    final requests = engine.requests.length;
    await key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(EditableText), findsNothing);
    // The pages and their thumbnails are asked for again.
    await tester.pump();
    expect(
      engine.requests
          .skip(requests)
          .expand((wanted) => wanted)
          .map((entry) => entry.item.runtimeType),
      containsAll(<Type>[TileItem, ThumbnailItem]),
    );
    final history = editor(tester).history;
    expect(history.current, 1);
    expect(history.steps.single.name, 'Edited text · page 1');
    expect(
      (await engine.textBlocks(document.id, 0)).blocks.first.text,
      'Madde 4',
    );
    expect(editor(tester).renderKey, isNotNull);
    expect(tab(tester).saveState, SaveState.unsaved);
    expect(tab(tester).editCount, 1);
  });

  testWidgets('the field takes another number of lines, and a click '
      'elsewhere commits', (tester) async {
    await pumpEditor(tester);
    await click(tester, const Offset(100, 306));
    final field = find.byType(EditableText);
    expect(
      tester.widget<EditableText>(field).controller.text,
      'Birinci satır\nİkinci satır',
    );
    await tester.enterText(field, 'İlk\nsatır\nİkinci');
    await tester.pump();
    expect(
      tester.widget<EditableText>(field).controller.text,
      'İlk\nsatır\nİkinci',
    );
    await click(tester, const Offset(500, 200));
    expect(find.byType(EditableText), findsNothing);
    expect(editor(tester).history.current, 1);
    expect(
      (await engine.textBlocks(
        document.id,
        0,
      )).blocks.last.lines.map((line) => line.text),
      ['İlk', 'satır', 'İkinci'],
    );
  });

  testWidgets('1.5 s without typing commits and keeps the field open', (
    tester,
  ) async {
    await pumpEditor(tester);
    await click(tester, const Offset(72, 106));
    await tester.enterText(find.byType(EditableText), 'Madde 5');
    await tester.pump(const Duration(milliseconds: 1400));
    expect(editor(tester).history.current, 0);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(editor(tester).history.current, 1);
    expect(find.byType(EditableText), findsOneWidget);
    // Typing on is a step of its own.
    await tester.enterText(find.byType(EditableText), 'Madde 6');
    await tester.pump();
    await key(tester, LogicalKeyboardKey.escape);
    expect(editor(tester).history.current, 2);
  });

  testWidgets('Ctrl+Z and Ctrl+Y undo and redo through the engine, and the '
      'row’s buttons follow', (tester) async {
    await pumpEditor(tester);
    IconButton button(String label) => tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.label == label,
      ),
    );
    expect(button('Undo').onPressed, isNull);
    expect(button('Redo').onPressed, isNull);
    await click(tester, const Offset(72, 106));
    await tester.enterText(find.byType(EditableText), 'Madde 4');
    await tester.pump();
    await key(tester, LogicalKeyboardKey.escape);
    expect(button('Undo').onPressed, isNotNull);

    await control(tester, LogicalKeyboardKey.keyZ);
    expect(editor(tester).history.current, 0);
    expect(
      (await engine.textBlocks(document.id, 0)).blocks.first.text,
      'Madde 3',
    );
    expect(button('Redo').onPressed, isNotNull);
    await control(tester, LogicalKeyboardKey.keyY);
    expect(editor(tester).history.current, 1);
    expect(button('Redo').onPressed, isNull);

    // In the field, Ctrl+Z is the field's own: the document keeps its step.
    await click(tester, const Offset(72, 106));
    await control(tester, LogicalKeyboardKey.keyZ);
    expect(editor(tester).history.current, 1);
    expect(find.byType(EditableText), findsOneWidget);
  });

  testWidgets('Save and Ctrl+S save the committed steps', (tester) async {
    await pumpEditor(tester);
    Button save() => tester.widget<Button>(
      find.ancestor(of: find.text('Save'), matching: find.byType(Button)),
    );
    expect(save().onPressed, isNull);
    expect(save().disabledReason, 'No changes to save');
    await click(tester, const Offset(72, 106));
    await tester.enterText(find.byType(EditableText), 'Madde 4');
    await tester.pump();
    // Ctrl+S in the field commits the typing first.
    await control(tester, LogicalKeyboardKey.keyS);
    expect(engine.saves, [(document.id, null)]);
    expect(editor(tester).history.current, 1);
    expect(tab(tester).saveState, SaveState.saved);
    expect(tab(tester).savedAt, isNotNull);
    expect(find.byType(EditableText), findsNothing);

    await control(tester, LogicalKeyboardKey.keyZ);
    expect(tab(tester).saveState, SaveState.unsaved);
    engine.saveFailure = const EngineException(messageKey: 'errorInternal');
    await tester.tap(find.text('Save'));
    await pumps(tester);
    expect(tab(tester).saveState, SaveState.error);
    expect(find.text('Couldn’t save'), findsOneWidget);
    // Save stays enabled to try again (G41).
    expect(save().onPressed, isNotNull);
  });

  testWidgets('a save after an edit gives the recent file the Edited badge, '
      'which stays over a reopen (B129)', (tester) async {
    await pumpEditor(tester);
    final path = tab(tester).path!;
    final recent = containerOf(tester).read(recentFilesProvider.notifier);
    bool edited() =>
        containerOf(tester)
            .read(recentFilesProvider)
            .firstWhere((file) => file.path == path)
            .edited;
    await recent.opened(path, name: 'kira.pdf', now: DateTime(2026));
    await click(tester, const Offset(72, 106));
    await tester.enterText(find.byType(EditableText), 'Madde 4');
    await tester.pump();
    engine.saveFailure = const EngineException(messageKey: 'errorInternal');
    await control(tester, LogicalKeyboardKey.keyS);
    expect(edited(), isFalse);
    engine.saveFailure = null;
    await control(tester, LogicalKeyboardKey.keyS);
    expect(edited(), isTrue);
    await recent.opened(path, name: 'kira.pdf', now: DateTime(2026));
    expect(edited(), isTrue);
  });

  testWidgets('typing not yet committed is unsaved, and Save commits it', (
    tester,
  ) async {
    await pumpEditor(tester);
    await click(tester, const Offset(72, 106));
    await tester.enterText(find.byType(EditableText), 'Madde 4');
    await tester.pump();
    expect(editor(tester).history.current, 0);
    expect(tab(tester).saveState, SaveState.unsaved);
    await tester.tap(find.text('Save'));
    await pumps(tester);
    expect(engine.saves, [(document.id, null)]);
    expect(editor(tester).history.current, 1);
    expect(tab(tester).saveState, SaveState.saved);
  });

  testWidgets('a step whose pages could not be drawn again is unsaved too', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      fake: _NoReload(
        documents: {'/kira.pdf': document},
        pageBlocks: {0: page},
      ),
    );
    await click(tester, const Offset(72, 106));
    await tester.enterText(find.byType(EditableText), 'Madde 4');
    await tester.pump();
    await key(tester, LogicalKeyboardKey.escape);
    containerOf(tester)
        .read(shellDocumentsProvider.notifier)
        .replace('/kira.pdf', tab(tester).withSave(SaveState.saved));
    await control(tester, LogicalKeyboardKey.keyZ);
    expect(editor(tester).history.current, 0);
    expect(editor(tester).renderKey, isNull);
    expect(tab(tester).saveState, SaveState.unsaved);
  });

  testWidgets('Close other documents keeps the unsaved ones', (tester) async {
    await pumpEditor(tester);
    containerOf(tester).read(shellDocumentsProvider.notifier)
      ..add(
        const ShellDocument(
          name: 'a.pdf',
          path: '/a.pdf',
          saveState: SaveState.unsaved,
        ),
      )
      ..add(
        const ShellDocument(
          name: 'b.pdf',
          path: '/b.pdf',
          saveState: SaveState.saved,
        ),
      );
    containerOf(tester)
        .read(documentOpenerProvider.notifier)
        .closeOthers('/kira.pdf');
    await pumps(tester);
    expect(
      containerOf(tester)
          .read(shellDocumentsProvider)
          .documents
          .map((tab) => tab.path),
      ['/kira.pdf', '/a.pdf'],
    );
    expect(tab(tester).path, '/kira.pdf');
  });

  testWidgets('Edit history lists the steps, greys the undone ones and goes '
      'back to the step clicked', (tester) async {
    await pumpEditor(tester);
    for (final text in ['Madde 4', 'Madde 5']) {
      await click(tester, const Offset(72, 106));
      await tester.enterText(find.byType(EditableText), text);
      await tester.pump();
      await key(tester, LogicalKeyboardKey.escape);
    }
    await control(tester, LogicalKeyboardKey.keyZ);
    expect(find.byType(EditHistoryPanel), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.label == 'Edit history',
      ),
    );
    await tester.pump();
    expect(find.byType(EditHistoryPanel), findsOneWidget);
    expect(find.byType(FmDocPanel), findsNothing);
    final panel = find.byType(EditHistoryPanel);
    expect(
      find.descendant(of: panel, matching: find.textContaining('kira.pdf')),
      findsOneWidget,
    );
    final steps = find.descendant(
      of: panel,
      matching: find.text('Edited text · page 1'),
    );
    expect(steps, findsNWidgets(2));
    final theme = tester.element(panel).ferman;
    Color colorOf(int index) =>
        tester.widget<Text>(steps.at(index)).style!.color!;
    expect(colorOf(0), theme.colors.textPrimary);
    expect(colorOf(1), theme.colors.textDisabled);
    expect(
      find.textContaining('Click a step to go back to it.'),
      findsOneWidget,
    );

    await tester.tap(steps.at(1));
    await pumps(tester);
    expect(editor(tester).history.current, 2);
    await tester.tap(find.textContaining('Opened'));
    await pumps(tester);
    expect(editor(tester).history.current, 0);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.label == 'Close history',
      ),
    );
    await tester.pump();
    expect(find.byType(EditHistoryPanel), findsNothing);
    expect(find.byType(FmDocPanel), findsOneWidget);
  });

  testWidgets("an AI client's step names it in the history, marks the "
      "document unsaved and undoes as the person's own (G94)", (tester) async {
    await pumpEditor(tester);
    final container = containerOf(tester)..read(aiClientsProvider);
    await container
        .read(settingsProvider.notifier)
        .change((settings) => settings.copyWith(aiClients: true));
    await pumps(tester);
    expect(engine.mcpFolder, isNotNull);

    engine.commitAsClient(document.id, 'Claude', 'Edited text · page 1');
    await pumps(tester);
    expect(editor(tester).history.current, 1);
    expect(editor(tester).history.steps.single.client, 'Claude');
    expect(tab(tester).saveState, SaveState.unsaved);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.label == 'Edit history',
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(EditHistoryPanel),
        matching: find.textContaining('· \u2068Claude\u2069'),
      ),
      findsOneWidget,
    );

    await control(tester, LogicalKeyboardKey.keyZ);
    expect(editor(tester).history.current, 0);
    // Stopped, so its poll ends with the test.
    await container
        .read(settingsProvider.notifier)
        .change((settings) => settings.copyWith(aiClients: false));
    await pumps(tester);
  });

  testWidgets('leaving Edit mode commits the typing', (tester) async {
    await pumpEditor(tester);
    await click(tester, const Offset(72, 106));
    await tester.enterText(find.byType(EditableText), 'Madde 9');
    await tester.pump();
    containerOf(tester)
        .read(shellModeProvider.notifier)
        .select(FermanMode.view);
    await pumps(tester);
    expect(editor(tester).history.current, 1);
    expect(find.byType(EditableText), findsNothing);
  });

  group('edit marks (f3)', () {
    List<EditMark>? marks(WidgetTester tester) {
      final paint = find.byKey(
        const ValueKey<String>('DocumentView.editMarks'),
      );
      if (paint.evaluate().isEmpty) return null;
      return (tester.widget<CustomPaint>(paint).painter! as EditMarksPainter)
          .marks;
    }

    Future<void> editSecondLine(WidgetTester tester) async {
      await click(tester, const Offset(100, 306));
      await tester.enterText(
        find.byType(EditableText),
        'Birinci satır\nDeğişti',
      );
      await tester.pump();
      await key(tester, LogicalKeyboardKey.escape);
      await pumps(tester);
    }

    testWidgets('only the changed line is marked, until it is undone', (
      tester,
    ) async {
      await pumpEditor(tester);
      expect(marks(tester), isNull);
      await editSecondLine(tester);

      final mark = marks(tester)!.single;
      final view = containerOf(tester).read(viewerProvider)!;
      final rect = view.placement.rects.first!;
      final left = rect.left - view.offset.dx + 72 * view.scale;
      final top = rect.top - view.offset.dy + 312 * view.scale;
      expect(mark.line.top, moreOrLessEquals(top));
      expect(mark.bar.left, moreOrLessEquals(left - 12 - 2));
      expect(mark.bar.width, 2);

      await control(tester, LogicalKeyboardKey.keyZ);
      await pumps(tester);
      expect(marks(tester), isNull);
    });

    testWidgets('the Edit row switch hides them and they stay after a save; '
        'the saved file is the same either way', (tester) async {
      final fake = _SavedFile(
        documents: {'/kira.pdf': document},
        pageBlocks: {0: page},
      );
      await pumpEditor(tester, fake: fake);
      await editSecondLine(tester);
      final notifier = containerOf(tester)
          .read(documentEditorProvider.notifier);

      await notifier.save();
      await pumps(tester);
      expect(marks(tester), hasLength(1));
      expect(tab(tester).saveState, SaveState.saved);

      final requests = fake.requests.length;
      await tester.tap(find.text('Mark edited text'));
      await pumps(tester);
      expect(marks(tester), isNull);
      expect(containerOf(tester).read(settingsProvider).markEdited, isFalse);
      // The switch asks nothing of the engine and leaves the file saved.
      expect(fake.requests.length, requests);
      expect(tab(tester).saveState, SaveState.saved);

      await notifier.save();
      await pumps(tester);
      expect(fake.files, hasLength(2));
      expect(fake.files.last, fake.files.first);
      expect(fake.files.first, contains('Değişti'));

      await tester.tap(find.text('Mark edited text'));
      await pumps(tester);
      expect(marks(tester), hasLength(1));
    });

    TextLine line(String text) => TextLine(
      text: text,
      bbox: Rect.zero,
      baselineStart: Offset.zero,
      baselineEnd: Offset.zero,
    );

    List<String> changed(List<String> before, List<String> now) => [
      for (final l in changedLines(before, [
        for (final text in now) line(text),
      ]))
        l.text,
    ];

    test('changedLines keeps out the lines that stayed the same', () {
      expect(changed(['a', 'b'], ['a', 'b']), isEmpty);
      expect(changed(['a', 'b', 'c'], ['a', 'x', 'c']), ['x']);
      expect(changed(['a', 'c'], ['a', 'b', 'c']), ['b']);
      expect(changed(['a', 'b', 'c'], ['a', 'c']), isEmpty);
      expect(changed(['a', 'a'], ['a', 'a', 'a']), ['a']);
      expect(changed(['a'], ['b', 'c']), ['b', 'c']);
    });
  });
}

/// Lets the engine's replies and the frames after them through.
Future<void> pumps(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

/// A fake whose render thread never reloads the revised document.
class _NoReload extends FakeEngineService {
  new({super.documents, super.pageBlocks});

  @override
  Future<RevisionInfo> commitEdit(int transaction, String name) async =>
      RevisionInfo(
        current: (await super.commitEdit(transaction, name)).current,
      );

  @override
  Future<RevisionInfo> undo(int document) async =>
      RevisionInfo(current: (await super.undo(document)).current);
}

/// A fake whose saves write what the engine holds, the page's text: all that
/// reaches a file, with or without the marks on.
class _SavedFile extends FakeEngineService {
  new({super.documents, super.pageBlocks});

  /// What each save wrote.
  final List<String> files = [];

  @override
  Future<String?> save(
    int document, {
    bool overChange = false,
    String? staging,
  }) async {
    final blocks = await textBlocks(document, 0);
    files.add(blocks.blocks.map((block) => block.text).join('\n'));
    return await super.save(document, overChange: overChange, staging: staging);
  }
}
