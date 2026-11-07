import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/editor/block_editor.dart';
import 'package:ferman/features/editor/format_bar.dart';
import 'package:ferman/features/editor/link_open_dialog.dart';
import 'package:ferman/features/editor/link_popover.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/editor/links_panel.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_host.dart';
import '../../helpers/fake_desktop_window.dart';
import '../../helpers/recording_file_access.dart';
import '../shell/shell_host.dart';
import 'editor_test.dart' show document, page, pumps;

const LinkInfo web = LinkInfo(
  handle: 1,
  page: 0,
  rect: Rect.fromLTWH(100, 300, 120, 20),
  kind: LinkKind.web,
  target: 'https://example.org/a/very/long/path?with=query',
);

const LinkInfo mail = LinkInfo(
  handle: 2,
  page: 0,
  rect: Rect.fromLTWH(100, 340, 120, 20),
  kind: LinkKind.mail,
  target: 'mailto:mert.kaya@ornekposta.com.tr',
);

const LinkInfo broken = LinkInfo(
  handle: 3,
  page: 0,
  rect: Rect.fromLTWH(100, 380, 120, 20),
  kind: LinkKind.broken,
  wantedPage: 5,
);

const LinkInfo script = LinkInfo(
  handle: 4,
  page: 0,
  rect: Rect.fromLTWH(100, 420, 120, 20),
  kind: LinkKind.script,
);

