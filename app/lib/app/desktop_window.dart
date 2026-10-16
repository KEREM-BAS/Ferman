import 'dart:async';

import 'package:ferman/app/platform_window.dart';
import 'package:ferman/app/window_setup.dart';
import 'package:ferman/design/components/additions/window_chrome.dart'
    show WindowPlatform;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

part 'desktop_window.g.dart';

/// What Ferman's own title bar draws about the window.
@immutable
final class DesktopWindowState {
  /// A window that is [maximized] and in [fullScreen] or not.
  const new({this.maximized = false, this.fullScreen = false});

  /// Whether the window is maximized (zoomed on macOS): the maximize
  /// caption button shows restore.
  final bool maximized;

  /// Whether the window is in full screen, where the system owns the title
  /// bar area on macOS.
  final bool fullScreen;

  @override
  bool operator ==(Object other) =>
      other is DesktopWindowState &&
      other.maximized == maximized &&
      other.fullScreen == fullScreen;

  @override
  int get hashCode => Object.hash(maximized, fullScreen);

  @override
  String toString() =>
      'DesktopWindowState(maximized: $maximized, fullScreen: $fullScreen)';
}

/// The app window as Ferman's own title bar sees it (M1 phase H1): its
/// state, the window commands, and the native hooks of the `ferman/window`
/// channel.
///
/// [platform] is null where the app draws no title bar of its own (the web,
/// iOS, Android): the system or the browser frames the app there.
abstract class DesktopWindow {
  /// The desktop system whose window controls the title bar draws, or null
  /// when the app draws no title bar.
  WindowPlatform? get platform;

  /// The window's state; listeners hear every change.
  ValueListenable<DesktopWindowState> get state;

  /// The hover and press state of the Windows maximize button while the
  /// native side owns its area (see [setMaximizeButtonRect]).
  ValueListenable<MaximizeButtonState> get maximizeButton;

  /// Minimizes the window.
  Future<void> minimize();

  /// Maximizes the window, or restores it when it is maximized.
  Future<void> toggleMaximize();

  /// Closes the window.
  Future<void> close();

  /// Moves the window with the pointer that is down on the title bar.
  Future<void> startDragging();

  /// Does what a double-click on the title bar does on [platform]: the
  /// System Settings choice on macOS (zoom, minimize or nothing), maximize
  /// or restore elsewhere.
  Future<void> titleBarDoubleClicked();

  /// Tells macOS where the traffic lights go (see
  /// [PlatformWindowChannel.setTrafficLightLayout]).
  Future<void> setTrafficLightLayout(TrafficLightLayout layout);

  /// Tells Windows where the maximize button is, in logical pixels of the
  /// Flutter view, or null to give its area back (see
  /// [PlatformWindowChannel.setMaximizeButtonRect]).
  Future<void> setMaximizeButtonRect(Rect? rect);

  /// Stops listening to the window.
  void dispose();
}

/// The window where the app draws no title bar of its own: the web and
/// mobile, and widget tests that do not ask for a desktop window.
class NoDesktopWindow implements DesktopWindow {
  /// A window without a custom title bar.
  new();

  final ValueNotifier<DesktopWindowState> _state = ValueNotifier(
    const DesktopWindowState(),
  );
  final ValueNotifier<MaximizeButtonState> _maximizeButton = ValueNotifier(
    MaximizeButtonState.idle,
  );

  @override
  WindowPlatform? get platform => null;

  @override
  ValueListenable<DesktopWindowState> get state => _state;

  @override
  ValueListenable<MaximizeButtonState> get maximizeButton => _maximizeButton;

  @override
  Future<void> minimize() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> startDragging() async {}

  @override
  Future<void> titleBarDoubleClicked() async {}

  @override
  Future<void> setTrafficLightLayout(TrafficLightLayout layout) async {}

  @override
  Future<void> setMaximizeButtonRect(Rect? rect) async {}

  @override
  void dispose() {
    _state.dispose();
    _maximizeButton.dispose();
  }
}

/// The desktop window through window_manager and the `ferman/window`
/// channel. [start] hides the system title bar and starts following the
/// window's state.
class WindowManagerDesktopWindow with WindowListener implements DesktopWindow {
  /// The window of a desktop app on [platform].
  new(this.platform, {PlatformWindowChannel? channel})
    : _channel = channel ?? PlatformWindowChannel();

  @override
  final WindowPlatform platform;

  final PlatformWindowChannel _channel;
  final ValueNotifier<DesktopWindowState> _state = ValueNotifier(
    const DesktopWindowState(),
  );

  // Every refresh and every event takes a new generation; a refresh whose
  // answers arrive after a newer one, after an event or after dispose is
  // dropped, so a slow answer never overwrites newer state.
  int _generation = 0;
  bool _disposed = false;

  /// The window of this desktop app, or null on the web and mobile.
  static WindowManagerDesktopWindow? forCurrentPlatform() {
    if (!isDesktop) return null;
    return WindowManagerDesktopWindow(switch (defaultTargetPlatform) {
      TargetPlatform.macOS => WindowPlatform.mac,
      TargetPlatform.windows => WindowPlatform.win,
      _ => WindowPlatform.linux,
    });
  }

  /// Hides the system title bar, so Ferman's own takes its place, and
  /// follows the window's state from now on. On macOS the system's traffic
  /// lights stay; the title bar places them ([setTrafficLightLayout]). On
  /// Linux the GTK header bar hides and the client-side frame (shadow and
  /// resize edges) stays.
  Future<void> start() async {
    windowManager.addListener(this);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await _refresh();
  }

  @override
  ValueListenable<DesktopWindowState> get state => _state;

  @override
  ValueListenable<MaximizeButtonState> get maximizeButton =>
      _channel.maximizeButton;

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<void> titleBarDoubleClicked() => platform == WindowPlatform.mac
      ? _channel.titleBarDoubleClicked()
      : toggleMaximize();

  @override
  Future<void> setTrafficLightLayout(TrafficLightLayout layout) =>
      _channel.setTrafficLightLayout(layout);

  @override
  Future<void> setMaximizeButtonRect(Rect? rect) =>
      _channel.setMaximizeButtonRect(rect);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    windowManager.removeListener(this);
    _channel.dispose();
    _state.dispose();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    final maximized = await windowManager.isMaximized();
    final fullScreen = await windowManager.isFullScreen();
    if (_disposed || generation != _generation) return;
    _state.value = DesktopWindowState(
      maximized: maximized,
      fullScreen: fullScreen,
    );
  }

  void _set({bool? maximized, bool? fullScreen}) {
    if (_disposed) return;
    _generation++;
    final current = _state.value;
    _state.value = DesktopWindowState(
      maximized: maximized ?? current.maximized,
      fullScreen: fullScreen ?? current.fullScreen,
    );
  }

  @override
  void onWindowMaximize() => _set(maximized: true);

  @override
  void onWindowUnmaximize() => _set(maximized: false);

  @override
  void onWindowEnterFullScreen() => _set(fullScreen: true);

  @override
  void onWindowLeaveFullScreen() => _set(fullScreen: false);

  // A snap or a restore from the Dock or taskbar does not always come with a
  // maximize event on every system; ask again after them.
  @override
  void onWindowRestore() => unawaited(_refresh());

  @override
  void onWindowResized() => unawaited(_refresh());
}

/// The app window. `bootstrap()` overrides it with the desktop window; the
/// default draws no title bar of its own.
@Riverpod(keepAlive: true)
DesktopWindow desktopWindow(Ref ref) {
  final window = NoDesktopWindow();
  ref.onDispose(window.dispose);
  return window;
}
