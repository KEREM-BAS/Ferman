import 'dart:async';

import 'package:ferman/design/components/core/kbd.dart';
import 'package:ferman/design/components/foundation/anchored_layout.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The side of its child a [Tooltip] opens on. Left and right are logical:
/// they swap in right to left.
enum TooltipSide {
  /// Above the child.
  top,

  /// Below the child, the default.
  bottom,

  /// Before the child in left to right (to its right in right to left).
  left,

  /// After the child in left to right (to its left in right to left).
  right;

  /// This side as an [AnchorSide] for [direction].
  AnchorSide resolve(TextDirection direction) => switch (this) {
    TooltipSide.top => AnchorSide.top,
    TooltipSide.bottom => AnchorSide.bottom,
    TooltipSide.left => AnchorSide.left,
    TooltipSide.right => AnchorSide.right,
  }.resolve(direction);
}

/// A short label for its child, the design-system `Tooltip` component
/// (`components/core/core.css`, `.fm-tooltip`). Never the Material
/// tooltip (ADR 0011).
///
/// The bubble shows [message] (one to four words, no period, or the reason
/// a control is disabled) and, after it, the platform [shortcut] as inverse
/// key caps (G22). It opens [delay] after the pointer enters the child or
/// keyboard focus moves into it, fades in over `--dur-fast` (at once with
/// reduced motion), and hides at once when the pointer leaves, focus leaves
/// or Escape is pressed. It sits 6 px from the child on [side], flips to
/// the other side when it does not fit, and never takes pointer events.
///
/// [open] forces the bubble open or closed for goldens and the state sheet;
/// null follows hover and focus.
///
/// For screen readers [message] is the child's tooltip.
class Tooltip extends StatefulWidget {
  /// Labels [child] with [message].
  const new({
    required this.message,
    required this.child,
    super.key,
    this.shortcut,
    this.side = TooltipSide.bottom,
    this.open,
    this.delay = defaultDelay,
    this.excludeFromSemantics = false,
  });

  /// The design-system default delay (450 ms).
  static const Duration defaultDelay = Duration(milliseconds: 450);

  /// `.fm-tooltip--*`: the distance between the child and the bubble.
  static const double gap = 6;

  /// `.fm-tooltip` `gap` between the text and the key caps.
  static const double contentGap = 8;

  /// The label.
  final String message;

  /// The control the tooltip labels.
  final Widget child;

  /// The shortcut key caps shown after [message], already resolved for the
  /// platform; null shows none.
  final List<String>? shortcut;

  /// The side the bubble opens on.
  final TooltipSide side;

  /// Forces the bubble open (true) or closed (false); null follows hover
  /// and focus.
  final bool? open;

  /// How long the pointer or focus stays before the bubble opens.
  final Duration delay;

  /// Whether to leave [message] out of the child's semantics, for a child
  /// that puts it on its own semantics node (`FermanInteractive`). Not a
  /// design-system prop.
  final bool excludeFromSemantics;

  @override
  State<Tooltip> createState() => _TooltipState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('message', message))
      ..add(IterableProperty<String>('shortcut', shortcut, defaultValue: null))
      ..add(
        EnumProperty<TooltipSide>(
          'side',
          side,
          defaultValue: TooltipSide.bottom,
        ),
      )
      ..add(
        FlagProperty('open', value: open, ifTrue: 'open', ifFalse: 'closed'),
      )
      ..add(
        DiagnosticsProperty<Duration>(
          'delay',
          delay,
          defaultValue: Tooltip.defaultDelay,
        ),
      );
  }
}

class _TooltipState extends State<Tooltip> {
  final OverlayPortalController _portal = OverlayPortalController();
  Timer? _timer;
  bool _hovered = false;
  bool _focused = false;
  bool _shown = false;

  bool get _wanted => widget.open ?? (_hovered || _focused);

  @override
  void initState() {
    super.initState();
    if (widget.open ?? false) _update();
  }

  @override
  void didUpdateWidget(Tooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      // The overlay cannot be shown or hidden during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _update();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _update() {
    _timer?.cancel();
    if (!_wanted) {
      _hide();
    } else if (!_shown) {
      if (widget.open ?? false) {
        // Forced open: show in the next frame, once the overlay is laid out.
        WidgetsBinding.instance.addPostFrameCallback((_) => _show());
      } else {
        _timer = Timer(widget.delay, _show);
      }
    }
  }

  void _show() {
    if (!mounted || _shown || !_wanted) return;
    if (Overlay.maybeOf(context) == null) return;
    setState(() => _shown = true);
    _portal.show();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _hide() {
    _timer?.cancel();
    if (!_shown) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _portal.hide();
    if (mounted) setState(() => _shown = false);
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        widget.open == null) {
      _hide();
    }
    // Escape still reaches the rest of the app (dialogs, menus).
    return false;
  }

  void _onHover(bool hovered) {
    _hovered = hovered;
    _update();
  }

  void _onFocusChange(bool focused) {
    // Only keyboard focus opens a tooltip; a click that focuses a button
    // already hovers it.
    _focused =
        focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    _update();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) => CustomSingleChildLayout(
        delegate: FermanAnchoredLayout(
          anchor: FermanAnchoredLayout.anchorRect(info),
          side: widget.side.resolve(direction),
          gap: Tooltip.gap,
        ),
        child: IgnorePointer(
          child: _TooltipBubble(
            message: widget.message,
            shortcut: widget.shortcut,
          ),
        ),
      ),
      child: Semantics(
        tooltip: widget.excludeFromSemantics ? null : widget.message,
        child: MouseRegion(
          onEnter: (_) => _onHover(true),
          onExit: (_) => _onHover(false),
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            // A listener only: a semantics node here would sit between a
            // tab bar and its tabs.
            includeSemantics: false,
            onFocusChange: _onFocusChange,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The bubble: inverse surface, caption text, small shadow, fading in.
class _TooltipBubble extends StatelessWidget {
  const new({required this.message, required this.shortcut});

  final String message;
  final List<String>? shortcut;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final keys = shortcut;
    final bubble = Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space2,
        vertical: theme.space.space1,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfaceInverse,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusSm)),
        boxShadow: theme.elevation.shadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Tooltip.contentGap,
        children: [
          Text(
            message,
            softWrap: false,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textInverse,
            ),
          ),
          if (keys != null && keys.isNotEmpty) Kbd(keys, tone: KbdTone.inverse),
        ],
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: theme.motion.durFast,
      curve: theme.motion.easeOut,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: ExcludeSemantics(child: bubble),
    );
  }
}