void main() {
  late FakeDesktopWindow window;
  late FakeEngineService engine;
  late RecordingFileAccess access;

  setUpAll(initializeRegionFormats);
  setUp(() {
    window = FakeDesktopWindow(WindowPlatform.linux);
    access = RecordingFileAccess();
  });
  tearDown(() => window.dispose());

  Future<void> pumpDocument(
    WidgetTester tester, {
    FermanMode mode = FermanMode.edit,
    List<LinkInfo> links = const [web, mail, broken, script],
    OpenedDocument open = document,
  }) async {
    engine = FakeEngineService(
      documents: {'/kira.pdf': open},
      pageBlocks: {0: page},
    );
    engine.fakeLinks[open.id] = [...links];
    engine.blockStyles[3] = const BlockStyleInfo(
      font: 'FakeSerif',
      family: 'FakeSerif',
      size: 11,
      frame: Rect.fromLTWH(0, 0, 100, 20),
    );
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        samples: false,
        overrides: [
          engineServiceProvider.overrideWithValue(engine),
          fileAccessProvider.overrideWithValue(access),
        ],
      ),
    );
    containerOf(tester)
        .read(shellDocumentsProvider.notifier)
        .add(
          ShellDocument(
            name: 'kira.pdf',
            path: '/kira.pdf',
            document: open,
            saveState: SaveState.saved,
            pageCount: 1,
          ),
        );
    containerOf(tester).read(shellModeProvider.notifier).select(mode);
    await settle(tester);
  }

  Future<void> linkToolOn(WidgetTester tester) async {
    containerOf(tester).read(linkToolProvider.notifier).toggle();
    await pumps(tester);
  }

  Offset onPage(WidgetTester tester, Offset point) {
    final view = containerOf(tester).read(viewerProvider)!;
    return tester.getTopLeft(find.byType(DocumentView)) +
        view.placement.rects.first!.topLeft -
        view.offset +
        point * view.scale;
  }

  Future<void> click(WidgetTester tester, Offset at) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await tester.pump();
    await mouse.down(at);
    await mouse.up();
    await mouse.removePointer();
    await pumps(tester);
  }

  Future<void> clickLink(WidgetTester tester, LinkInfo link) =>
      click(tester, onPage(tester, link.rect.center));

  Future<void> pressText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await pumps(tester);
  }

  testWidgets('the Link tool takes the panel, and T gives it back', (
    tester,
  ) async {
    await pumpDocument(tester);
    expect(find.byType(LinksPanel), findsNothing);
    await linkToolOn(tester);
    expect(find.byType(LinksPanel), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('mert.kaya@ornekposta.com.tr'), findsOneWidget);
    expect(find.textContaining('mailto:'), findsNothing);
    expect(find.textContaining('Broken: this document has'), findsOneWidget);
    expect(find.textContaining('Script, not run'), findsWidgets);
    containerOf(tester).read(linkToolProvider.notifier).show(on: false);
    await pumps(tester);
    expect(find.byType(LinksPanel), findsNothing);
  });

  testWidgets('leaving Edit mode turns the tool off', (tester) async {
    await pumpDocument(tester);
    await linkToolOn(tester);
    containerOf(tester)
        .read(shellModeProvider.notifier)
        .select(FermanMode.view);
    await pumps(tester);
    expect(containerOf(tester).read(linkToolProvider).on, isFalse);
  });

  testWidgets('with the tool on, a click marks a link and edits no text', (
    tester,
  ) async {
    await pumpDocument(tester);
    await linkToolOn(tester);
    await clickLink(tester, web);
    expect(containerOf(tester).read(linkToolProvider).selected, web.handle);
    expect(find.byType(LinkPopover), findsOneWidget);
    expect(find.byType(BlockEditor), findsNothing);
    expect(containerOf(tester).read(organizeDialogProvider), isNull);
  });

  testWidgets('the open popover settles, for its goldens', (tester) async {
    await pumpDocument(tester);
    await linkToolOn(tester);
    await clickLink(tester, web);
    await tester.pumpAndSettle();
    expect(find.byType(LinkPopover), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Save link changes the target; a bad one says why', (
    tester,
  ) async {
    await pumpDocument(tester);
    await linkToolOn(tester);
    await clickLink(tester, web);
    final field = find.descendant(
      of: find.byType(LinkPopover),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'not an address');
    await pressText(tester, 'Save link');
    expect(
      find.text('Type a web address that starts with http:// or https://.'),
      findsOneWidget,
    );
    expect(engine.fakeLinks[document.id]!.first.target, web.target);

    await tester.enterText(field, 'example.com');
    await pressText(tester, 'Save link');
    expect(engine.fakeLinks[document.id]!.first.target, 'https://example.com');
    expect(find.byType(LinkPopover), findsNothing);
  });

  testWidgets('only the look changing leaves a refused link its action', (
    tester,
  ) async {
    await pumpDocument(tester);
    await linkToolOn(tester);
    await clickLink(tester, script);
    expect(
      find.descendant(
        of: find.byType(LinkPopover),
        matching: find.textContaining('script'),
      ),
      findsOneWidget,
    );
    await pressText(tester, 'Save link');
    expect(engine.fakeLinks[document.id]!.last.kind, LinkKind.script);
    expect(find.byType(LinkPopover), findsNothing);
  });

  testWidgets('Remove link deletes it as a step', (tester) async {
    await pumpDocument(tester);
    await linkToolOn(tester);
    await clickLink(tester, mail);
    await pressText(tester, 'Remove link');
    expect(
      engine.fakeLinks[document.id]!.map((link) => link.handle),
      isNot(contains(mail.handle)),
    );
    expect(find.byType(LinkPopover), findsNothing);
  });

  testWidgets('a canvas selection becomes a new link on its text', (
    tester,
  ) async {
    await pumpDocument(tester, links: const []);
    await linkToolOn(tester);
    final container = containerOf(tester);
    container
        .read(canvasSelectionProvider.notifier)
        .select(
          const PageSelection(
            quads: [Rect.fromLTWH(100, 100, 50, 12)],
            text: 'mert',
          ),
        );
    await pumps(tester);
    expect(find.text('No links in this document.'), findsOneWidget);
    container.read(linkToolProvider.notifier).addSelection();
    await pumps(tester);
    expect(find.text('Add link'), findsWidgets);
    expect(find.text('Remove link'), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byType(LinkPopover),
        matching: find.byType(EditableText),
      ),
      'https://example.org',
    );
    await pressText(tester, 'Save link');
    final added = engine.fakeLinks[document.id]!.single;
    expect(added.kind, LinkKind.web);
    expect(added.rect, const Rect.fromLTWH(100, 100, 50, 12));
    expect(added.quads.single, hasLength(4));
  });

  testWidgets('a3-1c: Add link commits the typing and opens the popover', (
    tester,
  ) async {
    await pumpDocument(tester, links: const []);
    // The first pass asks for the page's blocks; the click finds them.
    await containerOf(tester)
        .read(engineServiceProvider)
        .textBlocks(document.id, 0);
    final at = onPage(tester, const Offset(100, 306));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.moveTo(at);
    await tester.pump();
    await tester.pump();
    await mouse.down(at);
    await mouse.up();
    await mouse.removePointer();
    await pumps(tester);
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(BlockEditor),
        matching: find.byType(EditableText),
      ),
    );
    field.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(FormatBar),
        matching: find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.icon == IconName.link,
        ),
      ),
    );
    await pumps(tester);
    final tool = containerOf(tester).read(linkToolProvider);
    expect(tool.on, isTrue);
    expect(tool.draft?.quads, isNotEmpty);
    expect(find.byType(LinkPopover), findsOneWidget);
    expect(find.byType(BlockEditor), findsNothing);
  });

  testWidgets('a3-1c: Highlight counts characters as the engine does', (
    tester,
  ) async {
    await pumpDocument(tester, links: const []);
    await containerOf(tester)
        .read(engineServiceProvider)
        .textBlocks(document.id, 0);
    final at = onPage(tester, const Offset(100, 306));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.moveTo(at);
    await tester.pump();
    await tester.pump();
    await mouse.down(at);
    await mouse.up();
    await mouse.removePointer();
    await pumps(tester);
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(BlockEditor),
        matching: find.byType(EditableText),
      ),
    );
    // Two characters outside the BMP before the selection: four code units.
    field.controller.value = const TextEditingValue(
      text: '😀😀 sözleşme',
      selection: TextSelection(baseOffset: 5, extentOffset: 8),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(FormatBar),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.icon == IconName.highlighter,
        ),
      ),
    );
    await pumps(tester);
    expect(engine.selectionRequests.last, (3, 6));
  });

  testWidgets('a web link asks first, showing all of it, and only then opens', (
    tester,
  ) async {
    await pumpDocument(tester, mode: FermanMode.view);
    await clickLink(tester, web);
    final container = containerOf(tester);
    final prompt = container.read(organizeDialogProvider)! as LinkOpenDialog;
    expect(prompt.link.handle, web.handle);
    expect(access.opened, isEmpty);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: componentHost(prompt),
      ),
    );
    await pumps(tester);
    expect(find.text(web.target), findsOneWidget);
    expect(access.opened, isEmpty);
    await pressText(tester, 'Open link');
    expect(access.opened, [web.target]);
    expect(container.read(organizeDialogProvider), isNull);
  });

  testWidgets('Cancel opens nothing', (tester) async {
    await pumpDocument(tester, mode: FermanMode.view);
    await clickLink(tester, mail);
    final container = containerOf(tester);
    final prompt = container.read(organizeDialogProvider)! as LinkOpenDialog;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: componentHost(prompt),
      ),
    );
    await pumps(tester);
    expect(find.text(mail.target), findsOneWidget);
    await pressText(tester, 'Cancel');
    expect(access.opened, isEmpty);
    expect(container.read(organizeDialogProvider), isNull);
  });

  testWidgets('only a web or mail link can reach the system', (tester) async {
    await pumpDocument(tester, mode: FermanMode.view);
    await containerOf(tester).read(linkToolProvider.notifier).open(script);
    expect(access.opened, isEmpty);
  });

  testWidgets('a script runs nothing and says so; a broken link says so', (
    tester,
  ) async {
    await pumpDocument(tester, mode: FermanMode.view);
    await clickLink(tester, script);
    expect(containerOf(tester).read(organizeDialogProvider), isNull);
    expect(access.opened, isEmpty);
    expect(
      containerOf(tester).read(toastNoticesProvider).single.tone,
      ToastTone.warning,
    );
    await clickLink(tester, broken);
    expect(containerOf(tester).read(organizeDialogProvider), isNull);
    expect(containerOf(tester).read(toastNoticesProvider), hasLength(2));
  });

  testWidgets('a drag is no click on a link', (tester) async {
    await pumpDocument(tester, mode: FermanMode.view);
    final at = onPage(tester, web.rect.center);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await tester.pump();
    await mouse.down(at);
    await mouse.moveTo(at + const Offset(40, 0));
    await mouse.up();
    await mouse.removePointer();
    await pumps(tester);
    expect(containerOf(tester).read(organizeDialogProvider), isNull);
  });

  testWidgets('a link to a page just goes there', (tester) async {
    const pages = OpenedDocument(
      id: 7,
      pages: [
        PageInfo(width: 595, height: 842),
        PageInfo(width: 595, height: 842),
      ],
    );
    const toSecond = LinkInfo(
      handle: 9,
      page: 0,
      rect: Rect.fromLTWH(100, 300, 120, 20),
      kind: LinkKind.page,
      targetPage: 1,
    );
    await pumpDocument(
      tester,
      mode: FermanMode.view,
      links: const [toSecond],
      open: pages,
    );
    await clickLink(tester, toSecond);
    expect(containerOf(tester).read(organizeDialogProvider), isNull);
    expect(containerOf(tester).read(viewerProvider)!.currentPage, 1);
  });

  testWidgets('File stays disabled with its future-version reason', (
    tester,
  ) async {
    await pumpDocument(tester);
    await linkToolOn(tester);
    await clickLink(tester, web);
    final control = tester.widget<SegmentedControl<Object?>>(
      find.descendant(
        of: find.byType(LinkPopover),
        matching: find.byWidgetPredicate(
          (widget) => widget is SegmentedControl,
        ),
      ),
    );
    final file = control.options.last;
    expect(file.disabled, isTrue);
    expect(file.disabledReason, futureVersion);
  });

  test('the shell keys: L for the tool, ⇧⌘K for Add link (G144)', () {
    expect(
      const ShortcutBindings(ShortcutPlatform.mac).caps(ShellCommand.addLink),
      ['⇧', '⌘', 'K'],
    );
    expect(
      const ShortcutBindings(ShortcutPlatform.mac)
          .caps(ShellCommand.commandPalette),
      ['⌘', 'K'],
    );
  });

  test('a mail link shows its address alone', () {
    expect(mailAddressOf('MAILTO:a@b.co?subject=x'), 'a@b.co');
  });

  test('the topmost link under a point wins', () {
    const under = LinkInfo(
      handle: 1,
      page: 0,
      rect: Rect.fromLTWH(0, 0, 10, 10),
      kind: LinkKind.web,
    );
    const over = LinkInfo(
      handle: 2,
      page: 0,
      rect: Rect.fromLTWH(0, 0, 10, 10),
      kind: LinkKind.mail,
    );
    expect(linkOver(const [under, over], 0, const Offset(5, 5)), over);
    expect(linkOver(const [under, over], 1, const Offset(5, 5)), isNull);
  });
}
