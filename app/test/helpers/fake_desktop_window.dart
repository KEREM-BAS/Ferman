import 'dart:ui';

import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:flutter/foundation.dart';

/// A [DesktopWindow] for tests: draws the title bar of [platform] and
/// records every command in [calls], every traffic-light layout in
/// [trafficLightLayouts], every maximize-button rectangle in
/// [maximizeButtonRects] and every minimum size in [minimumSizes]. Tests
/// change [stateNotifier] and [maximizeButtonNotifier] to play the system's
/// part.
class FakeDesktopWindow implements DesktopWindow {
  /// A window with Ferman's title bar for [platform] (null: none).
  new(this.platform);

  @override
  final WindowPlatform? platform;

  /// The window commands called, by name.
  final List<String> calls = [];

  /// The layouts sent with [setTrafficLightLayout].
  final List<TrafficLightLayout> trafficLightLayouts = [];

  /// The rectangles sent with [setMaximizeButtonRect].
  final List<Rect?> maximizeButtonRects = [];

  /// The sizes sent with [setMinimumSize].
  final List<Size> minimumSizes = [];

  /// The window state the title bar sees.
  final ValueNotifier<DesktopWindowState> stateNotifier = ValueNotifier(
    const DesktopWindowState(),
  );

  /// The maximize button state the native side reports.
  final ValueNotifier<MaximizeButtonState> maximizeButtonNotifier =
      ValueNotifier(MaximizeButtonState.idle);

  @override
  ValueListenable<DesktopWindowState> get state => stateNotifier;

  @override
  ValueListenable<MaximizeButtonState> get maximizeButton =>
      maximizeButtonNotifier;

  /// The double-click settings the title bar counts with.
  @override
  DoubleClickSettings doubleClick = DoubleClickSettings.fallback;

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<void> toggleMaximize() async => calls.add('toggleMaximize');

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> startDragging() async => calls.add('startDragging');

  @override
  Future<void> titleBarDoubleClicked() async =>
      calls.add('titleBarDoubleClicked');

  @override
  Future<void> setTrafficLightLayout(TrafficLightLayout layout) async =>
      trafficLightLayouts.add(layout);

  @override
  Future<void> setMaximizeButtonRect(Rect? rect) async =>
      maximizeButtonRects.add(rect);

  @override
  Future<void> setMinimumSize(Size size) async => minimumSizes.add(size);

  @override
  void dispose() {
    stateNotifier.dispose();
    maximizeButtonNotifier.dispose();
  }
}
