import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The height of a form control (`.fm-input`, `.fm-input--sm`): medium
/// takes `--control-h-md`, small `--control-h-sm`.
enum FieldSize {
  /// `--control-h-sm` (26 px on desktop), 6 px side padding, 12 px text
  /// and 14 px icons: panel inputs and dense settings rows.
  sm,

  /// `--control-h-md` (30 px on desktop), 8 px side padding, 13 px text
  /// and 16 px icons: the default.
  md,
}

/// The label, the input box and the hint or error line every Ferman field
/// shares, the internal `Field` of the component spec
/// (`components/forms/forms.css`, `.fm-field` and `.fm-input`).
///
/// It stacks, 4 px apart:
///
/// - [label] in 12 px medium secondary text (`.fm-field__label`);
/// - the input box ([FieldBox]) around [child], [size] tall, with the
///   design's hover, focus, error, warning and disabled looks;
/// - [error] with a `circle-alert` glyph in the danger colour
///   (`.fm-field__error`), or else [hint] in tertiary caption text
///   (`.fm-field__hint`).
///
/// The box shows focus whenever focus is inside it (`:focus-within`, so a
/// click focuses it too): the focus border and a 1 px ring (G22, the
/// design's "fields show focus on the box"). [focused] and [hovered]
/// override the states the box tracks itself; a `FermanForcedStates`
/// above it forces them for goldens.
///
/// The texts are visual only: the control inside announces the label and
/// the hint or error itself (its semantics label and hint), so screen
/// readers hear them once, on the control.
///
/// A field fills the width it is given; give it a width (a `SizedBox`, an
/// `Expanded`) where the width is unbounded.
class Field extends StatelessWidget {
  /// Frames [child] with a label, a box and a hint or error line.
  const new({
    required this.child,
    super.key,
    this.label,
    this.hint,
    this.error,
    this.warning = false,
    this.size = FieldSize.md,
    this.disabled = false,
    this.focused,
    this.hovered,
    this.focusRingStyle = FocusRingStyle.field,
    this.padding,
    this.clip = false,
  });

  /// `.fm-field` `gap` between the label, the box and the message.
  static const double gap = 4;

  /// The label above the box; null shows none.
  final String? label;

  /// The hint below the box; null shows none. [error] replaces it.
  final String? hint;

  /// The error below the box, which also turns the border the danger
  /// colour (`.fm-input--error`); null for none.
  final String? error;

  /// Whether the border takes the warning colour (`.fm-input--warning`,
  /// the FontPicker's missing font).
  final bool warning;

  /// The height, padding and text size of the box.
  final FieldSize size;

  /// Whether the box takes the disabled look (`.fm-input--disabled`).
  final bool disabled;

  /// The control inside the box.
  final Widget child;

  /// Whether the box shows focus; null tracks focus inside it.
  final bool? focused;

  /// Whether the box shows the hover border; null tracks the pointer.
  final bool? hovered;

  /// The ring the box shows with focus: the field ring of `.fm-input`, or
  /// the outer `--focus-ring` of the picker triggers
  /// (`.fm-colortrigger:focus-visible`, `.fm-fonttrigger:focus-visible`).
  final FocusRingStyle focusRingStyle;

  /// The padding inside the box; null takes the size's side padding.
  final EdgeInsetsGeometry? padding;

  /// Whether the box clips its content to its rounded shape
  /// (`.fm-stepper` `overflow: hidden`).
  final bool clip;

  /// The label line of a field (`.fm-field__label`), for controls that
  /// build their own box. Visual only.
  static Widget labelOf(BuildContext context, String label) {
    final theme = context.ferman;
    return ExcludeSemantics(
      child: Text(
        label,
        style: theme.typography.caption.copyWith(
          fontWeight: theme.typeScale.weightMedium,
          color: theme.colors.textSecondary,
        ),
      ),
    );
  }

