import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The colours of a [Badge] (`.fm-badge`, `.fm-badge--accent`, …).
enum BadgeTone {
  /// Sunken surface, default border, secondary text; the default.
  neutral,

  /// Accent-subtle fill, info border, accent text.
  accent,

  /// Success fill, border and text.
  success,

  /// Warning fill, border and text.
  warning,

  /// Danger fill, border and text.
  danger,

  /// Edited text: accent-subtle fill, no border, accent text (the DS
  /// additions' fix 3; not the teal of `core.css`).
  edited,
}

/// A small status label, the design-system `Badge` component
/// (`components/core/core.css`, `.fm-badge`; `Badge.jsx`): counts, file
/// states, document languages.
///
/// An 18 px tall pill with 2 px corners showing [label] in the label type
/// with tabular figures, never wrapping, after an optional 6 px [dot] in
/// the text colour and an optional 12 px [icon] drawn at stroke 2. [tone]
/// picks the colours.
///
/// It is not interactive. For screen readers it is one text node, [label].
class Badge extends StatelessWidget {
  /// Creates a badge showing [label].
  const new({
    required this.label,
    super.key,
    this.tone = BadgeTone.neutral,
    this.dot = false,
    this.icon,
  });

  /// `.fm-badge` `height: 18px`.
  static const double height = 18;

  /// `.fm-badge__dot` `width` and `height`.
  static const double dotSize = 6;

  /// `Badge.jsx` icon size.
  static const double iconSize = 12;

  /// `Badge.jsx` icon stroke width.
  static const double iconStrokeWidth = 2;

  /// The text.
  final String label;

  /// The colours.
  final BadgeTone tone;

  /// Whether a dot in the text colour comes before the label.
  final bool dot;

  /// The icon before the label; null shows none.
  final IconName? icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final (background, border, foreground) = switch (tone) {
      BadgeTone.neutral => (
        colors.surfaceSunken,
        colors.borderDefault,
        colors.textSecondary,
      ),
      BadgeTone.accent => (
        colors.accentSubtle,
        colors.infoBorder,
        colors.textAccent,
      ),
      BadgeTone.success => (
        colors.successBg,
        colors.successBorder,
        colors.success,
      ),
      BadgeTone.warning => (
        colors.warningBg,
        colors.warningBorder,
        colors.warning,
      ),
      BadgeTone.danger => (colors.dangerBg, colors.dangerBorder, colors.danger),
      // fm-additions.css: `[data-theme="dark"] .fm-badge--edited` uses
      // --ink-300.
      BadgeTone.edited => (
        colors.accentSubtle,
        const Color(0x00000000),
        theme.isDark ? theme.ramps.ink300 : colors.textAccent,
      ),
    };
    final box = Container(
      height: height,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space1_5,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: theme.border.borderWidth),
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusXs)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space1,
        children: [
          if (dot)
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: foreground,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusFull),
                ),
              ),
            ),
          if (icon != null)
            Icon(
              icon!,
              size: iconSize,
              strokeWidth: iconStrokeWidth,
              color: foreground,
            ),
          Text(
            label,
            softWrap: false,
            maxLines: 1,
            style: theme.typography.label.copyWith(
              color: foreground,
              fontFeatures: [
                ...theme.typeScale.featuresUi,
                ...theme.typeScale.numericTabular,
              ],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: box),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(
        EnumProperty<BadgeTone>('tone', tone, defaultValue: BadgeTone.neutral),
      )
      ..add(FlagProperty('dot', value: dot, ifTrue: 'dot'))
      ..add(EnumProperty<IconName>('icon', icon, defaultValue: null));
  }
}
