import 'package:ferman/app/platform_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(PlatformWindowChannel.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> fromNative(String method, Object? arguments) async {
    final data = const StandardMethodCodec().encodeMethodCall(
      MethodCall(method, arguments),
    );
    await messenger.handlePlatformMessage(
      PlatformWindowChannel.channelName,
      data,
      (_) {},
    );
  }

  group('PlatformWindowChannel', () {
    test('sends the traffic-light layout', () async {
      final window = PlatformWindowChannel();
      addTearDown(window.dispose);
      await window.setTrafficLightLayout(
        const TrafficLightLayout(
          titleBarHeight: 38,
          leading: 14,
          diameter: 12,
          spacing: 8,
        ),
      );
      expect(calls.single.method, 'setTrafficLightLayout');
      expect(calls.single.arguments, {
        'titleBarHeight': 38.0,
        'leading': 14.0,
        'diameter': 12.0,
        'spacing': 8.0,
        'rightToLeft': false,
      });
      await window.setTrafficLightLayout(
        const TrafficLightLayout(
          titleBarHeight: 38,
          leading: 14,
          diameter: 12,
          spacing: 8,
          rightToLeft: true,
        ),
      );
      expect(calls.last.arguments, containsPair('rightToLeft', true));
    });

    test('sends the maximize button rectangle, or null to clear it', () async {
      final window = PlatformWindowChannel();
      addTearDown(window.dispose);
      await window.setMaximizeButtonRect(const Rect.fromLTWH(1100, 0, 46, 38));
      expect(calls.last.method, 'setMaximizeButtonRect');
      expect(calls.last.arguments, {
        'left': 1100.0,
        'top': 0.0,
        'width': 46.0,
        'height': 38.0,
      });
      await window.setMaximizeButtonRect(null);
      expect(calls.last.arguments, isNull);
    });

    test('reports the native hover and press state', () async {
      final window = PlatformWindowChannel();
      addTearDown(window.dispose);
      final seen = <MaximizeButtonState>[];
      window.maximizeButton.addListener(
        () => seen.add(window.maximizeButton.value),
      );
      await fromNative('maximizeButtonState', {
        'hovered': true,
        'pressed': false,
      });
      await fromNative('maximizeButtonState', {
        'hovered': true,
        'pressed': true,
      });
      expect(seen, [
        const MaximizeButtonState(hovered: true),
        const MaximizeButtonState(hovered: true, pressed: true),
      ]);
      // Clearing the rectangle resets the state.
      await window.setMaximizeButtonRect(null);
      expect(window.maximizeButton.value, MaximizeButtonState.idle);
    });

    test('asks macOS to handle a title-bar double-click', () async {
      final window = PlatformWindowChannel();
      addTearDown(window.dispose);
      await window.titleBarDoubleClicked();
      expect(calls.single.method, 'titleBarDoubleClicked');
      expect(calls.single.arguments, isNull);
    });

    test("reads the system's double-click settings", () async {
      final window = PlatformWindowChannel();
      addTearDown(window.dispose);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {'interval': 500, 'distance': 2.0};
      });
      expect(
        await window.doubleClickSettings(),
        const DoubleClickSettings(
          interval: Duration(milliseconds: 500),
          distance: 2,
        ),
      );
      expect(calls.single.method, 'doubleClickSettings');
    });

    test('a missing or bad double-click value falls back to Flutter', () async {
      final window = PlatformWindowChannel();
      addTearDown(window.dispose);
      // macOS reports no distance.
      messenger.setMockMethodCallHandler(channel, (call) async {
        return {'interval': 450};
      });
      expect(
        await window.doubleClickSettings(),
        DoubleClickSettings(
          interval: const Duration(milliseconds: 450),
          distance: DoubleClickSettings.fallback.distance,
        ),
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        return {'interval': 0, 'distance': -1};
      });
      expect(await window.doubleClickSettings(), DoubleClickSettings.fallback);
      messenger.setMockMethodCallHandler(channel, (call) async => 'nonsense');
      expect(await window.doubleClickSettings(), DoubleClickSettings.fallback);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'error'),
      );
      expect(await window.doubleClickSettings(), DoubleClickSettings.fallback);
    });

    test('does nothing where no runner handles the channel', () async {
      messenger.setMockMethodCallHandler(channel, null);
      final window = PlatformWindowChannel();
      addTearDown(window.dispose);
      await window.setTrafficLightLayout(
        const TrafficLightLayout(
          titleBarHeight: 38,
          leading: 14,
          diameter: 12,
          spacing: 8,
        ),
      );
      await window.setMaximizeButtonRect(const Rect.fromLTWH(0, 0, 1, 1));
      await window.titleBarDoubleClicked();
      expect(await window.doubleClickSettings(), DoubleClickSettings.fallback);
    });

    test('equality of the state', () {
      expect(
        const MaximizeButtonState(hovered: true),
        const MaximizeButtonState(hovered: true),
      );
      expect(
        const MaximizeButtonState(hovered: true).hashCode,
        const MaximizeButtonState(hovered: true).hashCode,
      );
      expect(MaximizeButtonState.idle.toString(), contains('hovered: false'));
    });
  });
}
