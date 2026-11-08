import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ferman/app/app.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/ai_clients/ai_client_overlays.dart';
import 'package:ferman/features/ai_clients/ai_clients.dart';
import 'package:ferman/features/ai_clients/ai_clients_pane.dart';
import 'package:ferman/features/ai_clients/client_setup.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/stop_ai_clients.dart';
import '../onboarding/ferman_app_harness.dart';

const String _pump = '/app/ferman-mcp';

/// The switch whose semantics label starts with [label].
Finder _switch(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Switch &&
      ((widget.semanticLabel ?? widget.label)?.startsWith(label) ?? false),
);

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(FmStart, skipOffstage: false)),
);

/// The app on the start screen with AI clients [on], `ferman-mcp` at [_pump]
/// and Claude Desktop's configuration at [claudeConfig].
Future<FakeEngineService> _pumpApp(
  WidgetTester tester, {
  bool on = false,
  String? claudeConfig,
}) async {
  final engine = FakeEngineService();
  await pumpFermanApp(
    tester,
    engine: engine,
    settings: AppSettings(onboardingCompleted: true, aiClients: on),
    overrides: [
      mcpPumpProvider.overrideWithValue(_pump),
      claudeDesktopConfigFileProvider.overrideWithValue(claudeConfig),
    ],
  );
  return engine;
}

Future<void> _openPane(WidgetTester tester, SettingsPane pane) async {
  unawaited(
    _container(tester)
        .read(routerProvider)
        .push(Routes.settingsPane(pane.path)),
  );
  await tester.pumpAndSettle();
}

/// Lets the client list be read again.
Future<void> _poll(WidgetTester tester) async {
  await tester.pump(AiClients.pollEvery);
  await tester.pumpAndSettle();
}

