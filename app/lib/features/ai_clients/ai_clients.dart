import 'dart:async';

import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/ai_clients/client_setup.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_clients.g.dart';

/// `ferman-mcp` beside the app's executable ([mcpPumpPath]); null on the web.
/// Tests give it a fixed path.
@Riverpod(keepAlive: true)
String? mcpPump(Ref ref) => mcpPumpPath();

/// Claude Desktop's configuration file where one-click setup can write it
/// ([claudeDesktopConfig]), or null. Tests give it a temporary file.
@Riverpod(keepAlive: true)
String? claudeDesktopConfigFile(Ref ref) => claudeDesktopConfig();

/// Where AI clients stand, as `aiClientsProvider`.
@immutable
final class AiClientsState {
  /// The state with the host listening in [folder] (null: stopped).
  const new({
    this.folder,
    this.clients = const [],
    this.requests = const [],
    this.failed = false,
  });

  /// The folder `ferman-mcp` takes while the host listens; null while it is
  /// stopped.
  final String? folder;

  /// The connected clients, oldest first.
  final List<McpClient> clients;

  /// The clients' requests waiting for the person's answer, oldest first;
  /// the first shows as a dialog.
  final List<ClientRequest> requests;

  /// Whether the host could not start although the setting is on.
  final bool failed;

  /// Whether the host listens.
  bool get running => folder != null;
}

/// AI clients through MCP (ADR 0019, G94), as `aiClientsProvider`: the host
/// runs while Settings › AI clients' switch (`AppSettings.aiClients`) is on,
/// off by default; the connected clients with their edit permission, read
/// only until the person grants it; the requests they make, answered through
/// a dialog; and their steps, which reach the pages and the history as the
/// person's own do.
@Riverpod(keepAlive: true)
class AiClients extends _$AiClients {
  /// How often the client list is read while the host runs, in
  /// milliseconds.
  static const int pollMs = 2000;

  /// [pollMs] as a duration.
  static const Duration pollEvery = Duration(milliseconds: pollMs);

  EngineService get _engine => ref.read(engineServiceProvider);

  Timer? _poll;
  StreamSubscription<ClientRequest>? _requests;
  StreamSubscription<ClientChange>? _changes;

  @override
  AiClientsState build() {
    ref
      ..onDispose(_unlisten)
      ..listen(
        settingsProvider.select((settings) => settings.aiClients),
        (_, on) => unawaited(on ? _start() : _stop()),
      );
    if (ref.read(settingsProvider).aiClients) {
      // Not while building: the start sets the state.
      scheduleMicrotask(() => unawaited(_start()));
    }
    return const AiClientsState();
  }

  Future<void> _start() async {
    if (state.running) return;
    final String folder;
    try {
      folder = await _engine.startMcpHost();
    } on EngineException {
      if (ref.mounted) state = const AiClientsState(failed: true);
      return;
    }
    if (!ref.mounted) return;
    // Turned off, or started twice, while it started: nothing listens
    // against the switch.
    if (!ref.read(settingsProvider).aiClients) {
      await _engine.stopMcpHost();
      return;
    }
    if (state.running) return;
    _requests = _engine.clientRequests().listen(
      (request) => state = AiClientsState(
        folder: state.folder,
        clients: state.clients,
        requests: [...state.requests, request],
      ),
    );
    _changes = _engine.clientChanges().listen(
      (change) => unawaited(
        ref
            .read(documentEditorProvider.notifier)
            .clientChanged(change.document, change.revision),
      ),
    );
    state = AiClientsState(folder: folder);
    // shortcut: the client list is polled, as the engine sends no event when
    // a client connects or leaves; a stream of those is the upgrade.
    _poll = Timer.periodic(pollEvery, (_) => unawaited(refresh()));
    await refresh();
  }

  Future<void> _stop() async {
    _unlisten();
    state = const AiClientsState();
    await _engine.stopMcpHost();
  }

  void _unlisten() {
    _poll?.cancel();
    _poll = null;
    unawaited(_requests?.cancel());
    unawaited(_changes?.cancel());
    _requests = null;
    _changes = null;
  }

  /// Reads the connected clients again, and drops the requests the engine
  /// no longer waits on (their client left), so their dialog closes.
  Future<void> refresh() async {
    if (!state.running) return;
    final clients = await _engine.mcpClients();
    final gone = <int>{
      for (final request in state.requests)
        if (!await _engine.clientRequestPending(request.id)) request.id,
    };
    if (!ref.mounted || !state.running) return;
    if (listEquals(clients, state.clients) && gone.isEmpty) return;
    state = AiClientsState(
      folder: state.folder,
      clients: clients,
      requests: [
        for (final request in state.requests)
          if (!gone.contains(request.id)) request,
      ],
    );
  }

  /// Lets [client] change documents ([mayEdit]), or makes it read only.
  Future<void> grantEdit(McpClient client, {required bool mayEdit}) async {
    try {
      await _engine.grantClientEdit(client.id, mayEdit: mayEdit);
    } on EngineException {
      // It left meanwhile; the list below says so.
    }
    await refresh();
  }

  /// The person's answer to [request]. Saving and restoring a version go
  /// through the app's own flow first, and the client hears whether they
  /// happened.
  Future<void> answer(ClientRequest request, {required bool allow}) async {
    state = AiClientsState(
      folder: state.folder,
      clients: state.clients,
      requests: [
        for (final each in state.requests)
          if (each.id != request.id) each,
      ],
    );
    // A client that left gets no answer: what it asked never runs.
    if (!await _engine.clientRequestPending(request.id)) return;
    var done = allow;
    if (allow) {
      final tab = tabOf(request);
      final saver = ref.read(documentSaverProvider.notifier);
      switch (request.kind) {
        case ClientRequestKind.save:
          done = tab != null && await saver.saveTab(tab);
        case ClientRequestKind.restoreVersion:
          final version = request.version;
          done =
              tab != null &&
              version != null &&
              await saver.restoreVersion(version, tab: tab);
        case ClientRequestKind.editSigned ||
            ClientRequestKind.writeFile ||
            ClientRequestKind.readFile ||
            ClientRequestKind.sign:
          break;
      }
    }
    await _engine.answerClientRequest(request.id, allow: done);
  }

  /// The tab of the document [request] is about, or null.
  ShellDocument? tabOf(ClientRequest request) => ref
      .read(shellDocumentsProvider)
      .documents
      .where(
        (tab) =>
            request.document != null && tab.document?.id == request.document,
      )
      .firstOrNull;
}
