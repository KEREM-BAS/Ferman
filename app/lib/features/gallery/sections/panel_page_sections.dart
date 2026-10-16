import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// `PanelSection`: expanded, collapsed, with actions, static and focused.
Widget panelSectionSection(BuildContext context) {
  final theme = context.ferman;
  Widget body() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: PanelSection.bodyGap,
    children: [
      for (final (label, value) in [
        (GallerySamples.pages, GallerySamples.pagesValue),
        (GallerySamples.size, GallerySamples.sizeValue),
      ])
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.typography.body.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
            ),
            Text(value),
          ],
        ),
    ],
  );
  Widget section({
    bool? open,
    bool collapsible = true,
    bool actions = false,
    bool topBorder = true,
  }) => DecoratedBox(
    decoration: BoxDecoration(color: theme.colors.surfacePanel),
    child: PanelSection(
      title: actions ? GallerySamples.sectionText : GallerySamples.sectionFile,
      open: open,
      collapsible: collapsible,
      showTopBorder: topBorder,
      actions: [
        if (actions)
          IconButton(
            icon: IconName.rotateCcw,
            label: GallerySamples.resetTextStyle,
            size: IconButtonSize.xs,
            onPressed: () {},
          ),
      ],
      child: body(),
    ),
  );
  final width = theme.size.panelW;
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(
        label: GalleryLabels.expanded,
        width: width,
        child: section(),
      ),
      GallerySpecimen(
        label: GalleryLabels.collapsed,
        width: width,
        child: section(open: false),
      ),
      GallerySpecimen(
        label: GalleryLabels.focusVisible,
        forced: GalleryForced.focusVisible,
        width: width,
        child: section(),
      ),
      GallerySpecimen(
        label: SpecName.actions.name,
        width: width,
        child: section(actions: true),
      ),
      GallerySpecimen(
        label: GalleryLabels.both(SpecName.collapsible.name, false.toString()),
        width: width,
        child: section(collapsible: false, topBorder: false),
      ),
    ],
  );
}

/// `PageThumbnail`: each state, the markers, badges and orientations.
Widget pageThumbnailSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  Widget thumb({
    bool selected = false,
    PageThumbnailState state = PageThumbnailState.idle,
    DropIndicator? drop,
    ThumbnailOrientation orientation = ThumbnailOrientation.vertical,
    int rotation = 0,
    ThumbnailMarker? marker,
    Widget? badges,
    String? label,
  }) => PageThumbnail(
    page: 2,
    label: label,
    selected: selected,
    state: state,
    dropIndicator: drop,
    orientation: orientation,
    rotation: rotation,
    marker: marker,
    markerTooltip: marker == null ? null : GallerySamples.editedSinceOpened,
    badges: badges,
    semanticLabel: GallerySamples.pageNumber(2),
    onPressed: () {},
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(label: GalleryLabels.standard, child: thumb()),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            child: thumb(),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: thumb(),
          ),
          GallerySpecimen(
            label: GalleryLabels.selected,
            child: thumb(selected: true),
          ),
          GallerySpecimen(
            label: PageThumbnailState.dragging.name,
            child: thumb(state: PageThumbnailState.dragging),
          ),
          GallerySpecimen(
            label: PageThumbnailState.placeholder.name,
            child: thumb(state: PageThumbnailState.placeholder),
          ),
          GallerySpecimen(
            label: SpecName.dropBefore.name,
            child: thumb(drop: DropIndicator.before),
          ),
          GallerySpecimen(
            label: SpecName.dropAfter.name,
            child: thumb(drop: DropIndicator.after),
          ),
          GallerySpecimen(
            label: SpecName.rotated.name,
            child: thumb(rotation: 90),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.props,
        children: [
          GallerySpecimen(
            label: SpecName.badges.name,
            child: thumb(
              selected: true,
              badges: const ThumbnailBadges(
                badges: {
                  ThumbnailBadge.edited,
                  ThumbnailBadge.comments,
                  ThumbnailBadge.warnings,
                },
                tooltips: {
                  ThumbnailBadge.comments: GallerySamples.badgeComments,
                  ThumbnailBadge.warnings: GallerySamples.badgeWarnings,
                },
              ),
            ),
          ),
          for (final marker in ThumbnailMarker.values)
            GallerySpecimen(
              label: GalleryLabels.named(SpecName.marker.name, marker.name),
              child: thumb(marker: marker),
            ),
          GallerySpecimen(
            label: SpecName.label.name,
            child: thumb(label: GallerySamples.romanLabel),
          ),
          GallerySpecimen(
            label: GalleryLabels.both(
              ThumbnailOrientation.horizontal.name,
              SpecName.dropAfter.name,
            ),
            child: thumb(
              orientation: ThumbnailOrientation.horizontal,
              drop: DropIndicator.after,
            ),
          ),
        ],
      ),
      GalleryNote(l10n.shellOrganizeHint),
    ],
  );
}
