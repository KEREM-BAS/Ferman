/// Setting up AI clients (ADR 0019, G94): where `ferman-mcp` is, where Claude
/// Desktop keeps its configuration, and writing Ferman into it. `dart:io` on
/// the desktop; the web has no MCP host.
library;

import 'dart:convert';

export 'package:ferman/features/ai_clients/client_setup_io.dart'
    if (dart.library.js_interop) 'package:ferman/features/ai_clients/client_setup_web.dart';

/// The name Ferman's server takes in a client's configuration.
const String mcpServerName = 'ferman';

/// A client's MCP configuration that starts [command], `ferman-mcp`, on the
/// host's [folder]: the `mcpServers` form Claude Desktop and most local
/// clients read.
Map<String, Object?> mcpServerEntry(String command, String folder) => {
  'command': command,
  'args': [folder],
};

/// The configuration to copy into a client: [entry] as Ferman's server.
String copyableConfig(Map<String, Object?> entry) =>
    const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {mcpServerName: entry},
    });

/// The client configuration [existing] (null: no file yet) with [entry] as
/// Ferman's server and everything else kept; null when [existing] is not a
/// JSON object whose `mcpServers` is one, so it is never overwritten.
String? withMcpServer(String? existing, Map<String, Object?> entry) {
  Object? json;
  try {
    json = existing == null || existing.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(existing);
  } on FormatException {
    return null;
  }
  if (json is! Map<String, Object?>) return null;
  final servers = json['mcpServers'] ?? <String, Object?>{};
  if (servers is! Map<String, Object?>) return null;
  final merged = {
    ...json,
    'mcpServers': {...servers, mcpServerName: entry},
  };
  return '${const JsonEncoder.withIndent('  ').convert(merged)}\n';
}
