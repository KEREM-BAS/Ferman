import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/phone/fm_phone.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The frame of a first-run welcome step (a1-2b, a1-2c): the step counter,
/// the headline and the text at the start, [aside] at the end, and the
/// footer with Skip, the step dots, Back and Next.
///
/// The two columns are at most [startWidth] and [asideWidth] wide with
/// [columnGap] between them, centred (`grid-template-columns:
/// minmax(0,440px) minmax(0,520px); gap: 80px; padding: 0 80px`); they
/// shrink together in a narrower window, and the page scrolls when the
/// window is too low. Numbers in the counter follow the region (G34).
///
/// At phone width everything is one column in a13-1's language (G129): Back
/// and Skip on top, the text and then [aside], which scroll, and the dots and
/// the main button pinned below.
class WelcomeStep extends ConsumerWidget {
  /// Step [step] of [count] (counted from 1).
  const new({
    required this.step,
    required this.count,
    required this.title,
    required this.paragraphs,
    required this.aside,
    required this.nextLabel,
    required this.onNext,
    super.key,
    this.asideWidth = 520,
    this.note,
    this.onBack,
    this.onSkip,
  });

  /// This step's number, from 1.
  final int step;

  /// How many welcome steps there are.
  final int count;

  /// The headline.
  final String title;

  /// The paragraphs under the headline.
  final List<String> paragraphs;

  /// A smaller line under the paragraphs (a1-2c: the licence and links).
  final Widget? note;

  /// The content of the end column.
  final Widget aside;

  /// The end column's largest width (a1-2b 520 px, a1-2c 540 px).
  final double asideWidth;

  /// The label of the main button ("Next", "Start using Ferman").
  final String nextLabel;

  /// Called by the main button.
  final VoidCallback onNext;

  /// Called by Back; null hides it.
  final VoidCallback? onBack;

  /// Called by Skip; null leaves its place empty (the last step drops
  /// Skip, a1-2c note).
  final VoidCallback? onSkip;

  /// The start column's largest width.
  static const double startWidth = 440;

  /// The gap between the columns.
  static const double columnGap = 80;

  /// The side padding of the columns.
  static const double paddingX = 80;

  /// The footer's height (`height: 72px`).
  static const double footerHeight = 72;

  /// The footer's side padding (`padding-inline: 32px`).
  static const double footerPaddingX = 32;

  /// The space Skip leaves on the last step (`width: 60px`).
  static const double skipPlaceholderWidth = 60;

  /// The size of the paragraphs (`font: 400 17px/1.6`).
  static const double proseSize = 17;

  /// The line height of the paragraphs and the note.
  static const double proseHeight = 1.6;

  /// The size of the note (`font: 400 15px/1.6`).
  static const double noteSize = 15;

  /// The gap in the start column (`gap: 18px`).
  static const double startGap = 18;

  /// Skip's size on a phone (a13-1 `font: 400 17px/1`).
  static const double phoneSkipSize = 17;

  /// The side padding on a phone (a13-1 `padding: 12px 24px`).
  static const double phonePaddingX = 24;

  /// The headline's size on a phone (`font: 700 30px/36px`, in semibold: no
  /// bold Plex is bundled).
  static const double phoneTitleSize = 30;

  /// The headline's line height on a phone.
  static const double phoneTitleHeight = 36 / 30;

  /// The paragraphs' line height on a phone (`font: 400 17px/24px`).
  static const double phoneProseHeight = 24 / 17;

  /// The gap between the text and the aside on a phone (`gap: 28px`).
  static const double phoneAsideGap = 28;

  /// The style of the paragraphs.
  static TextStyle proseStyle(BuildContext context) {
    final theme = context.ferman;
    return theme.typography.prose.copyWith(
      fontSize: proseSize,
      height: proseHeight,
      color: theme.colors.textSecondary,
    );
  }

