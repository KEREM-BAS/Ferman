/// Opens the recent files' store of the platform: the file store on the
/// desktop, memory on the web.
library;

export 'package:ferman/recent/recent_files_store_io.dart'
    if (dart.library.js_interop) 'package:ferman/recent/recent_files_store_web.dart'
    show openRecentFilesStore, userHomeDirectory;
