import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/review_list.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import '../viewer/text_layer_test.dart' show block;
import 'editor_test.dart' show pumps;

const OpenedDocument document = OpenedDocument(
  id: 9,
  pages: [PageInfo(width: 595, height: 842)],
);

void main() {
  late FakeDesktopWindow window;
  late FakeEngineService engine;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<void> pumpReview(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    engine = FakeEngineService(
      documents: {'/kira.pdf': document},
      pageBlocks: {
        0: PageBlocks(
          blocks: [
            block(1, const Rect.fromLTRB(72, 100, 300, 112), ['Madde 3']),
            block(3, const Rect.fromLTRB(72, 300, 400, 312), ['18.500 TL']),
          ],
        ),
      },
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

  EditorState editor(WidgetTester tester) =>
      containerOf(tester).read(documentEditorProvider);

  /// Commits [text] into block [id] through the editor, as typing does.
  Future<void> edit(WidgetTester tester, int id, String text) async {
    final notifier = containerOf(tester).read(documentEditorProvider.notifier);
    final blocks = await engine.textBlocks(document.id, 0);
    await notifier.open(
      0,
      blocks.blocks.firstWhere((candidate) => candidate.id == id),
      caret: 0,
      name: 'Edited text · page 1',
    );
    notifier.type(text);
    await notifier.finish();
    await pumps(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await pumps(tester);
  }

  Button button(WidgetTester tester, String label) =>
      tester.widget<Button>(find.widgetWithText(Button, label));

  test('changedWords keeps the words that changed', () {
    expect(
      changedWords(
        'Bedel 18.500 TL aylık\nodenir',
        'Bedel 19.500 TL aylık\nodenir',
      ),
      ('18.500', '19.500'),
    );
    expect(changedWords('Madde 3', 'Madde 3 ek'), ('3', '3 ek'));
    expect(changedWords('', 'yeni'), ('', 'yeni'));
  });

  test('live leaves out reverted steps, reverts and undone steps', () {
    final time = DateTime(2026);
    final steps = [
      HistoryStep(name: 'a', time: time),
      HistoryStep(name: 'b', time: time),
      HistoryStep(name: 'r', time: time, reverts: const [0]),
      HistoryStep(name: 'c', time: time),
    ];
    expect(EditHistory(steps: steps, current: 4).live, [1, 3]);
    expect(EditHistory(steps: steps, current: 2).live, [0, 1]);
  });

  test('a step that kept a warning has its text row and a warning row', () {
    final rows = reviewRows(
      EditHistory(
        steps: [
          HistoryStep(
            name: 'n',
            time: DateTime(2026),
            page: 0,
            before: 'a',
            after: 'b',
            hiddenLines: 2,
          ),
        ],
        current: 1,
      ),
    );
    expect(rows.map((row) => row.kind), [
      ReviewRowKind.text,
      ReviewRowKind.warning,
    ]);
    expect(rows.last.hiddenLines, 2);
  });

  testWidgets('Review edits opens the empty list, with its footer disabled, '
      'in the right panel’s place', (tester) async {
    await pumpReview(tester);
    expect(find.byType(ReviewListPanel), findsNothing);
    await tapText(tester, 'Review edits');
    expect(find.byType(ReviewListPanel), findsOneWidget);
    expect(find.byType(FmDocPanel), findsNothing);
    expect(find.text('No edits yet'), findsOneWidget);
    expect(button(tester, 'Revert all…').onPressed, isNull);
    expect(button(tester, 'Export list…').onPressed, isNull);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.label == 'Close review',
      ),
    );
    await pumps(tester);
    expect(find.byType(ReviewListPanel), findsNothing);
  });

  testWidgets('a row reverts alone and Undo brings it back', (tester) async {
    await pumpReview(tester);
    await edit(tester, 1, 'Madde 4');
    await edit(tester, 3, '19.500 TL');
    await tapText(tester, 'Review edits');
    expect(find.text('Go to'), findsNWidgets(2));
    expect(find.text('Page 1 · text'), findsNWidgets(2));

    await tester.tap(find.text('Revert').first);
    await pumps(tester);
    expect(find.text('Revert'), findsOneWidget);
    final history = editor(tester).history;
    expect(history.steps.last.reverts, [0]);
    expect(history.live, [1]);
    expect(
      containerOf(tester).read(shellDocumentsProvider).active!.editCount,
      1,
    );
    final blocks = await engine.textBlocks(document.id, 0);
    expect(blocks.blocks.first.text, 'Madde 3');

    await containerOf(tester).read(documentEditorProvider.notifier).undo();
    await pumps(tester);
    expect(find.text('Revert'), findsNWidgets(2));
  });

  testWidgets('an edit a later one depends on asks, and Revert both takes '
      'both or Cancel neither', (tester) async {
    await pumpReview(tester);
    await edit(tester, 3, '19.500 TL');
    await edit(tester, 3, '19.500 TL (on dokuz bin)');
    await tapText(tester, 'Review edits');

    await tester.tap(find.text('Revert').first);
    await pumps(tester);
    expect(find.text('Also revert the edit that depends on it?'), findsOne);
    expect(editor(tester).history.steps, hasLength(2));

    await tapText(tester, 'Cancel');
    expect(find.text('Revert both'), findsNothing);
    expect(editor(tester).history.live, [0, 1]);

    await tester.tap(find.text('Revert').first);
    await pumps(tester);
    await tapText(tester, 'Revert both');
    expect(editor(tester).history.live, isEmpty);
    expect(editor(tester).history.steps.last.reverts, [0, 1]);
    expect(find.text('No edits yet'), findsOneWidget);
  });

  testWidgets('Revert all asks first', (tester) async {
    await pumpReview(tester);
    await edit(tester, 1, 'Madde 4');
    await edit(tester, 3, '19.500 TL');
    await tapText(tester, 'Review edits');
    await tapText(tester, 'Revert all…');
    expect(find.text('Revert all 2 edits?'), findsOneWidget);
    expect(editor(tester).history.live, [0, 1]);
    await tapText(tester, 'Revert 2 edits');
    expect(editor(tester).history.live, isEmpty);
    expect(find.text('No edits yet'), findsOneWidget);
    final blocks = await engine.textBlocks(document.id, 0);
    expect(blocks.blocks.first.text, 'Madde 3');
  });

  testWidgets('the filter leaves the rows of its kind', (tester) async {
    await pumpReview(tester);
    await edit(tester, 1, 'Madde 4');
    await tapText(tester, 'Review edits');
    expect(find.text('Page 1 · text'), findsOneWidget);
    await tapText(tester, 'Warnings');
    expect(find.text('Page 1 · text'), findsNothing);
    await tapText(tester, 'Text');
    expect(find.text('Page 1 · text'), findsOneWidget);
  });
}
