/// Whether a file is at a path, and read-only: `dart:io` on the desktop, never
/// on the web, whose engine saves nothing until P5.
library;

export 'package:ferman/features/save/file_exists_io.dart'
    if (dart.library.js_interop) 'package:ferman/features/save/file_exists_web.dart';
