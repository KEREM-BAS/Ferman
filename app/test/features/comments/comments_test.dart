import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_overlay.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/comments/comment_style_bar.dart';
import 'package:ferman/features/comments/commenter_name_dialog.dart';
import 'package:ferman/features/comments/comments_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';

const String _path = '/docs/kira.pdf';
const int _document = 9;

const OpenedDocument _opened = OpenedDocument(
  id: _document,
  pages: [
    PageInfo(width: 595, height: 842, handle: 100),
    PageInfo(width: 595, height: 842, handle: 101),
  ],
);

const AnnotationColor _red = AnnotationColor(0.85, 0.23, 0.17);

const AnnotationInfo _rectangle = AnnotationInfo(
  handle: 1,
  page: 100,
  kind: AnnotationKind.square,
  rect: Rect.fromLTWH(100, 100, 200, 80),
  thread: 1,
  color: _red,
  stroke: 2,
  author: 'Av. Deniz Aksoy',
  contents: 'TBK m. 342',
  quote: 'Madde 5',
);

const AnnotationInfo _note = AnnotationInfo(
  handle: 2,
  page: 101,
  kind: AnnotationKind.note,
  rect: Rect.fromLTWH(50, 50, 24, 24),
  thread: 2,
  author: 'Mert Kaya',
  contents: 'Artış oranı',
);

const AnnotationInfo _reply = AnnotationInfo(
  handle: 3,
  page: 101,
  kind: AnnotationKind.note,
  rect: Rect.fromLTWH(50, 50, 24, 24),
  thread: 2,
  repliesTo: 2,
  author: 'Ayşe Yılmaz',
  contents: 'Katılıyorum @Mert Kaya',
  mentions: ['Mert Kaya'],
);

const AnnotationInfo _resolved = AnnotationInfo(
  handle: 4,
  page: 100,
  kind: AnnotationKind.highlight,
  rect: Rect.fromLTWH(100, 300, 100, 14),
  thread: 4,
  resolved: true,
  resolvedBy: 'Mert Kaya',
  author: 'Mert Kaya',
);

FakeEngineService _engine({
  List<AnnotationInfo> annotations = const [
    _rectangle,
    _note,
    _reply,
    _resolved,
  ],
}) =>
    FakeEngineService(documents: {_path: _opened})
      ..initialAnnotations[_document] = annotations;

/// The app in Comment mode with the document open and the name settled.
Future<ProviderContainer> _open(
  WidgetTester tester,
  FakeEngineService engine, {
  String? name = 'Elif',
}) async {
  await pumpFermanApp(
    tester,
    engine: engine,
    home: '/docs',
    picker: FakeFilePickerService(picked: const [_path]),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FmStart)),
  );
  if (name != null) {
    await container
        .read(settingsProvider.notifier)
        .change((old) => old.copyWith(commenterName: name));
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  container.read(shellModeProvider.notifier).select(FermanMode.comment);
  await tester.pumpAndSettle();
  return container;
}

