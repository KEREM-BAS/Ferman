import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:ferman/design/tokens.g.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

import '../helpers/fake_desktop_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const windowManagerChannel = MethodChannel('window_manager');
  const fermanChannel = MethodChannel(PlatformWindowChannel.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> windowManagerCalls;
  late List<MethodCall> fermanCalls;
  late bool maximized;
  late bool fullScreen;

  setUp(() {
    windowManagerCalls = [];
    fermanCalls = [];
    maximized = false;
    fullScreen = false;
    messenger
      ..setMockMethodCallHandler(windowManagerChannel, (call) async {
        windowManagerCalls.add(call);
        return switch (call.method) {
          'isMaximized' => maximized,
          'isFullScreen' => fullScreen,
          _ => null,
        };
      })
      ..setMockMethodCallHandler(fermanChannel, (call) async {
        fermanCalls.add(call);
        return null;
      });
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(windowManagerChannel, null)
      ..setMockMethodCallHandler(fermanChannel, null);
  });

  List<String> methods() => [for (final c in windowManagerCalls) c.method];

  Future<void> windowEvent(String name) async {
    await messenger.handlePlatformMessage(
      windowManagerChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('onEvent', {'eventName': name}),
      ),
      (_) {},
    );
    // Let a refresh's channel calls finish.
    await pumpEventQueue();
  }

  Future<WindowManagerDesktopWindow> started(WindowPlatform platform) async {
    final window = WindowManagerDesktopWindow(platform);
    addTearDown(window.dispose);
    await window.start();
    windowManagerCalls.clear();
    // start also asks the ferman/window channel for the double-click
    // settings.
    fermanCalls.clear();
    return window;
  }

  group('WindowManagerDesktopWindow', () {
    test(
      'start hides the system title bar and reads the window state',
      () async {
        maximized = true;
        final window = WindowManagerDesktopWindow(WindowPlatform.win);
        addTearDown(window.dispose);
        await window.start();
        final style = windowManagerCalls.firstWhere(
          (c) => c.method == 'setTitleBarStyle',
        );
        expect(style.arguments, {
          'titleBarStyle': 'hidden',
          'windowButtonVisibility': true,
        });
        expect(window.state.value, const DesktopWindowState(maximized: true));
      },
    );

    test('follows maximize and full-screen events', () async {
      final window = await started(WindowPlatform.win);
      await windowEvent('maximize');
      expect(window.state.value.maximized, isTrue);
      await windowEvent('unmaximize');
      expect(window.state.value.maximized, isFalse);
      await windowEvent('enter-full-screen');
      expect(window.state.value.fullScreen, isTrue);
      await windowEvent('leave-full-screen');
      expect(window.state.value.fullScreen, isFalse);
    });

    test('asks again after a resize or a restore', () async {
      final window = await started(WindowPlatform.win);
      maximized = true;
      await windowEvent('resized');
      expect(window.state.value.maximized, isTrue);
      maximized = false;
      await windowEvent('restore');
      expect(window.state.value.maximized, isFalse);
      expect(methods(), containsAll(['isMaximized', 'isFullScreen']));
    });

    test('toggleMaximize maximizes, or restores a maximized window', () async {
      final window = await started(WindowPlatform.win);
      await window.toggleMaximize();
      expect(methods(), ['isMaximized', 'maximize']);
      windowManagerCalls.clear();
      maximized = true;
      await window.toggleMaximize();
      expect(methods(), ['isMaximized', 'unmaximize']);
    });

    test('runs the other window commands', () async {
      final window = await started(WindowPlatform.linux);
      await window.minimize();
      await window.startDragging();
      await window.close();
      expect(methods(), [
        'minimize',
        // window_manager does not start a drag in full screen on Windows,
        // and asks first when the tests run there.
        if (Platform.isWindows) 'isFullScreen',
        'startDragging',
        'close',
      ]);
    });

    test('a title-bar double-click follows the system setting on macOS and '
        'maximizes elsewhere', () async {
      final mac = await started(WindowPlatform.mac);
      await mac.titleBarDoubleClicked();
      expect(fermanCalls.single.method, 'titleBarDoubleClicked');
      expect(windowManagerCalls, isEmpty);

      final win = await started(WindowPlatform.win);
      await win.titleBarDoubleClicked();
      expect(methods(), ['isMaximized', 'maximize']);
      expect(fermanCalls, isEmpty);
    });

    test('passes the native hooks to the ferman/window channel', () async {
      final window = await started(WindowPlatform.win);
      await window.setMaximizeButtonRect(const Rect.fromLTWH(1, 2, 3, 4));
      await window.setTrafficLightLayout(
        const TrafficLightLayout(
          titleBarHeight: 37,
          leading: 14,
          diameter: 12,
          spacing: 8,
        ),
      );
      expect(
        [for (final c in fermanCalls) c.method],
        ['setMaximizeButtonRect', 'setTrafficLightLayout'],
      );
    });

    test('keeps the window at least the minimum size through '
        'window_manager', () async {
      final window = await started(WindowPlatform.win);
      await window.setMinimumSize(const Size(1024, 640));
      expect(methods(), ['setMinimumSize']);
      final arguments = windowManagerCalls.single.arguments as Map;
      expect(arguments['width'], 1024);
      expect(arguments['height'], 640);
    });

    test('a slow refresh never overwrites a newer event', () async {
      final window = await started(WindowPlatform.win);
      final answer = Completer<Object?>();
      messenger.setMockMethodCallHandler(windowManagerChannel, (call) async {
        windowManagerCalls.add(call);
        return switch (call.method) {
          'isMaximized' => await answer.future,
          'isFullScreen' => false,
          _ => null,
        };
      });
      // A resize starts a refresh that waits for its answer...
      await messenger.handlePlatformMessage(
        windowManagerChannel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onEvent', {'eventName': 'resized'}),
        ),
        (_) {},
      );
      // ...while the window is maximized.
      await windowEvent('maximize');
      expect(window.state.value.maximized, isTrue);
      answer.complete(false);
      await pumpEventQueue();
      expect(window.state.value.maximized, isTrue);
    });

    test('a refresh that ends after dispose changes nothing', () async {
      final answer = Completer<Object?>();
      final window = await started(WindowPlatform.win);
      messenger.setMockMethodCallHandler(windowManagerChannel, (call) async {
        return switch (call.method) {
          'isMaximized' => await answer.future,
          _ => false,
        };
      });
      await messenger.handlePlatformMessage(
        windowManagerChannel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onEvent', {'eventName': 'restore'}),
        ),
        (_) {},
      );
      window.dispose();
      answer.complete(true);
      // Setting a disposed notifier would throw here.
      await pumpEventQueue();
    });

    test('stops following the window once disposed', () async {
      final window = WindowManagerDesktopWindow(WindowPlatform.win);
      await window.start();
      expect(windowManager.listeners, contains(window));
      window.dispose();
      expect(windowManager.listeners, isNot(contains(window)));
      // An event that still reaches it changes nothing and does not throw.
      expect(window.onWindowMaximize, returnsNormally);
    });

    test("start reads the system's double-click settings", () async {
      messenger.setMockMethodCallHandler(fermanChannel, (call) async {
        fermanCalls.add(call);
        return call.method == 'doubleClickSettings'
            ? {'interval': 500, 'distance': 2.0}
            : null;
      });
      final window = WindowManagerDesktopWindow(WindowPlatform.win);
      addTearDown(window.dispose);
      expect(window.doubleClick, DoubleClickSettings.fallback);
      await window.start();
      expect(
        window.doubleClick,
        const DoubleClickSettings(
          interval: Duration(milliseconds: 500),
          distance: 2,
        ),
      );
    });
  });

  group('WindowManagerDesktopWindow.forCurrentPlatform', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    for (final (target, expected) in [
      (TargetPlatform.macOS, WindowPlatform.mac),
      (TargetPlatform.windows, WindowPlatform.win),
      (TargetPlatform.linux, WindowPlatform.linux),
    ]) {
      test('$target draws the ${expected.name} title bar', () {
        debugDefaultTargetPlatformOverride = target;
        final window = WindowManagerDesktopWindow.forCurrentPlatform();
        addTearDown(() => window?.dispose());
        expect(window?.platform, expected);
      });
    }

    test('mobile draws none', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(WindowManagerDesktopWindow.forCurrentPlatform(), isNull);
    });
  });

  group('NoDesktopWindow', () {
    test('draws no title bar and ignores the commands', () async {
      final window = NoDesktopWindow();
      addTearDown(window.dispose);
      expect(window.platform, isNull);
      await window.minimize();
      await window.toggleMaximize();
      await window.close();
      await window.startDragging();
      await window.titleBarDoubleClicked();
      await window.setMaximizeButtonRect(null);
      await window.setMinimumSize(const Size(1024, 640));
      expect(windowManagerCalls, isEmpty);
      expect(fermanCalls, isEmpty);
    });
  });

  group('applyWindowLimits', () {
    test('asks the window for the shell’s minimum size at start-up: 1024 × '
        '640 (G21; the width Proposed)', () async {
      final window = FakeDesktopWindow(WindowPlatform.win);
      addTearDown(window.dispose);
      await applyWindowLimits(window);
      expect(window.minimumSizes, [WindowMetrics.minimumSize]);
      expect(WindowMetrics.minimumSize, const Size(1024, 640));
      expect(WindowMetrics.minimumWidth, 1024);
    });

    test('at the minimum width either side panel fits beside the canvas', () {
      expect(
        WindowMetrics.minimumWidth,
        greaterThanOrEqualTo(
          WindowMetrics.canvasMinWidth +
              math.max(FermanSizeTokens.sidebarW, FermanSizeTokens.panelW),
        ),
      );
    });
  });
}
