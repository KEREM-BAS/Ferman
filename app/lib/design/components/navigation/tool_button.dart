import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// How a [ToolButton] arranges its icon and label (`.fm-toolbtn`,
/// `.fm-toolbtn--stacked`).
enum ToolButtonLayout {
  /// Icon and label side by side, `--control-h-md` tall.
  inline,

  /// Icon above a small label, 48 px tall.
  stacked,
}

/// A button in a tool row, the design-system `ToolButton` component
/// (`components/navigation/navigation.css`, `.fm-toolbtn`;
/// `ToolButton.jsx`).
///
/// It shows an [icon] and its [label] ([layout] side by side or stacked),
/// or only the icon when [showLabel] is false. A tool that can be on or off
/// passes [active] (the design's `aria-pressed`): on draws the accent fill;
/// null means the button is not a toggle. [hasMenu] adds a small caret for
/// a tool with a menu, and [swatch] a 14 × 3 colour bar near the bottom
/// (the current annotation colour).
///
/// **Tooltip** (G22): the label and the platform [shortcut] as key caps,
/// shown when the button is icon-only or has a shortcut; tool-button
/// tooltips always show the shortcut when one exists. A disabled button
/// with a [disabledReason] shows the reason instead (G10) and stays
/// focusable; a plain disabled button shows nothing and is skipped by the
/// keyboard.
///
/// **Keyboard:** Enter and Space call [onPressed]. With [hasMenu],
/// ArrowDown opens the menu (the menu-button pattern; not in the bundle):
/// it calls [onMenuRequested], or [onPressed] when that is null, for a
/// plain menu button whose press opens the menu. The menu itself (the
/// design-system Menu) is placed by the caller around this button.
///
/// **Semantics:** a button named [label], toggled when [active] is set,
/// with the tooltip.
class ToolButton extends StatelessWidget {
  /// A tool button named [label].
  const new({
    required this.label,
    super.key,
    this.icon,
    this.showLabel = true,
    this.layout = ToolButtonLayout.inline,
    this.active,
    this.hasMenu = false,
    this.swatch,
    this.shortcut,
    this.disabled = false,
    this.disabledReason,
    this.onPressed,
    this.onMenuRequested,
    this.focusNode,
  });

  /// The glyph: 16 px inline, 20 px stacked (`--icon-md`, `--icon-lg`).
  final IconName? icon;

  /// The localized name of the tool: the visible label, or the tooltip and
  /// accessible name when [showLabel] is false.
  final String label;

  /// Whether the label is shown; false draws an icon-only button.
  final bool showLabel;

  /// Side by side or stacked.
  final ToolButtonLayout layout;

  /// Whether the tool is on (`aria-pressed`); null when it is not a toggle.
  final bool? active;

  /// Whether the tool opens a menu: draws the caret and enables ArrowDown.
  final bool hasMenu;

  /// The colour bar near the bottom (the annotation colour of the active
  /// tool); null draws none.
  final Color? swatch;

  /// The shortcut as key caps already resolved for the platform (`KeyCaps`),
  /// shown in the tooltip.
  final List<String>? shortcut;

  /// Whether the button is disabled even though [onPressed] is set.
  final bool disabled;

  /// Why the button is disabled (G10): later-phase tools pass the localized
  /// "Available in a future version".
  final String? disabledReason;

  /// Called when the button is activated; null disables it.
  final VoidCallback? onPressed;

  /// Called when ArrowDown asks for the menu of a [hasMenu] button; null
  /// falls back to [onPressed]. Not a design-system prop.
  final VoidCallback? onMenuRequested;

  /// The focus node; one is created when null. Not a design-system prop.
  final FocusNode? focusNode;

  /// `.fm-toolbtn--stacked` `height: 48px`.
  static const double stackedHeight = 48;

  /// `.fm-toolbtn--stacked` `min-width: 56px`.
  static const double stackedMinWidth = 56;

  /// `.fm-toolbtn--stacked` `padding: 4px 6px`, horizontal part (vertical
  /// is `space1`).
  static const double stackedPaddingX = 6;

  /// The caret glyph: `chevron-down` at 12 px (`ToolButton.jsx`).
  static const double caretSize = 12;

  /// `.fm-toolbtn__caret` `margin-inline-start: -2px`.
  static const double caretOverlap = 2;

  /// `.fm-toolbtn__caret` `opacity: 0.7`.
  static const double caretOpacity = 0.7;

  /// `.fm-toolbtn__swatch` `width: 14px`.
  static const double swatchWidth = 14;

  /// `.fm-toolbtn__swatch` `height: 3px`.
  static const double swatchHeight = 3;

  /// `.fm-toolbtn__swatch` `border-radius: 1px`.
  static const double swatchRadius = 1;

  /// `.fm-toolbtn__swatch` `bottom: 4px`.
  static const double swatchBottom = 4;

  bool get _enabled => !disabled && onPressed != null;

  bool get _iconOnly => !showLabel;