  /// The style of the note.
  static TextStyle noteStyle(BuildContext context) {
    final theme = context.ferman;
    return theme.typography.prose.copyWith(
      fontSize: noteSize,
      height: proseHeight,
      color: theme.colors.textTertiary,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final scale = theme.typeScale;
    final l10n = AppLocalizations.of(context);
    final format = ref.watch(regionProvider).format;
    final stepText = format.integer(step);
    final countText = format.integer(count);

    if (WindowMetrics.isPhone(context)) {
      return _phoneLayout(
        context,
        _StepDots(
          step: step,
          count: count,
          label: l10n.onboardingStepLabel(stepText, countText),
        ),
      );
    }

    final start = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: startGap,
      children: [
        Text(
          l10n.onboardingStep(stepText, countText),
          style: typography.label.copyWith(
            color: colors.textTertiary,
            letterSpacing: scale.trackingLabel * scale.sizeXs,
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            title,
            style: typography.headline.copyWith(
              fontSize: scale.size4xl,
              height: scale.height4xl,
              letterSpacing: scale.trackingTight * scale.size4xl,
            ),
          ),
        ),
        for (final paragraph in paragraphs)
          Text(paragraph, style: proseStyle(context)),
        ?note,
      ],
    );

    final body = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: paddingX,
              vertical: theme.space.space8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: columnGap,
              children: [
                Flexible(
                  flex: startWidth.round(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: startWidth),
                    child: start,
                  ),
                ),
                Flexible(
                  flex: asideWidth.round(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: asideWidth),
                    child: aside,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final footer = Container(
      height: footerHeight,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: footerPaddingX,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: Row(
        spacing: theme.space.space3,
        children: [
          if (onSkip case final skip?)
            Button(
              variant: ButtonVariant.ghost,
              onPressed: skip,
              child: Text(l10n.onboardingSkip),
            )
          else
            const SizedBox(width: skipPlaceholderWidth),
          Expanded(
            child: Center(
              child: _StepDots(
                step: step,
                count: count,
                label: l10n.onboardingStepLabel(stepText, countText),
              ),
            ),
          ),
          if (onBack case final back?)
            Button(
              size: ButtonSize.lg,
              onPressed: back,
              child: Text(l10n.onboardingBack),
            ),
          Button(
            variant: ButtonVariant.primary,
            size: ButtonSize.lg,
            iconEnd: step < count ? IconName.arrowRight : null,
            onPressed: onNext,
            child: Text(nextLabel),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        footer,
      ],
    );
  }

  Widget _phoneLayout(BuildContext context, Widget dots) {
    final theme = context.ferman;
    final space = theme.space;
    final scale = theme.typeScale;
    final l10n = AppLocalizations.of(context);
    return FmPhone(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              phonePaddingX,
              space.space3,
              phonePaddingX,
              space.space1,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (onBack case final back?)
                  Button(
                    variant: ButtonVariant.ghost,
                    onPressed: back,
                    child: Text(l10n.onboardingBack),
                  )
                else
                  const SizedBox.shrink(),
                if (onSkip case final skip?)
                  FermanInteractive(
                    onPressed: skip,
                    semanticLabel: l10n.onboardingSkip,
                    builder: (context, states, _) => FocusRing(
                      visible: states.contains(WidgetState.focused),
                      child: Container(
                        constraints: BoxConstraints(
                          minWidth: theme.density.hitMin,
                          minHeight: theme.density.hitMin,
                        ),
                        alignment: AlignmentDirectional.centerEnd,
                        child: ExcludeSemantics(
                          child: Text(
                            l10n.onboardingSkip,
                            style: theme.typography.body.copyWith(
                              fontSize: phoneSkipSize,
                              color: theme.colors.textAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: phonePaddingX,
                vertical: space.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: phoneAsideGap,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: space.space3,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.typography.headline.copyWith(
                            fontSize: phoneTitleSize,
                            height: phoneTitleHeight,
                            fontWeight: scale.weightSemibold,
                            letterSpacing: scale.trackingTight * phoneTitleSize,
                          ),
                        ),
                      ),
                      for (final paragraph in paragraphs)
                        Text(
                          paragraph,
                          style: proseStyle(context)
                              .copyWith(height: phoneProseHeight),
                        ),
                      ?note,
                    ],
                  ),
                  aside,
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: phonePaddingX,
              vertical: space.space4,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colors.borderSubtle,
                  width: theme.border.borderWidth,
                ),
              ),
            ),
            child: Column(
              spacing: startGap,
              children: [
                dots,
                Button(
                  variant: ButtonVariant.primary,
                  size: ButtonSize.lg,
                  fullWidth: true,
                  onPressed: onNext,
                  child: Text(nextLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The step dots in the footer: the current step a 20 × 6 pill in the
/// accent colour, the others 6 px dots in the strong border colour, 8 px
/// apart. Screen readers hear "Step 1 of 2" (a1-2a note).
class _StepDots extends StatelessWidget {
  const new({required this.step, required this.count, required this.label});

  final int step;
  final int count;
  final String label;

  /// A dot's height and an inactive dot's width.
  static const double dotSize = 6;

  /// The current step's width.
  static const double currentWidth = 20;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    // A node of its own, as the board's `aria-label` element.
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.space.space2,
          children: [
            for (var i = 1; i <= count; i++)
              Container(
                width: i == step ? currentWidth : dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: i == step
                      ? theme.colors.accent
                      : theme.colors.borderStrong,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(dotSize / 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
