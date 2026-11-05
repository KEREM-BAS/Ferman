/// Whether a file is at [path]: never on the web.
Future<bool> fileExists(String path) async => false;

/// Whether the file at [path] says no one may write it: never on the web.
bool fileReadOnly(String path) => false;
