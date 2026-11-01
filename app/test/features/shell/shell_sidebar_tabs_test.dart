import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/attachment_save.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../../helpers/fake_file_picker.dart';
import '../../helpers/recording_file_access.dart';
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
  layersSwitchable: true,
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

/// A layer the engine cannot switch: a repaired file, or one opened with a
/// password.
const OpenedDocument repaired = OpenedDocument(
  id: 5,
  pages: [PageInfo(width: 595, height: 842)],
  layers: [Layer(name: 'Metin')],
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
    OpenedDocument document, {
    FakeFilePickerService? picker,
    RecordingFileAccess? access,
  }) async {
    final engine = FakeEngineService(documents: {'/doc.pdf': document});
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        overrides: [
          engineServiceProvider.overrideWithValue(engine),
          if (picker != null)
            filePickerServiceProvider.overrideWithValue(picker),
          if (access != null) fileAccessProvider.overrideWithValue(access),
        ],
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

  testWidgets('Pages: the arrow keys move focus between thumbnails, Enter '
      'goes to the focused one', (tester) async {
    await pumpDocument(tester, kira);
    int? focused() {
      final context = FocusManager.instance.primaryFocus?.context;
      return context?.findAncestorWidgetOfExactType<PageThumbnail>()?.page;
    }

    tester
        .widgetList<Focus>(
          find.descendant(
            of: inSidebar(find.byType(PageThumbnail)).first,
            matching: find.byType(Focus),
          ),
        )
        .map((focus) => focus.focusNode)
        .firstWhere((node) => node?.debugLabel == 'PageThumbnail')!
        .requestFocus();
    await settle(tester);
    expect(focused(), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(focused(), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(focused(), 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(focused(), 2);
    // Focus alone does not move the reader.
    expect(currentPage(tester), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(currentPage(tester), 1);
  });

  testWidgets('Outline nests, folds, tints the current section and goes', (
    tester,
  ) async {
    await pumpDocument(tester, kira);
    await showTab(tester, SidebarTab.outline);
    expect(
      inSidebar(find.text(bidiIsolate('4.1 Yıllık artış'))),
      findsOneWidget,
    );

    await tester.tap(inSidebar(find.text(bidiIsolate('4.2 Gecikme'))));
    await settle(tester);
    expect(currentPage(tester), 2);
    // The last bookmark at or before page 3 is the current section.
    final tinted = find.ancestor(
      of: find.text(bidiIsolate('İmzalar')),
      matching: find.byWidgetPredicate(
        (widget) => widget is FermanInteractive && widget.selected,
      ),
    );
    expect(tinted, findsOneWidget);

    // ← closes the focused parent, → opens it again.
    Focus.of(
      tester.element(
        inSidebar(find.text(bidiIsolate('Madde 4 — Kira bedeli'))),
      ),
    ).requestFocus();
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(inSidebar(find.text(bidiIsolate('4.1 Yıllık artış'))), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(
      inSidebar(find.text(bidiIsolate('4.1 Yıllık artış'))),
      findsOneWidget,
    );
  });

  testWidgets('each document keeps its sidebar tab, folds and scroll, '
      'also while the sidebar is hidden (B091)', (tester) async {
    final long = OpenedDocument(
      id: 6,
      pages: [
        for (var i = 0; i < 40; i++) const PageInfo(width: 595, height: 842),
      ],
    );
    await pumpDocument(tester, kira);
    final container = containerOf(tester);
    Future<void> show(OpenedDocument document) async {
      container.read(openDocumentProvider.notifier).show(document);
      await settle(tester);
    }

    double offset() => tester
        .state<ScrollableState>(
          inSidebar(find.byType(Scrollable)).hitTestable().first,
        )
        .position
        .pixels;

    await showTab(tester, SidebarTab.outline);
    Focus.of(
      tester.element(
        inSidebar(find.text(bidiIsolate('Madde 4 — Kira bedeli'))),
      ),
    ).requestFocus();
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(inSidebar(find.text(bidiIsolate('4.1 Yıllık artış'))), findsNothing);

    // A new document starts on Pages, at the top.
    await show(long);
    expect(container.read(shellSidebarTabProvider), SidebarTab.pages);
    await tester.drag(
      inSidebar(find.byType(Scrollable)).hitTestable().first,
      const Offset(0, -600),
    );
    await settle(tester);
    final scrolled = offset();
    expect(scrolled, greaterThan(0));

    await show(kira);
    expect(container.read(shellSidebarTabProvider), SidebarTab.outline);
    expect(
      inSidebar(find.text(bidiIsolate('Madde 4 — Kira bedeli'))),
      findsOneWidget,
    );
    expect(inSidebar(find.text(bidiIsolate('4.1 Yıllık artış'))), findsNothing);

    await show(long);
    expect(container.read(shellSidebarTabProvider), SidebarTab.pages);
    expect(offset(), scrolled);

    // Hiding the sidebar takes it out of the tree; its state stays.
    container.read(shellSidebarOpenProvider.notifier).close();
    await settle(tester);
    expect(find.byType(FmSidebar), findsNothing);
    container.read(shellSidebarOpenProvider.notifier).open();
    await settle(tester);
    expect(offset(), scrolled);
    await show(kira);
    expect(inSidebar(find.text(bidiIsolate('4.1 Yıllık artış'))), findsNothing);
  });

  testWidgets('Save attachment as… writes the file where the save panel '
      'says; under the sandbox through the staging directory (B110)', (
    tester,
  ) async {
    final picker = FakeFilePickerService(saveTo: '/out/Demirbaş.xlsx');
    final access = RecordingFileAccess();
    final engine = await pumpDocument(
      tester,
      kira,
      picker: picker,
      access: access,
    );
    await showTab(tester, SidebarTab.attachments);
    await tester.tap(iconButton('Save attachment as…').first);
    await settle(tester);
    expect(picker.saves, ['Ek-1 Demirbaş listesi.xlsx']);
    expect(engine.savedAttachments, [(3, 0, '/out/Demirbaş.xlsx', null)]);

    access.stagingDirectory = '/stage';
    await tester.tap(iconButton('Save attachment as…').last);
    await settle(tester);
    expect(engine.savedAttachments.last, (
      3,
      1,
      '/out/Demirbaş.xlsx',
      '/stage',
    ));
    expect(access.swapped, [('/stage/staged', '/out/Demirbaş.xlsx')]);

    // Cancelled: nothing is written.
    picker.saveTo = null;
    await tester.tap(iconButton('Save attachment as…').first);
    await settle(tester);
    expect(engine.savedAttachments, hasLength(2));

    // A name from the file never picks the folder.
    await containerOf(tester)
        .read(attachmentSaverProvider.notifier)
        .save(3, 0, '../../ek/kötü.sh');
    expect(picker.saves.last, 'kötü.sh');
  });

  testWidgets('a save that fails shows the toast until it is dismissed', (
    tester,
  ) async {
    final engine = await pumpDocument(
      tester,
      kira,
      picker: FakeFilePickerService(saveTo: '/out/ek.xlsx'),
    );
    engine.saveFailure = const EngineException(
      kind: EngineErrorKind.permissionDenied,
      messageKey: 'errorFilePermissionDenied',
    );
    await showTab(tester, SidebarTab.attachments);
    await tester.tap(iconButton('Save attachment as…').first);
    await settle(tester);
    expect(find.textContaining('wasn’t saved'), findsOne);
    expect(find.textContaining('couldn’t write the file there'), findsOne);

    await tester.tap(
      find.descendant(
        of: find.byType(Toast),
        matching: find.byType(IconButton),
      ),
    );
    await settle(tester);
    expect(find.byType(Toast), findsNothing);
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
          .map((button) => button.onPressed != null),
      [true, true],
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

  testWidgets('the eye buttons show and hide layers, and every view asks '
      'for its pixels again', (tester) async {
    final engine = await pumpDocument(tester, kira);
    // The first bitmaps decode outside the fake clock, so they are here
    // before the change and go stale with it.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await showTab(tester, SidebarTab.layers);
    final asked = engine.requests.length;

    await tester.tap(iconButton('Show layer'));
    await settle(tester);
    expect(engine.layerRequests, [
      [true, true, true],
    ]);
    expect(iconButton('Show layer'), findsNothing);
    expect(containerOf(tester).read(layerVisibilityProvider)!.renderKey, 1);
    final again = engine.requests.skip(asked).toList();
    // The canvas's tiles, and the Pages tab's three thumbnails.
    expect(
      again.expand((wanted) => wanted.map((entry) => entry.item)),
      contains(isA<TileItem>()),
    );
    expect(
      again.any(
        (wanted) =>
            wanted.length == 3 &&
            wanted.every((entry) => entry.item is ThumbnailItem),
      ),
      isTrue,
    );

    // The locked layer keeps the document's state.
    final buttons = tester
        .widgetList<IconButton>(iconButton('Hide layer'))
        .toList();
    expect([for (final b in buttons) b.disabledReason], [null, 'Locked', null]);
    await tester.tap(iconButton('Hide layer').first);
    await settle(tester);
    expect(engine.layerRequests.last, [false, true, true]);
  });

  testWidgets('a document whose layers cannot be switched keeps them as '
      'they are', (tester) async {
    await pumpDocument(tester, repaired);
    await showTab(tester, SidebarTab.layers);
    expect(
      tester.widget<IconButton>(iconButton('Hide layer')).disabledReason,
      futureVersion,
    );
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
