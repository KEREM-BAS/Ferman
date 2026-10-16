import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The look of an [IconButton] (`.fm-iconbtn`, `--secondary`, `--primary`).
enum IconButtonVariant {
  /// No fill until hovered; the default.
  ghost,

  /// A raised surface with a border and a small shadow.
  secondary,

  /// Filled with the accent colour.
  primary,
}

/// The size of an [IconButton] (`.fm-iconbtn--xs`, `--sm`, `.fm-iconbtn`,
/// `--lg`): a square of the matching control height.
enum IconButtonSize {
  /// `--control-h-xs`, 2 px corners and a 14 px icon.
  xs,

  /// `--control-h-sm` and a 16 px icon.
  sm,

  /// `--control-h-md` and a 16 px icon; the default.
  md,

  /// `--control-h-lg` and a 20 px icon.
  lg,
}

/// A square icon-only button, the design-system `IconButton` component
/// (`components/core/core.css`, `.fm-iconbtn`; `IconButton.jsx`).
///
/// [label] names the button for screen readers and is its tooltip (one to
/// four words, no period), with [shortcut] after it as inverse key caps;
/// [showTooltip] false keeps the name and drops the tooltip (a banner's
/// Dismiss).
///
/// [active] makes the button a toggle (`aria-pressed`): null is a plain
/// button, true shows the accent-subtle "on" look.
///
/// States (`core.css`, the "Interactive states" matrix of
/// `DS additions.dc.html`): hover and pressed fills, the outer focus ring
/// on keyboard focus (G22), the toggle's on look, disabled (the disabled
/// icon colour, no fill, no tooltip) and disabled with [disabledReason]:
/// focusable, the reason as tooltip and semantics hint (G10). Keyboard
/// focus also drops the secondary shadow, which the ring replaces. The
/// fill and icon colours change over `--dur-instant`, the shadows (the
/// focus ring included) over `--dur-fast`.
///
/// [loading] shows a [Spinner] the size of the icon in place of the
/// button's fill and icon, as the state sheet draws it, keeping the
/// button's footprint. The button stays in the focus order (a focused
/// button keeps its focus and ring) and activating it does nothing until
/// loading ends.
class IconButton extends StatelessWidget {
  /// Creates an icon button showing [icon], named [label].
  const new({
    required this.icon,
    required this.label,
    super.key,
    this.size = IconButtonSize.md,
    this.variant = IconButtonVariant.ghost,
    this.active,
    this.shortcut,
    this.showTooltip = true,
    this.tooltipSide = TooltipSide.bottom,
    this.disabled = false,
    this.disabledReason,
    this.onPressed,
    this.loading = false,
    this.focusNode,
    this.autofocus = false,
  });

  /// `IconButton.jsx` icon size at [IconButtonSize.xs].
  static const double iconSizeXs = 14;

  /// `IconButton.jsx` icon size at [IconButtonSize.sm] and
  /// [IconButtonSize.md].
  static const double iconSize = 16;

  /// `IconButton.jsx` icon size at [IconButtonSize.lg].
  static const double iconSizeLg = 20;

  /// The glyph.
  final IconName icon;

  /// The accessible name and tooltip text.
  final String label;

  /// The square's size and the icon size.
  final IconButtonSize size;

  /// The colours.
  final IconButtonVariant variant;

  /// The toggle state: null for a plain button, true or false for a
  /// toggle.
  final bool? active;

  /// The shortcut key caps shown in the tooltip, already resolved for the
  /// platform; null shows none.
  final List<String>? shortcut;

  /// Whether [label] shows as a tooltip on hover and keyboard focus.
  final bool showTooltip;

  /// The side the tooltip opens on.
  final TooltipSide tooltipSide;

  /// Whether the button is disabled even though [onPressed] is set.
  final bool disabled;

  /// Why the button is disabled; shown as its tooltip and semantics hint
  /// while it is disabled (G10).
  final String? disabledReason;

  /// Called when the button is activated; null disables it.
  final VoidCallback? onPressed;

  /// Whether the action is running: a spinner replaces the button's fill
  /// and icon (the state sheet's loading state) and activation does
  /// nothing. Not a design-system prop (COMPONENTS.md, decision 17).
  final bool loading;

  /// The focus node; one is created when null. Not a design-system prop.
  final FocusNode? focusNode;

  /// Whether the button takes focus when it first appears. Not a
  /// design-system prop.
  final bool autofocus;

  /// The icon size for [size].
  static double iconSizeFor(IconButtonSize size) => switch (size) {
    IconButtonSize.xs => iconSizeXs,
    IconButtonSize.sm || IconButtonSize.md => iconSize,
    IconButtonSize.lg => iconSizeLg,
  };

