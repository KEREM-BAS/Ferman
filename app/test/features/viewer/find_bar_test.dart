import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/shell_sidebar_tabs.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/features/viewer/find_bar.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import '../shell/shell_host.dart';

/// Three A4 pages.
const OpenedDocument document = OpenedDocument(
  id: 9,
  pages: [
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
    PageInfo(width: 595, height: 842),
  ],
);

SearchMatch hit(int page) => SearchMatch(
  page: page,
  rects: const [Rect.fromLTRB(72, 80, 120, 94)],
  snippet: 'KİRA SÖZLEŞMESİ',
  snippetStart: 0,
  snippetEnd: 4,
);

/// A search that reads [searched] pages of [pages], finds the first page's
/// match, and waits.
class _SlowSearch extends FakeEngineService {
  new({this.searched = 1, this.pages = 3})
    : super(documents: {'/kira.pdf': document});

  final int searched;
  final int pages;

  @override
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  ) async* {
    yield SearchMatches([hit(0)]);
    yield SearchProgress(searched: searched, pages: pages);
    await Completer<void>().future;
  }
}

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<FakeEngineService> pumpDocument(
    WidgetTester tester, {
    bool textless = false,
  }) async {
    final engine = FakeEngineService(
      documents: {'/kira.pdf': document},
      textless: textless,
      searchResults: {
        'kira': [
          [hit(0)],
          [hit(2)],
        ],
      },
    );
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

  FindState findState(WidgetTester tester) =>
      containerOf(tester).read(findProvider);

  Future<void> controlF(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
  }

  Finder field() => find.byType(EditableText);

  testWidgets('Ctrl+F opens the bar with its options; typing searches and '
      'Enter steps through the matches', (tester) async {
    final engine = await pumpDocument(tester);
    expect(find.byType(SearchReplaceBar), findsNothing);
    await controlF(tester);
    expect(find.byType(SearchReplaceBar), findsOneWidget);
    expect(find.byType(FindBar), findsOneWidget);
    // The field takes focus from the canvas.
    expect(tester.widget<EditableText>(field()).focusNode.hasFocus, isTrue);
    expect(find.text('Ignore accents and dotted/dotless i'), findsOneWidget);

    await tester.enterText(field(), 'kira');
    await settle(tester);
    expect(engine.searches.single, ('kira', const SearchOptions()));
    expect(findState(tester).matches, hasLength(2));
    expect(find.textContaining('1 of 2'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(findState(tester).current, 1);
    expect(containerOf(tester).read(viewerProvider)!.currentPage, 2);
    expect(find.textContaining('2 of 2'), findsOneWidget);

    // The regular-expression option waits for a future version.
    final regex = tester.widget<Checkbox>(
      find.byWidgetPredicate(
        (widget) => widget is Checkbox && widget.label == 'Regular expression',
      ),
    );
    expect(regex.disabledReason, futureVersion);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(SearchReplaceBar), findsNothing);
  });

  testWidgets('pages that changed while another document showed search again', (
    tester,
  ) async {
    final engine = await pumpDocument(tester);
    final container = containerOf(tester);
    final documents = container.read(openDocumentProvider.notifier);
    final find_ = container.read(findProvider.notifier);
    await controlF(tester);
    find_.setQuery('kira');
    await settle(tester);
    expect(findState(tester).matches, hasLength(2));

    const other = OpenedDocument(
      id: 10,
      pages: [PageInfo(width: 1, height: 1)],
    );
    documents.show(other);
    await settle(tester);
    engine.searchResults['kira'] = [
      [hit(0)],
    ];
    find_.pagesChangedElsewhere(document.id);
    documents.show(document);
    await settle(tester);
    expect(findState(tester).matches, hasLength(1));
    expect(findState(tester).stale, isFalse);
  });

  testWidgets('Alt+Enter shows every result in the sidebar, grouped by '
      'page; a click goes to one, and the arrow keys move from it', (
    tester,
  ) async {
    await pumpDocument(tester);
    await controlF(tester);
    await tester.enterText(find.byType(EditableText).first, 'kira');
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    final container = containerOf(tester);
    expect(container.read(shellSidebarTabProvider), SidebarTab.search);
    expect(find.byType(SidebarSearch), findsOneWidget);
    final results = find.descendant(
      of: find.byType(SidebarSearch),
      matching: find.textContaining('SÖZLEŞMESİ', findRichText: true),
    );
    expect(results, findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(SidebarSearch),
        matching: find.text('PAGE 3'),
      ),
      findsOneWidget,
    );
    expect(find.text('2 matches on 2 pages'), findsOneWidget);
    await tester.tap(results.last);
    await settle(tester);
    expect(findState(tester).current, 1);
    expect(container.read(viewerProvider)!.currentPage, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(findState(tester).current, 0);
    expect(container.read(viewerProvider)!.currentPage, 0);
    // The first result stays first: ↑ does not wrap, as ↵ in the bar does.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(findState(tester).current, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(findState(tester).current, 1);
    expect(container.read(viewerProvider)!.currentPage, 2);
  });

  testWidgets('a document without text says so in the sidebar, with Recognize '
      'text for a future version (a2-3m)', (tester) async {
    await pumpDocument(tester, textless: true);
    await controlF(tester);
    await tester.enterText(field(), 'kira bedeli');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    expect(findState(tester).textless, isTrue);
    final sidebar = find.byType(SidebarSearch);
    expect(
      find.descendant(of: sidebar, matching: find.text('No text to search')),
      findsOneWidget,
    );
    final ocr = tester.widget<Button>(
      find.descendant(of: sidebar, matching: find.byType(Button)),
    );
    expect(ocr.disabled, isTrue);
    expect(ocr.disabledReason, futureVersion);
  });

  testWidgets('a search that finds nothing says what it searched (a2-4d)', (
    tester,
  ) async {
    await pumpDocument(tester);
    await controlF(tester);
    await tester.enterText(field(), 'depozito');
    await settle(tester);
    expect(find.text('No results for “depozito”'), findsOneWidget);
    expect(
      find.text(
        'Ferman searched all 3 pages, ignoring accents and dotted/dotless i. '
        'Comments and form fields weren’t searched.',
      ),
      findsOneWidget,
    );
    expect(find.text('No results'), findsOneWidget);

    // Back in the bar, the query is selected, so typing replaces it.
    await controlF(tester);
    final editable = tester.widget<EditableText>(field());
    expect(editable.focusNode.hasFocus, isTrue);
    expect(
      editable.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 8),
    );
  });

  testWidgets('a long search shows its progress under the bar, counting '
      'what it found; Esc cancels it, then closes the bar (a2-4c)', (
    tester,
  ) async {
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        overrides: [
          engineServiceProvider.overrideWithValue(
            _SlowSearch(searched: 38, pages: 120),
          ),
        ],
      ),
    );
    containerOf(tester).read(openDocumentProvider.notifier).show(document);
    await settle(tester);
    await controlF(tester);
    await tester.enterText(field(), 'kira');
    await settle(tester);
    final bar = find.byType(FindBar);
    Finder inBar(Finder finder) => find.descendant(of: bar, matching: finder);
    // The heading, and the bar's accessible name.
    expect(inBar(find.text('Searching · page 38 of 120')), findsWidgets);
    expect(
      inBar(find.text('Matches appear as they’re found.')),
      findsOneWidget,
    );
    expect(inBar(find.byType(Spinner)), findsOneWidget);
    expect(
      tester.widget<ProgressBar>(inBar(find.byType(ProgressBar))).value,
      closeTo(38 / 120, 1e-9),
    );
    // The options give way to the progress; the match found counts.
    expect(
      inBar(find.text('Ignore accents and dotted/dotless i')),
      findsNothing,
    );
    expect(inBar(find.textContaining('1 of 1')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(findState(tester).searched, isNull);
    expect(find.byType(SearchReplaceBar), findsOneWidget);
    expect(inBar(find.byType(ProgressBar)), findsNothing);
    expect(findState(tester).matches, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(SearchReplaceBar), findsNothing);
  });

  testWidgets('a running search shows in the status bar, whose Cancel stops '
      'it (B124)', (tester) async {
    await pumpShell(
      tester,
      shellHost(
        window: window,
        regionCode: 'GB',
        overrides: [engineServiceProvider.overrideWithValue(_SlowSearch())],
      ),
    );
    containerOf(tester).read(openDocumentProvider.notifier).show(document);
    await settle(tester);
    await controlF(tester);
    await tester.enterText(field(), 'kira');
    await settle(tester);
    final task = find.descendant(
      of: find.byType(ShellStatusBar),
      matching: find.byType(TaskProgress),
    );
    expect(task, findsOneWidget);
    final progress = tester.widget<TaskProgress>(task);
    expect(progress.title, 'Searching');
    expect(progress.detail, 'Page 1 of 3');
    expect(progress.value, closeTo(1 / 3, 1e-9));
    progress.onCancel!();
    await settle(tester);
    expect(task, findsNothing);
    expect(findState(tester).searched, isNull);
  });

  testWidgets('Look in › Bookmarks searches the bookmarks too; comments and '
      'form fields wait (B114)', (tester) async {
    final engine = await pumpDocument(tester);
    await controlF(tester);
    await tester.enterText(field(), 'kira');
    await settle(tester);
    Checkbox checkbox(String label) => tester.widget<Checkbox>(
      find.byWidgetPredicate(
        (widget) => widget is Checkbox && widget.label == label,
      ),
    );
    expect(checkbox('Bookmarks').disabled, isFalse);
    expect(checkbox('Comments').checked, isTrue);
    expect(checkbox('Comments').disabled, isFalse);
    expect(checkbox('Form fields').disabledReason, futureVersion);
    checkbox('Bookmarks').onChanged!(true);
    await settle(tester);
    expect(engine.searches.last, (
      'kira',
      const SearchOptions(bookmarks: true),
    ));
  });
}
