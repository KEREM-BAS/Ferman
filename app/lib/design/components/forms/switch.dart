import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A 28 × 16 on/off switch with an optional label, the design-system
/// `Switch` component (`components/forms/Switch.jsx`, `.fm-switch`); 44 × 26
/// at touch density. Material has a `Switch` too: files that import
/// Material hide it.
///
/// The track is the strong border colour when off and the accent when on
/// ([value]); the white 12 px thumb (22 px at touch density) with a small
/// shadow slides along the inline start, so it mirrors in right to left.
/// Both change over `--dur-fast` (at once with reduced motion). [label]
/// follows 8 px after the track in body text. Keyboard focus adds the outer
/// focus ring around the track. The design draws no hover look. The whole
/// row is the hit target (the bundle's `<label>`), and Space toggles (not
/// Enter, which passes on to the enclosing handlers, as from a native
/// checkbox).
///
/// The widget is controlled: activating it calls [onChanged] with the
/// opposite of [value].
///
/// **Disabled.** [disabled] fades the track to 50 % (the thumb, a sibling of
/// the faded `<input>` in the bundle, stays opaque with its shadow) and
/// turns the label the disabled text colour. With [disabledReason] (G10;
/// the Settings → Privacy rows until their milestone) the switch stays
/// focusable and shows the reason as its tooltip and semantics hint.
///
/// For screen readers it is a switch, toggled on or off, named by [label]
/// or, without one, [semanticLabel].
class Switch extends StatelessWidget {
  /// Creates a switch.
  const new({
    required this.value,
    super.key,
    this.label,
    this.disabled = false,
    this.disabledReason,
    this.onChanged,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  /// `.fm-switch__track` `width`.
  static const double trackWidth = 28;

  /// `.fm-switch__track` `height`.
  static const double trackHeight = 16;

  /// `.fm-switch__thumb` `width` and `height`.
  static const double thumbSize = 12;

  /// `.fm-switch__thumb` `top` and its off `inset-inline-start`.
  static const double thumbInset = 2;

  /// `[data-density="touch"] .fm-switch__track` `width`.
  static const double touchTrackWidth = 44;

  /// `[data-density="touch"] .fm-switch__track` `height`.
  static const double touchTrackHeight = 26;

  /// `[data-density="touch"] .fm-switch__thumb` `width` and `height`.
  static const double touchThumbSize = 22;

  /// `.fm-switch__thumb` `background: #FFFFFF`, in both themes.
  static const Color thumbColor = Color(0xFFFFFFFF);

  /// `.fm-switch__thumb` `box-shadow: 0 1px 2px rgba(0,0,0,.25)`.
  /// A CSS blur of 2 px is a Gaussian with a sigma of 1, which is a
  /// [BoxShadow.blurRadius] of 0.866 (as `tools/tokens` converts the
  /// shadow tokens).
  static const BoxShadow thumbShadow = BoxShadow(
    color: Color(0x40000000),
    offset: Offset(0, 1),
    blurRadius: 0.866,
  );

  /// `.fm-switch__input:disabled` `opacity`: the track fill only.
  static const double disabledOpacity = 0.5;

  /// The label after the track; null shows none.
  final String? label;

  /// Whether the switch is on (the DS `checked`).
  final bool value;

  /// Whether the switch is disabled.
  final bool disabled;

  /// Why the switch is disabled: its tooltip and semantics hint while
  /// disabled (G10).
  final String? disabledReason;

  /// Called with the new value when the user toggles the switch; null
  /// disables it.
  final ValueChanged<bool>? onChanged;

  /// The accessible name when no [label] is shown (`aria-label`: the
  /// Privacy rows).
  final String? semanticLabel;

  /// The focus node; one is created when null. Not a design-system prop.
  final FocusNode? focusNode;

  /// Whether the switch takes focus when it first appears. Not a
  /// design-system prop.
  final bool autofocus;

  Widget _track(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final touch = identical(theme.density, FermanDensityTokens.touch);
    final width = touch ? touchTrackWidth : trackWidth;
    final height = touch ? touchTrackHeight : trackHeight;
    final thumb = touch ? touchThumbSize : thumbSize;
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusFull));
    final fill = value ? colors.accent : colors.borderStrong;
    // `.fm-switch__input:disabled { opacity: .5 }` fades the childless
    // input that paints the track; the thumb is its sibling and stays
    // opaque.
    final faded = states.contains(WidgetState.disabled);
    final track = AnimatedContainer(
      duration: theme.motion.durFast,
      curve: theme.motion.easeOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: faded ? fill.withValues(alpha: fill.a * disabledOpacity) : fill,
        borderRadius: radius,
      ),
      child: Stack(
        children: [
          AnimatedPositionedDirectional(
            duration: theme.motion.durFast,
            curve: theme.motion.easeOut,
            top: thumbInset,
            start: value ? width - thumbInset - thumb : thumbInset,
            width: thumb,
            height: thumb,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: thumbColor,
                shape: BoxShape.circle,
                boxShadow: [thumbShadow],
              ),
            ),
          ),
        ],
      ),
    );
    return FocusRing(
      visible: states.contains(WidgetState.focused),
      borderRadius: radius,
      child: track,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final change = onChanged;
    final text = label;
    return FermanInteractive(
      onPressed: change == null ? null : () => change(!value),
      activateOnEnter: false,
      disabled: disabled,
      disabledReason: disabledReason,
      toggled: value,
      isButton: false,
      semanticLabel: text == null ? semanticLabel : null,
      focusNode: focusNode,
      autofocus: autofocus,
      builder: (context, states, _) {
        final track = _track(context, states);
        if (text == null) return track;
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.space.space2,
          children: [
            track,
            Flexible(
              child: Text(
                text,
                style: theme.typography.body.copyWith(
                  color: states.contains(WidgetState.disabled)
                      ? theme.colors.textDisabled
                      : theme.colors.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(FlagProperty('value', value: value, ifTrue: 'on', ifFalse: 'off'))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      )
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}
