import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/open_problem_tab.dart';
import 'package:ferman/features/shell/shell_mode_bar.dart';
import 'package:ferman/features/shell/shell_screen.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';

const OpenedDocument kira = OpenedDocument(
  id: 1,
  pages: [PageInfo(width: 595, height: 842)],
  layers: [Layer(name: 'Ölçüler')],
  layersSwitchable: true,
);
const OpenedDocument nda = OpenedDocument(
  id: 2,
  pages: [PageInfo(width: 612, height: 792), PageInfo(width: 612, height: 792)],
);

FakeEngineService engine() => FakeEngineService(
  documents: {
    '/docs/kira-tr.pdf': kira,
    '/docs/nda-en.pdf': nda,
    r'C:\docs\nda-en.pdf': nda,
    r'/docs/a\b.pdf': nda,
  },
);

Future<void> controlO(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Open file… opens each chosen PDF in a new active tab '
      '(a1-13)', (tester) async {
    final picker = FakeFilePickerService(
      picked: ['/docs/kira-tr.pdf', '/docs/nda-en.pdf'],
    );
    await pumpFermanApp(tester, engine: engine(), picker: picker);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FmStart)),
    );
    await tester.tap(find.text('Open file…'));
    await tester.pumpAndSettle();
    expect(picker.requests, ['PDF documents']);
    expect(find.byType(FmWindow), findsOneWidget);
    expect(find.byType(DocumentView), findsOneWidget);
    // Both tabs, the last one shown; the placeholders are gone. (The
    // harness has no custom title bar, so the tabs are read from the state.)
    List<String?> tabs() => [
      for (final document in container.read(shellDocumentsProvider).documents)
        document.path,
    ];
    expect(tabs(), ['/docs/kira-tr.pdf', '/docs/nda-en.pdf']);
    final list = container.read(shellDocumentsProvider);
    expect(list.activeIndex, 1);
    expect(list.active!.name, 'nda-en.pdf');
    expect(list.active!.pageCount, 2);
    // No save in this session yet.
    expect(find.text('Saved on this device'), findsOneWidget);

    // Ctrl+O in the editor: a file already open shows its tab instead of
    // opening twice.
    picker.picked = ['/docs/kira-tr.pdf'];
    await controlO(tester);
    expect(picker.requests, hasLength(2));
    expect(tabs(), hasLength(2));
    expect(container.read(shellDocumentsProvider).activeIndex, 0);
    expect(find.byType(FmWindow), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a file that does not open gets an error tab (a1-9b); '
      'opening it again tries again', (tester) async {
    final documents = <String, OpenedDocument>{'/docs/kira-tr.pdf': kira};
    final fake = FakeEngineService(documents: documents);
    final picker = FakeFilePickerService(picked: ['/docs/missing.pdf']);
    await pumpFermanApp(tester, engine: fake, picker: picker);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FmStart)),
    );
    await controlO(tester);
    expect(find.byType(FmWindow), findsOneWidget);
    expect(find.byType(OpenErrorTab), findsOneWidget);
    // The name is isolated, so it keeps its order in a right-to-left UI.
    expect(find.text('Ferman can’t open “\u2068missing.pdf\u2069”'), findsOne);
    expect(
      find.text(
        'The file isn’t there any more. It may have been moved, renamed or '
        'deleted.',
      ),
      findsOne,
    );
    // Only the canvas: no mode bar, sidebar or status bar.
    expect(find.byType(ShellModeBar), findsNothing);
    expect(find.byType(ShellStatusBar), findsNothing);
    final tab = container.read(shellDocumentsProvider).active!;
    expect(tab.icon, IconName.fileX);
    expect(tab.error!.kind, EngineErrorKind.notFound);
    final show = tester.widget<Button>(
      find.widgetWithText(Button, 'Show in folder'),
    );
    expect(show.disabled, isTrue);

    // Open another file… shows the open panel.
    picker.picked = ['/docs/kira-tr.pdf'];
    await tester.tap(find.text('Open another file…'));
    await tester.pumpAndSettle();
    expect(picker.requests, hasLength(2));
    // The file is back: opened again, it is tried in its own tab, ahead of
    // the one opened after it.
    documents['/docs/missing.pdf'] = nda;
    picker.picked = ['/docs/missing.pdf'];
    await controlO(tester);
    expect([
      for (final tab in container.read(shellDocumentsProvider).documents)
        tab.path,
    ], ['/docs/missing.pdf', '/docs/kira-tr.pdf']);
    expect(container.read(shellDocumentsProvider).activeIndex, 0);
    expect(find.byType(OpenErrorTab), findsNothing);
    expect(find.byType(DocumentView), findsOneWidget);
    expect(find.byType(ShellModeBar), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a damaged file shows its cause and technical details '
      '(a1-9b)', (tester) async {
    final fake = FakeEngineService(
      failures: {
        '/docs/truncated.pdf': const EngineException(
          kind: EngineErrorKind.damaged,
          messageKey: 'errorDamagedTruncated',
          details: '18432 bytes · no trailer',
        ),
      },
    );
    final picker = FakeFilePickerService(picked: ['/docs/truncated.pdf']);
    await pumpFermanApp(tester, engine: fake, picker: picker);
    await controlO(tester);
    expect(find.textContaining('The file stops before its end'), findsOne);
    expect(find.text('18432 bytes · no trailer'), findsOne);
    await tester.tap(find.text('Copy technical details'));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("a file that is not a PDF gets a1-9c's error tab, with "
      'Convert to PDF… disabled', (tester) async {
    final fake = FakeEngineService(
      failures: {
        '/docs/Ek-1.xlsx': const EngineException(
          kind: EngineErrorKind.unsupported,
          messageKey: 'errorNotPdf',
        ),
      },
    );
    final picker = FakeFilePickerService(picked: ['/docs/Ek-1.xlsx']);
    await pumpFermanApp(tester, engine: fake, picker: picker);
    await controlO(tester);
    final zone = tester.widget<DropZone>(find.byType(DropZone));
    expect(zone.state, DropZoneState.error);
    expect(zone.errorTitle, 'That file isn’t a PDF.');
    expect(
      zone.errorSubtitle,
      '“\u2068Ek-1.xlsx\u2069” isn’t a PDF file. Ferman opens PDF files.',
    );
    final convert = tester.widget<Button>(
      find.widgetWithText(Button, 'Convert to PDF…'),
    );
    expect(convert.disabled, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a file that needs a password opens as a locked tab with the '
      'unlock dialog (a1-8, a1-8b)', (tester) async {
    final fake = FakeEngineService(
      documents: {'/docs/payslip.pdf': nda},
      passwords: {'/docs/payslip.pdf': 'Eylül2026maaşı'},
    );
    final picker = FakeFilePickerService(picked: ['/docs/payslip.pdf']);
    await pumpFermanApp(tester, engine: fake, picker: picker);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FmStart)),
    );
    await controlO(tester);
    expect(find.byType(UnlockTab), findsOneWidget);
    expect(find.text('This PDF is password-protected'), findsOne);
    // The field has focus over the canvas, so typing goes to it.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    // Asked for again before it is unlocked, it shows its tab and is not
    // remembered: only a file that opens joins the recent files.
    await controlO(tester);
    expect(container.read(shellDocumentsProvider).documents, hasLength(1));
    expect(container.read(recentFilesProvider), isEmpty);
    expect(container.read(shellDocumentsProvider).active!.icon, IconName.lock);
    expect(find.byType(ShellModeBar), findsNothing);

    // A wrong password: a1-8b's error, the attempt kept and selected.
    await tester.enterText(find.byType(EditableText), 'eylul2026');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('That password didn’t work.'), findsOne);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.selection.start, 0);
    expect(field.controller.selection.end, 'eylul2026'.length);

    // The right one, submitted with Enter, opens the document in place.
    await tester.enterText(find.byType(EditableText), 'Eylül2026maaşı');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(UnlockTab), findsNothing);
    expect(find.byType(DocumentView), findsOneWidget);
    final list = container.read(shellDocumentsProvider);
    expect(list.documents, hasLength(1));
    expect(list.active!.document, nda);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Cancel closes the locked tab; with no tab left Start shows', (
    tester,
  ) async {
    final fake = FakeEngineService(
      documents: {'/docs/payslip.pdf': nda},
      passwords: {'/docs/payslip.pdf': 'x'},
    );
    final picker = FakeFilePickerService(picked: ['/docs/payslip.pdf']);
    await pumpFermanApp(tester, engine: fake, picker: picker);
    await controlO(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(FmStart), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a file that runs out of memory gets no tab: a banner on '
      'Start, a toast in the editor, each with Try again (a1-9f)', (
    tester,
  ) async {
    const outOfMemory = EngineException(
      kind: EngineErrorKind.resourceLimit,
      messageKey: 'errorOutOfMemory',
    );
    final fake = FakeEngineService(
      documents: {'/docs/kira-tr.pdf': kira},
      failures: {'/docs/imar.pdf': outOfMemory},
    );
    final picker = FakeFilePickerService(picked: ['/docs/imar.pdf']);
    await pumpFermanApp(tester, engine: fake, picker: picker);
    await controlO(tester);
    expect(find.byType(FmStart), findsOneWidget);
    final banner = tester.widget<Banner>(find.byType(Banner));
    expect(banner.tone, BannerTone.danger);
    expect(banner.title, '“\u2068imar.pdf\u2069” was closed');
    expect(find.text('Try again'), findsOne);
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byType(Banner), findsNothing);

    picker.picked = ['/docs/imar.pdf', '/docs/kira-tr.pdf'];
    await controlO(tester);
    expect(find.byType(FmWindow), findsOneWidget);
    final toast = tester.widget<Toast>(find.byType(Toast));
    expect(toast.tone, ToastTone.danger);
    expect(toast.title, '“\u2068imar.pdf\u2069” was closed');
    expect(
      toast.message,
      'This computer ran out of memory while opening it. Your other '
      'documents are open and unchanged.',
    );
    expect(toast.action!.label, 'Try again');
    picker.picked = ['/docs/kira-tr.pdf'];
    await controlO(tester);
    expect(find.byType(Toast), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a cancelled panel changes nothing', (tester) async {
    final picker = FakeFilePickerService();
    await pumpFermanApp(tester, engine: engine(), picker: picker);
    await tester.tap(find.text('Open a PDF'));
    await tester.pumpAndSettle();
    expect(picker.requests, hasLength(1));
    expect(find.byType(FmStart), findsOneWidget);
    expect(find.byType(Banner), findsNothing);
  });

  group('the tab name is the end of the path', () {
    test(r'after the last slash on macOS and Linux, where \ is a letter', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(fileName(r'/docs/a\b.pdf'), r'a\b.pdf');
      expect(fileName('/docs/kira-tr.pdf'), 'kira-tr.pdf');
    });

    test('after the last slash or backslash on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(fileName(r'C:\docs\nda-en.pdf'), 'nda-en.pdf');
      expect(fileName(r'\\server\share\nda-en.pdf'), 'nda-en.pdf');
      expect(fileName('C:/docs/nda-en.pdf'), 'nda-en.pdf');
    });
  });

  test('each tab keeps its layers, view and search', () async {
    final fake = engine();
    final container = ProviderContainer.test(
      overrides: [engineServiceProvider.overrideWithValue(fake)],
    );
    final documents = container.read(shellDocumentsProvider.notifier);
    // Keep the views alive, as the shell's widgets do.
    container
      ..listen(layerVisibilityProvider, (_, _) {})
      ..listen(viewerProvider, (_, _) {})
      ..listen(findProvider, (_, _) {});
    documents.add(
      const ShellDocument(name: 'kira-tr.pdf', path: '/k', document: kira),
    );
    await container
        .read(layerVisibilityProvider.notifier)
        .show(0, visible: false);
    container.read(viewerProvider.notifier)
      ..resize(const Size(800, 600))
      ..zoomTo(2);
    container.read(findProvider.notifier).open();
    expect(container.read(layerVisibilityProvider)!.visible, [false]);
    final key = container.read(layerVisibilityProvider)!.renderKey;

    documents.add(
      const ShellDocument(name: 'nda-en.pdf', path: '/n', document: nda),
    );
    expect(container.read(viewerProvider)!.document.id, nda.id);
    expect(container.read(viewerProvider)!.zoom, isNot(2));
    expect(container.read(findProvider).open, isFalse);

    documents.activate(0);
    final layers = container.read(layerVisibilityProvider)!;
    expect(layers.visible, [false]);
    expect(layers.renderKey, key);
    expect(container.read(viewerProvider)!.zoom, 2);
    expect(container.read(findProvider).open, isTrue);
    expect(fake.layerRequests, [
      [false],
    ]);
  });

  test('a search event that arrives after a tab switch stays with its '
      'document', () async {
    final engine = _HeldEngine();
    final container = ProviderContainer.test(
      overrides: [engineServiceProvider.overrideWithValue(engine)],
    );
    final documents = container.read(shellDocumentsProvider.notifier);
    container
      ..listen(findProvider, (_, _) {})
      ..listen(viewerProvider, (_, _) {});
    documents.add(
      const ShellDocument(name: 'kira-tr.pdf', path: '/k', document: kira),
    );
    container.read(findProvider.notifier)
      ..open()
      ..setQuery('kira');
    final search = engine.held.single;
    documents.add(
      const ShellDocument(name: 'nda-en.pdf', path: '/n', document: nda),
    );
    // A's search speaks before anything has read the find state again.
    search
      ..add(const SearchProgress(searched: 30, pages: 300))
      ..add(
        const SearchMatches([
          SearchMatch(
            page: 0,
            rects: [],
            snippet: 'KİRA',
            snippetStart: 0,
            snippetEnd: 4,
          ),
        ]),
      );
    await pumpEventQueue();
    final b = container.read(findProvider);
    expect(b.matches, isEmpty);
    expect(b.searched, isNull);
    expect(b.query, isEmpty);
    documents
      ..activate(1)
      ..activate(0);
    expect(container.read(findProvider).query, 'kira');
    documents.activate(1);
    expect(container.read(findProvider).matches, isEmpty);
  });

  test('a layer change the engine answers after a tab switch comes back '
      'with its tab', () async {
    final engine = _HeldEngine();
    final container = ProviderContainer.test(
      overrides: [engineServiceProvider.overrideWithValue(engine)],
    );
    final documents = container.read(shellDocumentsProvider.notifier);
    container.listen(layerVisibilityProvider, (_, _) {});
    documents.add(
      const ShellDocument(name: 'kira-tr.pdf', path: '/k', document: kira),
    );
    final hiding = container
        .read(layerVisibilityProvider.notifier)
        .show(0, visible: false);
    documents.add(
      const ShellDocument(name: 'nda-en.pdf', path: '/n', document: nda),
    );
    expect(container.read(layerVisibilityProvider)!.visible, isEmpty);
    engine.layers.complete(7);
    await hiding;
    documents.activate(0);
    final layers = container.read(layerVisibilityProvider)!;
    expect(layers.visible, [false]);
    expect(layers.renderKey, 7);
  });
}

/// An engine whose searches and layer changes answer when the test says.
final class _HeldEngine extends FakeEngineService {
  final List<StreamController<SearchUpdate>> held = [];
  final Completer<int> layers = Completer();

  @override
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  ) {
    final updates = StreamController<SearchUpdate>();
    held.add(updates);
    return updates.stream;
  }

  @override
  Future<int> showLayers(int document, List<bool> visible) => layers.future;
}
