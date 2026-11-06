import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import '../viewer/text_layer_test.dart' show block;
import 'editor_test.dart' show pumps;

const OpenedDocument document = OpenedDocument(
  id: 9,
  pages: [PageInfo(width: 595, height: 842)],
  language: 'tr-TR',
);

/// Reading order against the page's geometry: the engine reads the lower
/// block first, as in a right-hand column read before a left-hand one.
final PageBlocks page = PageBlocks(
  blocks: [
    block(3, const Rect.fromLTRB(72, 300, 400, 324), [
      'Birinci satır',
      'İkinci satır',
    ]),
    block(1, const Rect.fromLTRB(72, 100, 300, 112), ['Madde 3']),
    block(5, const Rect.fromLTRB(72, 180, 300, 192), [
      'Kilitli',
    ], notEditable: NotEditableReason.imageOnly),
  ],
);

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<void> pumpEditor(
    WidgetTester tester, {
    SaveState saveState = SaveState.saved,
  }) async {
    final engine = FakeEngineService(
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
          ShellDocument(
            name: 'kira.pdf',
            path: '/kira.pdf',
            document: document,
            saveState: saveState,
            pageCount: 1,
          ),
        );
    containerOf(tester)
        .read(shellModeProvider.notifier)
        .select(FermanMode.edit);
    await settle(tester);
    await pumps(tester);
  }

  Finder node(int id) =>
      find.byKey(ValueKey<String>('DocumentView.block.0.$id'));

  testWidgets(
    'without a screen reader no blocks are asked for',
    semanticsEnabled: false,
    (tester) async {
      await pumpEditor(tester);
      expect(node(1), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets("each block is a node, in the engine's reading order", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpEditor(tester);
    final group = tester.getSemantics(node(3)).parent!;
    final labels = group
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .map((child) => child.getSemanticsData().label)
        .toList();
    expect(labels, ['Birinci satır\nİkinci satır', 'Madde 3', 'Kilitli']);
    final editable = tester.getSemantics(node(1)).getSemanticsData();
    expect(editable.locale, const Locale('tr', 'TR'));
    expect(editable.hasAction(SemanticsAction.tap), isTrue);
    final locked = tester.getSemantics(node(5)).getSemanticsData();
    expect(locked.hint, isNotEmpty);
    expect(locked.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('the active block is a multi-line field with its value, '
      'selection and language, in its place in the order', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpEditor(tester);
    tester
        .getSemantics(node(1))
        .owner!
        .performAction(tester.getSemantics(node(1)).id, SemanticsAction.tap);
    await pumps(tester);
    expect(
      containerOf(tester).read(documentEditorProvider).active?.block.id,
      1,
    );
    expect(node(1), findsNothing);

    final group = tester.getSemantics(node(3)).parent!;
    final order = group.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    );
    expect(order.first.getSemanticsData().label, startsWith('Birinci'));
    expect(order.last.getSemanticsData().label, 'Kilitli');

    SemanticsData? field;
    void walk(SemanticsNode at) {
      final data = at.getSemanticsData();
      if (data.flagsCollection.isTextField) field = data;
      at.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    walk(order[1]);
    expect(field, isNotNull);
    expect(field!.flagsCollection.isMultiline, isTrue);
    expect(field!.value, 'Madde 3');
    expect(field!.textSelection, isNotNull);
    expect(field!.locale, const Locale('tr', 'TR'));

    handle.dispose();
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets('a saving Save button says so', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpEditor(tester, saveState: SaveState.saving);
    final save = tester.getSemantics(find.text('Save')).getSemanticsData();
    expect(save.hint, 'Saving…');
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });
}
