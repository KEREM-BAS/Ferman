import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await Future<void>.delayed(Duration.zero);
  }

  Future<WindowManagerDesktopWindow> started(WindowPlatform platform) async {
    final window = WindowManagerDesktopWindow(platform);
    addTearDown(window.dispose);
    await window.start();
    windowManagerCalls.clear();
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
      expect(methods(), ['minimize', 'startDragging', 'close']);
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
      expect(fermanCalls, hasLength(1));
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

    test('stops following the window once disposed', () async {
      final window = WindowManagerDesktopWindow(WindowPlatform.win);
      await window.start();
      final state = window.state;
      window.dispose();
      // The listener is gone: no call reaches the disposed state.
      await windowEvent('maximize');
      expect(() => state.value, returnsNormally);
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
      expect(windowManagerCalls, isEmpty);
      expect(fermanCalls, isEmpty);
    });
  });
}