  /// The error line (`.fm-field__error`) when [error] is set, else the hint
  /// line (`.fm-field__hint`) when [hint] is set, else null. Visual only.
  static Widget? messageOf(
    BuildContext context, {
    String? hint,
    String? error,
  }) {
    final theme = context.ferman;
    final caption = theme.typography.caption;
    if (error != null) {
      return ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: gap,
          children: [
            Padding(
              // `.fm-field__error svg { margin-top: 1px }`.
              padding: const EdgeInsetsDirectional.only(top: 1),
              child: Icon(
                IconName.circleAlert,
                size: theme.density.iconSm,
                color: theme.colors.danger,
              ),
            ),
            Flexible(
              child: Text(
                error,
                style: caption.copyWith(color: theme.colors.danger),
              ),
            ),
          ],
        ),
      );
    }
    if (hint != null) {
      return ExcludeSemantics(
        child: Text(
          hint,
          style: caption.copyWith(color: theme.colors.textTertiary),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final message = messageOf(context, hint: hint, error: error);
    final text = label;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        if (text != null) labelOf(context, text),
        FieldBox(
          size: size,
          error: error != null,
          warning: warning,
          disabled: disabled,
          focused: focused,
          hovered: hovered,
          focusRingStyle: focusRingStyle,
          padding: padding,
          clip: clip,
          child: child,
        ),
        ?message,
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(StringProperty('hint', hint, defaultValue: null))
      ..add(StringProperty('error', error, defaultValue: null))
      ..add(FlagProperty('warning', value: warning, ifTrue: 'warning'))
      ..add(EnumProperty<FieldSize>('size', size, defaultValue: FieldSize.md))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'));
  }
}

/// The input box of a field (`.fm-input`): a raised, 1 px bordered, 4 px
/// rounded row [size] tall, which [Field] and the picker triggers share.
///
/// Its border is, in order of precedence: the focus colour with a 1 px
/// ring ([focused]; the danger colour and ring with [error]), the subtle
/// disabled border ([disabled]), the danger colour ([error]), the warning
/// colour ([warning]), the strong border ([hovered], never while
/// disabled), else the default border.
/// The border changes over `--dur-instant` and the ring over `--dur-fast`.
///
/// The box's text style is the body role (12 px at [FieldSize.sm]) with
/// tabular figures (`.fm-input__control`), in the primary text colour or
/// the disabled one.
class FieldBox extends StatefulWidget {
  /// Draws the box around [child].
  const new({
    required this.child,
    super.key,
    this.size = FieldSize.md,
    this.error = false,
    this.warning = false,
    this.disabled = false,
    this.focused,
    this.hovered,
    this.focusRingStyle = FocusRingStyle.field,
    this.padding,
    this.clip = false,
  });

  /// The key of the decorated box, for tests and goldens.
  static const Key boxKey = ValueKey<String>('FieldBox.box');

  /// `.fm-input` `gap` between the box's parts (icon, control, suffix).
  static const double contentGap = 6;

  /// The content of the box.
  final Widget child;

  /// The height, padding and text size.
  final FieldSize size;

  /// Whether the box shows the error border.
  final bool error;

  /// Whether the box shows the warning border.
  final bool warning;

  /// Whether the box shows the disabled look.
  final bool disabled;

  /// Whether the box shows focus; null tracks focus inside it.
  final bool? focused;

  /// Whether the box shows the hover border; null tracks the pointer.
  final bool? hovered;

  /// The ring shown with focus.
  final FocusRingStyle focusRingStyle;

  /// The padding inside the box; null takes the size's side padding.
  final EdgeInsetsGeometry? padding;

  /// Whether the content is clipped to the rounded box.
  final bool clip;

  /// The height of a box of [size] in [theme].
  static double heightOf(FermanTheme theme, FieldSize size) => switch (size) {
    FieldSize.sm => theme.density.controlHSm,
    FieldSize.md => theme.density.controlHMd,
  };

  /// The side padding of a box of [size] (`.fm-input` 8 px,
  /// `.fm-input--sm` 6 px).
  static double sidePaddingOf(FermanTheme theme, FieldSize size) =>
      switch (size) {
        FieldSize.sm => theme.space.space1_5,
        FieldSize.md => theme.space.space2,
      };

  /// The size of an icon in a box of [size] (14 px small, 16 px medium).
  static double iconSizeOf(FermanTheme theme, FieldSize size) => switch (size) {
    FieldSize.sm => theme.density.iconSm,
    FieldSize.md => theme.density.iconMd,
  };

  /// The text style of the control in a box of [size]
  /// (`.fm-input__control`, `.fm-input--sm .fm-input__control`): the body
  /// role with tabular figures, 12 px at [FieldSize.sm], in [color].
  static TextStyle textStyleOf(
    FermanTheme theme,
    FieldSize size, {
    required Color color,
  }) {
    final body = theme.typography.body;
    return body.copyWith(
      fontSize: size == FieldSize.sm ? theme.typeScale.sizeSm : null,
      color: color,
      fontFeatures: [
        ...theme.typeScale.featuresUi,
        ...theme.typeScale.numericTabular,
      ],
    );
  }

  @override
  State<FieldBox> createState() => _FieldBoxState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<FieldSize>('size', size, defaultValue: FieldSize.md))
      ..add(FlagProperty('error', value: error, ifTrue: 'error'))
      ..add(FlagProperty('warning', value: warning, ifTrue: 'warning'))
      ..add(FlagProperty('disabled', value: disabled, ifTrue: 'disabled'))
      ..add(
        FlagProperty(
          'focused',
          value: focused,
          ifTrue: 'focused',
          ifFalse: 'unfocused',
        ),
      )
      ..add(
        EnumProperty<FocusRingStyle>(
          'focusRingStyle',
          focusRingStyle,
          defaultValue: FocusRingStyle.field,
        ),
      );
  }
}

