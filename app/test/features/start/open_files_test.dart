import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_screen.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/features/viewer/document_view.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  testWidgets('a file that does not open shows a banner on the start screen '
      '(G116)', (tester) async {
    final picker = FakeFilePickerService(picked: ['/docs/missing.pdf']);
    await pumpFermanApp(tester, engine: engine(), picker: picker);
    await controlO(tester);
    expect(find.byType(FmStart), findsOneWidget);
    final banner = tester.widget<Banner>(find.byType(Banner));
    expect(banner.tone, BannerTone.danger);
    // The name is isolated, so it keeps its order in a right-to-left UI.
    expect(banner.title, 'Ferman can’t open “\u2068missing.pdf\u2069”');
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byType(Banner), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a file that fails next to one that opens is reported in the '
      'editor; the next pick clears it', (tester) async {
    final picker = FakeFilePickerService(
      picked: ['/docs/missing.pdf', '/docs/kira-tr.pdf'],
    );
    await pumpFermanApp(tester, engine: engine(), picker: picker);
    await controlO(tester);
    expect(find.byType(FmWindow), findsOneWidget);
    final toast = tester.widget<Toast>(find.byType(Toast));
    expect(toast.tone, ToastTone.danger);
    expect(toast.title, 'A file didn’t open');
    expect(toast.message, 'Ferman can’t open “\u2068missing.pdf\u2069”');
    picker.picked = ['/docs/nda-en.pdf'];
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
