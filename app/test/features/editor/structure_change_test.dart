import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/review_list.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import '../viewer/text_layer_test.dart' show block;
import 'editor_test.dart' show pumps;

const PageInfo first = PageInfo(width: 595, height: 842, handle: 70000);
const PageInfo second = PageInfo(width: 595, height: 842, handle: 80000);
const OpenedDocument document = OpenedDocument(id: 9, pages: [first, second]);

void main() {
  late FakeDesktopWindow window;
  late FakeEngineService engine;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    engine = FakeEngineService(
      documents: {'/kira.pdf': document},
      pageBlocks: {
        1: PageBlocks(
          blocks: [
            block(1, const Rect.fromLTRB(72, 100, 300, 112), ['Madde 3']),
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
            pageCount: 2,
          ),
        );
    containerOf(tester)
        .read(shellModeProvider.notifier)
        .select(FermanMode.edit);
    await settle(tester);
  }

  /// Commits a change of the block on page 2 through the editor.
  Future<void> editSecondPage(WidgetTester tester) async {
    final notifier = containerOf(tester).read(documentEditorProvider.notifier);
    final blocks = await engine.textBlocks(document.id, 1);
    await notifier.open(1, blocks.blocks.single, caret: 0, name: 'Edited');
    notifier.type('Madde 4');
    await notifier.finish();
    await pumps(tester);
  }

  testWidgets('a commit on one page asks again only for that page', (
    tester,
  ) async {
    await pump(tester);
    await pumps(tester);
    Set<RenderItem> asked() => {
      for (final set in engine.requests)
        for (final entry in set) entry.item,
    };
    final drawn = asked();
    // Bitmaps decode outside the test's clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(drawn.map((item) => item.page), containsAll(<int>[0, 1]));
    engine.requests.clear();
    engine.nextChangedPages = [1];
    await editSecondPage(tester);
    final again = asked().intersection(drawn);
    expect(again, isNotEmpty);
    expect(again.map((item) => item.page).toSet(), {
      1,
    }, reason: "page 0's bitmaps stay");
    expect(containerOf(tester).read(documentEditorProvider).changedPages, [1]);
  });

  testWidgets('a revision that changes the pages reaches the tab, the canvas '
      'and a running search, and a step keeps its page by handle', (
    tester,
  ) async {
    await pump(tester);
    final container = containerOf(tester);
    await editSecondPage(tester);

    final steps = container.read(documentEditorProvider).history.steps;
    expect(steps.single.pages, [second.handle]);
    OpenedDocument? shown() => container.read(viewerProvider)?.document;
    expect(
      reviewRows(
        container.read(documentEditorProvider).history,
        shown(),
      ).first.page,
      1,
    );

    container.read(findProvider.notifier).setQuery('Madde');
    await pumps(tester);
    final searches = engine.searches.length;

    // The page that was second now comes first, and is on its side; a third
    // page joined them.
    const third = PageInfo(width: 300, height: 200, handle: 90000);
    engine.nextStructure = const DocumentStructure(
      pages: [PageInfo(width: 842, height: 595, handle: 80000), first, third],
    );
    await container.read(documentEditorProvider.notifier).undo();
    await pumps(tester);

    expect(shown()?.pages.length, 3);
    expect(
      container.read(viewerProvider)?.pageSizes.first,
      const Size(842, 595),
    );
    expect(container.read(shellDocumentsProvider).active?.pageCount, 3);
    expect(
      engine.searches.length,
      searches + 1,
      reason: 'the search ran again',
    );
    expect(shown()?.pageIndexOf(second.handle!), 0);
    expect(shown()?.pageIndexOf(70001), isNull);

    await container.read(documentEditorProvider.notifier).redo();
    await pumps(tester);
    expect(
      reviewRows(
        container.read(documentEditorProvider).history,
        shown(),
      ).first.page,
      0,
      reason: 'the step follows its page',
    );
  });

  test('a page without a handle answers to its index', () {
    const plain = OpenedDocument(
      id: 1,
      pages: [PageInfo(width: 1, height: 1), PageInfo(width: 1, height: 1)],
    );
    expect(plain.pageHandle(1), 1);
    expect(plain.pageIndexOf(1), 1);
    expect(plain.pageIndexOf(2), isNull);
  });
}
