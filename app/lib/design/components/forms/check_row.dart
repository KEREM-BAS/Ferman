import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The row a checkbox or radio sits in (`components/forms/forms.css`,
/// `.fm-check`): the 16 px [box] 1 px below the top, 8 px before the text,
/// then [label] in body text and [description] under it in tertiary
/// caption text, 2 px apart (`.fm-check__text`, `.fm-check__desc`).
///
/// The label turns the disabled text colour when [disabled]
/// (`.fm-check--disabled`); the description keeps its tertiary colour, as
/// `.fm-check__desc` sets it. The label is part of the control's
/// semantics label; the description is left out of it, for the control to
/// announce as its hint.
class CheckRow extends StatelessWidget {
  /// Lays out [box] with its texts.
  const new({
    required this.box,
    super.key,
    this.label,
    this.description,
    this.disabled = false,
  });

  /// `.fm-check__box` `width` and `height`.
  static const double boxSize = 16;

  /// `.fm-check__box` `margin-top`.
  static const double boxTopMargin = 1;

  /// `.fm-check__text` `gap`.
  static const double textGap = 2;

  /// The checkbox or radio.
  final Widget box;

  /// The label; null shows none.
  final String? label;

  /// The description under the label; null shows none.
  final String? description;

  /// Whether the label takes the disabled colour.
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final text = label;
    final desc = description;
    final boxed = Padding(
      padding: const EdgeInsetsDirectional.only(top: boxTopMargin),
      child: SizedBox.square(dimension: boxSize, child: box),
    );
    if (text == null && desc == null) return boxed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2,
      children: [
        boxed,
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: textGap,
            children: [
              if (text != null)
                Text(
                  text,
                  style: theme.typography.body.copyWith(
                    color: disabled ? colors.textDisabled : colors.textPrimary,
                  ),
                ),
              if (desc != null)
                ExcludeSemantics(
                  child: Text(
                    desc,
                    style: theme.typography.caption.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(StringProperty('description', description, defaultValue: null))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'));
  }
}

/// The border colour of an unchecked checkbox or radio under the pointer
/// (`.fm-check:hover .fm-check__input`): `--paper-500`, or `--soot-500` in
/// the dark theme. The design has no semantic token for it.
Color checkHoverBorder(FermanTheme theme) =>
    theme.isDark ? theme.ramps.soot500 : theme.ramps.paper500;
