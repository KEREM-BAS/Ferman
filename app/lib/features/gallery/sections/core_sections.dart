import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The foundation, not a spec entry: the three focus rings (G22).
Widget focusRingSection(BuildContext context) {
  final theme = context.ferman;
  Widget box(String label, FocusRingStyle style, {required bool visible}) =>
      FocusRing(
        visible: visible,
        style: style,
        borderRadius: BorderRadius.circular(theme.radius.radiusSm),
        child: Container(
          width: theme.size.thumbW,
          height: theme.density.controlHMd,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            border: Border.all(
              color: theme.colors.borderDefault,
              width: theme.border.borderWidth,
            ),
            borderRadius: BorderRadius.circular(theme.radius.radiusSm),
          ),
          child: Text(label),
        ),
      );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.named(GalleryLabels.state, GalleryLabels.visible),
        children: [
          for (final style in FocusRingStyle.values)
            GallerySpecimen(
              label: style.name,
              child: box(style.name, style, visible: true),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.named(GalleryLabels.state, GalleryLabels.hidden),
        children: [
          GallerySpecimen(
            label: GalleryLabels.hidden,
            child: box(
              FocusRingStyle.outer.name,
              FocusRingStyle.outer,
              visible: false,
            ),
          ),
        ],
      ),
    ],
  );
}

/// `Icon`: the density's icon sizes and the directional icons.
Widget iconSection(BuildContext context) {
  final theme = context.ferman;
  const samples = [
    IconName.save,
    IconName.rotateCw,
    IconName.highlighter,
    IconName.signature,
    IconName.shield,
  ];
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final (name, size) in [
            (SpecName.iconSm.name, theme.density.iconSm),
            (SpecName.iconMd.name, theme.density.iconMd),
            (SpecName.iconLg.name, theme.density.iconLg),
          ])
            GallerySpecimen(
              label: name,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space2,
                children: [for (final icon in samples) Icon(icon, size: size)],
              ),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.both(
          GalleryLabels.standard,
          SpecName.rtlMirrored.name,
        ),
        children: [
          for (final icon in IconName.values.where((icon) => icon.directional))
            GallerySpecimen(label: icon.id, child: Icon(icon)),
        ],
      ),
      GalleryRow(
        label: SpecName.flipRtl.name,
        children: [
          GallerySpecimen(
            label: GalleryLabels.both(
              IconName.arrowRight.id,
              GalleryLabels.named(SpecName.flipRtl.name, false.toString()),
            ),
            child: const Icon(IconName.arrowRight, flipRtl: false),
          ),
          GallerySpecimen(
            label: GalleryLabels.both(
              IconName.rotateCw.id,
              GalleryLabels.named(SpecName.flipRtl.name, true.toString()),
            ),
            child: const Icon(IconName.rotateCw, flipRtl: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.named(
              SpecName.color.name,
              SpecName.accent.name,
            ),
            child: Icon(IconName.badgeCheck, color: theme.colors.accent),
          ),
        ],
      ),
      const GalleryNote(GalleryLabels.rtlNote),
    ],
  );
}