class _FieldBoxState extends State<FieldBox> {
  bool _hovered = false;
  bool _focusWithin = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final forced = FermanForcedStates.of(context);
    final disabled = widget.disabled;
    // Focus shows even on a field that is disabled with a reason, which
    // stays focusable (G10); a plain disabled field never takes focus.
    final focused =
        widget.focused ??
        (_focusWithin || forced.contains(WidgetState.focused));
    final hovered =
        !disabled &&
        (widget.hovered ?? (_hovered || forced.contains(WidgetState.hovered)));
    final Color border;
    if (focused) {
      border = widget.error ? colors.danger : colors.borderFocus;
    } else if (disabled) {
      border = colors.borderSubtle;
    } else if (widget.error) {
      border = colors.danger;
    } else if (widget.warning) {
      border = colors.warningSolid;
    } else if (hovered) {
      border = colors.borderStrong;
    } else {
      border = colors.borderDefault;
    }
    final List<BoxShadow> ring;
    if (!focused) {
      ring = const [];
    } else if (widget.error) {
      ring = [BoxShadow(color: colors.danger, spreadRadius: 1)];
    } else if (widget.focusRingStyle == FocusRingStyle.outer) {
      ring = FocusRing.outerShadows(theme);
    } else {
      ring = FocusRing.fieldShadows(theme);
    }
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
    final side = FieldBox.sidePaddingOf(theme, widget.size);
    final textColor = disabled ? colors.textDisabled : colors.textPrimary;
    Widget box = AnimatedContainer(
      key: FieldBox.boxKey,
      duration: theme.motion.durInstant,
      curve: theme.motion.easeOut,
      height: FieldBox.heightOf(theme, widget.size),
      padding:
          widget.padding ?? EdgeInsetsDirectional.symmetric(horizontal: side),
      clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: disabled ? colors.surfaceSunken : colors.surfaceRaised,
        borderRadius: radius,
        border: Border.all(color: border, width: theme.border.borderWidth),
      ),
      child: DefaultTextStyle.merge(
        style: FieldBox.textStyleOf(theme, widget.size, color: textColor),
        child: widget.child,
      ),
    );
    box = AnimatedContainer(
      duration: theme.motion.durFast,
      curve: theme.motion.easeOut,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: ring),
      child: box,
    );
    if (widget.focused == null) {
      box = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (value) => setState(() => _focusWithin = value),
        child: box,
      );
    }
    if (widget.hovered == null) {
      box = MouseRegion(
        opaque: false,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: box,
      );
    }
    return box;
  }
}
