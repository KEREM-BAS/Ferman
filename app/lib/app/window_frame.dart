import 'dart:async';

import 'package:ferman/app/desktop_window.dart';
import 'package:ferman/app/platform_window.dart';
import 'package:ferman/design/components/additions/window_chrome.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The frame of every desktop screen: Ferman's own title bar above [child]
/// (the FmWindow header, M1 phase H1).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TitleBar(window: window, platform: platform, content: titleBarContent),
        Expanded(child: child),
      ],
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
///   shows its snap layouts there.
///
/// The bar's empty space moves the window, and a double-click there does
/// what the system does on a title bar ([DesktopWindow.titleBarDoubleClicked]).
/// Controls in [content] keep their own clicks: only the space between them
/// moves the window.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sendTrafficLightLayout();
  }

  @override
  void didUpdateWidget(TitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window != widget.window) _sentLayout = null;
    _sendTrafficLightLayout();
  }

  @override
  void dispose() {
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
                onMaximizeButtonRect: widget.platform == WindowPlatform.win
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => window.startDragging(),
                    onDoubleTap: window.titleBarDoubleClicked,
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
