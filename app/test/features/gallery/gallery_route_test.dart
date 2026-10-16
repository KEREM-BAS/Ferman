import 'package:ferman/app/app.dart';
import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/app/window_frame.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/gallery/gallery_screen.dart';
import 'package:ferman/features/shell/shell_title_bar.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import 'gallery_host.dart';

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  testWidgets('/debug/gallery builds the gallery in the window frame, under '
      'the bare title bar, and leaves the app’s settings alone', (
    tester,
  ) async {
    useView(tester, artboard);
    final container = ProviderContainer.test(
      overrides: [
        desktopWindowProvider.overrideWithValue(window),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(onboardingCompleted: true),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FermanApp()),
    );
    await settleFrames(tester);
    final before = container.read(settingsProvider);

    container.read(routerProvider).go(Routes.debugGallery);
    await settleFrames(tester);

    expect(find.byType(GalleryScreen), findsOneWidget);
    expect(find.byType(WindowFrame), findsOneWidget);
    expect(find.byType(ShellTitleBarContent), findsNothing);
    expect(find.byType(GallerySection), findsWidgets);
    expect(tester.takeException(), isNull);

    // Switching the preview never touches the stored settings.
    await tester.tap(
      find.descendant(
        of: find.byKey(GalleryControls.controlKey('Theme')),
        matching: find.text('Dark'),
      ),
    );
    await settleFrames(tester);
    expect(container.read(settingsProvider), before);
    expect(tester.takeException(), isNull);
  });
}
