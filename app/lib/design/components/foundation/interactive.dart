import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The pointer, keyboard, focus, tooltip and semantics behaviour every
/// interactive Ferman component shares (buttons, icon buttons, tool
/// buttons, tabs, segments, menu rows, thumbnails).
///
/// It tracks the component's interaction states and rebuilds [builder]
/// with them:
///
/// - [WidgetState.hovered] while the pointer is over an enabled control;
/// - [WidgetState.pressed] while an enabled control is held down;
/// - [WidgetState.focused] while the control has keyboard focus and the
///   focus highlight shows: the design's focus-visible state (G22), never
///   set by a pointer click;
/// - [WidgetState.disabled] when [disabled] is true or [onPressed] is null;
/// - [WidgetState.selected] when [selected] is true;
///
/// plus the states a [FermanForcedStates] above it forces.
///
/// A tap, Enter or Space activates an enabled control ([onPressed]).
///
/// **Disabled with a reason (G10).** When the control is disabled and
/// [disabledReason] is set, the reason shows as the tooltip and the
/// semantics hint, and the control stays focusable, so keyboard and
/// screen-reader users can read why; activating it does nothing.
/// Unshipped features pass the localized "Available in a future version"
/// (`futureVersionReason`). Without a reason a disabled control is skipped
/// by focus traversal.
///
/// Otherwise [tooltip] (with [tooltipShortcut] as key caps) labels the
/// control on hover and keyboard focus.
class FermanInteractive extends StatefulWidget {
  /// Makes the control [builder] draws interactive.
  const new({
    required this.builder,
    super.key,
    this.onPressed,
    this.disabled = false,
    this.disabledReason,
    this.selected = false,
    this.toggled,
    this.tooltip,
    this.tooltipShortcut,
    this.tooltipSide = TooltipSide.bottom,
    this.semanticLabel,
    this.semanticsRole,
    this.isButton = true,
    this.focusNode,
    this.autofocus = false,
    this.child,
  });

  /// Draws the control for the current interaction states. [child] is
  /// passed through unchanged, for the parts that do not depend on them.
  final ValueWidgetBuilder<Set<WidgetState>> builder;

  /// Called when the control is activated; null disables it.
  final VoidCallback? onPressed;

  /// Whether the control is disabled even though [onPressed] is set.
  final bool disabled;

  /// Why the control is disabled; shown as its tooltip and semantics hint
  /// while it is disabled (G10).
  final String? disabledReason;

  /// Whether the control is the selected one of a set (a tab, a segment).
  final bool selected;

  /// The pressed state of a toggle (`aria-pressed`); null for a control
  /// that is not a toggle.
  final bool? toggled;

  /// The label shown on hover and keyboard focus while enabled; null shows
  /// none.
  final String? tooltip;

  /// The shortcut key caps shown after [tooltip].
  final List<String>? tooltipShortcut;

  /// The side the tooltip opens on.
  final TooltipSide tooltipSide;

  /// The accessible name when the visible content does not give one (an
  /// icon-only control).
  final String? semanticLabel;

  /// The semantics role beyond a button, such as [SemanticsRole.tab].
  final SemanticsRole? semanticsRole;

  /// Whether screen readers announce the control as a button.
  final bool isButton;

  /// The focus node; one is created when null.
  final FocusNode? focusNode;

  /// Whether the control takes focus when it first appears.
  final bool autofocus;

  /// The part of the control that does not depend on the states.
  final Widget? child;

  /// Whether a control with [onPressed] and [disabled] is enabled.
  static bool isEnabled({
    required VoidCallback? onPressed,
    required bool disabled,
  }) => !disabled && onPressed != null;

  @override
  State<FermanInteractive> createState() => _FermanInteractiveState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        FlagProperty(
          'enabled',
          value: isEnabled(onPressed: onPressed, disabled: disabled),
          ifFalse: 'disabled',
        ),
      )
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      )
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(
        FlagProperty(
          'toggled',
          value: toggled,
          ifTrue: 'toggled on',
          ifFalse: 'toggled off',
        ),
      )
      ..add(StringProperty('tooltip', tooltip, defaultValue: null))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

class _FermanInteractiveState extends State<FermanInteractive> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  bool _focusVisible = false;
  FocusNode? _ownNode;

  FocusNode get _node =>
      widget.focusNode ??
      (_ownNode ??= FocusNode(debugLabel: 'FermanInteractive'));

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  bool get _enabled => FermanInteractive.isEnabled(
    onPressed: widget.onPressed,
    disabled: widget.disabled,
  );

  bool get _showsReason => !_enabled && widget.disabledReason != null;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (_) => _activate(),
    ),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
      onInvoke: (_) => _activate(),
    ),
  };

  Object? _activate() {
    if (_enabled) widget.onPressed?.call();
    return null;
  }

  @override
  void didUpdateWidget(FermanInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) _pressed = false;
  }

  Set<WidgetState> _states(BuildContext context) => {
    if (_enabled && _hovered) WidgetState.hovered,
    if (_enabled && _pressed) WidgetState.pressed,
    if (_focusVisible) WidgetState.focused,
    if (!_enabled) WidgetState.disabled,
    if (widget.selected) WidgetState.selected,
    ...FermanForcedStates.of(context),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final focusable = enabled || _showsReason;
    final message = _showsReason
        ? widget.disabledReason
        : (enabled ? widget.tooltip : null);
    Widget result = FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: focusable,
      shortcuts: _shortcuts,
      actions: _actions,
      // The control's own semantics node below says focusable and focused,
      // so the label, hint and state stay on one node.
      includeFocusSemantics: false,
      onFocusChange: (value) => setState(() => _focused = value),
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: widget.builder(context, _states(context), widget.child),
        ),
      ),
    );
    result = Semantics(
      container: true,
      button: widget.isButton,
      role: widget.semanticsRole,
      enabled: enabled,
      focusable: focusable,
      focused: focusable ? _focused : null,
      selected: widget.selected ? true : null,
      toggled: widget.toggled,
      label: widget.semanticLabel,
      hint: _showsReason ? widget.disabledReason : null,
      tooltip: message,
      onTap: enabled ? widget.onPressed : null,
      onFocus: focusable ? _node.requestFocus : null,
      child: result,
    );
    if (message != null) {
      result = Tooltip(
        message: message,
        shortcut: _showsReason ? null : widget.tooltipShortcut,
        side: widget.tooltipSide,
        excludeFromSemantics: true,
        child: result,
      );
    }
    return result;
  }
}
