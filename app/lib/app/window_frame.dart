import 'dart:async';

import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:ferman/design/components/foundation/modal_scope.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The frame of every desktop screen: Ferman's own title bar above [child]
/// (the FmWindow header, M1 phase H1).
///
/// The window's own keys from the shortcut table (⌘M and ⌘Q on macOS,
/// Alt+F4 on Windows and Linux, Ctrl+Q on Linux) work on every screen it
/// frames, through [WindowCommandScope].
///
/// Where the app draws no title bar of its own (the web, mobile, see
/// [DesktopWindow.platform]) the frame is just [child].
class WindowFrame extends ConsumerWidget {
  /// Frames [child] with the title bar, which holds [titleBarContent].
  const new({required this.child, super.key, this.titleBarContent});

  /// The screen below the title bar.
  final Widget child;

  /// What the title bar shows between the window controls: the home tab,
  /// the document tabs, search and settings. Null leaves the title bar bare
  /// (FmWindow `bare`), as onboarding shows it.
  final Widget? titleBarContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(desktopWindowProvider);
    final platform = window.platform;
    if (platform == null) return child;
    return WindowCommandScope(
      window: window,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(
            window: window,
            platform: platform,
            content: titleBarContent,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Ferman's own title bar (FmWindow `<header>`): `--titlebar-h` tall on
/// `--surface-sunken` with a `--border-subtle` line below, the window
/// controls of [platform] and [content] between them.
///
/// - **macOS:** the slot of the native traffic lights at the start, which
///   this bar places through [DesktopWindow.setTrafficLightLayout] (at the
///   right edge in right to left, a12-1ar). In full screen the system owns
///   the lights, and the slot narrows to the Windows gap.
/// - **Windows and Linux:** an 8 px gap at the start and the caption
///   buttons at the end (G15, Q12). On Windows the maximize button's area
///   answers the system's hit test as the maximize button, so Windows 11
///   shows its snap layouts there, except while a modal covers the window
///   ([ModalScope]): its scrim lies over the bar, so the area is Flutter's.
///
/// The bar's empty space moves the window, and a double-click there does
/// what the system does on a title bar ([DesktopWindow.titleBarDoubleClicked]),
/// counted from the presses with the system's double-click interval and
/// distance ([DesktopWindow.doubleClick]), as a native title bar counts them.
/// Only a pressed pointer moves the window: a trackpad's two-finger scroll
/// or pinch over the bar does nothing. Controls in [content] keep their own
/// clicks: only the space between them moves the window. The empty space is
/// not in the semantics tree; screen readers reach the window commands
/// through the caption buttons, the traffic lights and the shortcuts.
class TitleBar extends StatefulWidget {
  /// The title bar of [window], drawn for [platform].
  const new({
    required this.window,
    required this.platform,
    super.key,
    this.content,
  });

  /// The window the bar controls.
  final DesktopWindow window;

  /// The system whose window controls are drawn.
  final WindowPlatform platform;

  /// What the bar shows between the window controls; null leaves it bare.
  final Widget? content;

  @override
  State<TitleBar> createState() => _TitleBarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<WindowPlatform>('platform', platform));
  }
}

class _TitleBarState extends State<TitleBar> {
  TrafficLightLayout? _sentLayout;

  /// Whether a modal covers the window ([ModalScope]): its scrim, in the
  /// root overlay, lies over the bar too.
  bool _modalOpen = ModalScope.isOpen;

  // The last primary press on the empty space, for counting double-clicks.
  Duration? _lastPressTime;
  Offset? _lastPressPosition;

  /// A click on the empty space that did not move: nothing to do (a
  /// double-click is counted from the presses in [_onPressDown]).
  void _onClick() {}

  /// Counts a press on the empty space; a second press within the system's
  /// interval and distance of the first is a double-click.
  void _onPressDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    final settings = widget.window.doubleClick;
    final lastTime = _lastPressTime;
    final lastPosition = _lastPressPosition;
    if (lastTime != null &&
        lastPosition != null &&
        event.timeStamp - lastTime <= settings.interval &&
        (event.position - lastPosition).distance <= settings.distance) {
      _lastPressTime = null;
      _lastPressPosition = null;
      unawaited(widget.window.titleBarDoubleClicked());
      return;
    }
    _lastPressTime = event.timeStamp;
    _lastPressPosition = event.position;
  }

