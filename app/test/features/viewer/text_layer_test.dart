import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';

const OpenedDocument document = OpenedDocument(
  id: 9,
  pages: [PageInfo(width: 595, height: 842)],
);

TextBlock block(
  int id,
  Rect frame,
  List<String> lines, {
  NotEditableReason? notEditable,
}) {
  final height = frame.height / lines.length;
  return TextBlock(
    id: id,
    frame: frame,
    notEditable: notEditable,
    lines: [
      for (final (i, text) in lines.indexed)
        TextLine(
          text: text,
          bbox: Rect.fromLTWH(
            frame.left,
            frame.top + i * height,
            frame.width,
            height,
          ),
          baselineStart: Offset(frame.left, frame.top + (i + 1) * height),
          baselineEnd: Offset(frame.right, frame.top + (i + 1) * height),
        ),
    ],
  );
}

/// A page with an editable heading, text drawn as shapes and an editable
/// two-line paragraph.
final PageBlocks contract = PageBlocks(
  blocks: [
    block(1, const Rect.fromLTRB(72, 100, 300, 112), ['Madde 3 — Kira bedeli']),
    block(2, const Rect.fromLTRB(72, 200, 300, 230), [
      'KİRA',
    ], notEditable: NotEditableReason.outlinedText),
    block(3, const Rect.fromLTRB(72, 300, 400, 324), [
      'Birinci satır',
      'İkinci satır',
    ]),
  ],
);

