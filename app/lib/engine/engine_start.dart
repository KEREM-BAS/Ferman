/// Starts the engine for the current platform: the Rust engine on desktop,
/// nothing on the web until phase 5. The conditional import keeps the bridge
/// out of the web build.
library;

export 'package:ferman/engine/engine_service_frb.dart'
    if (dart.library.js_interop) 'package:ferman/engine/engine_service_web.dart'
    show startEngine;
