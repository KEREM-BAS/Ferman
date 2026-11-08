/// Setting up AI clients on the desktop.
library;

import 'dart:io';

import 'package:ferman/features/ai_clients/client_setup.dart'
    show withMcpServer;

/// `ferman-mcp`, which every desktop build puts beside the app's executable
/// (ADR 0019).
String? mcpPumpPath() {
  final folder = File(Platform.resolvedExecutable).parent.path;
  return Platform.isWindows ? '$folder\\ferman-mcp.exe' : '$folder/ferman-mcp';
}

/// Claude Desktop's configuration file, where one-click setup can write it.
/// None on Linux, where there is no Claude Desktop, and none under the macOS
/// App Sandbox, which keeps Ferman out of another app's folder: there the
/// configuration is copied instead (ADR 0019 f).
String? claudeDesktopConfig() {
  final environment = Platform.environment;
  if (Platform.isMacOS &&
      !environment.containsKey('APP_SANDBOX_CONTAINER_ID')) {
    final home = environment['HOME'];
    return home == null
        ? null
        : '$home/Library/Application Support/Claude/claude_desktop_config.json';
  }
  if (Platform.isWindows) {
    final appData = environment['APPDATA'];
    return appData == null
        ? null
        : '$appData\\Claude\\claude_desktop_config.json';
  }
  return null;
}

/// Adds [entry] as Ferman's server to the client configuration at [path],
/// keeping everything else, through a temporary file and a rename. False,
/// with the file as it was, when the client's folder is missing (it is not
/// installed), the file is not a configuration it can read, or the write
/// fails.
Future<bool> addMcpServer(String path, Map<String, Object?> entry) async {
  final file = File(path);
  try {
    if (!file.parent.existsSync()) return false;
    final text = withMcpServer(
      file.existsSync() ? await file.readAsString() : null,
      entry,
    );
    if (text == null) return false;
    final temporary = File('$path.ferman-tmp');
    await temporary.writeAsString(text, flush: true);
    await temporary.rename(path);
    return true;
  } on FileSystemException {
    return false;
  }
}
