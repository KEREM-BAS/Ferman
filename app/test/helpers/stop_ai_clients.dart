import 'package:ferman/app/app.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Turns AI clients off in the app's root container, so their client-list
/// poll stops before flutter_test checks for pending timers: a container of
/// the test's own (the goldens') outlives the widget tree until tearDown.
Future<void> stopAiClients(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FermanApp)),
  );
  await container
      .read(settingsProvider.notifier)
      .change((settings) => settings.copyWith(aiClients: false));
  await tester.pump();
}
