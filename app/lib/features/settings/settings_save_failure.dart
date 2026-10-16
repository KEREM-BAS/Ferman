import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:ferman/settings/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_save_failure.g.dart';

/// Whether the last change made in Settings could not be stored, as
/// `settingsSaveFailedProvider`.
///
/// `SettingsNotifier.change` keeps a change for the session when the
/// settings file cannot be written (`SettingsStoreException`); Settings then
/// shows a warning Banner saying so, until the next change is stored or
/// the person dismisses it. No board draws this state (G90).
@Riverpod(keepAlive: true)
class SettingsSaveFailed extends _$SettingsSaveFailed {
  @override
  bool build() => false;

  /// Records whether the last change was stored ([stored]) or not.
  void record({required bool stored}) => state = !stored;

  /// Hides the warning (its Dismiss button).
  void dismiss() => state = false;
}

/// Applies [update] to the settings from a Settings pane and records
/// whether it was stored ([SettingsSaveFailed]). The change applies at once
/// either way.
Future<void> changeSetting(
  WidgetRef ref,
  AppSettings Function(AppSettings settings) update,
) async {
  // Read before the await: the pane may rebuild (a new language) meanwhile.
  final failure = ref.read(settingsSaveFailedProvider.notifier);
  try {
    await ref.read(settingsProvider.notifier).change(update);
    failure.record(stored: true);
  } on SettingsStoreException {
    failure.record(stored: false);
  }
}