  @override
  void initState() {
    super.initState();
    ModalScope.openCount.addListener(_onModalCountChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sendTrafficLightLayout();
  }

  /// While a modal is open, the Windows maximize button gives its snap-
  /// layout area (and the top resize edge over the bar) back to Flutter, so
  /// the scrim takes the pointer there as everywhere else; once the last
  /// modal closes, the button reports its rectangle again.
  void _onModalCountChanged() {
    final open = ModalScope.isOpen;
    if (open == _modalOpen) return;
    if (open && widget.platform == WindowPlatform.win) {
      unawaited(widget.window.setMaximizeButtonRect(null));
    }
    setState(() => _modalOpen = open);
  }

  @override
  void didUpdateWidget(TitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window != widget.window) _sentLayout = null;
    _sendTrafficLightLayout();
  }

  @override
  void dispose() {
    ModalScope.openCount.removeListener(_onModalCountChanged);
    if (widget.platform == WindowPlatform.win) {
      unawaited(widget.window.setMaximizeButtonRect(null));
    }
    super.dispose();
  }

  /// Places the native traffic lights in the slot: centred in the bar above
  /// its bottom line, 14 px from the leading edge, 12 px circles 8 px apart.
  void _sendTrafficLightLayout() {
    if (widget.platform != WindowPlatform.mac) return;
    final theme = context.ferman;
    final layout = TrafficLightLayout(
      titleBarHeight: theme.density.titlebarH - theme.border.borderWidth,
      leading: WindowChrome.macSlotStart,
      diameter: WindowChrome.macLightSize,
      spacing: theme.space.space2,
      rightToLeft: Directionality.of(context) == TextDirection.rtl,
    );
    if (_sameLayout(layout, _sentLayout)) return;
    _sentLayout = layout;
    unawaited(widget.window.setTrafficLightLayout(layout));
  }

  static bool _sameLayout(TrafficLightLayout a, TrafficLightLayout? b) =>
      b != null &&
      a.titleBarHeight == b.titleBarHeight &&
      a.leading == b.leading &&
      a.diameter == b.diameter &&
      a.spacing == b.spacing &&
      a.rightToLeft == b.rightToLeft;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final window = widget.window;
    return ValueListenableBuilder<DesktopWindowState>(
      valueListenable: window.state,
      builder: (context, state, _) {
        // The gap before the content on Windows and Linux (FmWindow `isWin`:
        // `width: 8px`), and on macOS in full screen.
        final gap = SizedBox(width: theme.space.space2);
        final Widget leading;
        final Widget? trailing;
        switch (widget.platform) {
          case WindowPlatform.mac:
            leading = state.fullScreen
                ? gap
                : const WindowChrome(
                    platform: WindowPlatform.mac,
                    minimizeLabel: '',
                    maximizeLabel: '',
                    restoreLabel: '',
                    closeLabel: '',
                  );
            trailing = null;
          case WindowPlatform.win || WindowPlatform.linux:
            leading = gap;
            trailing = ValueListenableBuilder<MaximizeButtonState>(
              valueListenable: window.maximizeButton,
              builder: (context, maximizeButton, _) => WindowChrome(
                platform: widget.platform,
                maximized: state.maximized,
                minimizeLabel: l10n.windowMinimize,
                maximizeLabel: l10n.windowMaximize,
                restoreLabel: l10n.windowRestore,
                closeLabel: l10n.windowClose,
                onMinimize: window.minimize,
                onMaximize: window.toggleMaximize,
                onClose: window.close,
                maximizeButtonStates: {
                  if (maximizeButton.hovered) WidgetState.hovered,
                  if (maximizeButton.pressed) WidgetState.pressed,
                },
                onMaximizeButtonRect:
                    widget.platform == WindowPlatform.win && !_modalOpen
                    ? window.setMaximizeButtonRect
                    : null,
              ),
            );
        }
        return SizedBox(
          height: theme.density.titlebarH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surfaceSunken,
              border: Border(
                bottom: BorderSide(
                  color: theme.colors.borderSubtle,
                  width: theme.border.borderWidth,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                bottom: theme.border.borderWidth,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Behind the controls: only the space between them moves
                  // the window.
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPressDown,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      // A trackpad's two-finger scroll or pinch arrives as a
                      // pan with no button down; a title bar never moves on
                      // it.
                      supportedDevices: const {
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.touch,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.invertedStylus,
                        PointerDeviceKind.unknown,
                      },
                      onPanStart: (_) => window.startDragging(),
                      // A click that does not move is a click: competing
                      // for the pointer, the tap keeps the drag from
                      // starting until the pointer moves, as on a native
                      // title bar.
                      onTap: _onClick,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leading,
                      Expanded(child: widget.content ?? const SizedBox()),
                      ?trailing,
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
