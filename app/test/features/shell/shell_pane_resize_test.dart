import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/shell/shell_pane_resize.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_desktop_window.dart';
import 'shell_host.dart';

void main() {
  late FakeDesktopWindow window;

  setUp(() => window = FakeDesktopWindow(WindowPlatform.linux));
  tearDown(() => window.dispose());

  double widthOf(WidgetTester tester, Type type) =>
      tester.getSize(find.byType(type)).width;

  Finder handle(ShellSide side) => find.byWidgetPredicate(
    (widget) => widget is ShellPaneResizeHandle && widget.side == side,
  );

  /// Drags [side]'s handle by [by] with the mouse, past its slop, so the
  /// whole offset reaches the panel.
  Future<void> drag(WidgetTester tester, ShellSide side, double by) async {
    final gesture = await tester.startGesture(
      tester.getCenter(handle(side)),
      kind: PointerDeviceKind.mouse,
    );
    final slop = by.sign * 20;
    await gesture.moveBy(Offset(slop, 0));
    await gesture.moveBy(Offset(-slop, 0));
    await gesture.moveBy(Offset(by, 0));
    await gesture.up();
    await settle(tester);
  }

  testWidgets('dragging the edges widens the sidebar and the panel, within '
      'their limits (B094)', (tester) async {
    await pumpShell(tester, shellHost(window: window));
    expect(widthOf(tester, FmSidebar), 216);
    expect(widthOf(tester, FmDocPanel), 264);

    await drag(tester, ShellSide.sidebar, 60);
    expect(widthOf(tester, FmSidebar), 276);
    // The panel grows towards the start.
    await drag(tester, ShellSide.panel, -50);
    expect(widthOf(tester, FmDocPanel), 314);

    // Never past the widest, never below the designed width.
    await drag(tester, ShellSide.sidebar, 400);
    expect(widthOf(tester, FmSidebar), WindowMetrics.sidebarMaxWidth);
    await drag(tester, ShellSide.sidebar, -600);
    expect(widthOf(tester, FmSidebar), 216);
  });

  testWidgets('in right to left the sidebar grows towards the left', (
    tester,
  ) async {
    await pumpShell(
      tester,
      shellHost(window: window, locale: const Locale('ar')),
    );
    await drag(tester, ShellSide.sidebar, -40);
    expect(widthOf(tester, FmSidebar), 256);
  });

  test('the canvas keeps its minimum: the sidebar narrows first, never '
      'below its own minimum', () {
    const both = ShellPanels(sidebar: true, panel: true);
    const chosen = (sidebar: 360.0, panel: 400.0);
    // 1440 - 640 leaves 800: the sidebar 800 - 264 at most, then the panel
    // what the sidebar leaves.
    expect(shellPaneWidthsIn(chosen: chosen, shown: both, width: 1440), (
      sidebar: 360.0,
      panel: 400.0,
    ));
    expect(shellPaneWidthsIn(chosen: chosen, shown: both, width: 1200), (
      sidebar: 296.0,
      panel: 264.0,
    ));
    expect(shellPaneWidthsIn(chosen: chosen, shown: both, width: 1024), (
      sidebar: 216.0,
      panel: 264.0,
    ));
    expect(
      shellPaneWidthsIn(
        chosen: chosen,
        shown: const ShellPanels(sidebar: false, panel: true),
        width: 1024,
      ),
      (sidebar: 216.0, panel: 384.0),
    );
  });
}
