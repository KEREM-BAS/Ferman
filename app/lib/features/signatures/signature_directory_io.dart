import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// `Signatures` beside `settings.json` in the app support directory (inside
/// the container while the macOS App Sandbox is on, Q18), apart from the
/// settings so export and reset never reach it (M4 decision 22).
/// Null when the system names no such directory.
Future<String?> savedSignatureDirectory() async {
  try {
    return '${(await getApplicationSupportDirectory()).path}'
        '${Platform.pathSeparator}Signatures';
  } on Exception {
    return null;
  }
}
