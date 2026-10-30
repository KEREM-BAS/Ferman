import 'dart:convert';
import 'dart:io';

import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/recent/recent_files_store_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

RecentEntry entry(String name, {bool pinned = false, int minutes = 0}) =>
    RecentEntry(
      path: '/docs/$name',
      name: name,
      opened: DateTime.utc(2026, 10, 30, 12, minutes),
      pages: 3,
      pinned: pinned,
    );

void main() {
  group('RecentFiles', () {
    ProviderContainer containerWith(List<RecentEntry> files) {
      final store = MemoryRecentFilesStore(files);
      final container = ProviderContainer(
        overrides: [
          initialRecentFilesProvider.overrideWithValue(files),
          recentFilesStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    List<String> names(ProviderContainer container) => [
      for (final file in container.read(recentFilesProvider)) file.name,
    ];

    test('a file opened goes first and keeps its pin and details', () async {
      final container = containerWith([
        entry('a.pdf'),
        entry('b.pdf', pinned: true),
      ]);
      final files = container.read(recentFilesProvider.notifier);
      await files.opened(
        '/docs/b.pdf',
        name: 'b.pdf',
        now: DateTime.utc(2026, 10, 31),
      );
      expect(names(container), ['b.pdf', 'a.pdf']);
      final b = container.read(recentFilesProvider).first;
      expect(b.pinned, isTrue);
      expect(b.pages, 3);
      expect(b.opened, DateTime.utc(2026, 10, 31));
      await files.opened(
        '/docs/c.pdf',
        name: 'c.pdf',
        now: DateTime.utc(2026, 11),
        pages: 7,
        signed: true,
      );
      expect(names(container), ['c.pdf', 'b.pdf', 'a.pdf']);
      expect(container.read(recentFilesProvider).first.signed, isTrue);
      expect(
        await container.read(recentFilesStoreProvider).load(),
        container.read(recentFilesProvider),
      );
    });

    test('keeps at most 50 files that are not pinned, and every pin', () async {
      final container = containerWith([
        entry('pinned.pdf', pinned: true),
        for (var i = 0; i < RecentFiles.limit; i++) entry('$i.pdf'),
      ]);
      await container
          .read(recentFilesProvider.notifier)
          .opened('/docs/new.pdf', name: 'new.pdf', now: DateTime.utc(2027));
      final files = container.read(recentFilesProvider);
      expect(files.where((file) => !file.pinned), hasLength(RecentFiles.limit));
      expect(files.first.name, 'new.pdf');
      expect(files.map((file) => file.name), contains('pinned.pdf'));
      expect(files.map((file) => file.name), isNot(contains('49.pdf')));
    });

    test('relocate merges into an entry already there, keeping a pin; '
        'another file starts without the old details', () async {
      final container = containerWith([
        RecentEntry(
          path: '/old/Kira.pdf',
          name: 'Kira.pdf',
          opened: DateTime.utc(2026),
          pages: 3,
          signed: true,
          bookmark: 'old',
        ),
        entry('Kira.pdf', pinned: true).copyWith(path: '/new/Kira.pdf'),
      ]);
      final files = container.read(recentFilesProvider.notifier);
      await files.relocate(
        '/old/Kira.pdf',
        to: '/new/Kira.pdf',
        name: 'Kira.pdf',
      );
      var only = container.read(recentFilesProvider).single;
      expect(only.path, '/new/Kira.pdf');
      expect(only.pinned, isTrue);
      expect(only.bookmark, 'old');
      expect(only.pages, 3);

      await files.relocate(
        '/new/Kira.pdf',
        to: '/other/Fatura.pdf',
        name: 'Fatura.pdf',
        bookmark: 'fresh',
        sameFile: false,
      );
      only = container.read(recentFilesProvider).single;
      expect(only.name, 'Fatura.pdf');
      expect(only.pages, isNull);
      expect(only.signed, isFalse);
      expect(only.bookmark, 'fresh');
      expect(only.pinned, isTrue);
    });

    test('pin, remove, and Clear list keeping the pinned files', () async {
      final container = containerWith([
        entry('a.pdf'),
        entry('b.pdf'),
        entry('c.pdf'),
      ]);
      final files = container.read(recentFilesProvider.notifier);
      await files.pin('/docs/b.pdf', pinned: true);
      expect(container.read(recentFilesProvider)[1].pinned, isTrue);
      await files.remove('/docs/a.pdf');
      expect(names(container), ['b.pdf', 'c.pdf']);
      await files.clear();
      expect(names(container), ['b.pdf']);
      await files.pin('/docs/b.pdf', pinned: false);
      expect(container.read(recentFilesProvider).single.pinned, isFalse);
    });
  });

  group('FileRecentFilesStore', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('ferman-recent-');
      addTearDown(() => directory.deleteSync(recursive: true));
    });

    test('round-trips the list in its versioned file', () async {
      final store = FileRecentFilesStore(directory);
      expect(await store.load(), isEmpty);
      final files = [
        entry('b.pdf', pinned: true),
        RecentEntry(
          path: '/docs/a.pdf',
          name: 'a.pdf',
          opened: DateTime.utc(2026),
          signed: true,
          bookmark: 'Ym9va21hcms=',
        ),
      ];
      await store.save(files);
      expect(await store.load(), files);
      final json = jsonDecode(store.file.readAsStringSync()) as Map;
      expect(json['version'], 1);
      expect(File('${store.file.path}.tmp').existsSync(), isFalse);
    });

    test('skips an entry it cannot read, and moves aside a file that is not '
        'the list', () async {
      final store = FileRecentFilesStore(directory);
      store.file.writeAsStringSync(
        jsonEncode({
          'version': 1,
          'files': [
            entry('a.pdf').toJson(),
            {'path': '/docs/no-date.pdf', 'name': 'no-date.pdf'},
            {...entry('b.pdf').toJson(), 'bookmark': ''},
            'not an entry',
          ],
        }),
      );
      final loaded = await store.load();
      expect(loaded.map((file) => file.name), ['a.pdf', 'b.pdf']);
      expect(loaded.last.bookmark, isNull);

      store.file.writeAsStringSync('{ not json');
      expect(await store.load(), isEmpty);
      expect(store.file.existsSync(), isFalse);
      expect(File('${store.file.path}.unreadable').existsSync(), isTrue);
    });
  });

  test('the home outside a macOS sandbox container', () {
    expect(
      homeOutsideContainer(
        '/Users/elif/Library/Containers/io.github.kerembas.ferman/Data',
      ),
      '/Users/elif',
    );
    expect(homeOutsideContainer('/home/elif'), '/home/elif');
    expect(homeOutsideContainer('/'), isNull);
    expect(homeOutsideContainer(null), isNull);
  });
}
