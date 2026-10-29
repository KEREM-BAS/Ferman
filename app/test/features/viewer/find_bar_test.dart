import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/shell_sidebar_tabs.dart';
import 'package:ferman/features/shell/shell_state.dart';
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

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  Future<FakeEngineService> pumpDocument(WidgetTester tester) async {
    final engine = FakeEngineService(
      documents: {'/kira.pdf': document},
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

  testWidgets('Alt+Enter shows every result in the sidebar, grouped by '
      'page; a click goes to one', (tester) async {
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
  });
}
