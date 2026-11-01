import 'dart:io';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/start/recent_files_view.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/recent/recent_files_store_io.dart';
import 'package:ferman/recent/recent_previews.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/onboarding/ferman_app_harness.dart';
import '../helpers/fake_file_picker.dart';

const String _path = '/docs/Kira sözleşmesi.pdf';

const OpenedDocument _kira = OpenedDocument(
  id: 5,
  pages: [PageInfo(width: 595, height: 842)],
);

/// [_kira] as a file that needs its password.
const OpenedDocument _kiraLocked = OpenedDocument(
  id: 5,
  pages: [PageInfo(width: 595, height: 842)],
  security: Security(
    method: EncryptionMethod.aes256,
    keyBits: 256,
    userPasswordRequired: true,
  ),
);

/// Opens [_path] with ⌘O from Start, then lets the preview's PNG encode,
/// which runs outside the test's fake clock.
Future<(ProviderContainer, MemoryRecentPreviewStore)> openKira(
  WidgetTester tester, {
  bool password = false,
  Uint8List? oldPreview,
}) async {
  await pumpFermanApp(
    tester,
    engine: FakeEngineService(
      documents: {_path: password ? _kiraLocked : _kira},
      passwords: {if (password) _path: '1234'},
    ),
    picker: FakeFilePickerService(picked: [_path]),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FmStart)),
  );
  final store =
      container.read(recentPreviewStoreProvider) as MemoryRecentPreviewStore;
  if (oldPreview != null) store.previews[_path] = oldPreview;
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
  await settlePreviews(tester);
  return (container, store);
}

Future<void> settlePreviews(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Finder inRecent(Finder finder) =>
    find.descendant(of: find.byType(RecentFilesView), matching: finder);

void main() {
  testWidgets("a file that opens keeps its first page's preview, which its "
      'card shows on Start (B118)', (tester) async {
    final (container, store) = await openKira(tester);
    final png = store.previews[_path];
    expect(png, isNotNull);
    // A PNG's signature.
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);

    container.read(documentOpenerProvider.notifier).close(_path);
    await tester.pumpAndSettle();
    expect(inRecent(find.byType(Image)), findsOne);
    expect(inRecent(find.byType(PageLines)), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a file that needs a password keeps no preview, loses an old '
      'one and shows the lock on its card (G109)', (tester) async {
    final (container, store) = await openKira(
      tester,
      password: true,
      oldPreview: Uint8List(1),
    );
    expect(store.previews, isEmpty);

    final opener = container.read(documentOpenerProvider.notifier);
    expect(await opener.unlock(_path, '1234'), isTrue);
    await tester.pumpAndSettle();
    await settlePreviews(tester);
    expect(store.previews, isEmpty);
    expect(container.read(recentFilesProvider).single.locked, isTrue);

    opener.close(_path);
    await tester.pumpAndSettle();
    expect(inRecent(find.byType(Image)), findsNothing);
    expect(
      inRecent(
        find.byWidgetPredicate(
          (widget) => widget is Icon && widget.name == IconName.lock,
        ),
      ),
      findsOne,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  test('a file off the list loses its preview: removed, cleared or past the '
      'limit', () async {
    RecentEntry entry(String name, {bool pinned = false}) => RecentEntry(
      path: '/docs/$name',
      name: name,
      opened: DateTime.utc(2026, 11),
      pinned: pinned,
    );
    final files = [
      entry('a.pdf'),
      entry('b.pdf'),
      entry('c.pdf', pinned: true),
    ];
    final previews = MemoryRecentPreviewStore();
    for (final file in files) {
      previews.previews[file.path] = Uint8List(1);
    }
    final container = ProviderContainer(
      overrides: [
        initialRecentFilesProvider.overrideWithValue(files),
        recentFilesStoreProvider.overrideWithValue(
          MemoryRecentFilesStore(files),
        ),
        recentPreviewStoreProvider.overrideWithValue(previews),
      ],
    );
    addTearDown(container.dispose);
    final recent = container.read(recentFilesProvider.notifier);
    await recent.remove('/docs/a.pdf');
    await pumpEventQueue();
    expect(previews.previews.keys, ['/docs/b.pdf', '/docs/c.pdf']);
    await recent.clear();
    await pumpEventQueue();
    expect(previews.previews.keys, ['/docs/c.pdf']);
  });

  test('the file store keeps a preview by a hash of its path, replaces it '
      'and deletes it', () async {
    final directory = await Directory.systemTemp.createTemp('previews');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileRecentPreviewStore(
      Directory('${directory.path}/recent_previews'),
    );
    expect(await store.load(_path), isNull);
    await store.save(_path, Uint8List.fromList([1, 2]));
    await store.save(_path, Uint8List.fromList([3]));
    expect(await store.load(_path), [3]);
    expect(await store.load('/docs/other.pdf'), isNull);
    final names = [
      for (final file in store.directory.listSync()) file.uri.pathSegments.last,
    ];
    expect(names, hasLength(1));
    expect(names.single, matches(RegExp(r'^[0-9a-f]{8}\.png$')));
    await store.remove(_path);
    await store.remove(_path);
    expect(await store.load(_path), isNull);
  });
}
