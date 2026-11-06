/// Where the engine keeps its crash recovery files (ARCHITECTURE §7.6,
/// ADR 0008): in the app data directory, never next to the person's file.
///
/// - macOS: `Recovery` in the app support directory
///   ([applicationSupport], `~/Library/Application Support/<bundle id>`,
///   inside the container while the App Sandbox is on, Q18).
/// - Windows: `%LOCALAPPDATA%\Ferman\Recovery`.
/// - Linux: `$XDG_STATE_HOME/ferman/recovery`, by default
///   `~/.local/state/ferman/recovery`.
///
/// [os] is `Platform.operatingSystem`. Null when the directory cannot be
/// named (no `LOCALAPPDATA` or `HOME`, or another system): the engine then
/// keeps no recovery files.
String? recoveryDirectory({
  required String os,
  required Map<String, String> environment,
  String? applicationSupport,
}) {
  String? present(String? value) =>
      value == null || value.isEmpty ? null : value;
  switch (os) {
    case 'macos':
      final support = present(applicationSupport);
      return support == null ? null : '$support/Recovery';
    case 'windows':
      final local = present(environment['LOCALAPPDATA']);
      return local == null ? null : '$local\\Ferman\\Recovery';
    case 'linux':
      // A relative XDG_STATE_HOME is invalid and ignored (XDG base directory
      // specification).
      final state = present(environment['XDG_STATE_HOME']);
      if (state != null && state.startsWith('/')) {
        return '$state/ferman/recovery';
      }
      final home = present(environment['HOME']);
      return home == null ? null : '$home/.local/state/ferman/recovery';
  }
  return null;
}
