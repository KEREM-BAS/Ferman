import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/recent/recent_previews.dart';

/// Opens the recent files' store of this platform: in memory on the web,
/// which cannot open files yet (B116).
Future<RecentFilesStore> openRecentFilesStore() async =>
    MemoryRecentFilesStore();

/// No home directory on the web.
String? userHomeDirectory() => null;

/// The previews in memory on the web.
Future<RecentPreviewStore> openRecentPreviewStore() async =>
    MemoryRecentPreviewStore();
