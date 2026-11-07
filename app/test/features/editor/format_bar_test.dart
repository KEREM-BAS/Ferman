import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/block_editor.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/format_bar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';
import 'editor_test.dart' show document, page, pumps;

const BlockFont boldFace = BlockFont(
  origin: FontOrigin.embedded,
  postscriptName: 'FakeSerif-Bold',
);

const BlockStyleInfo plain = BlockStyleInfo(
  font: 'FakeSerif',
  family: 'FakeSerif',
  size: 11,
  frame: Rect.fromLTWH(0, 0, 100, 20),
  boldToggle: boldFace,
  documentColours: [0xC81E1E],
);

void main() {
  late FakeDesktopWindow window;
  late FakeEngineService engine;

  setUpAll(initializeRegionFormats);
  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<void> pumpEditor(WidgetTester tester) async {
    engine = FakeEngineService(
      documents: {'/kira.pdf': document},
      pageBlocks: {0: page},
    );
    engine.blockStyles[3] = plain;
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
    final at =
        tester.getTopLeft(find.byType(DocumentView)) +
        view.placement.rects.first!.topLeft -
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

  EditableText field(WidgetTester tester) => tester.widget<EditableText>(
    find.descendant(
      of: find.byType(BlockEditor),
      matching: find.byType(EditableText),
    ),
  );

  Future<void> select(WidgetTester tester) async {
    field(tester).controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  EditorState editor(WidgetTester tester) =>
      containerOf(tester).read(documentEditorProvider);

  Finder onBar(IconName icon) => find.descendant(
    of: find.byType(FormatBar),
    matching: find.byWidgetPredicate((w) => w is IconButton && w.icon == icon),
  );

  IconButton button(WidgetTester tester, IconName icon) =>
      tester.widget<IconButton>(onBar(icon));

  testWidgets('a selection opens the bar, and Esc closes it, then editing', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(find.byType(FormatBar), findsNothing);
    await select(tester);
    expect(find.byType(FormatBar), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(find.byType(FormatBar), findsNothing);
    expect(editor(tester).active, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await pumps(tester);
    expect(editor(tester).active, isNull);
  });

  testWidgets('a double-click selects a word and opens the bar', (
    tester,
  ) async {
    await pumpEditor(tester);
    final at =
        tester.getTopLeft(find.byType(EditableText).first) +
        const Offset(10, 6);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.down(at);
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.down(at);
    await mouse.up();
    await mouse.removePointer();
    await pumps(tester);
    expect(field(tester).controller.selection.isCollapsed, isFalse);
    expect(find.byType(FormatBar), findsOneWidget);
  });

  testWidgets('Bold is one step of the block, and the field stays open', (
    tester,
  ) async {
    await pumpEditor(tester);
    await select(tester);
    await tester.tap(onBar(IconName.bold));
    await pumps(tester);
    expect(engine.styles.single.font, boldFace);
    expect(editor(tester).history.steps.single.name, contains('page 1'));
    expect(editor(tester).active, isNotNull);
    expect(field(tester).focusNode.hasFocus, isTrue);
    expect(find.byType(FormatBar), findsOneWidget);
    expect(field(tester).controller.selection.extentOffset, 4);
  });

  testWidgets('after typing, a style that changes the ids keeps the editor', (
    tester,
  ) async {
    await pumpEditor(tester);
    engine.newIdsOnStyle = true;
    final typed = '${field(tester).controller.text} x';
    field(tester).controller.text = typed;
    await pumps(tester);
    await select(tester);
    await tester.tap(onBar(IconName.bold));
    await pumps(tester);
    expect(editor(tester).active?.block.text, typed);
    expect(editor(tester).active?.block.id, isNot(page.blocks.first.id));
    expect(field(tester).controller.text, typed);
  });

  testWidgets('the colour popover keeps the editor and applies the colour', (
    tester,
  ) async {
    await pumpEditor(tester);
    await select(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(FormatBar),
        matching: find.byType(ToolButton),
      ),
    );
    await pumps(tester);
    expect(editor(tester).active, isNotNull);
    expect(editor(tester).held, isTrue);
    await tester.tap(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == '#C81E1E',
            ),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    await pumps(tester);
    expect(engine.styles.single.colour, 0xC81E1E);
    expect(editor(tester).held, isFalse);
    expect(editor(tester).active, isNotNull);
  });

  testWidgets('what waits for later is disabled with its reason', (
    tester,
  ) async {
    await pumpEditor(tester);
    await select(tester);
    for (final icon in [IconName.link, IconName.replace]) {
      expect(
        button(tester, icon).disabledReason,
        'Available in a future version',
      );
    }
    expect(button(tester, IconName.highlighter).onPressed, isNotNull);
    expect(button(tester, IconName.messageSquare).onPressed, isNotNull);
    expect(button(tester, IconName.underline).onPressed, isNull);
    expect(button(tester, IconName.italic).onPressed, isNull);
    expect(button(tester, IconName.bold).onPressed, isNotNull);
  });
}
