import 'package:ferman/settings/settings_store.dart';

/// Opens the settings store of this platform: in memory on the web until
/// phase 5 decides its storage.
Future<SettingsStore> openSettingsStore() async => MemorySettingsStore();
