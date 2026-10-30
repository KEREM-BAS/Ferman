import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import 'shell_host.dart';

ShellDocumentList list(int count, int active) => ShellDocumentList(
  documents: [
    for (var i = 0; i < count; i++) ShellDocument(name: '$i.pdf', path: '/$i'),
  ],
  activeIndex: active,
);

void main() {
  test('the first tabs show, the active one in the last place when it lies '
      'further on', () {
    expect(list(3, 2).shown(5), [0, 1, 2]);
    expect(list(8, 1).shown(4), [0, 1, 2, 3]);
    expect(list(8, 6).shown(4), [0, 1, 2, 6]);
    expect(list(8, 3).shown(4), [0, 1, 2, 3]);
    expect(list(8, 5).shown(0), [5]);
  });

  testWidgets('twenty documents fit the title bar: the active one shows and '
      'the rest go behind "+N" (a1-10)', (tester) async {
    final window = FakeDesktopWindow(WindowPlatform.linux);
    addTearDown(window.dispose);
    await pumpShell(
      tester,
      shellHost(
        window: window,
        overrides: [
          engineServiceProvider.overrideWithValue(FakeEngineService()),
        ],
      ),
    );
    final documents = containerOf(tester).read(shellDocumentsProvider.notifier);
    for (var i = 0; i < 20; i++) {
      documents.add(
        ShellDocument(
          name: 'Belge ${i + 1}.pdf',
          path: '/belge-$i.pdf',
          document: OpenedDocument(
            id: i + 1,
            pages: const [PageInfo(width: 595, height: 842)],
          ),
        ),
      );
    }
    await settle(tester);
    expect(tester.takeException(), isNull);
    final tabs = tester.widgetList<DocumentTab>(find.byType(DocumentTab));
    expect(tabs.length, lessThan(20));
    expect(tabs.last.name, 'Belge 20.pdf');
    expect(tabs.last.active, isTrue);
    expect(find.text('+${20 - tabs.length}'), findsOneWidget);

    documents.activate(0);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<DocumentTab>(find.byType(DocumentTab).first).active,
      isTrue,
    );
  });

  Future<ShellDocuments> pumpWith(WidgetTester tester, int count) async {
    final window = FakeDesktopWindow(WindowPlatform.linux);
    addTearDown(window.dispose);
    await pumpShell(
      tester,
      shellHost(
        window: window,
        overrides: [
          engineServiceProvider.overrideWithValue(FakeEngineService()),
        ],
      ),
    );
    final documents = containerOf(tester).read(shellDocumentsProvider.notifier);
    for (var i = 0; i < count; i++) {
      documents.add(
        ShellDocument(
          name: 'Belge ${i + 1}.pdf',
          path: '/belge-$i.pdf',
          document: OpenedDocument(
            id: i + 1,
            pages: const [PageInfo(width: 595, height: 842)],
          ),
        ),
      );
    }
    await settle(tester);
    return documents;
  }

  /// How much wider than their 112 px least width the shown tabs are, all
  /// together: once tabs hide, less than one more tab and its gap.
  double spare(WidgetTester tester) => [
    for (final element in find.byType(DocumentTab).evaluate())
      tester.getSize(find.byWidget(element.widget)).width - 112,
  ].fold(0, (sum, extra) => sum + extra);

  List<String> tabNames(WidgetTester tester) => [
    for (final tab in tester.widgetList<DocumentTab>(find.byType(DocumentTab)))
      tab.name,
  ];

  testWidgets('from 1 to 20 documents the strip never overflows and never '
      'leaves room for one more tab', (tester) async {
    final documents = await pumpWith(tester, 0);
    var hid = false;
    for (var i = 0; i < 20; i++) {
      documents.add(
        ShellDocument(
          name: 'Belge ${i + 1}.pdf',
          path: '/belge-$i.pdf',
          document: OpenedDocument(
            id: i + 1,
            pages: const [PageInfo(width: 595, height: 842)],
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '${i + 1} documents');
      final shown = tabNames(tester).length;
      if (shown == i + 1) continue;
      expect(find.text('+${i + 1 - shown}'), findsOneWidget);
      expect(spare(tester), lessThan(112 + 2), reason: '${i + 1} documents');
      hid = true;
    }
    expect(hid, isTrue);
  });

  testWidgets('at any window width, twenty documents leave no room for one '
      'more tab', (tester) async {
    final window = FakeDesktopWindow(WindowPlatform.linux);
    addTearDown(window.dispose);
    final sizes = ValueNotifier(artboard);
    addTearDown(sizes.dispose);
    await pumpShellAt(
      tester,
      shellHost(
        window: window,
        size: sizes,
        overrides: [
          engineServiceProvider.overrideWithValue(FakeEngineService()),
        ],
      ),
      sizes,
    );
    final documents = containerOf(tester).read(shellDocumentsProvider.notifier);
    for (var i = 0; i < 20; i++) {
      documents.add(
        ShellDocument(
          name: 'Belge ${i + 1}.pdf',
          path: '/belge-$i.pdf',
          document: OpenedDocument(
            id: i + 1,
            pages: const [PageInfo(width: 595, height: 842)],
          ),
        ),
      );
    }
    for (var width = 1024.0; width <= 1440; width += 16) {
      await resizeShell(tester, sizes, Size(width, artboard.height));
      expect(tester.takeException(), isNull, reason: '$width px');
      expect(spare(tester), lessThan(112 + 2), reason: '$width px');
    }
  });

  testWidgets('a focused tab keeps its focus when the tabs before it leave '
      'the strip', (tester) async {
    final documents = await pumpWith(tester, 6);
    final last = find.byType(DocumentTab).last;
    tester.widget<DocumentTab>(last).focusNode!.requestFocus();
    await settle(tester);
    expect(tester.widget<DocumentTab>(last).focusNode!.hasPrimaryFocus, isTrue);
    for (var i = 6; i < 20; i++) {
      documents.add(
        ShellDocument(
          name: 'Belge ${i + 1}.pdf',
          path: '/belge-$i.pdf',
          document: OpenedDocument(
            id: i + 1,
            pages: const [PageInfo(width: 595, height: 842)],
          ),
        ),
      );
    }
    documents.activate(5);
    await settle(tester);
    final focused = tester
        .widgetList<DocumentTab>(find.byType(DocumentTab))
        .where((tab) => tab.focusNode?.hasPrimaryFocus ?? false);
    expect(focused.single.name, 'Belge 6.pdf');
  });

  testWidgets('"+N" lists the hidden documents with their keys; picking one '
      'shows it (a1-10)', (tester) async {
    final documents = await pumpWith(tester, 20);
    documents.activate(0);
    await settle(tester);
    final hidden = 20 - tabNames(tester).length;
    await tester.tap(find.text('+$hidden'));
    await settle(tester);
    expect(find.byType(Menu), findsOneWidget);
    expect(find.text('$hidden more documents'), findsOneWidget);
    expect(find.text('Belge 20.pdf'), findsOneWidget);
    expect(find.text('Show all open documents'), findsOneWidget);
    expect(find.text('Close other documents…'), findsOneWidget);
    await tester.tap(find.text('Belge 20.pdf'));
    await settle(tester);
    expect(find.byType(Menu), findsNothing);
    expect(containerOf(tester).read(shellDocumentsProvider).activeIndex, 19);
    expect(tabNames(tester).last, 'Belge 20.pdf');
  });
}