/// Where the point [point] of page [page] is on the screen.
Offset _at(
  ProviderContainer container,
  WidgetTester tester,
  Offset point, {
  int page = 0,
}) {
  final view = container.read(viewerProvider)!;
  final rect = view.placement.rects[page]!;
  final origin = tester.getTopLeft(find.byType(CommentOverlay));
  return origin + rect.topLeft + point * view.scale - view.offset;
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<List<AnnotationInfo>> _list(FakeEngineService engine) async =>
    (await engine.annotations(_document)).annotations;

void main() {
  testWidgets('the panel lists open threads under their pages, with counts', (
    tester,
  ) async {
    await _open(tester, _engine());
    expect(find.byType(CommentsPanel), findsOneWidget);
    expect(find.text('Open 2'), findsOneWidget);
    expect(find.text('Resolved 1'), findsOneWidget);
    expect(find.text('All 3'), findsOneWidget);
    expect(find.text('TBK m. 342'), findsOneWidget);
    expect(find.text('“Madde 5”'), findsOneWidget);
    expect(find.text('1 reply'), findsOneWidget);
    // The state reply and the resolved thread are out.
    expect(find.byType(CommentCard), findsNWidgets(2));
  });

  testWidgets('an empty document and a filter with no match say so', (
    tester,
  ) async {
    await _open(tester, _engine(annotations: const []));
    expect(find.text('No comments'), findsOneWidget);
  });

  testWidgets('a filter with no match says so', (tester) async {
    await _open(tester, _engine(annotations: const [_rectangle]));
    await tester.tap(find.text('Resolved 0'));
    await tester.pumpAndSettle();
    expect(find.text('No comments match'), findsOneWidget);
  });

  testWidgets('a card selects its mark by handle, and shows its page', (
    tester,
  ) async {
    final container = await _open(tester, _engine());
    await tester.tap(find.text('Mert Kaya').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(container.read(commentSelectionProvider)?.handle, 2);
    expect(container.read(viewerProvider)?.currentPage, 1);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
  });

  testWidgets('a reply is a step; a resolve moves the thread out of Open', (
    tester,
  ) async {
    final engine = _engine();
    final container = await _open(tester, engine);
    await tester.tap(find.text('Mert Kaya').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Tamam');
    await tester.pump();
    await tester.tap(find.widgetWithText(Button, 'Reply'));
    await tester.pumpAndSettle();
    expect((await _list(engine)).last.contents, 'Tamam');
    expect((await _list(engine)).last.author, 'Elif');

    await tester.tap(find.widgetWithText(Button, 'Resolve'));
    await tester.pumpAndSettle();
    expect(find.text('Open 1'), findsOneWidget);
    await tester.tap(find.text('Resolved 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Elif'), findsWidgets);
    expect(container.read(commentSelectionProvider)?.handle, 2);
  });

  testWidgets('typing @ suggests the file’s people and puts the name in', (
    tester,
  ) async {
    await _open(tester, _engine());
    await tester.tap(find.text('Mert Kaya').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    await tester.enterText(field, 'Selam @Me');
    await tester.pumpAndSettle();
    expect(find.text('People in this document'), findsOneWidget);
    await tester.tap(find.text('Mert Kaya').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field).controller!.text,
      'Selam @Mert Kaya ',
    );
  });

  testWidgets('dragging a shape adds it in one step and selects it', (
    tester,
  ) async {
    final engine = _engine(annotations: const []);
    final container = await _open(tester, engine);
    container.read(commentToolProvider.notifier).shape(ShapeTool.rectangle);
    await tester.pump();
    await _drag(
      tester,
      _at(container, tester, const Offset(100, 100)),
      _at(container, tester, const Offset(200, 160)),
    );
    final added = (await _list(engine)).single;
    expect(added.kind, AnnotationKind.square);
    expect(added.rect.width, closeTo(100, 1));
    expect(added.author, 'Elif');
    expect(container.read(commentSelectionProvider)?.handle, added.handle);
    // Shapes go back to Select unless kept.
    expect(container.read(commentToolProvider).tool, AnnotationTool.select);
    expect(find.byType(CommentStyleBar), findsOneWidget);
    expect((await engine.history(_document)).current, 1);
  });

  testWidgets('a stroke commits once, at the end of the drag', (tester) async {
    final engine = _engine(annotations: const []);
    final container = await _open(tester, engine);
    container.read(commentToolProvider.notifier).pick(AnnotationTool.pen);
    await tester.pump();
    final gesture = await tester.startGesture(
      _at(container, tester, const Offset(100, 100)),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i < 5; i++) {
      await gesture.moveBy(const Offset(10, 4));
      await tester.pump();
      expect(await _list(engine), isEmpty);
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final ink = (await _list(engine)).single;
    expect(ink.kind, AnnotationKind.ink);
    expect(ink.points.single.length, 5);
    expect(container.read(commentToolProvider).tool, AnnotationTool.pen);
  });

  testWidgets('a click selects a mark, a drag moves it in one step', (
    tester,
  ) async {
    final engine = _engine();
    final container = await _open(tester, engine);
    container.read(commentToolProvider.notifier).pick(AnnotationTool.select);
    await tester.pump();
    final view = container.read(viewerProvider)!;
    await _drag(
      tester,
      _at(container, tester, const Offset(150, 140)),
      _at(container, tester, const Offset(170, 150)),
    );
    expect(container.read(commentSelectionProvider)?.handle, 1);
    final moved = (await _list(engine)).first;
    expect(moved.rect.left, closeTo(120, 2 / view.scale + 0.5));
    expect(moved.rect.top, closeTo(110, 2 / view.scale + 0.5));
    expect(moved.contents, 'TBK m. 342');
  });

  testWidgets('the style bar changes one thing, Delete offers Undo', (
    tester,
  ) async {
    final engine = _engine();
    final container = await _open(tester, engine);
    container.read(commentToolProvider.notifier).pick(AnnotationTool.select);
    container.read(commentSelectionProvider.notifier).select(1);
    await tester.pumpAndSettle();
    await container
        .read(commentCommandsProvider.notifier)
        .update(1, const AnnotationChange(opacity: 0.6));
    await tester.pumpAndSettle();
    expect((await _list(engine)).first.opacity, 0.6);

    await tester.tap(
      find.descendant(
        of: find.byType(CommentStyleBar),
        matching: find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.label == 'Delete',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (await _list(engine)).map((annotation) => annotation.handle),
      isNot(contains(1)),
    );
    expect(container.read(commentSelectionProvider), isNull);
    expect(find.text('Comment deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      (await _list(engine)).map((annotation) => annotation.handle),
      contains(1),
    );
  });

  testWidgets('a note’s pin opens it on the page, Esc closes it', (
    tester,
  ) async {
    final container = await _open(tester, _engine());
    container.read(commentToolProvider.notifier).pick(AnnotationTool.select);
    container.read(viewerProvider.notifier).goToPage(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('StickyNote.pin')));
    await tester.pumpAndSettle();
    expect(container.read(commentSelectionProvider)?.noteOpen, isTrue);
    expect(find.byKey(const ValueKey<String>('StickyNote.card')), findsOne);
    await tester.tap(
      find.descendant(
        of: find.byType(StickyNote),
        matching: find.bySemanticsLabel('Close note'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('StickyNote.card')), findsNothing);
  });

  testWidgets('a note typed on the page commits when it loses focus', (
    tester,
  ) async {
    final engine = _engine(annotations: const []);
    final container = await _open(tester, engine);
    container.read(commentToolProvider.notifier).pick(AnnotationTool.note);
    await tester.pump();
    await tester.tapAt(
      _at(container, tester, const Offset(100, 100)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(await _list(engine), isEmpty);
    await tester.enterText(find.byType(EditableText).last, 'Bak buna');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final note = (await _list(engine)).single;
    expect(note.kind, AnnotationKind.note);
    expect(note.contents, 'Bak buna');
    expect(note.rect.topLeft.dx, closeTo(100, 1));
  });

  testWidgets('an empty new note leaves nothing behind', (tester) async {
    final engine = _engine(annotations: const []);
    final container = await _open(tester, engine);
    container.read(commentToolProvider.notifier).pick(AnnotationTool.note);
    await tester.pump();
    await tester.tapAt(
      _at(container, tester, const Offset(100, 100)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(await _list(engine), isEmpty);
  });

  testWidgets(
    'the first comment asks for the name once, and Cancel adds none',
    (tester) async {
      final engine = _engine(annotations: const []);
      final container = await _open(tester, engine, name: null);
      container.read(commentToolProvider.notifier).shape(ShapeTool.rectangle);
      await tester.pump();
      Future<void> draw() => _drag(
        tester,
        _at(container, tester, const Offset(100, 100)),
        _at(container, tester, const Offset(200, 160)),
      );
      await draw();
      expect(find.byType(CommenterNameDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await _list(engine), isEmpty);

      container.read(commentToolProvider.notifier).shape(ShapeTool.rectangle);
      await tester.pump();
      await draw();
      await tester.enterText(
        find.descendant(
          of: find.byType(CommenterNameDialog),
          matching: find.byType(TextField),
        ),
        'Elif Şahin',
      );
      await tester.tap(find.widgetWithText(Button, 'Continue'));
      await tester.pumpAndSettle();
      expect((await _list(engine)).single.author, 'Elif Şahin');
      expect(container.read(settingsProvider).commenterName, 'Elif Şahin');

      container.read(commentToolProvider.notifier).shape(ShapeTool.rectangle);
      await tester.pump();
      await _drag(
        tester,
        _at(container, tester, const Offset(300, 300)),
        _at(container, tester, const Offset(400, 360)),
      );
      expect(find.byType(CommenterNameDialog), findsNothing);
      expect((await _list(engine)).length, 2);
    },
  );

  testWidgets('Show comments hides every mark, with a4-5’s notice', (
    tester,
  ) async {
    final engine = _engine();
    final container = await _open(tester, engine);
    final switched = find.byWidgetPredicate(
      (widget) => widget is Switch && widget.label == 'Show comments',
    );
    await tester.tap(switched);
    await tester.pumpAndSettle();
    expect(engine.commentRequests, [false]);
    expect(find.text('3 comments hidden'), findsOneWidget);
    expect(find.byType(StickyNote), findsNothing);
    await tester.tap(find.widgetWithText(Button, 'Show comments'));
    await tester.pumpAndSettle();
    expect(engine.commentRequests, [false, true]);
    expect(find.text('3 comments hidden'), findsNothing);
    expect(container.read(commentsShownProvider).visible, isTrue);
  });

  testWidgets('Delete takes the selected mark, not a key typed in a field', (
    tester,
  ) async {
    final engine = _engine();
    final container = await _open(tester, engine);
    container
        .read(commentSelectionProvider.notifier)
        .select(2, composing: true);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(
      (await _list(engine)).map((annotation) => annotation.handle),
      contains(2),
    );

    container.read(commentSelectionProvider.notifier).select(1);
    await tester.pumpAndSettle();
    await tester.tapAt(
      _at(container, tester, const Offset(10, 10)),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(
      (await _list(engine)).map((annotation) => annotation.handle),
      isNot(contains(1)),
    );
  });

  testWidgets('a restricted document refuses the tools but lists comments', (
    tester,
  ) async {
    final engine = _engine()
      ..opGates[(_document, DocumentOp.comment)] = OpGate.forbidden;
    await _open(tester, engine);
    final tools = tester.widget<AnnotationTools>(find.byType(AnnotationTools));
    expect(tools.disabledReasons, contains(AnnotationTool.highlight));
    expect(find.byType(CommentCard), findsNWidgets(2));
  });

  testWidgets('search finds a comment and selects it', (tester) async {
    final container = await _open(tester, _engine());
    container.read(findProvider.notifier)
      ..open()
      ..setQuery('oranı');
    await tester.pumpAndSettle();
    final match = container.read(findProvider).matches.single;
    expect(match.comment, 2);
    expect(match.page, 1);
    expect(container.read(commentSelectionProvider)?.handle, 2);
    expect(container.read(viewerProvider)?.currentPage, 1);
  });
}
