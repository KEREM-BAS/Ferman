import 'dart:async';

import 'package:ferman/app/app.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/tokens.g.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/open_problem_tab.dart';
import 'package:ferman/features/shell/shell_screen.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_open_requests.dart';
import '../onboarding/ferman_app_harness.dart';

const OpenedDocument kira = OpenedDocument(
  id: 1,
  pages: [PageInfo(width: 595, height: 842)],
);
const OpenedDocument nda = OpenedDocument(
  id: 2,
  pages: [PageInfo(width: 612, height: 792), PageInfo(width: 612, height: 792)],
);
const Map<String, OpenedDocument> documents = {
  '/docs/kira-tr.pdf': kira,
  '/docs/nda-en.pdf': nda,
};

/// An engine whose opens wait until [release] completes, counting them.
final class _HeldEngine extends FakeEngineService {
  new() : super(documents: documents);

  final Completer<void> release = Completer();

  int opens = 0;

  @override
  Future<OpenedDocument> open(String path, {String? password}) {
    opens++;
    return release.future.then((_) => super.open(path, password: password));
  }
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FermanApp)));

/// The paths of the open tabs.
List<String?> tabs(WidgetTester tester) => [
  for (final document in containerOf(
    tester,
  ).read(shellDocumentsProvider).documents)
    document.path,
];