void main() {
  late FakeDesktopWindow window;
  late List<String> copied;

  setUp(() {
    window = FakeDesktopWindow(WindowPlatform.linux);
    copied = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });
  tearDown(() {
    window.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpDocument(
    WidgetTester tester, {
    PageBlocks blocks = const PageBlocks(),
    FermanMode mode = FermanMode.view,
    OpenedDocument shown = document,
    Map<int, PageBlocks>? pages,
  }) async {
    final engine = FakeEngineService(
      documents: {'/kira.pdf': shown},
      pageBlocks: pages ?? {0: blocks},
    );
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        overrides: [engineServiceProvider.overrideWithValue(engine)],
      ),
    );
    containerOf(tester).read(openDocumentProvider.notifier).show(shown);
    containerOf(tester).read(shellModeProvider.notifier).select(mode);
    await settle(tester);
  }

  /// Where page space's [point] of the first page is on screen.
  Offset onScreen(WidgetTester tester, Offset point) {
    final view = containerOf(tester).read(viewerProvider)!;
    final page = view.placement.rects.first!;
    return tester.getTopLeft(find.byType(DocumentView)) +
        page.topLeft -
        view.offset +
        point * view.scale;
  }

  Future<TestGesture> hover(WidgetTester tester, Offset point) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(
      location: tester.getTopLeft(find.byType(DocumentView)),
    );
    await mouse.moveTo(onScreen(tester, point));
    await tester.pump();
    // The blocks arrive, and the hover follows them.
    await tester.pump();
    return mouse;
  }

  MouseCursor cursor() =>
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;

  testWidgets('Edit mode frames only the block under the pointer, with the '
      'I-beam and its tooltip', (tester) async {
    await pumpDocument(tester, blocks: contract, mode: FermanMode.edit);
    final mouse = await hover(tester, const Offset(100, 106));
    expect(find.byType(TextEditBox), findsOneWidget);
    expect(
      tester.widget<TextEditBox>(find.byType(TextEditBox)).state,
      TextEditBoxState.hover,
    );
    expect(find.textContaining('Click to edit · '), findsOneWidget);
    expect(find.textContaining('Madde 3 — Kira bedeli'), findsOneWidget);
    expect(cursor(), SystemMouseCursors.text);
    expect(find.text('This text can’t be edited'), findsNothing);

    // Off the blocks: no frame, no tooltip.
    await mouse.moveTo(onScreen(tester, const Offset(500, 150)));
    await tester.pump();
    expect(find.byType(TextEditBox), findsNothing);
    expect(find.textContaining('Click to edit'), findsNothing);

    // A click on a block places the engine's caret.
    await mouse.moveTo(onScreen(tester, const Offset(72, 106)));
    await mouse.down(onScreen(tester, const Offset(72, 106)));
    await mouse.up();
    await tester.pump();
    expect(find.byType(TextCaret), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('text that cannot be edited shows not-allowed, its reason and '
      'the panel callout', (tester) async {
    await pumpDocument(tester, blocks: contract, mode: FermanMode.edit);
    final mouse = await hover(tester, const Offset(100, 215));
    expect(cursor(), SystemMouseCursors.forbidden);
    expect(find.byType(TextEditBox), findsNothing);
    expect(
      find.text('This text is drawn as shapes, so it can’t be edited'),
      findsOneWidget,
    );
    final panel = find.byType(FmDocPanel);
    expect(
      find.descendant(
        of: panel,
        matching: find.text('This text can’t be edited'),
      ),
      findsOneWidget,
    );
    // Empty space keeps the callout; editable text takes it away.
    await mouse.moveTo(onScreen(tester, const Offset(500, 150)));
    await tester.pump();
    expect(find.text('This text can’t be edited'), findsOneWidget);
    await mouse.moveTo(onScreen(tester, const Offset(100, 106)));
    await tester.pump();
    expect(find.text('This text can’t be edited'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('a scanned page offers Recognize text, disabled until P3', (
    tester,
  ) async {
    await pumpDocument(
      tester,
      blocks: const PageBlocks(empty: NotEditableReason.imageOnly),
      mode: FermanMode.edit,
    );
    final mouse = await hover(tester, const Offset(300, 400));
    expect(cursor(), SystemMouseCursors.forbidden);
    expect(
      find.text('No text on this page yet · Recognize text to edit'),
      findsOneWidget,
    );
    final recognize = find.ancestor(
      of: find.text('Recognize text (OCR)'),
      matching: find.byType(Button),
    );
    expect(
      find.descendant(of: find.byType(FmDocPanel), matching: recognize),
      findsOneWidget,
    );
    expect(tester.widget<Button>(recognize).disabledReason, futureVersion);
    await mouse.removePointer();
  });

  testWidgets('the Select tool selects text by dragging and copies it', (
    tester,
  ) async {
    await pumpDocument(tester, blocks: contract);
    // The pointer over a page brings its blocks.
    final mouse = await hover(tester, const Offset(73, 106));
    expect(cursor(), SystemMouseCursors.text);
    await mouse.down(onScreen(tester, const Offset(73, 106)));
    await tester.pump();
    await mouse.moveTo(onScreen(tester, const Offset(236, 318)));
    await tester.pump();
    await tester.pump();
    final selection = containerOf(tester).read(canvasSelectionProvider)!;
    expect(
      selection.text,
      'Madde 3 — Kira bedeli\nKİRA\nBirinci satır\nİkinci',
    );
    expect(selection.quads, hasLength(4));
    await mouse.up();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(copied, ['Madde 3 — Kira bedeli\nKİRA\nBirinci satır\nİkinci']);

    // The context menu's Copy.
    await mouse.removePointer();
    final right = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await right.down(onScreen(tester, const Offset(150, 106)));
    await right.up();
    await tester.pump();
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, hasLength(2));
    expect(find.text('Copy'), findsNothing);

    // A click elsewhere clears the selection.
    final click = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await click.down(onScreen(tester, const Offset(500, 150)));
    await click.up();
    await tester.pump();
    expect(containerOf(tester).read(canvasSelectionProvider), isNull);
  });

  testWidgets('the owner password makes restricted text editable at once', (
    tester,
  ) async {
    const restricted = OpenedDocument(
      id: 9,
      pages: [PageInfo(width: 595, height: 842)],
      security: Security(method: EncryptionMethod.aes128, restricted: true),
    );
    final pages = {
      0: PageBlocks(
        blocks: [
          block(1, const Rect.fromLTRB(72, 100, 300, 112), [
            'Madde 3',
          ], notEditable: NotEditableReason.restricted),
        ],
      ),
    };
    await pumpDocument(
      tester,
      shown: restricted,
      pages: pages,
      mode: FermanMode.edit,
    );
    final mouse = await hover(tester, const Offset(100, 106));
    expect(cursor(), SystemMouseCursors.forbidden);
    expect(find.text('This text can’t be edited'), findsOneWidget);

    // The engine now answers without the restriction.
    pages[0] = contract;
    containerOf(tester)
        .read(openDocumentProvider.notifier)
        .show(
          restricted.withSecurity(
            const Security(method: EncryptionMethod.aes128, owner: true),
          ),
        );
    await tester.pump();
    await tester.pump();
    expect(cursor(), SystemMouseCursors.text);
    expect(find.text('This text can’t be edited'), findsNothing);
    await mouse.removePointer();
  });
}