/// `ICON_PATHS`, the generated `IconName` enum: every glyph with its id.
Widget iconPathsSection(BuildContext context) {
  final theme = context.ferman;
  return Wrap(
    spacing: theme.space.space1,
    runSpacing: theme.space.space3,
    children: [
      for (final icon in IconName.values)
        SizedBox(
          width: theme.size.thumbW,
          child: Column(
            spacing: theme.space.space1,
            children: [
              Icon(icon, size: theme.density.iconLg),
              Text(
                icon.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// The interaction states of a control, as the state sheet's columns.
List<Widget> _interactionStates(Widget Function() build) => [
  GallerySpecimen(label: GalleryLabels.standard, child: build()),
  GallerySpecimen(
    label: GalleryLabels.hover,
    forced: GalleryForced.hover,
    child: build(),
  ),
  GallerySpecimen(
    label: GalleryLabels.pressed,
    forced: GalleryForced.pressed,
    child: build(),
  ),
  GallerySpecimen(
    label: GalleryLabels.focusVisible,
    forced: GalleryForced.focusVisible,
    child: build(),
  ),
];

/// `Button`: every variant in every state, and the sizes.
Widget buttonSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final future = futureVersionReason(context);
  final theme = context.ferman;
  (String, IconName?) copy(ButtonVariant variant) => switch (variant) {
    ButtonVariant.primary => (l10n.shellSave, IconName.save),
    ButtonVariant.secondary => (GallerySamples.cancel, null),
    ButtonVariant.ghost => (GallerySamples.clear, IconName.eraser),
    ButtonVariant.danger => (GallerySamples.apply, null),
  };
  Widget button(
    ButtonVariant variant, {
    ButtonSize size = ButtonSize.md,
    bool disabled = false,
    String? disabledReason,
    bool loading = false,
  }) {
    final (label, icon) = copy(variant);
    return Button(
      variant: variant,
      size: size,
      icon: icon,
      disabled: disabled,
      disabledReason: disabledReason,
      loading: loading,
      onPressed: () {},
      child: Text(label),
    );
  }

  return GalleryBody(
    children: [
      for (final variant in ButtonVariant.values)
        GalleryRow(
          label: GalleryLabels.named(GalleryLabels.variant, variant.name),
          children: [
            ..._interactionStates(() => button(variant)),
            GallerySpecimen(
              label: GalleryLabels.disabled,
              child: button(variant, disabled: true),
            ),
            GallerySpecimen(
              label: GalleryLabels.disabledWithReason,
              child: button(variant, disabled: true, disabledReason: future),
            ),
            GallerySpecimen(
              label: GalleryLabels.loading,
              child: button(variant, loading: true),
            ),
          ],
        ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in ButtonSize.values)
            GallerySpecimen(
              label: size.name,
              child: button(ButtonVariant.primary, size: size),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.props,
        children: [
          GallerySpecimen(
            label: SpecName.iconEnd.name,
            child: Button(
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              iconEnd: IconName.chevronDown,
              onPressed: () {},
              child: const Text(GallerySamples.moreDocuments),
            ),
          ),
          GallerySpecimen(
            label: SpecName.fullWidth.name,
            width: theme.size.panelW,
            child: Button(
              variant: ButtonVariant.danger,
              icon: IconName.eyeOff,
              fullWidth: true,
              onPressed: () {},
              child: const Text(GallerySamples.applyRedactions),
            ),
          ),
        ],
      ),
      const GalleryNote(GalleryLabels.forcedNote),
    ],
  );
}

/// `IconButton`: every variant in every state, and the sizes.
Widget iconButtonSection(BuildContext context) {
  final env = GalleryEnvironment.of(context);
  final future = futureVersionReason(context);
  Widget button(
    IconButtonVariant variant, {
    IconButtonSize size = IconButtonSize.md,
    bool? active,
    bool disabled = false,
    String? disabledReason,
    bool loading = false,
  }) => IconButton(
    icon: active ?? false ? IconName.bold : IconName.rotateCw,
    label: active ?? false ? GallerySamples.bold : GallerySamples.rotatePage,
    variant: variant,
    size: size,
    active: active,
    shortcut: env.caps(ShellCommand.rotateRight),
    disabled: disabled,
    disabledReason: disabledReason,
    loading: loading,
    onPressed: () {},
  );
  return GalleryBody(
    children: [
      for (final variant in IconButtonVariant.values)
        GalleryRow(
          label: GalleryLabels.named(GalleryLabels.variant, variant.name),
          children: [
            ..._interactionStates(() => button(variant)),
            GallerySpecimen(
              label: GalleryLabels.toggledOn,
              child: button(variant, active: true),
            ),
            GallerySpecimen(
              label: GalleryLabels.disabled,
              child: button(variant, disabled: true),
            ),
            GallerySpecimen(
              label: GalleryLabels.disabledWithReason,
              child: button(variant, disabled: true, disabledReason: future),
            ),
            GallerySpecimen(
              label: GalleryLabels.loading,
              child: button(variant, loading: true),
            ),
          ],
        ),
      GalleryRow(
        label: GalleryLabels.size,
        children: [
          for (final size in IconButtonSize.values)
            GallerySpecimen(
              label: size.name,
              child: button(IconButtonVariant.secondary, size: size),
            ),
        ],
      ),
    ],
  );
}

/// `Tooltip`: hidden and visible on each side, each in a stage of its own.
Widget tooltipSection(BuildContext context) {
  final theme = context.ferman;
  final env = GalleryEnvironment.of(context);
  Widget stage(TooltipSide side, {required bool open}) => GalleryStage(
    width: theme.size.dialogWSm,
    height: theme.space.space16 * 2,
    alignment: AlignmentDirectional.center,
    child: Tooltip(
      message: GallerySamples.rotatePage,
      shortcut: env.caps(ShellCommand.rotateRight),
      side: side,
      open: open,
      child: IconButton(
        icon: IconName.rotateCw,
        label: GallerySamples.rotatePage,
        showTooltip: false,
        onPressed: () {},
      ),
    ),
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.named(GalleryLabels.state, GalleryLabels.visible),
        children: [
          for (final side in TooltipSide.values)
            GallerySpecimen(
              label: GalleryLabels.named(SpecName.side.name, side.name),
              child: stage(side, open: true),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.named(GalleryLabels.state, GalleryLabels.hidden),
        children: [
          GallerySpecimen(
            label: GalleryLabels.hidden,
            child: stage(TooltipSide.bottom, open: false),
          ),
        ],
      ),
    ],
  );
}

/// `Kbd`: the three tones, the inverse one on the tooltip's surface.
Widget kbdSection(BuildContext context) {
  final theme = context.ferman;
  final env = GalleryEnvironment.of(context);
  final save = env.caps(ShellCommand.save) ?? const [];
  final replace = env.caps(ShellCommand.findAndReplace) ?? const [];
  return GalleryRow(
    label: GalleryLabels.tone,
    children: [
      for (final tone in KbdTone.values)
        GallerySpecimen(
          label: tone.name,
          child: tone == KbdTone.inverse
              ? GallerySurface(
                  color: theme.colors.surfaceInverse,
                  child: Kbd(save, tone: tone),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: theme.space.space3,
                  children: [
                    Kbd(save, tone: tone),
                    Kbd(replace, tone: tone),
                  ],
                ),
        ),
    ],
  );
}

/// `Badge`: every tone, plain, with a dot and with an icon.
Widget badgeSection(BuildContext context) {
  return GalleryBody(
    children: [
      for (final tone in BadgeTone.values)
        GalleryRow(
          label: GalleryLabels.named(GalleryLabels.tone, tone.name),
          children: [
            GallerySpecimen(
              label: GalleryLabels.standard,
              child: Badge(
                tone: tone,
                label: GallerySamples.badges[tone.name] ?? tone.name,
              ),
            ),
            GallerySpecimen(
              label: SpecName.dot.name,
              child: Badge(
                tone: tone,
                dot: true,
                label: GallerySamples.badges[tone.name] ?? tone.name,
              ),
            ),
            GallerySpecimen(
              label: SpecName.icon.name,
              child: Badge(
                tone: tone,
                icon: IconName.circleCheck,
                label: GallerySamples.badges[tone.name] ?? tone.name,
              ),
            ),
          ],
        ),
    ],
  );
}