/// Sends desktop_drop's [method] as its runner would.
Future<void> dropEvent(
  WidgetTester tester,
  String method, [
  Object? arguments,
]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'desktop_drop',
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Files dragged over the window at (100, 100).
Future<void> dragIn(WidgetTester tester) =>
    dropEvent(tester, 'entered', <double>[100, 100]);

void main() {
  group('files from the system (ADR 0021)', () {
    testWidgets('a cold launch with files opens them before the first frame '
        'shows, and skips Start (G25)', (tester) async {
      final engine = _HeldEngine();
      final requests = FakeOpenRequests(
        launch: ['/docs/kira-tr.pdf', '/docs/nda-en.pdf'],
      );
      addTearDown(requests.close);
      await pumpFermanApp(tester, engine: engine, openRequests: requests);
      // The first frame waits for the documents.
      expect(engine.opens, 1);
      expect(tester.binding.sendFramesToEngine, isFalse);

      engine.release.complete();
      await tester.pumpAndSettle();
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(find.byType(FmStart), findsNothing);
      expect(find.byType(FmWindow), findsOneWidget);
      expect(tabs(tester), ['/docs/kira-tr.pdf', '/docs/nda-en.pdf']);
    });

    testWidgets('the first frame waits for the launch at most 500 ms, then '
        'the file opens in the editor when it lands', (tester) async {
      final engine = _HeldEngine();
      final requests = FakeOpenRequests(launch: ['/docs/kira-tr.pdf']);
      addTearDown(requests.close);
      await pumpFermanApp(tester, engine: engine, openRequests: requests);
      expect(tester.binding.sendFramesToEngine, isFalse);
      // The open never lands within the wait (the harness has settled part
      // of it already).
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(find.byType(FmStart), findsOneWidget);

      engine.release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FmWindow), findsOneWidget);
      expect(tabs(tester), ['/docs/kira-tr.pdf']);
    });

    testWidgets('later requests wait for the launch and do not hold up '
        'other files', (tester) async {
      final engine = _HeldEngine();
      final requests = FakeOpenRequests(launch: ['/docs/kira-tr.pdf']);
      addTearDown(requests.close);
      requests.requests.add(['/docs/kira-tr.pdf', '/docs/nda-en.pdf']);
      await pumpFermanApp(tester, engine: engine, openRequests: requests);
      // The launch's file opens first; the later request waits for it and
      // opens only the other one.
      engine.release.complete();
      await tester.pumpAndSettle();
      expect(engine.opens, 2);
      expect(tabs(tester), ['/docs/kira-tr.pdf', '/docs/nda-en.pdf']);
    });

    testWidgets('a cold launch with a file that does not open shows its '
        'error tab (a1-9b)', (tester) async {
      final requests = FakeOpenRequests(launch: ['/docs/gone.pdf']);
      addTearDown(requests.close);
      await pumpFermanApp(
        tester,
        engine: FakeEngineService(documents: documents),
        openRequests: requests,
      );
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(find.byType(OpenErrorTab), findsOneWidget);
    });

    testWidgets('a later request opens in a new tab, and a file asked for '
        'twice at once opens once', (tester) async {
      final engine = _HeldEngine();
      final requests = FakeOpenRequests();
      addTearDown(requests.close);
      await pumpFermanApp(tester, engine: engine, openRequests: requests);
      expect(find.byType(FmStart), findsOneWidget);

      // Two double-clicks on the same file while the first still opens.
      requests.requests
        ..add(['/docs/kira-tr.pdf'])
        ..add(['/docs/kira-tr.pdf']);
      await tester.pumpAndSettle();
      expect(engine.opens, 1);
      engine.release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(FmWindow), findsOneWidget);
      expect(tabs(tester), ['/docs/kira-tr.pdf']);
      expect(engine.opens, 1);

      requests.requests.add(['/docs/nda-en.pdf']);
      await tester.pumpAndSettle();
      expect(tabs(tester), ['/docs/kira-tr.pdf', '/docs/nda-en.pdf']);
      expect(containerOf(tester).read(shellDocumentsProvider).activeIndex, 1);
    });
  });

  group('files dropped on the window (a1-6, G105)', () {
    testWidgets('files dragged over the window show a1-6 without a count, '
        'and leaving hides it', (tester) async {
      await pumpFermanApp(
        tester,
        engine: FakeEngineService(documents: documents),
      );
      expect(find.text('Drop to open the files'), findsNothing);

      await dragIn(tester);
      expect(find.text('Drop to open the files'), findsOneWidget);
      expect(find.text('Move over a choice, then let go.'), findsOneWidget);
      expect(find.text('Open in tabs'), findsOneWidget);
      expect(find.text('Each file opens on its own.'), findsOneWidget);
      // Combining waits for M4 (B104): disabled, its line the reason; only
      // the tabs target has the accent ring.
      Finder target(String title) => find
          .ancestor(of: find.text(title), matching: find.byType(Container))
          .first;
      const colors = FermanColorTokens.light;
      expect(
        find.descendant(
          of: target('Combine into one PDF'),
          matching: find.text('Available in a future version'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: target('Open in tabs'),
          matching: find.text('Available in a future version'),
        ),
        findsNothing,
      );
      expect(
        tester.widget<Text>(find.text('Combine into one PDF')).style?.color,
        colors.textDisabled,
      );
      List<Color> rings(String title) => [
        for (final shadow
            in ((tester.widget<Container>(target(title)).decoration!
                        as BoxDecoration)
                    .boxShadow ??
                const <BoxShadow>[]))
          shadow.color,
      ];
      expect(rings('Open in tabs'), contains(colors.accent));
      expect(rings('Combine into one PDF'), isNot(contains(colors.accent)));

      await dropEvent(tester, 'exited');
      expect(find.text('Drop to open the files'), findsNothing);
      expect(tabs(tester), isNot(contains('/docs/kira-tr.pdf')));
    });

    testWidgets('a drop on Start opens each file in a new tab and shows the '
        'editor', (tester) async {
      await pumpFermanApp(
        tester,
        engine: FakeEngineService(documents: documents),
      );
      await dragIn(tester);
      await dropEvent(tester, 'performOperation', [
        '/docs/kira-tr.pdf',
        '/docs/nda-en.pdf',
      ]);
      expect(find.text('Drop to open the files'), findsNothing);
      expect(find.byType(FmWindow), findsOneWidget);
      expect(tabs(tester), ['/docs/kira-tr.pdf', '/docs/nda-en.pdf']);

      // The editor takes drops too.
      await dragIn(tester);
      expect(find.text('Drop to open the files'), findsOneWidget);
      await dropEvent(tester, 'performOperation', ['/docs/kira-tr.pdf']);
      expect(tabs(tester), ['/docs/kira-tr.pdf', '/docs/nda-en.pdf']);
      expect(containerOf(tester).read(shellDocumentsProvider).activeIndex, 0);
    });

    testWidgets('a dropped file that does not open gets its error tab', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        engine: FakeEngineService(documents: documents),
      );
      await dragIn(tester);
      await dropEvent(tester, 'performOperation', ['/docs/notes.txt']);
      expect(find.byType(OpenErrorTab), findsOneWidget);
    });

    testWidgets('no drops while the engine cannot open files', (tester) async {
      await pumpFermanApp(
        tester,
        engine: const UnavailableEngineService(
          EngineUnavailableException(EngineUnavailableReason.libraryMissing),
        ),
      );
      await dragIn(tester);
      expect(find.text('Drop to open the files'), findsNothing);
      await dropEvent(tester, 'performOperation', ['/docs/kira-tr.pdf']);
      expect(tabs(tester), isNot(contains('/docs/kira-tr.pdf')));
    });

    testWidgets('no drops on Settings', (tester) async {
      await pumpFermanApp(
        tester,
        engine: FakeEngineService(documents: documents),
      );
      unawaited(containerOf(tester).read(routerProvider).push(Routes.settings));
      await tester.pumpAndSettle();
      await dragIn(tester);
      expect(find.text('Drop to open the files'), findsNothing);
      await dropEvent(tester, 'performOperation', ['/docs/kira-tr.pdf']);
      expect(tabs(tester), isNot(contains('/docs/kira-tr.pdf')));
    });
  });
}