  @override
  Widget build(BuildContext context) {
    final menu = onMenuRequested ?? onPressed;
    Widget button = FermanInteractive(
      focusNode: focusNode,
      onPressed: onPressed,
      disabled: disabled,
      disabledReason: disabledReason,
      toggled: active,
      tooltip: _iconOnly || shortcut != null ? label : null,
      tooltipShortcut: shortcut,
      semanticLabel: label,
      builder: (context, states, _) =>
          ExcludeSemantics(child: _visual(context, states)),
    );
    if (hasMenu && _enabled && menu != null) {
      button = CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.arrowDown): menu},
        child: button,
      );
    }
    return button;
  }

  Widget _visual(BuildContext context, Set<WidgetState> states) {
    final theme = context.ferman;
    final colors = theme.colors;
    final density = theme.density;
    final stacked = layout == ToolButtonLayout.stacked;
    final isDisabled = states.contains(WidgetState.disabled);
    final on = active ?? false;
    final hovered = states.contains(WidgetState.hovered);
    final pressed = states.contains(WidgetState.pressed);
    final Color background;
    final Color foreground;
    final Color iconColor;
    if (isDisabled) {
      background = const Color(0x00000000);
      foreground = colors.textDisabled;
      iconColor = colors.iconDisabled;
    } else if (on) {
      background = hovered ? colors.accentSubtleHover : colors.accentSubtle;
      foreground = colors.textAccent;
      iconColor = colors.textAccent;
    } else {
      background = pressed
          ? colors.surfacePressed
          : (hovered ? colors.surfaceHover : const Color(0x00000000));
      foreground = colors.textPrimary;
      iconColor = colors.iconPrimary;
    }
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
    final glyph = icon;
    final text = showLabel
        ? Text(label, maxLines: 1, softWrap: false, textAlign: TextAlign.center)
        : null;
    final caret = hasMenu
        ? Opacity(
            opacity: caretOpacity,
            child: Icon(
              IconName.chevronDown,
              size: caretSize,
              color: iconColor,
            ),
          )
        : null;
    final Widget content;
    if (stacked) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space0_5,
        children: [
          if (glyph != null)
            Icon(glyph, size: density.iconLg, color: iconColor),
          ?text,
          ?caret,
        ],
      );
    } else {
      final gap = theme.space.space1_5;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null)
            Icon(glyph, size: density.iconMd, color: iconColor),
          if (glyph != null && text != null) SizedBox(width: gap),
          ?text,
          if (caret != null && (glyph != null || text != null))
            SizedBox(width: gap - caretOverlap),
          ?caret,
        ],
      );
    }
    final style = stacked
        ? DefaultTextStyle.of(context).style
              .merge(theme.typography.body)
              .copyWith(
                fontSize: theme.typeScale.sizeXs,
                fontWeight: theme.typeScale.weightRegular,
                height: theme.typeScale.leadingXs / theme.typeScale.sizeXs,
                color: foreground,
              )
        : DefaultTextStyle.of(context).style
              .merge(theme.typography.body)
              .copyWith(color: foreground);
    final EdgeInsetsDirectional padding;
    if (stacked) {
      padding = EdgeInsetsDirectional.symmetric(
        horizontal: stackedPaddingX,
        vertical: theme.space.space1,
      );
    } else if (_iconOnly) {
      padding = EdgeInsetsDirectional.zero;
    } else {
      padding = EdgeInsetsDirectional.symmetric(horizontal: theme.space.space2);
    }
    final height = stacked ? stackedHeight : density.controlHMd;
    final minWidth = stacked ? stackedMinWidth : density.controlHMd;
    final color = swatch;
    return FocusRing(
      visible: states.contains(WidgetState.focused),
      borderRadius: radius,
      child: AnimatedContainer(
        duration: theme.motion.durInstant,
        curve: theme.motion.easeOut,
        height: height,
        constraints: BoxConstraints(minWidth: minWidth),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          // `border: 1px solid transparent`, inside the height.
          border: Border.all(
            color: const Color(0x00000000),
            width: theme.border.borderWidth,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: padding,
              child: AnimatedDefaultTextStyle(
                duration: theme.motion.durInstant,
                curve: theme.motion.easeOut,
                style: style,
                child: content,
              ),
            ),
            if (color != null)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: swatchBottom,
                child: Center(
                  child: SizedBox(
                    width: swatchWidth,
                    height: swatchHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(swatchRadius),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(EnumProperty<IconName>('icon', icon, defaultValue: null))
      ..add(
        FlagProperty(
          'showLabel',
          value: showLabel,
          ifFalse: 'icon only',
          defaultValue: true,
        ),
      )
      ..add(
        EnumProperty<ToolButtonLayout>(
          'layout',
          layout,
          defaultValue: ToolButtonLayout.inline,
        ),
      )
      ..add(FlagProperty('active', value: active, ifTrue: 'on', ifFalse: 'off'))
      ..add(FlagProperty('hasMenu', value: hasMenu, ifTrue: 'hasMenu'))
      ..add(ColorProperty('swatch', swatch, defaultValue: null))
      ..add(IterableProperty<String>('shortcut', shortcut, defaultValue: null))
      ..add(FlagProperty('enabled', value: _enabled, ifFalse: 'disabled'))
      ..add(
        StringProperty('disabledReason', disabledReason, defaultValue: null),
      );
  }
}