void main() {
  group('client configuration', () {
    final entry = mcpServerEntry(_pump, '/data/mcp');

    test('adds Ferman and keeps everything else', () {
      final merged = withMcpServer(
        '{"theme":"dark","mcpServers":{"other":{"command":"x"}}}',
        entry,
      );
      expect(jsonDecode(merged!), {
        'theme': 'dark',
        'mcpServers': {
          'other': {'command': 'x'},
          'ferman': {
            'command': _pump,
            'args': ['/data/mcp'],
          },
        },
      });
      expect(jsonDecode(withMcpServer(null, entry)!), {
        'mcpServers': {'ferman': entry},
      });
    });

    test('never overwrites a file it cannot read', () {
      expect(withMcpServer('{not json', entry), isNull);
      expect(withMcpServer('[1]', entry), isNull);
      expect(withMcpServer('{"mcpServers":[]}', entry), isNull);
    });

    test('settings keep the switch, and an import never turns it on', () {
      const on = AppSettings(aiClients: true);
      expect(AppSettings.fromJson(on.toJson()).aiClients, isTrue);
      expect(const AppSettings().aiClients, isFalse);
      expect(
        AppSettings.imported({
          'version': 1,
          'aiClients': true,
        }, const AppSettings())!.aiClients,
        isFalse,
      );
    });
  });

  testWidgets('Settings › AI clients: off by default, on starts the host and '
      'offers the configuration, and a client is read only until granted', (
    tester,
  ) async {
    final engine = await _pumpApp(tester);
    await _openPane(tester, SettingsPane.aiClients);
    expect(find.byType(AiClientsPane), findsOneWidget);
    expect(
      tester.widget<Switch>(_switch('Let AI clients connect')).value,
      false,
    );
    expect(engine.mcpFolder, isNull);
    expect(find.text('Turn on the switch above to set up a client.'), findsOne);
    expect(find.textContaining('ChatGPT'), findsOneWidget);

    await tester.tap(_switch('Let AI clients connect'));
    await tester.pumpAndSettle();
    expect(engine.mcpFolder, '/data/mcp');
    expect(_container(tester).read(settingsProvider).aiClients, isTrue);
    expect(find.textContaining('"command": "$_pump"'), findsOneWidget);
    // No Claude Desktop configuration to write here: it is copied.
    expect(
      find.text('Copy the configuration below into its settings.'),
      findsOneWidget,
    );
    expect(find.text('No client is connected.'), findsOneWidget);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Copy configuration'));
    await tester.pump();
    expect(copied, copyableConfig(mcpServerEntry(_pump, '/data/mcp')));

    engine.connectedClients = [const McpClient(id: 1, name: 'Claude')];
    await _poll(tester);
    expect(find.text('No client is connected.'), findsNothing);
    final grant = _switch('\u2068Claude\u2069 can change documents');
    expect(tester.widget<Switch>(grant).value, isFalse);
    await tester.tap(grant);
    await tester.pumpAndSettle();
    expect(engine.connectedClients.single.mayEdit, isTrue);
    expect(tester.widget<Switch>(grant).value, isTrue);

    await tester.tap(_switch('Let AI clients connect'));
    await tester.pumpAndSettle();
    expect(engine.mcpFolder, isNull);
    expect(find.text('No client is connected.'), findsOneWidget);
  });

  testWidgets('stopAiClients ends the poll in a container that outlives the '
      'tree, as the goldens build it', (tester) async {
    const settings = AppSettings(onboardingCompleted: true, aiClients: true);
    final engine = FakeEngineService();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: ProviderContainer.test(
          overrides: [
            engineServiceProvider.overrideWithValue(engine),
            settingsStoreProvider.overrideWithValue(
              MemorySettingsStore(settings),
            ),
            initialSettingsProvider.overrideWithValue(settings),
            mcpPumpProvider.overrideWithValue(_pump),
          ],
        ),
        child: const FermanApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(engine.mcpFolder, '/data/mcp');
    await stopAiClients(tester);
    expect(engine.mcpFolder, isNull);
  });

  testWidgets('a failed start says so', (tester) async {
    final engine = FakeEngineService()..mcpStartFails = true;
    await pumpFermanApp(
      tester,
      engine: engine,
      settings: const AppSettings(onboardingCompleted: true, aiClients: true),
      overrides: [mcpPumpProvider.overrideWithValue(_pump)],
    );
    await _openPane(tester, SettingsPane.aiClients);
    expect(find.textContaining("couldn't open its connection"), findsOne);
  });

  testWidgets('Set up writes Ferman into Claude Desktop and keeps its own '
      'settings', (tester) async {
    final folder = Directory.systemTemp.createTempSync('ferman-claude');
    addTearDown(() => folder.deleteSync(recursive: true));
    final config = File('${folder.path}/claude_desktop_config.json')
      ..writeAsStringSync('{"globalShortcut":"Ctrl+Space"}');
    await _pumpApp(tester, on: true, claudeConfig: config.path);
    await _openPane(tester, SettingsPane.aiClients);
    await tester.runAsync(() async {
      await tester.tap(find.text('Set up'));
      // The write runs on real files.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(jsonDecode(config.readAsStringSync()), {
      'globalShortcut': 'Ctrl+Space',
      'mcpServers': {
        'ferman': {
          'command': _pump,
          'args': ['/data/mcp'],
        },
      },
    });
    expect(find.textContaining('is set up'), findsOneWidget);
  });

  testWidgets('the notice names the connected clients on every screen, and '
      'Stop turns the server off', (tester) async {
    final engine = await _pumpApp(tester, on: true);
    expect(engine.mcpFolder, '/data/mcp');
    expect(find.byType(AiClientNotice), findsNothing);
    engine.connectedClients = [
      const McpClient(id: 1, name: 'Claude'),
      const McpClient(id: 2, name: 'Cursor'),
    ];
    await _poll(tester);
    expect(find.byType(AiClientNotice), findsOneWidget);
    expect(
      find.text('AI clients connected: \u2068Claude\u2069, \u2068Cursor\u2069'),
      findsOneWidget,
    );

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();
    expect(engine.mcpFolder, isNull);
    expect(_container(tester).read(settingsProvider).aiClients, isFalse);
    expect(find.byType(AiClientNotice), findsNothing);
  });

  testWidgets('a request asks, and the answer reaches the client', (
    tester,
  ) async {
    final engine = await _pumpApp(tester, on: true);
    engine.clientRequestEvents
      ..add(
        const ClientRequest(
          id: 7,
          client: 1,
          clientName: 'Claude',
          kind: ClientRequestKind.writeFile,
          path: '/home/out.pdf',
        ),
      )
      ..add(
        const ClientRequest(
          id: 8,
          client: 1,
          clientName: 'Claude',
          kind: ClientRequestKind.save,
          document: 99,
        ),
      );
    await tester.pumpAndSettle();
    expect(find.byType(ClientRequestDialog), findsOneWidget);
    expect(find.text('\u2068Claude\u2069 wants to write a file'), findsOne);
    expect(find.text('\u2068/home/out.pdf\u2069'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(engine.clientAnswers, [(7, true)]);

    // The next one: saving a document no longer open cannot happen.
    expect(find.textContaining('wants to save'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(engine.clientAnswers.last, (8, false));
    expect(find.byType(ClientRequestDialog), findsNothing);

    engine.clientRequestEvents.add(
      const ClientRequest(
        id: 9,
        client: 1,
        clientName: 'Claude',
        kind: ClientRequestKind.sign,
        signer: 'Jane Smith',
        page: 2,
        field: 'Buyer',
      ),
    );
    await tester.pumpAndSettle();
    // The dialog shows the name it writes, the field and the page.
    expect(
      find.text(
        'It writes the name \u2068Jane Smith\u2069 in the field '
        '\u2068Buyer\u2069 on page 2: a simple signature, not a certificate '
        'signature.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text("Don't allow").last);
    await tester.pumpAndSettle();
    expect(engine.clientAnswers.last, (9, false));
  });

  testWidgets('a keystroke under way when a request arrives never allows it', (
    tester,
  ) async {
    final engine = await _pumpApp(tester, on: true);
    engine.clientRequestEvents.add(
      const ClientRequest(
        id: 3,
        client: 1,
        clientName: 'Claude',
        kind: ClientRequestKind.writeFile,
        path: '/home/out.pdf',
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(engine.clientAnswers, [(3, false)]);
  });

  testWidgets('a request whose client left closes, and Allow on it saves '
      'nothing', (tester) async {
    final engine = await _pumpApp(tester, on: true);
    engine.connectedClients = [const McpClient(id: 1, name: 'Claude')];
    final container = _container(tester);
    const request = ClientRequest(
      id: 4,
      client: 1,
      clientName: 'Claude',
      kind: ClientRequestKind.writeFile,
      path: '/home/out.pdf',
    );
    engine.clientRequestEvents.add(request);
    await tester.pumpAndSettle();
    expect(find.byType(ClientRequestDialog), findsOneWidget);

    // The client leaves: the engine drops its request.
    engine
      ..connectedClients = []
      ..droppedRequests.add(4);
    // Allow before the poll closes the dialog: nothing runs, nothing answers.
    await container
        .read(aiClientsProvider.notifier)
        .answer(request, allow: true);
    expect(engine.clientAnswers, isEmpty);

    engine.clientRequestEvents.add(
      const ClientRequest(
        id: 5,
        client: 1,
        clientName: 'Claude',
        kind: ClientRequestKind.save,
        document: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ClientRequestDialog), findsOneWidget);
    engine.droppedRequests.add(5);
    await _poll(tester);
    expect(find.byType(ClientRequestDialog), findsNothing);
    expect(engine.clientAnswers, isEmpty);
  });

  testWidgets('Settings › AI clients: the set-up rows reach screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester, on: true);
    await _openPane(tester, SettingsPane.aiClients);
    // Without Claude Desktop's file, its row still says to copy.
    expect(
      find.bySemanticsLabel(
        RegExp('Claude Desktop.*Copy the configuration', dotAll: true),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp("Other local clients.*client's MCP settings", dotAll: true),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Copy configuration'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Settings › Privacy says when AI clients could not start', (
    tester,
  ) async {
    final engine = FakeEngineService()..mcpStartFails = true;
    await pumpFermanApp(
      tester,
      engine: engine,
      settings: const AppSettings(onboardingCompleted: true, aiClients: true),
      overrides: [mcpPumpProvider.overrideWithValue(_pump)],
    );
    await tester.pumpAndSettle();
    await _openPane(tester, SettingsPane.privacy);
    expect(
      tester
          .widget<Switch>(_switch('AI clients on this computer'))
          .semanticLabel,
      contains("AI clients can't connect"),
    );
  });

  testWidgets('Settings › Privacy lists AI clients with a working switch', (
    tester,
  ) async {
    final engine = await _pumpApp(tester);
    await _openPane(tester, SettingsPane.privacy);
    final row = _switch('AI clients on this computer');
    expect(tester.widget<Switch>(row).value, isFalse);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(engine.mcpFolder, '/data/mcp');
    engine.connectedClients = [const McpClient(id: 1, name: 'Claude')];
    await _poll(tester);
    expect(
      tester.widget<Switch>(row).semanticLabel,
      contains('AI clients connected: \u2068Claude\u2069'),
    );
  });
}
