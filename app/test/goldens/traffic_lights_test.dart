import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/app/window_frame.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/component_host.dart';
import '../helpers/traffic_lights.dart';

void main() {
  const width = 1440.0;

  /// The layout the macOS title bar sends, at 1440 px in [direction].
  Future<TrafficLightLayout> sentLayout(
    WidgetTester tester,
    TextDirection direction,
  ) async {
    final window = GoldenDesktopWindow(WindowPlatform.mac);
    addTearDown(window.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [desktopWindowProvider.overrideWithValue(window)],
        child: componentHost(
          const SizedBox(
            width: width,
            height: 100,
            child: WindowFrame(child: SizedBox.expand()),
          ),
          textDirection: direction,
          size: const Size(width, 100),
        ),
      ),
    );
    return window.layout.value!;
  }

  testWidgets('the lights sit where MainFlutterWindow.swift places them: '
      '12 px circles 8 px apart, 14 px from the leading edge, centred in the '
      '37 px above the title bar line', (tester) async {
    final layout = await sentLayout(tester, TextDirection.ltr);
    final theme = FermanTheme.light;
    expect(
      layout.titleBarHeight,
      theme.density.titlebarH - theme.border.borderWidth,
    );
    expect(TrafficLightsPainter.circles(layout, width), const [
      Rect.fromLTWH(14, 12.5, 12, 12),
      Rect.fromLTWH(34, 12.5, 12, 12),
      Rect.fromLTWH(54, 12.5, 12, 12),
    ]);
    expect(TrafficLightsPainter.colors, const [
      WindowChrome.macClose,
      WindowChrome.macMinimize,
      WindowChrome.macZoom,
    ]);
  });

  testWidgets('in right to left they mirror, close rightmost (a12-1ar)', (
    tester,
  ) async {
    final layout = await sentLayout(tester, TextDirection.rtl);
    expect(layout.rightToLeft, isTrue);
    expect(TrafficLightsPainter.circles(layout, width), const [
      Rect.fromLTWH(width - 26, 12.5, 12, 12),
      Rect.fromLTWH(width - 46, 12.5, 12, 12),
      Rect.fromLTWH(width - 66, 12.5, 12, 12),
    ]);
  });
}
