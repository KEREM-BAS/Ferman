import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The look of a [Button] (`.fm-btn--primary`, `--secondary`, `--ghost`,
/// `--danger`).
enum ButtonVariant {
  /// Filled with the accent colour: the main action of a view or dialog.
  primary,

  /// A raised surface with a border and a small shadow; the default.
  secondary,

  /// No fill until hovered: quiet actions in bars and panels.
  ghost,

  /// Filled with the solid danger colour: destructive actions.
  danger,
}

/// The height of a [Button] (`.fm-btn--sm`, `.fm-btn`, `.fm-btn--lg`).
enum ButtonSize {
  /// `--control-h-sm`, 8 px padding, 12 px text and 14 px icons.
  sm,

  /// `--control-h-md` and 12 px padding; the default.
  md,

  /// `--control-h-lg` and 16 px padding.
  lg,
}

/// A text button with an optional leading and trailing icon, the
/// design-system `Button` component (`components/core/core.css`,
/// `.fm-btn`; `Button.jsx`).
///
/// [child] is the label, usually a [Text]; boards also put a `Kbd` or a
/// `Badge` after it. The button takes [variant]'s colours, [size]'s height,
/// padding and type, and shows [icon] before the label and [iconEnd] after
/// it (14 px at [ButtonSize.sm], 16 px otherwise).
///
/// States (`core.css`, the "Interactive states" matrix of
/// `DS additions.dc.html`):
///
/// - hover and pressed change the fill (and the secondary border and
///   shadow); the danger button's pressed state adds an inner shadow;
/// - keyboard focus shows the outer focus ring (G22), which takes the place
///   of the secondary button's shadow;
/// - the fill, border and text colours change over `--dur-instant`, the
///   shadows (the focus ring included) over `--dur-fast`;
/// - [disabled] (or a null [onPressed]) shows the sunken fill and the
///   disabled text colour, a ghost button stays unfilled; with
///   [disabledReason] the button stays focusable and shows the reason as
///   its tooltip and semantics hint (G10);
/// - [loading] replaces the leading icon with a loader-circle turning once
///   every 0.9 s (it keeps turning under reduced motion, as the CSS
///   animation does), hides [iconEnd] and shows the progress cursor. It
///   does not disable the button: pass [disabled] as well when activation
///   must wait.
///
/// The button never wraps its label. With [fullWidth] it fills the width
/// of its parent, which must then be bounded.
///
/// For screen readers it is a button labelled by [child]'s text. A failed
/// action is reported with a `Toast`; the button has no error look.
class Button extends StatelessWidget {
  /// Creates a button labelled [child].
  const new({
    required this.child,
    super.key,
    this.variant = ButtonVariant.secondary,
    this.size = ButtonSize.md,
    this.icon,
    this.iconEnd,
    this.loading = false,
    this.disabled = false,
    this.disabledReason,
    this.fullWidth = false,
    this.onPressed,
    this.focusNode,
    this.autofocus = false,
  });

  /// `Button.jsx` icon size at [ButtonSize.md] and [ButtonSize.lg].
  static const double iconSize = 16;

  /// `Button.jsx` icon size at [ButtonSize.sm].
  static const double iconSizeSm = 14;

  /// `.fm-btn .fm-icon-spin` `animation: fm-spin 0.9s linear infinite`.
  static const Duration spinPeriod = Duration(milliseconds: 900);

  /// `.fm-btn--danger` `color: #FFFFFF`.
  static const Color dangerForeground = Color(0xFFFFFFFF);

  /// `.fm-btn--danger:active` `box-shadow: inset 0 1px 2px rgba(0,0,0,.2)`.
  /// A CSS blur of 2 px is a Gaussian with a sigma of 1, which is a
  /// [BoxShadow.blurRadius] of 0.866 (as `tools/tokens` converts the
  /// shadow tokens).
  static const BoxShadow dangerPressedShadow = BoxShadow(
    color: Color(0x33000000),
    offset: Offset(0, 1),
    blurRadius: 0.866,
  );

  /// The label, usually a [Text].
  final Widget child;

  /// The colours.
  final ButtonVariant variant;

  /// The height, padding, type and icon size.
  final ButtonSize size;

  /// The icon before the label; null shows none.
  final IconName? icon;

  /// The icon after the label (a menu button's chevron-down); hidden while
  /// [loading].
  final IconName? iconEnd;

  /// Whether the action is running: a turning loader replaces [icon].
  final bool loading;

  /// Whether the button is disabled even though [onPressed] is set.
  final bool disabled;

  /// Why the button is disabled; shown as its tooltip and semantics hint
  /// while it is disabled (G10), such as "No changes to save" or the
  /// localized "Available in a future version".
  final String? disabledReason;

  /// Whether the button fills the width of its parent.
  final bool fullWidth;

  /// Called when the button is activated; null disables it.
  final VoidCallback? onPressed;

  /// The focus node; one is created when null. Not a design-system prop.
  final FocusNode? focusNode;

  /// Whether the button takes focus when it first appears. Not a
  /// design-system prop.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => FermanInteractive(
    onPressed: onPressed,
    disabled: disabled,
    disabledReason: disabledReason,
    focusNode: focusNode,
    autofocus: autofocus,
    builder: (context, states, _) => _body(context, states),
  );

  Widget _body(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final isDisabled = states.contains(WidgetState.disabled);
    final hovered = states.contains(WidgetState.hovered);
    final pressed = states.contains(WidgetState.pressed);
    final focused = states.contains(WidgetState.focused);
    const transparent = Color(0x00000000);

    var background = transparent;
    var foreground = colors.textPrimary;
    var border = transparent;
    var shadow = const <BoxShadow>[];
    var innerShadow = false;
    switch (variant) {
      case ButtonVariant.primary:
        background = pressed
            ? colors.accentPressed
            : hovered
            ? colors.accentHover
            : colors.accent;
        foreground = colors.textOnAccent;
      case ButtonVariant.secondary:
        background = pressed
            ? Color.alphaBlend(colors.surfacePressed, colors.surfaceRaised)
            : hovered
            ? Color.alphaBlend(colors.surfaceHover, colors.surfaceRaised)
            : colors.surfaceRaised;
        border = hovered ? colors.borderStrong : colors.borderDefault;
        // `:active` drops `--shadow-sm`, and `.fm-btn:focus-visible` puts the
        // focus ring in its place (it is the more specific rule).
        shadow = pressed || focused ? const [] : theme.elevation.shadowSm;
      case ButtonVariant.ghost:
        background = pressed
            ? colors.surfacePressed
            : hovered
            ? colors.surfaceHover
            : transparent;
      case ButtonVariant.danger:
        background = pressed || hovered
            ? colors.dangerHover
            : colors.dangerSolid;
        foreground = dangerForeground;
        innerShadow = pressed;
    }
    if (isDisabled) {
      background = variant == ButtonVariant.ghost
          ? transparent
          : colors.surfaceSunken;
      foreground = colors.textDisabled;
      border = transparent;
      shadow = const [];
      innerShadow = false;
    }

    final density = theme.density;
    final (height, padding) = switch (size) {
      ButtonSize.sm => (density.controlHSm, theme.space.space2),
      ButtonSize.md => (density.controlHMd, theme.space.space3),
      ButtonSize.lg => (density.controlHLg, theme.space.space4),
    };
    final glyph = size == ButtonSize.sm ? iconSizeSm : iconSize;
    final role = theme.typography.bodyStrong;
    var label = role.copyWith(color: foreground);
    if (size == ButtonSize.sm) {
      // `.fm-btn--sm` changes only the font size; the line height stays.
      final lineHeight = (role.fontSize ?? 0) * (role.height ?? 1);
      final fontSize = theme.typeScale.sizeSm;
      label = label.copyWith(fontSize: fontSize, height: lineHeight / fontSize);
    }
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
    final leading = loading
        ? SpinRotation(
            period: spinPeriod,
            child: Icon(IconName.loaderCircle, size: glyph),
          )
        : icon == null
        ? null
        : Icon(icon!, size: glyph);
    final trailing = iconEnd == null || loading
        ? null
        : Icon(iconEnd!, size: glyph);

    final motion = theme.motion;
    // Inside the border (the CSS padding box): the padding, then the label.
    Widget content = Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: padding),
      child: AnimatedDefaultTextStyle(
        duration: motion.durInstant,
        curve: motion.easeOut,
        style: DefaultTextStyle.of(context).style.merge(label),
        softWrap: false,
        maxLines: 1,
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: theme.space.space1_5,
          children: [?leading, child, ?trailing],
        ),
      ),
    );
    // `.fm-btn--danger:active`'s inset shadow: cast inside the padding box,
    // under the label, and faded in and out over --dur-fast like every
    // box-shadow change of `.fm-btn`. Always in the tree, so pressing never
    // rebuilds the label.
    content = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: innerShadow ? 1 : 0),
      duration: motion.durFast,
      curve: motion.easeOut,
      builder: (context, t, child) => CustomPaint(
        painter: t <= 0
            ? null
            : InsetShadowPainter(
                shadow: dangerPressedShadow
                    .scale(t)
                    .copyWith(
                      color: dangerPressedShadow.color.withValues(
                        alpha: dangerPressedShadow.color.a * t,
                      ),
                    ),
                borderRadius: theme.radius.radiusSm - theme.border.borderWidth,
              ),
        child: child,
      ),
      child: content,
    );

    // `.fm-btn` changes its fill, border and text over --dur-instant …
    Widget result = AnimatedContainer(
      duration: motion.durInstant,
      curve: motion.easeOut,
      height: height,
      width: fullWidth ? double.infinity : null,
      constraints: BoxConstraints(minWidth: density.hitMin),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: theme.border.borderWidth),
        borderRadius: radius,
      ),
      child: content,
    );
    // … and its box shadow over --dur-fast.
    result = AnimatedContainer(
      duration: motion.durFast,
      curve: motion.easeOut,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
      child: result,
    );
    result = FocusRing(
      visible: focused,
      borderRadius: radius,
      duration: motion.durFast,
      curve: motion.easeOut,
      child: result,
    );
    if (loading) {
      // `.fm-btn[aria-busy="true"] { cursor: progress }`, which also wins
      // over the disabled cursor.
      result = MouseRegion(cursor: SystemMouseCursors.progress, child: result);
    }
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<ButtonVariant>(
          'variant',
          variant,
          defaultValue: ButtonVariant.secondary,
        ),
      )
      ..add(EnumProperty<ButtonSize>('size', size, defaultValue: ButtonSize.md))
      ..add(EnumProperty<IconName>('icon', icon, defaultValue: null))
      ..add(EnumProperty<IconName>('iconEnd', iconEnd, defaultValue: null))
      ..add(FlagProperty('loading', value: loading, ifTrue: 'loading'))
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
      ..add(FlagProperty('fullWidth', value: fullWidth, ifTrue: 'fullWidth'));
  }
}

/// Paints a CSS `inset` box shadow inside a rounded rectangle the size of
/// the canvas, which `BoxDecoration` cannot draw: the area outside the
/// rectangle moved by the shadow's offset, blurred, clipped to the
/// rectangle.
class InsetShadowPainter extends CustomPainter {
  /// Paints [shadow] inside a rectangle with corners of [borderRadius].
  const new({required this.shadow, required this.borderRadius});

  /// The shadow: colour, offset and blur radius (spread is ignored).
  final BoxShadow shadow;

  /// The corner radius of the rectangle.
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(shadow.blurRadius * 2 + 8))
      ..addRRect(box.shift(shadow.offset));
    canvas
      ..save()
      ..clipRRect(box)
      ..drawPath(
        outside,
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(InsetShadowPainter oldDelegate) =>
      oldDelegate.shadow != shadow || oldDelegate.borderRadius != borderRadius;
}
