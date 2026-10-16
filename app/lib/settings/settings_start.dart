/// `openSettingsStore()` for this platform: the file store on desktop, the
/// memory store on the web (the conditional import keeps `dart:io` out of
/// the web build).
library;

export 'package:ferman/settings/settings_store_io.dart'
    if (dart.library.js_interop) 'package:ferman/settings/settings_store_web.dart'
    show openSettingsStore;
