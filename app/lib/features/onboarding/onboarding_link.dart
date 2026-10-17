import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// An inline text link of the first-run screens (the boards' `<a>`: the
/// link colour, underlined), such as "Help translate Ferman" (a1-1) or
/// "Source code" (a1-2c), with an optional [trailingIcon] after the text
/// ("See every connection in Settings › Privacy →", a1-2b).
///
/// With [onPressed] null it is disabled with [disabledReason] (G10): the
/// disabled text colour, still focusable, the reason as tooltip and
/// semantics hint. Screen readers hear a link, as the boards' `<a>`, not a
/// button. Links that leave the app (the translation project, the
/// source code) stay disabled in M1: the app opens no web pages yet.
class OnboardingLink extends StatelessWidget {
  /// A link labelled [label] in [style].
  const new({
    required this.label,
    required this.style,
    super.key,
    this.onPressed,
    this.disabledReason,
    this.trailingIcon,
  });

  /// The link text.
  final String label;

  /// The text style before the link colour and underline are applied.
  final TextStyle style;

  /// Follows the link; null disables it.
  final VoidCallback? onPressed;

  /// Why the link is disabled (G10).
  final String? disabledReason;

  /// An icon after the text, in the link colour and not underlined (a1-2b:
  /// `arrow-right`, 14 px, 6 px after the text, mirrored right to left).
  final IconName? trailingIcon;

  /// The trailing icon's size (`size="{{ 14 }}"`).
  static const double trailingIconSize = 14;

  @override
  Widget build(BuildContext context) => FermanInteractive(
    onPressed: onPressed,
    disabledReason: disabledReason,
    semanticLabel: label,
    isButton: false,
    builder: (context, states, _) {
      final theme = context.ferman;
      final colors = theme.colors;
      final color = states.contains(WidgetState.disabled)
          ? colors.textDisabled
          : states.contains(WidgetState.hovered)
          ? colors.accentHover
          : colors.textLink;
      final text = Text(
        label,
        style: style.copyWith(
          color: color,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      );
      final icon = trailingIcon;
      // Not a container: the link flag joins the control's own node, which
      // keeps the label, the reason and the tap.
      return Semantics(
        link: true,
        child: FocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusXs),
          ),
          child: ExcludeSemantics(
            child: icon == null
                ? text
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: theme.space.space1_5,
                    children: [
                      Flexible(child: text),
                      Icon(icon, size: trailingIconSize, color: color),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
