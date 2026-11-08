/// Where saved signatures live: a folder of the app data directory on the
/// desktop, none on the web.
library;

export 'package:ferman/features/signatures/signature_directory_io.dart'
    if (dart.library.js_interop) 'package:ferman/features/signatures/signature_directory_web.dart'
    show savedSignatureDirectory;
