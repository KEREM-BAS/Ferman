import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import 'shell_host.dart';

/// a2-3o's contract in three pages, with a2-3b's attachments, a2-3c's
/// layers and a2-14's signatures.
final OpenedDocument kira = OpenedDocument(
  id: 3,
  pages: const [
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
  ],
  outline: const [
    OutlineEntry(title: 'Madde 1 — Taraflar', page: 0),
    OutlineEntry(title: 'Madde 4 — Kira bedeli', page: 1, open: true),
    OutlineEntry(title: '4.1 Yıllık artış', page: 1, depth: 1),
    OutlineEntry(title: '4.2 Gecikme', page: 2, depth: 1),
    OutlineEntry(title: 'İmzalar', page: 2),
  ],
  attachments: [
    Attachment(
      name: 'Ek-1 Demirbaş listesi.xlsx',
      size: 18 * 1024,
      modified: DateTime(2026, 10, 12, 9, 30),
    ),
    const Attachment(name: 'Tapu fotokopisi.jpg'),
  ],
  layers: const [
    Layer(name: 'Metin'),
    Layer(name: 'İmzalar', locked: true),
    Layer(name: 'Filigran — TASLAK', visible: false),
  ],
  signatures: [
    Signature(
      field: 'KiraVeren.Imza',
      signed: true,
      signer: 'Mert Kaya',
      signedAt: DateTime(2026, 10, 13, 11, 4),
      page: 2,
    ),
    const Signature(field: 'Kiracı · İmza', page: 2),
  ],
);

/// A page with nothing in the sidebar's lists.
const OpenedDocument bare = OpenedDocument(
  id: 4,
  pages: [PageInfo(width: 595, height: 842)],
);

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<FakeEngineService> pumpDocument(
    WidgetTester tester,
    OpenedDocument document,
  ) async {
    final engine = FakeEngineService(documents: {'/doc.pdf': document});
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        overrides: [engineServiceProvider.overrideWithValue(engine)],
      ),
    );
    containerOf(tester).read(openDocumentProvider.notifier).show(document);
    await settle(tester);
    return engine;
  }

  Future<void> showTab(WidgetTester tester, SidebarTab tab) async {
    containerOf(tester).read(shellSidebarTabProvider.notifier).select(tab);
    await settle(tester);
  }

  int currentPage(WidgetTester tester) =>
      containerOf(tester).read(viewerProvider)!.currentPage;

  Finder inSidebar(Finder finder) =>
      find.descendant(of: find.byType(FmSidebar), matching: finder);

  Finder iconButton(String label) => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.label == label,
  );

  testWidgets('Pages shows a thumbnail of every page and goes to one', (
    tester,
  ) async {
    final engine = await pumpDocument(tester, kira);
    final thumbs = tester
        .widgetList<PageThumbnail>(inSidebar(find.byType(PageThumbnail)))
        .toList();
    expect([for (final t in thumbs) t.label], ['1', '2', '3']);
    expect([for (final t in thumbs) t.selected], [true, false, false]);
    expect(
      engine.requests.expand((wanted) => wanted.map((entry) => entry.item)),
      containsAll(const [
        ThumbnailItem(page: 1, size: previewSize),
        ThumbnailItem(page: 2, size: previewSize),
      ]),
    );
    expect(inSidebar(find.text('3')), findsWidgets);

    await tester.tap(inSidebar(find.bySemanticsLabel('Page 3')));
    await settle(tester);
    expect(currentPage(tester), 2);
    expect(
      tester.widget<PageThumbnail>(find.byType(PageThumbnail).last).selected,
      isTrue,
    );
  });

  testWidgets('Outline nests, folds, tints the current section and goes', (
    tester,
  ) async {
    await pumpDocument(tester, kira);
    await showTab(tester, SidebarTab.outline);
    expect(inSidebar(find.text('4.1 Yıllık artış')), findsOneWidget);

    await tester.tap(inSidebar(find.text('4.2 Gecikme')));
    await settle(tester);
    expect(currentPage(tester), 2);
    // The last bookmark at or before page 3 is the current section.
    final tinted = find.ancestor(
      of: find.text('İmzalar'),
      matching: find.byWidgetPredicate(
        (widget) => widget is FermanInteractive && widget.selected,
      ),
    );
    expect(tinted, findsOneWidget);

    // ← closes the focused parent, → opens it again.
    Focus.of(tester.element(inSidebar(find.text('Madde 4 — Kira bedeli'))))
        .requestFocus();
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(inSidebar(find.text('4.1 Yıllık artış')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(inSidebar(find.text('4.1 Yıllık artış')), findsOneWidget);
  });

  testWidgets('Attachments, Layers and Signatures list the document', (
    tester,
  ) async {
    await pumpDocument(tester, kira);

    await showTab(tester, SidebarTab.attachments);
    expect(inSidebar(find.text('Ek-1 Demirbaş listesi.xlsx')), findsOneWidget);
    // Region values are bidi-isolated, so the text contains them.
    expect(inSidebar(find.textContaining(RegExp(r'18\sKB'))), findsOneWidget);
    expect(inSidebar(find.textContaining('12/10/2026')), findsOneWidget);
    expect(
      tester
          .widgetList<IconButton>(iconButton('Save attachment as…'))
          .map((button) => button.disabledReason),
      [futureVersion, futureVersion],
    );

    await showTab(tester, SidebarTab.layers);
    expect(inSidebar(find.text('Filigran — TASLAK')), findsOneWidget);
    expect(iconButton('Hide layer'), findsNWidgets(2));
    expect(iconButton('Show layer'), findsOneWidget);
    expect(find.bySemanticsLabel('Locked'), findsOneWidget);

    await showTab(tester, SidebarTab.signatures);
    expect(inSidebar(find.text('Mert Kaya')), findsOneWidget);
    expect(
      inSidebar(
        find.text('Signature checking is available in a future version.'),
      ),
      findsOneWidget,
    );
    expect(inSidebar(find.textContaining('Page 3')), findsNWidgets(2));
    expect(inSidebar(find.text('Empty signature field')), findsOneWidget);
    // The heading counts the list.
    expect(inSidebar(find.text('2')), findsOneWidget);
  });

  testWidgets('empty tabs say so with one EmptyState', (tester) async {
    await pumpDocument(tester, bare);
    for (final (tab, title) in [
      (SidebarTab.outline, 'No bookmarks'),
      (SidebarTab.attachments, 'No attachments'),
      (SidebarTab.layers, 'No layers'),
      (SidebarTab.signatures, 'No signatures'),
    ]) {
      await showTab(tester, tab);
      expect(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.text(title),
        ),
        findsOneWidget,
        reason: '$tab',
      );
    }
  });
}
