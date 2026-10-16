import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The hover and press state of the Windows maximize button, as the native
/// side reports it while that button answers the system's hit test (see
/// [PlatformWindowChannel.setMaximizeButtonRect]).
@immutable
final class MaximizeButtonState {
  /// A state with [hovered] and [pressed].
  const new({this.hovered = false, this.pressed = false});

  /// Neither hovered nor pressed.
  static const MaximizeButtonState idle = MaximizeButtonState();

  /// Whether the pointer is over the button.
  final bool hovered;

  /// Whether the primary button is down on it.
  final bool pressed;

  @override
  bool operator ==(Object other) =>
      other is MaximizeButtonState &&
      other.hovered == hovered &&
      other.pressed == pressed;

  @override
  int get hashCode => Object.hash(hovered, pressed);

  @override
  String toString() =>
      'MaximizeButtonState(hovered: $hovered, pressed: $pressed)';
}

/// Where the macOS traffic lights sit under Ferman's own title bar.
@immutable
final class TrafficLightLayout {
  /// A layout for a title bar [titleBarHeight] tall, with lights of
  /// [diameter], [spacing] apart, the first [leading] from the window's
  /// leading edge: the left edge, or the right edge when [rightToLeft].
  const new({
    required this.titleBarHeight,
    required this.leading,
    required this.diameter,
    required this.spacing,
    this.rightToLeft = false,
  });

  /// The title bar's height.
  final double titleBarHeight;

  /// The distance from the window's leading edge to the first light.
  final double leading;

  /// The diameter of one light.
  final double diameter;

  /// The gap between two lights.
  final double spacing;

  /// Whether the UI runs right to left: the lights then sit at the right
  /// edge with close rightmost (a12-1ar).
  final bool rightToLeft;

  /// The channel arguments.
  Map<String, Object> toArguments() => {
    'titleBarHeight': titleBarHeight,
    'leading': leading,
    'diameter': diameter,
    'spacing': spacing,
    'rightToLeft': rightToLeft,
  };
}

/// The `ferman/window` channel to the native runners, for what
/// window_manager does not cover under Ferman's own title bar (M1 phase
/// H1):
///
/// - macOS: [setTrafficLightLayout] places the system's close, minimize and
///   zoom buttons where the design draws its lights (`MainFlutterWindow`).
/// - Windows: [setMaximizeButtonRect] makes the area of the Flutter-drawn
///   maximize button answer the system's hit test as the maximize button,
///   so Windows 11 shows its snap layouts there (`title_bar.cpp`). The
///   pointer then reaches the native side instead of Flutter, which reports
///   it back as [maximizeButton].
///
/// The native side does nothing until these are called. On a platform
/// without a handler (Linux, tests) the calls do nothing.
class PlatformWindowChannel {
  /// Talks to the native side over the `ferman/window` channel, or over
  /// the channel given (tests).
  new([this._channel = const MethodChannel(channelName)]) {
    _channel.setMethodCallHandler(_handle);
  }

  /// The channel's name, the same in every runner.
  static const String channelName = 'ferman/window';

  final MethodChannel _channel;

  /// The Windows maximize button's hover and press state while
  /// [setMaximizeButtonRect] has a rectangle.
  final ValueNotifier<MaximizeButtonState> maximizeButton = ValueNotifier(
    MaximizeButtonState.idle,
  );

  /// Places the macOS traffic lights by [layout]; it stays in effect across
  /// resizes. macOS only.
  Future<void> setTrafficLightLayout(TrafficLightLayout layout) =>
      _invoke('setTrafficLightLayout', layout.toArguments());

  /// Reports the maximize button's [rect] in logical pixels of the Flutter
  /// view, or null to give the area back to Flutter. Windows only.
  Future<void> setMaximizeButtonRect(Rect? rect) {
    if (rect == null) maximizeButton.value = MaximizeButtonState.idle;
    return _invoke(
      'setMaximizeButtonRect',
      rect == null
          ? null
          : {
              'left': rect.left,
              'top': rect.top,
              'width': rect.width,
              'height': rect.height,
            },
    );
  }

  /// Stops listening to the native side.
  void dispose() {
    _channel.setMethodCallHandler(null);
    maximizeButton.dispose();
  }

  Future<void> _invoke(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // No native handler on this platform: nothing to do.
    }
  }

  Future<Object?> _handle(MethodCall call) async {
    if (call.method == 'maximizeButtonState') {
      final arguments = call.arguments;
      if (arguments is Map) {
        maximizeButton.value = MaximizeButtonState(
          hovered: arguments['hovered'] == true,
          pressed: arguments['pressed'] == true,
        );
      }
      return null;
    }
    throw MissingPluginException('ferman/window has no ${call.method}');
  }
}
