import 'package:ferman/app/app.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/shell_screen.dart';
import 'package:ferman/features/start/recent_files_view.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';

final DateTime now = DateTime.now();

RecentEntry recent(
  String name, {
  bool pinned = false,
  int pages = 3,
  bool signed = false,
  DateTime? opened,
  String folder = '/docs',
}) => RecentEntry(
  path: '$folder/$name',
  name: name,
  opened: opened ?? now,
  pages: pages,
  pinned: pinned,
  signed: signed,
);

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FermanApp)));

List<String> cardNames(WidgetTester tester) => [
  for (final element
      in find
          .descendant(
            of: find.byType(RecentFilesView),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  (widget.data?.endsWith('.pdf') ?? false) &&
                  widget.style?.fontWeight != null,
            ),
          )
          .evaluate())
    (element.widget as Text).data!,
];

void main() {
  missingAndBookmarks();

  testWidgets('no recent files keep a1-5’s drop zone', (tester) async {
    await pumpFermanApp(tester);
    expect(find.byType(DropZone), findsOneWidget);
    expect(find.byType(RecentFilesView), findsNothing);
  });

  testWidgets('recent files take the drop zone’s place (a1-4-m2): the drop '
      'strip, pinned and recent cards, the note and Clear list', (
    tester,
  ) async {
    await pumpFermanApp(
      tester,
      recentFiles: [
        recent('Kira sözleşmesi.pdf', signed: true),
        recent(
          'Fatura.pdf',
          pages: 1,
          opened: now.subtract(const Duration(days: 1)),
        ),
        recent('Tez.pdf', pinned: true, pages: 64, folder: '/home/elif/Okul'),
      ],
    );
    expect(find.byType(DropZone), findsNothing);
    expect(find.text('Drop files anywhere in this window'), findsOneWidget);
    expect(find.text('PDF files open in tabs.'), findsOneWidget);
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    // A pinned file is in both places, as the boards list it.
    expect(find.text('Tez.pdf'), findsNWidgets(2));
    expect(find.text('/home/elif/Okul · 64 pages'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Today .* · 3 pages$')),
      findsOneWidget,
    );
    expect(
      find.textContaining(RegExp(r'^Yesterday .* · 1 page$')),
      findsOneWidget,
    );
    expect(find.text('Signed'), findsOneWidget);
    expect(
      find.text('Recent files are listed only on this device.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear list'));
    await tester.pumpAndSettle();
    expect(find.text('Kira sözleşmesi.pdf'), findsNothing);
    expect(find.text('Tez.pdf'), findsNWidgets(2));
    expect(find.text('Fatura.pdf'), findsNothing);
  });

  testWidgets('the search keeps the names that match, ignoring Turkish case', (
    tester,
  ) async {
    await pumpFermanApp(
      tester,
      settings: const AppSettings(
        onboardingCompleted: true,
        languageCode: 'tr',
        regionCode: 'TR',
      ),
      recentFiles: [recent('İMAR PLANI.pdf'), recent('Kira.pdf')],
    );
    await tester.enterText(find.byType(EditableText), 'imar');
    await tester.pumpAndSettle();
    expect(find.text('İMAR PLANI.pdf'), findsOneWidget);
    expect(find.text('Kira.pdf'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'yok');
    await tester.pumpAndSettle();
    expect(find.textContaining('“yok”'), findsOneWidget);
  });

  testWidgets('Name sorts through the engine’s collator; Last opened is the '
      'stored order', (tester) async {
    final engine = _CountingEngine();
    await pumpFermanApp(
      tester,
      engine: engine,
      recentFiles: [recent('b.pdf'), recent('c.pdf'), recent('a.pdf')],
    );
    expect(cardNames(tester), ['b.pdf', 'c.pdf', 'a.pdf']);
    tester
        .widget<Select<RecentSort>>(find.byType(Select<RecentSort>))
        .onChanged!(RecentSort.name);
    await tester.pumpAndSettle();
    // The UI language's tag, and the names in their stored order.
    expect(engine.collations.single.$1, 'en');
    expect(engine.collations.single.$2, ['b.pdf', 'c.pdf', 'a.pdf']);
    expect(cardNames(tester), ['a.pdf', 'b.pdf', 'c.pdf']);
  });

  testWidgets('the list view (a1-4c) shows the location, pages and time', (
    tester,
  ) async {
    await pumpFermanApp(tester, recentFiles: [recent('Kira.pdf', pages: 12)]);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.name == IconName.list,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('/docs'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining(RegExp('^Today ')), findsOneWidget);
  });

  testWidgets('a recent file’s pin shows under the pointer and pins it; the '
      'pinned card’s unpins it (G118)', (tester) async {
    await pumpFermanApp(tester, recentFiles: [recent('Kira.pdf')]);
    double pinOpacity() => tester
        .widget<Opacity>(
          find.ancestor(
            of: find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.label == 'Pin',
            ),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(pinOpacity(), 0);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Kira.pdf')));
    await tester.pumpAndSettle();
    expect(pinOpacity(), 1);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.label == 'Pin',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pinned'), findsOneWidget);
    expect(containerOf(tester).read(recentFilesProvider).single.pinned, isTrue);

    // Both the pinned card and the recent card now offer Unpin.
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) => widget is IconButton && widget.label == 'Unpin',
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pinned'), findsNothing);
  });

  testWidgets('picking a recent file opens it in the editor and puts it '
      'first', (tester) async {
    await pumpFermanApp(
      tester,
      engine: FakeEngineService(
        documents: {
          '/docs/Kira.pdf': const OpenedDocument(
            id: 1,
            pages: [PageInfo(width: 595, height: 842)],
          ),
        },
      ),
      recentFiles: [
        recent('Fatura.pdf'),
        recent('Kira.pdf', opened: now.subtract(const Duration(days: 3))),
      ],
    );
    await tester.tap(find.text('Kira.pdf'));
    await tester.pumpAndSettle();
    expect(find.byType(FmWindow), findsOneWidget);
    expect(
      containerOf(tester).read(recentFilesProvider).first.name,
      'Kira.pdf',
    );
    expect(find.byType(FmStart), findsNothing);
  });
}

const OpenedDocument kira = OpenedDocument(
  id: 1,
  pages: [PageInfo(width: 595, height: 842)],
);

/// Bookmarks named after their path; [moves] says where a bookmark's file
/// is now, and [stale] which bookmarks are renewed.
final class _FakeFileAccess implements FileAccess {
  final Map<String, String> moves = {};
  final Set<String> stale = {};
  final List<String> accessed = [];

  /// Whether [bookmark] makes one; off, a stored bookmark can only come
  /// from a renewal.
  bool makes = true;

  @override
  Future<String?> bookmark(String path) async =>
      makes ? 'bookmark:$path' : null;

  @override
  Future<BookmarkAccess?> access(String bookmark) async {
    accessed.add(bookmark);
    final path = bookmark.substring('bookmark:'.length);
    final now = moves[path] ?? path;
    return BookmarkAccess(
      path: now,
      renewed: stale.contains(bookmark) ? 'renewed:$now' : null,
    );
  }
}

/// A fake engine that records each collation it is asked for.
final class _CountingEngine extends FakeEngineService {
  final List<(String, List<String>)> collations = [];

  @override
  Future<List<int>> collationOrder(String locale, List<String> texts) {
    collations.add((locale, texts));
    return super.collationOrder(locale, texts);
  }
}

void missingAndBookmarks() {
  testWidgets('a recent file that is gone asks what to do (a1-9e); Remove '
      'from list drops it', (tester) async {
    await pumpFermanApp(
      tester,
      recentFiles: [
        recent('Gone.pdf', folder: '/docs/Banka'),
        recent('Kira.pdf'),
      ],
    );
    await tester.tap(find.text('Gone.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('“\u2068Gone.pdf\u2069” can’t be found'), findsOneWidget);
    expect(
      find.text(
        'It was moved, renamed or deleted after you last opened it. It was '
        'in \u2068/docs/Banka\u2069.',
      ),
      findsOneWidget,
    );
    // Not reported as a file that did not open.
    expect(find.byType(Banner), findsNothing);
    await tester.tap(find.text('Remove from list'));
    await tester.pumpAndSettle();
    expect(find.text('Gone.pdf'), findsNothing);
    expect(find.text('Kira.pdf'), findsOneWidget);
  });

  testWidgets('Locate… points the entry to the file chosen and opens it', (
    tester,
  ) async {
    final picker = FakeFilePickerService(picked: ['/new/Kira.pdf']);
    await pumpFermanApp(
      tester,
      picker: picker,
      engine: FakeEngineService(documents: {'/new/Kira.pdf': kira}),
      recentFiles: [recent('Kira.pdf', pinned: true)],
    );
    await tester.tap(find.text('Kira.pdf').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locate…'));
    await tester.pumpAndSettle();
    expect(find.byType(FmWindow), findsOneWidget);
    final entry = containerOf(tester).read(recentFilesProvider).single;
    expect(entry.path, '/new/Kira.pdf');
    expect(entry.pinned, isTrue);
  });

  testWidgets('a file opened keeps a bookmark, and a recent file opens '
      'through it, following a move and a renewed bookmark (Q18)', (
    tester,
  ) async {
    final access = _FakeFileAccess()
      ..makes = false
      ..moves['/docs/Kira.pdf'] = '/moved/Kira.pdf'
      ..stale.add('bookmark:/docs/Kira.pdf');
    await pumpFermanApp(
      tester,
      fileAccess: access,
      engine: FakeEngineService(documents: {'/moved/Kira.pdf': kira}),
      recentFiles: [
        RecentEntry(
          path: '/docs/Kira.pdf',
          name: 'Kira.pdf',
          opened: now,
          bookmark: 'bookmark:/docs/Kira.pdf',
        ),
      ],
    );
    await tester.tap(find.text('Kira.pdf'));
    await tester.pumpAndSettle();
    expect(access.accessed, ['bookmark:/docs/Kira.pdf']);
    expect(find.byType(FmWindow), findsOneWidget);
    final entry = containerOf(tester).read(recentFilesProvider).single;
    expect(entry.path, '/moved/Kira.pdf');
    // The renewed bookmark is the one kept.
    expect(entry.bookmark, 'renewed:/moved/Kira.pdf');
  });

  testWidgets('a file opened from Start is kept with a bookmark', (
    tester,
  ) async {
    await pumpFermanApp(
      tester,
      fileAccess: _FakeFileAccess(),
      picker: FakeFilePickerService(picked: ['/docs/Kira.pdf']),
      engine: FakeEngineService(documents: {'/docs/Kira.pdf': kira}),
    );
    await tester.tap(find.text('Open file…'));
    await tester.pumpAndSettle();
    final entry = containerOf(tester).read(recentFilesProvider).single;
    expect(entry.bookmark, 'bookmark:/docs/Kira.pdf');
    expect(entry.pages, 1);
  });

  testWidgets('Escape leaves a1-9e and keeps the file', (tester) async {
    await pumpFermanApp(tester, recentFiles: [recent('Gone.pdf')]);
    await tester.tap(find.text('Gone.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from list'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Remove from list'), findsNothing);
    expect(find.text('Gone.pdf'), findsOneWidget);
  });

  testWidgets('a location under the home directory reads "~"', (tester) async {
    await pumpFermanApp(
      tester,
      home: '/home/elif',
      recentFiles: [
        recent('Tez.pdf', pinned: true, pages: 64, folder: '/home/elif/Okul'),
      ],
    );
    expect(find.text('~/Okul · 64 pages'), findsOneWidget);
  });

  testWidgets('Tab reaches a hidden pin, which shows while focused and is in '
      'the semantics tree all along', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpFermanApp(tester, recentFiles: [recent('Kira.pdf')]);
    final pin = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.label == 'Pin',
    );
    double opacity() => tester
        .widget<Opacity>(find.ancestor(of: pin, matching: find.byType(Opacity)))
        .opacity;
    expect(opacity(), 0);
    expect(find.bySemanticsLabel('Pin'), findsOneWidget);
    for (var i = 0; i < 20 && opacity() == 0; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(opacity(), 1);
    semantics.dispose();
  });

  testWidgets('the sort and the view last when Start shows again', (
    tester,
  ) async {
    await pumpFermanApp(tester, recentFiles: [recent('Kira.pdf')]);
    containerOf(tester).read(recentLayoutProvider.notifier)
      ..sortBy(RecentSort.name)
      ..show(RecentView.list);
    await tester.pumpAndSettle();
    final router = containerOf(tester).read(routerProvider)..go(Routes.editor);
    await tester.pumpAndSettle();
    router.go(Routes.start);
    await tester.pumpAndSettle();
    expect(find.text('Location'), findsOneWidget);
    expect(
      tester.widget<Select<RecentSort>>(find.byType(Select<RecentSort>)).value,
      RecentSort.name,
    );
  });
}
