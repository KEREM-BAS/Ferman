import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// `AnnotationTools`: both variants, the active tool and colour, the
/// disabled colours and tools.
Widget annotationToolsSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final future = futureVersionReason(context);
  Widget tools({
    AnnotationTool tool = AnnotationTool.highlight,
    AnnotationColor color = AnnotationColor.yellow,
    ToolbarVariant variant = ToolbarVariant.bar,
    bool showLabels = false,
    Map<AnnotationTool, String> disabledReasons = const {},
    String? colorsDisabledReason,
  }) => GalleryValue<(AnnotationTool, AnnotationColor)>(
    initial: (tool, color),
    builder: (context, value, set) => AnnotationTools(
      tool: value.$1,
      color: value.$2,
      onToolChanged: (tool) => set((tool, value.$2)),
      onColorChanged: (color) => set((value.$1, color)),
      variant: variant,
      showLabels: showLabels,
      disabledReasons: disabledReasons,
      colorsDisabledReason: colorsDisabledReason,
      semanticLabel: l10n.shellCommentTools,
      toolLabelOf: l10n.annotationToolLabel,
      colorsSemanticLabel: l10n.shellColor,
      colorLabelOf: l10n.annotationColorLabel,
    ),
  );
  final unshipped = {
    for (final tool in [
      AnnotationTool.callout,
      AnnotationTool.shapes,
      AnnotationTool.stamp,
      AnnotationTool.measure,
    ])
      tool: future,
  };
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.variant,
        children: [
          for (final variant in ToolbarVariant.values)
            GallerySpecimen(
              label: variant.name,
              child: GallerySideScroll(child: tools(variant: variant)),
            ),
          GallerySpecimen(
            label: SpecName.showLabels.name,
            child: GallerySideScroll(child: tools(showLabels: true)),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(
            label: GalleryLabels.both(
              SpecName.toolActive.name,
              SpecName.colorChecked.name,
            ),
            child: GallerySideScroll(
              child: tools(
                tool: AnnotationTool.pen,
                color: AnnotationColor.blue,
              ),
            ),
          ),
          GallerySpecimen(
            label: SpecName.colorsDisabled.name,
            child: GallerySideScroll(child: tools(tool: AnnotationTool.select)),
          ),
          GallerySpecimen(
            label: SpecName.toolDisabledWithReason.name,
            child: GallerySideScroll(child: tools(disabledReasons: unshipped)),
          ),
          GallerySpecimen(
            label: SpecName.colorsDisabledWithReason.name,
            child: GallerySideScroll(
              child: tools(colorsDisabledReason: future),
            ),
          ),
          GallerySpecimen(
            label: GalleryLabels.both(
              SpecName.colorHover.name,
              SpecName.colorFocusVisible.name,
            ),
            forced: const {
              ...GalleryForced.hover,
              ...GalleryForced.focusVisible,
            },
            child: GallerySideScroll(child: tools()),
          ),
        ],
      ),
    ],
  );
}

/// `Highlight`: every variant in every annotation colour, on the page.
Widget highlightSection(BuildContext context) => GalleryBody(
  children: [
    for (final variant in HighlightVariant.values)
      GalleryRow(
        label: GalleryLabels.named(GalleryLabels.variant, variant.name),
        children: [
          for (final color in AnnotationColor.values)
            GallerySpecimen(
              label: color.name,
              child: GalleryPage(
                child: Highlight(
                  variant: variant,
                  color: color,
                  child: const TextSpan(text: GallerySamples.runHighlight),
                ),
              ),
            ),
        ],
      ),
  ],
);

/// `StickyNote`: the pin in every colour, the card, and the forced states.
Widget stickyNoteSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  Widget note({
    bool collapsed = false,
    AnnotationColor color = AnnotationColor.yellow,
  }) => StickyNote(
    collapsed: collapsed,
    color: color,
    author: GallerySamples.mert,
    time: GallerySamples.noteTime,
    text: GallerySamples.noteText,
    replies: const [
      NoteReply(
        author: GallerySamples.ayse,
        time: GallerySamples.replyTime,
        text: GallerySamples.replyText,
      ),
    ],
    semanticLabel: GallerySamples.noteFrom(GallerySamples.mert),
    moreLabel: l10n.shellMore,
    closeLabel: GallerySamples.closeNote,
    replyPlaceholder: GallerySamples.reply,
    onToggle: () {},
    onReply: (_) {},
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.collapsed,
        children: [
          for (final color in AnnotationColor.values)
            GallerySpecimen(
              label: color.name,
              child: GalleryPage(child: note(collapsed: true, color: color)),
            ),
          GallerySpecimen(
            label: SpecName.pinFocusVisible.name,
            forced: GalleryForced.focusVisible,
            child: GalleryPage(child: note(collapsed: true)),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.expanded,
        children: [
          GallerySpecimen(label: GalleryLabels.expanded, child: note()),
          GallerySpecimen(
            label: SpecName.headButtonHover.name,
            forced: GalleryForced.hover,
            child: note(color: AnnotationColor.green),
          ),
        ],
      ),
    ],
  );
}

/// `Stamp`: every tone, the Turkish casing and a meta line, on the page.
Widget stampSection(BuildContext context) {
  final theme = context.ferman;
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.tone,
        children: [
          for (final tone in StampTone.values)
            GallerySpecimen(
              label: tone.name,
              child: GalleryPage(
                child: Stamp(
                  label: GallerySamples.stamps[tone.name] ?? tone.name,
                  tone: tone,
                ),
              ),
            ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.props,
        children: [
          GallerySpecimen(
            label: GalleryLabels.named(
              SpecName.locale.name,
              AppLanguage.turkish.tag,
            ),
            child: const GalleryPage(
              child: Stamp(
                label: GallerySamples.stampTurkish,
                locale: Locale('tr'),
              ),
            ),
          ),
          GallerySpecimen(
            label: SpecName.meta.name,
            child: const GalleryPage(
              child: Stamp(
                label: GallerySamples.stampApproved,
                meta: GallerySamples.stampMeta,
                locale: Locale('tr'),
                rotation: -6,
              ),
            ),
          ),
          GallerySpecimen(
            label: SpecName.fontSize.name,
            child: GalleryPage(
              child: Stamp(
                label: GallerySamples.stamps[StampTone.green.name] ?? '',
                tone: StampTone.green,
                rotation: 0,
                fontSize: theme.typeScale.sizeSm,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
