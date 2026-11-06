import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/edit_panel.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import 'editor_test.dart' show document, page, pumps;

const plain = BlockStyleInfo(
  font: 'FakeSerif',
  family: 'FakeSerif',
  size: 11,
  frame: Rect.fromLTWH(0, 0, 100, 20),
);

void main() {
  late FakeDesktopWindow window;
  late FakeEngineService engine;

  setUpAll(initializeRegionFormats);
  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  /// kira.pdf in Edit mode with its paragraph (block 3) open, [style] its
  /// style.
  Future<void> pumpPanel(
    WidgetTester tester, {
    BlockStyleInfo style = plain,
  }) async {
    engine = FakeEngineService(
      documents: {'/kira.pdf': document},
      pageBlocks: {0: page},
    );
    engine.blockStyles[3] = style;
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
    final view = containerOf(tester).read(viewerProvider)!;
    final rect = view.placement.rects.first!;
    final at =
        tester.getTopLeft(find.byType(DocumentView)) +
        rect.topLeft -
        view.offset +
        const Offset(100, 306) * view.scale;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getTopLeft(find.byType(DocumentView)),
    );
    await mouse.moveTo(at);
    await tester.pump();
    await tester.pump();
    await mouse.down(at);
    await mouse.up();
    await mouse.removePointer();
    await pumps(tester);
  }

  EditorState editor(WidgetTester tester) =>
      containerOf(tester).read(documentEditorProvider);

  DocumentEditor notifier(WidgetTester tester) =>
      containerOf(tester).read(documentEditorProvider.notifier);

  IconButton button(WidgetTester tester, IconName icon) =>
      tester.widget<IconButton>(
        find.byWidgetPredicate((w) => w is IconButton && w.icon == icon),
      );

  testWidgets('the panel takes the right panel while a block is edited', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(find.byType(FmEditPanel), findsOneWidget);
    expect(find.text('Text block'), findsOneWidget);
    expect(find.text('FakeSerif'), findsOneWidget);
    // The field and the panel's number fields each have their own text.
    expect(find.byType(EditableText), findsWidgets);
  });

  testWidgets('a style is one step, undo takes it back, and the panel stays', (
    tester,
  ) async {
    await pumpPanel(tester);
    await tester.runAsync(
      () =>
          notifier(tester)
              .setBlockStyle(const BlockStyle(colour: 0xC81E1E), name: 'Style'),
    );
    await pumps(tester);
    expect(engine.styles.single.colour, 0xC81E1E);
    expect(editor(tester).history.current, 1);
    expect(editor(tester).history.steps.single.name, 'Style');
    expect(editor(tester).active, isNotNull);
    expect(editor(tester).style?.colour, 0xC81E1E);
    expect(find.byType(FmEditPanel), findsOneWidget);
    await tester.runAsync(() => notifier(tester).undo());
    await pumps(tester);
    expect(editor(tester).history.current, 0);
  });

  testWidgets('a move and a resize take the new box', (tester) async {
    await pumpPanel(tester);
    final before = editor(tester).active!.block.frame;
    await tester.runAsync(
      () => notifier(tester).moveBlock(const Offset(10, 4), name: 'Move'),
    );
    await pumps(tester);
    expect(
      editor(tester).active?.block.frame,
      before.shift(const Offset(10, 4)),
    );
    final moved = editor(tester).active!.block.frame;
    final wider = Rect.fromLTWH(
      moved.left,
      moved.top,
      moved.width + 20,
      moved.height,
    );
    await tester.runAsync(
      () => notifier(tester).resizeBlock(wider, name: 'Resize'),
    );
    await pumps(tester);
    expect(editor(tester).active?.block.frame, wider);
    expect(editor(tester).history.current, 2);
  });

  testWidgets("a handle's drag resizes the block (B016)", (tester) async {
    await pumpPanel(tester);
    final before = editor(tester).active!.block.frame;
    final scale = containerOf(tester).read(viewerProvider)!.scale;
    // From top-start around, the end edge's middle is the fourth.
    await tester.drag(
      find.byKey(const ValueKey<String>('TextEditBox.handle')).at(3),
      const Offset(40, 0),
      touchSlopX: 0,
    );
    await pumps(tester);
    final after = editor(tester).active!.block.frame;
    expect(after.left, before.left);
    expect(
      after.width,
      moreOrLessEquals(before.width + 40 / scale, epsilon: 1),
    );
    expect(editor(tester).history.current, 1);
  });

  testWidgets('a font that cannot draw the block adds no step', (tester) async {
    await pumpPanel(tester);
    await tester.runAsync(
      () => notifier(tester).setBlockStyle(
        const BlockStyle(
          font: BlockFont(
            origin: FontOrigin.bundled,
            postscriptName: 'Missing',
          ),
        ),
        name: 'Style',
      ),
    );
    await pumps(tester);
    expect(editor(tester).history.current, 0);
    expect(editor(tester).active, isNotNull);
  });

  testWidgets('Bold and Italic are disabled with the reason without a real '
      'face, and Underline always is', (tester) async {
    await pumpPanel(tester);
    expect(button(tester, IconName.bold).onPressed, isNull);
    expect(button(tester, IconName.bold).disabledReason, isNotNull);
    expect(button(tester, IconName.italic).disabledReason, isNotNull);
    expect(button(tester, IconName.underline).disabledReason, isNotNull);
  });

  testWidgets('Bold sets the block in the real face', (tester) async {
    const bold = BlockFont(
      origin: FontOrigin.bundled,
      postscriptName: 'FakeSerif-Bold',
    );
    await pumpPanel(
      tester,
      style: const BlockStyleInfo(
        font: 'FakeSerif',
        family: 'FakeSerif',
        size: 11,
        frame: Rect.fromLTWH(0, 0, 100, 20),
        boldToggle: bold,
      ),
    );
    button(tester, IconName.bold).onPressed!();
    await pumps(tester);
    expect(engine.styles.single.font, bold);
  });
}
