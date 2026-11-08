import 'package:ferman/app/router.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/ai_clients/ai_clients.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/stop_ai_clients.dart';
import '../helpers/window_golden.dart';

/// AI clients through MCP (G94, no board): Settings › AI clients with two
/// clients connected, one granted edit; the window's notice on the start
/// screen; and a client's request, in light and dark × en, tr and ar with
/// macOS chrome. Goldens run on Linux CI only.
Future<void> main() async {
  const screens = ['settings_ai_clients', 'ai_client_notice', 'client_request'];
  for (final screen in screens) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        final engine = FakeEngineService()
          ..connectedClients = [
            const McpClient(id: 1, name: 'Claude', mayEdit: true),
            const McpClient(id: 2, name: 'Cursor'),
          ];
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ).copyWith(aiClients: true),
          engine: engine,
          initialLocation: screen == 'settings_ai_clients'
              ? Routes.settingsPane(SettingsPane.aiClients.path)
              : null,
          overrides: [
            mcpPumpProvider.overrideWithValue(
              '/Applications/Ferman.app/Contents/MacOS/ferman-mcp',
            ),
            claudeDesktopConfigFileProvider.overrideWithValue(
              '/Users/ayse/Library/Application Support/Claude/claude_desktop_config.json',
            ),
          ],
          // The request is a Dialog, which hides while tickers are muted.
          muteTickers: screen != 'client_request',
          // The client-list poll would outlive the tree.
          cleanUp: stopAiClients,
          open: (tester) async {
            await tester.pumpAndSettle();
            if (screen == 'client_request') {
              engine.clientRequestEvents.add(
                const ClientRequest(
                  id: 1,
                  client: 1,
                  clientName: 'Claude',
                  kind: ClientRequestKind.writeFile,
                  path: '/Users/ayse/Documents/kira-sozlesmesi-ozet.pdf',
                ),
              );
              await tester.pumpAndSettle();
            }
          },
        );
      }
    }
  }
}
