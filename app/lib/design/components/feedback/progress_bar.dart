import 'dart:ui' show SemanticsRole;

import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The fill colour of a [ProgressBar] (`.fm-progress--success`, …).
enum ProgressTone {
  /// The accent colour; the default.
  accent,

  /// The solid success colour: finished.
  success,

  /// The danger colour: failed.
  danger,

  /// The strong border colour: paused.
  paused,
}

/// The track height of a [ProgressBar].
enum ProgressSize {
  /// 4 px; the default.
  sm,

  /// 6 px (`.fm-progress--md`).
  md,
}

/// A progress track, the design-system `ProgressBar` component
/// (`components/feedback/feedback.css`, `.fm-progress`; `ProgressBar.jsx`).
/// Never the Material progress indicator (ADR 0011).
///
/// A rounded 4 px ([ProgressSize.sm]) or 6 px ([ProgressSize.md]) sunken
/// track with a fill in [tone]'s colour. Determinate: the fill covers
/// [value] (0 to 1) of the track from the start edge and eases to a new
/// value over `--dur-base`. [indeterminate]: a fill of 40 % sweeps from
/// before the start edge past the end edge every 1.4 s; under reduced
/// motion it stays still at the start (COMPONENTS.md, decision 12).
///
/// Above the track an optional head shows [label] and, with [showValue]
/// (determinate only), the percentage at the end. The percentage is
/// "N%" unless the screen passes [valueText] formatted for the region
/// setting (G34).
///
/// The bar takes the width of its parent, which must be bounded.
///
/// For screen readers it is a progress bar named [label] with the
/// percentage as its value, or a loading indicator while indeterminate.
class ProgressBar extends StatelessWidget {
  /// Creates a progress bar.
  const new({
    super.key,
    this.value,
    this.indeterminate = false,
    this.tone = ProgressTone.accent,
    this.size = ProgressSize.sm,
    this.label,
    this.showValue = false,
    this.valueText,
  });

  /// `.fm-progress__track` `height: 4px`.
  static const double trackHeight = 4;

  /// `.fm-progress--md .fm-progress__track` `height: 6px`.
  static const double trackHeightMd = 6;

  /// `.fm-progress--indeterminate .fm-progress__fill` `width: 40%`.
  static const double indeterminateFraction = 0.4;

  /// `.fm-progress--indeterminate .fm-progress__fill`
  /// `animation: fm-indeterminate 1.4s`.
  static const Duration indeterminatePeriod = Duration(milliseconds: 1400);

  /// How much is done, from 0 to 1; null and NaN count as 0 (an empty job
  /// whose done / total is 0 / 0 shows an empty bar).
  final double? value;

  /// Whether the amount is unknown.
  final bool indeterminate;

  /// The fill colour.
  final ProgressTone tone;

  /// The track height.
  final ProgressSize size;

  /// The text above the track and the accessible name; null shows none.
  final String? label;

  /// Whether the percentage shows above the track (determinate only).
  final bool showValue;

  /// The percentage as the screen formats it for the region setting
  /// ("%40" in Turkish); null shows "N%". Not a design-system prop.
  final String? valueText;

  /// [value] as a whole percentage from 0 to 100 (`ProgressBar.jsx`
  /// `Math.round(Math.max(0, Math.min(1, value || 0)) * 100)`); null and
  /// NaN count as 0, as `value || 0` does.
  int get percent {
    final v = value;
    if (v == null || v.isNaN) return 0;
    return (v.clamp(0.0, 1.0) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final fill = switch (tone) {
      ProgressTone.accent => colors.accent,
      ProgressTone.success => colors.successSolid,
      ProgressTone.danger => colors.danger,
      ProgressTone.paused => colors.borderStrong,
    };
    final full = BorderRadius.all(Radius.circular(theme.radius.radiusFull));
    final fillBox = DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: full),
    );
    final Widget bar;
    if (!indeterminate) {
      bar = AnimatedFractionallySizedBox(
        duration: theme.motion.durBase,
        curve: theme.motion.easeOut,
        alignment: AlignmentDirectional.centerStart,
        widthFactor: percent / 100,
        child: fillBox,
      );
    } else if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      bar = FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: indeterminateFraction,
        child: fillBox,
      );
    } else {
      bar = _IndeterminateSweep(child: fillBox);
    }
    final track = SizedBox(
      width: double.infinity,
      height: size == ProgressSize.md ? trackHeightMd : trackHeight,
      child: DecoratedBox(
        // `box-shadow: inset 0 0 0 1px var(--border-subtle)`, under the fill.
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          border: Border.all(
            color: colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
          borderRadius: full,
        ),
        child: ClipRRect(borderRadius: full, child: bar),
      ),
    );
    final shownValue = showValue && !indeterminate;
    final text = valueText ?? '$percent%';
    Widget result = track;
    if (label != null || shownValue) {
      final caption = theme.typography.caption;
      result = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space1_5,
        children: [
          Row(
            spacing: theme.space.space2,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            // `.fm-progress__head` stretches its items, so the percentage
            // stays on the first line of a label that wraps.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label ?? '',
                  style: caption.copyWith(color: colors.textSecondary),
                ),
              ),
              if (shownValue)
                Text(
                  text,
                  style: caption.copyWith(
                    color: colors.textTertiary,
                    fontFeatures: [
                      ...theme.typeScale.featuresUi,
                      ...theme.typeScale.numericTabular,
                    ],
                  ),
                ),
            ],
          ),
          track,
        ],
      );
    }
    return Semantics(
      container: true,
      label: label,
      role: indeterminate
          ? SemanticsRole.loadingSpinner
          : SemanticsRole.progressBar,
      value: indeterminate ? null : '$percent',
      minValue: indeterminate ? null : '0',
      maxValue: indeterminate ? null : '100',
      child: ExcludeSemantics(child: result),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('value', value, defaultValue: null))
      ..add(
        FlagProperty(
          'indeterminate',
          value: indeterminate,
          ifTrue: 'indeterminate',
        ),
      )
      ..add(
        EnumProperty<ProgressTone>(
          'tone',
          tone,
          defaultValue: ProgressTone.accent,
        ),
      )
      ..add(
        EnumProperty<ProgressSize>('size', size, defaultValue: ProgressSize.sm),
      )
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(FlagProperty('showValue', value: showValue, ifTrue: 'showValue'))
      ..add(StringProperty('valueText', valueText, defaultValue: null));
  }
}

/// The indeterminate fill: [ProgressBar.indeterminateFraction] of the
/// track, its start edge moving from −40 % to 100 % of the track
/// (`fm-indeterminate`, `--ease-in-out`), mirrored in right to left.
class _IndeterminateSweep extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_IndeterminateSweep> createState() => _IndeterminateSweepState();
}

class _IndeterminateSweepState extends State<_IndeterminateSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ProgressBar.indeterminatePeriod,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fraction = ProgressBar.indeterminateFraction;
    final curve = context.ferman.motion.easeInOut;
    final sign = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final start =
            -fraction + (1 + fraction) * curve.transform(_controller.value);
        return FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: fraction,
          child: FractionalTranslation(
            translation: Offset(sign * start / fraction, 0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