  @override
  Widget build(BuildContext context) {
    final density = context.ferman.density;
    final extent = switch (size) {
      IconButtonSize.xs => density.controlHXs,
      IconButtonSize.sm => density.controlHSm,
      IconButtonSize.md => density.controlHMd,
      IconButtonSize.lg => density.controlHLg,
    };
    final press = onPressed;
    // The control stays mounted and enabled while loading, so a focused
    // button keeps its focus node and its focus; only activation waits.
    return FermanInteractive(
      onPressed: press == null
          ? null
          : () {
              if (!loading) press();
            },
      disabled: disabled,
      disabledReason: disabledReason,
      toggled: active,
      tooltip: showTooltip ? label : null,
      tooltipShortcut: shortcut,
      tooltipSide: tooltipSide,
      semanticLabel: label,
      focusNode: focusNode,
      autofocus: autofocus,
      builder: (context, states, _) => loading
          ? _loadingBody(context, states, extent)
          : _body(context, states, extent),
    );
  }

  BorderRadius _radius(FermanTheme theme) => BorderRadius.all(
    Radius.circular(
      size == IconButtonSize.xs ? theme.radius.radiusXs : theme.radius.radiusSm,
    ),
  );

  /// The loading state: the spinner in the button's footprint, no fill,
  /// border or shadow (the state sheet), with the focus ring.
  Widget _loadingBody(
    BuildContext context,
    Set<WidgetState> states,
    double extent,
  ) {
    final theme = context.ferman;
    return FocusRing(
      visible: states.contains(WidgetState.focused),
      borderRadius: _radius(theme),
      duration: theme.motion.durFast,
      curve: theme.motion.easeOut,
      child: SizedBox.square(
        dimension: extent,
        child: Center(
          child: Spinner(size: iconSizeFor(size), semanticLabel: label),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Set<WidgetState> states, double extent) {
    final theme = context.ferman;
    final colors = theme.colors;
    final hovered = states.contains(WidgetState.hovered);
    final pressed = states.contains(WidgetState.pressed);
    final focused = states.contains(WidgetState.focused);
    const transparent = Color(0x00000000);

    var background = transparent;
    var foreground = hovered ? colors.textPrimary : colors.iconPrimary;
    var border = transparent;
    var shadow = const <BoxShadow>[];
    switch (variant) {
      case IconButtonVariant.ghost:
        background = pressed
            ? colors.surfacePressed
            : hovered
            ? colors.surfaceHover
            : transparent;
      case IconButtonVariant.secondary:
        // A pointer press also hovers, and `--secondary:hover` comes after
        // `:active` in core.css, so the pressed fill is the hover fill.
        background = hovered || pressed
            ? Color.alphaBlend(colors.surfaceHover, colors.surfaceRaised)
            : colors.surfaceRaised;
        border = colors.borderDefault;
        // `.fm-iconbtn:focus-visible` puts the focus ring in place of
        // `--shadow-sm` (it is the more specific rule).
        shadow = focused ? const [] : theme.elevation.shadowSm;
      case IconButtonVariant.primary:
        // As for secondary, `--primary:hover` wins over `:active`.
        background = hovered || pressed ? colors.accentHover : colors.accent;
        foreground = colors.textOnAccent;
    }
    if (active ?? false) {
      background = hovered ? colors.accentSubtleHover : colors.accentSubtle;
      foreground = colors.textAccent;
    }
    if (states.contains(WidgetState.disabled)) {
      background = transparent;
      foreground = colors.iconDisabled;
      shadow = const [];
    }

    final radius = _radius(theme);
    final motion = theme.motion;
    return FocusRing(
      visible: focused,
      borderRadius: radius,
      duration: motion.durFast,
      curve: motion.easeOut,
      // `.fm-iconbtn` changes its box shadow over --dur-fast …
      child: AnimatedContainer(
        duration: motion.durFast,
        curve: motion.easeOut,
        decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
        // … and its fill and icon colour over --dur-instant.
        child: AnimatedContainer(
          duration: motion.durInstant,
          curve: motion.easeOut,
          width: extent,
          height: extent,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: theme.border.borderWidth),
            borderRadius: radius,
          ),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: foreground),
            duration: motion.durInstant,
            curve: motion.easeOut,
            builder: (context, color, _) =>
                Icon(icon, size: iconSizeFor(size), color: color),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<IconName>('icon', icon))
      ..add(StringProperty('label', label))
      ..add(
        EnumProperty<IconButtonSize>(
          'size',
          size,
          defaultValue: IconButtonSize.md,
        ),
      )
      ..add(
        EnumProperty<IconButtonVariant>(
          'variant',
          variant,
          defaultValue: IconButtonVariant.ghost,
        ),
      )
      ..add(
        FlagProperty(
          'active',
          value: active,
          ifTrue: 'active',
          ifFalse: 'inactive',
        ),
      )
      ..add(IterableProperty<String>('shortcut', shortcut, defaultValue: null))
      ..add(
        FlagProperty('showTooltip', value: showTooltip, ifFalse: 'no tooltip'),
      )
      ..add(
        EnumProperty<TooltipSide>(
          'tooltipSide',
          tooltipSide,
          defaultValue: TooltipSide.bottom,
        ),
      )
      ..add(
        FlagProperty(
          'enabled',
          value: FermanInteractive.isEnabled(
            onPressed: onPressed,
            disabled: disabled,
          ),
          ifFalse: 'disabled',
        ),
      )
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      )
      ..add(FlagProperty('loading', value: loading, ifTrue: 'loading'));
  }
}
