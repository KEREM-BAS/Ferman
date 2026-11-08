import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/document_parts.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';
import 'shell_host.dart';

const String _path = '/Belgeler/Kira.pdf';

const List<PageInfo> _pages = [
  PageInfo(width: 595, height: 842, handle: 1),
  PageInfo(width: 595, height: 842, handle: 2),
  PageInfo(width: 595, height: 842, handle: 3),
];

const List<OutlineEntry> _outline = [
  OutlineEntry(title: 'Madde 1', page: 0),
  OutlineEntry(title: 'Madde 4', page: 1),
  OutlineEntry(title: '4.1 Artış', page: 1, depth: 1),
  OutlineEntry(title: 'İmzalar', page: 2),
];

List<OutlineEdit> _items(List<(String, int)> rows) => [
  for (final (index, (title, depth)) in rows.indexed)
    OutlineEdit(item: index, title: title, depth: depth),
];

List<(String, int)> _shape(List<OutlineEdit>? items) => [
  for (final item in items!) (item.title, item.depth),
];

void main() {
  group('outline edits', () {
    final items = _items(const [
      ('A', 0),
      ('B', 0),
      ('B1', 1),
      ('B2', 1),
      ('C', 0),
    ]);

    test('a moved bookmark takes its children to each of the three places', () {
      expect(_shape(outlineMoved(items, 1, 0, OutlineDrop.before)), const [
        ('B', 0),
        ('B1', 1),
        ('B2', 1),
        ('A', 0),
        ('C', 0),
      ]);
      expect(_shape(outlineMoved(items, 1, 4, OutlineDrop.into)), const [
        ('A', 0),
        ('C', 0),
        ('B', 1),
        ('B1', 2),
        ('B2', 2),
      ]);
      expect(_shape(outlineMoved(items, 0, 1, OutlineDrop.after)), const [
        ('B', 0),
        ('B1', 1),
        ('B2', 1),
        ('A', 0),
        ('C', 0),
      ]);
      // Never into its own branch.
      expect(outlineMoved(items, 1, 2, OutlineDrop.into), isNull);
      expect(outlineMoved(items, 1, 1, OutlineDrop.before), isNull);
    });

    test('nesting, steps and delete keep the tree whole', () {
      expect(_shape(outlineNested(items, 4, inward: true)), const [
        ('A', 0),
        ('B', 0),
        ('B1', 1),
        ('B2', 1),
        ('C', 1),
      ]);
      expect(outlineNested(items, 0, inward: true), isNull);
      expect(outlineNested(items, 2, inward: true), isNull);
      expect(outlineNested(items, 0, inward: false), isNull);
      expect(_shape(outlineStepped(items, 3, down: false)), const [
        ('A', 0),
        ('B', 0),
        ('B2', 1),
        ('B1', 1),
        ('C', 0),
      ]);
      expect(outlineStepped(items, 3, down: true), isNull);
      expect(_shape(outlineStepped(items, 0, down: true)), const [
        ('B', 0),
        ('B1', 1),
        ('B2', 1),
        ('A', 0),
        ('C', 0),
      ]);
      expect(_shape(outlineRemoved(items, 1)), const [('A', 0), ('C', 0)]);
      // Every item kept names where it came from.
      expect(
        [for (final item in outlineRemoved(items, 1)) item.item],
        const [0, 4],
      );
    });

    test("⌘B goes after the section of the reader's page", () {
      expect(outlineItemAt(_outline, 0), 0);
      expect(outlineItemAt(_outline, 1), 2);
      expect(outlineItemAt(const [OutlineEntry(title: 'x', page: 2)], 0), null);
    });
  });

  group("the document's parts", () {
    late FakeEngineService engine;
    late FakeFilePickerService picker;

    Future<ProviderContainer> open(
      WidgetTester tester, {
      List<Signature> signatures = const [],
      OpGate? organize,
      DocumentInfo info = const DocumentInfo(title: 'Kira sözleşmesi'),
    }) async {
      engine = FakeEngineService(
        documents: {
          _path: OpenedDocument(
            id: 1,
            pages: _pages,
            outline: _outline,
            signatures: signatures,
            info: info,
          ),
        },
      );
      if (organize != null) engine.opGates[(1, DocumentOp.organize)] = organize;
      picker = FakeFilePickerService(picked: [_path]);
      await pumpFermanApp(
        tester,
        engine: engine,
        home: '/home/elif',
        picker: picker,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FmStart)),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      picker.picked = [];
      return container;
    }

    Future<void> showTab(
      ProviderContainer container,
      WidgetTester tester,
      SidebarTab tab,
    ) async {
      container.read(shellSidebarTabProvider.notifier).select(tab);
      await settle(tester);
    }

    List<String> titles(ProviderContainer container) => [
      for (final entry in container.read(openDocumentProvider)!.outline)
        '${'  ' * entry.depth}${entry.title}',
    ];

    // The outline's titles keep their direction in a bidi isolate.
    Finder row(String title) => find.descendant(
      of: find.byType(FmSidebar),
      matching: find.textContaining(title),
    );

    Finder sidebarButton(String label) => find.descendant(
      of: find.byType(FmSidebar),
      matching: find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.label == label,
      ),
    );

    testWidgets("Add bookmark adds one to the reader's page after its "
        'section and renames it in place', (tester) async {
      final container = await open(tester);
      await showTab(container, tester, SidebarTab.outline);
      await tester.tap(sidebarButton('Add bookmark'));
      await settle(tester);
      expect(engine.outlineEdits.single[1].item, isNull);
      expect(engine.outlineEdits.single[1].page, 0);
      expect(titles(container), [
        'Madde 1',
        'New bookmark',
        'Madde 4',
        '  4.1 Artış',
        'İmzalar',
      ]);
      expect(find.byType(InlineNameField), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Giriş');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(titles(container)[1], 'Giriş');
      expect(find.byType(InlineNameField), findsNothing);
      // Two steps: the bookmark, then its name.
      expect(engine.outlineEdits, hasLength(2));
      expect(
        container.read(shellDocumentsProvider).active!.saveState,
        SaveState.unsaved,
      );
    });

    testWidgets('Esc leaves the name as it was', (tester) async {
      final container = await open(tester);
      await showTab(container, tester, SidebarTab.outline);
      container.read(outlineRenamingProvider.notifier).start(0);
      await settle(tester);
      await tester.enterText(find.byType(EditableText), 'Başka');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(InlineNameField), findsNothing);
      expect(engine.outlineEdits, isEmpty);
      expect(titles(container).first, 'Madde 1');
    });

    testWidgets('More acts on the selected bookmark: nest, then delete with '
        'its children', (tester) async {
      final container = await open(tester);
      await showTab(container, tester, SidebarTab.outline);
      Future<void> more(String item) async {
        await tester.tap(sidebarButton('More'));
        await settle(tester);
        await tester.tap(find.text(item));
        await settle(tester);
      }

      await tester.tap(row('İmzalar'));
      await settle(tester);
      await more('Nest under the one above');
      expect(titles(container), [
        'Madde 1',
        'Madde 4',
        '  4.1 Artış',
        '  İmzalar',
      ]);
      await tester.tap(row('Madde 4'));
      await settle(tester);
      await more('Delete bookmark');
      expect(titles(container), ['Madde 1']);
      // Each a step of its own, undone one by one.
      expect(engine.outlineEdits, hasLength(2));
    });

    testWidgets("a bookmark dragged onto another's top goes before it", (
      tester,
    ) async {
      final container = await open(tester);
      await showTab(container, tester, SidebarTab.outline);
      final target = tester.getRect(row('Madde 1'));
      final gesture = await tester.startGesture(
        tester.getCenter(row('İmzalar')),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveTo(Offset(target.center.dx, target.top + 1));
      await tester.pump();
      await gesture.up();
      await settle(tester);
      expect(titles(container), [
        'İmzalar',
        'Madde 1',
        'Madde 4',
        '  4.1 Artış',
      ]);
    });

    testWidgets('bookmarks stay as they are where pages cannot change', (
      tester,
    ) async {
      final container = await open(tester, organize: OpGate.forbidden);
      await showTab(container, tester, SidebarTab.outline);
      final add = tester.widget<IconButton>(sidebarButton('Add bookmark'));
      expect(add.onPressed, isNull);
      expect(add.disabledReason, isNotNull);
    });

    testWidgets('Attach a file embeds the chosen file as one step', (
      tester,
    ) async {
      final container = await open(tester);
      await showTab(container, tester, SidebarTab.attachments);
      picker.picked = ['/Belgeler/Ek-2 Tapu.jpg'];
      await tester.tap(sidebarButton('Attach a file'));
      await settle(tester);
      expect(engine.attachedFiles, [
        (1, '/Belgeler/Ek-2 Tapu.jpg', 'Ek-2 Tapu.jpg'),
      ]);
      expect(picker.requests.last, '*');
      expect(find.text('Ek-2 Tapu.jpg'), findsOneWidget);
      expect(
        container.read(openDocumentProvider)!.attachments.single.name,
        'Ek-2 Tapu.jpg',
      );
    });

    testWidgets("thumbnails carry f5's badges, and the info button opens "
        'the legend', (tester) async {
      final container = await open(
        tester,
        signatures: const [Signature(field: 'İmza', page: 2)],
      );
      await showTab(container, tester, SidebarTab.pages);
      Set<ThumbnailBadge> badgesOf(int page) {
        final badges = tester
            .widgetList<PageThumbnail>(find.byType(PageThumbnail))
            .elementAt(page)
            .badges;
        return badges is ThumbnailBadges ? badges.badges : const {};
      }

      expect(badgesOf(2), {ThumbnailBadge.signature});
      expect(
        tester
            .widgetList<PageThumbnail>(find.byType(PageThumbnail))
            .elementAt(2)
            .semanticLabel,
        'Page 3, signature field',
      );

      expect(find.byType(ThumbnailBadgeLegend), findsNothing);
      await tester.tap(sidebarButton('What the page badges mean'));
      await settle(tester);
      expect(find.byType(ThumbnailBadgeLegend), findsOneWidget);
      expect(find.text('Page badges'), findsOneWidget);
      await tester.tap(sidebarButton('What the page badges mean'));
      await settle(tester);
      expect(find.byType(ThumbnailBadgeLegend), findsNothing);
    });

    testWidgets('Document properties edits the title in place', (tester) async {
      final container = await open(tester);
      container.read(documentPropertiesRequestProvider.notifier).request();
      await settle(tester);
      await tester.tap(find.textContaining('Kira sözleşmesi'));
      await settle(tester);
      await tester.enterText(
        find.byType(EditableText),
        'Konut Kira Sözleşmesi',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(
        container.read(openDocumentProvider)!.info.title,
        'Konut Kira Sözleşmesi',
      );
      expect(find.textContaining('Konut Kira Sözleşmesi'), findsOneWidget);
    });

    testWidgets('a file without an /Info object shows its metadata read-only '
        '(B221)', (tester) async {
      final container = await open(
        tester,
        info: const DocumentInfo(title: 'Kira sözleşmesi', editable: false),
      );
      container.read(documentPropertiesRequestProvider.notifier).request();
      await settle(tester);
      await tester.tap(find.textContaining('Kira sözleşmesi').last);
      await settle(tester);
      expect(find.byType(InlineNameField), findsNothing);
    });
  });
}
