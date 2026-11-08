/// The web has no MCP host and no client to set up.
library;

/// No `ferman-mcp` on the web.
String? mcpPumpPath() => null;

/// No Claude Desktop configuration on the web.
String? claudeDesktopConfig() => null;

/// Never writes on the web.
Future<bool> addMcpServer(String path, Map<String, Object?> entry) async =>
    false;
