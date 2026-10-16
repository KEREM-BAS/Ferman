import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// `PageMark`: every kind, on the page, with the lease's text.
Widget pageMarkSection(BuildContext context) {
  (String, String?) copy(PageMarkKind kind) => switch (kind) {
    PageMarkKind.selection => (GallerySamples.runSelection, null),
    PageMarkKind.edited => (GallerySamples.runEdited, GallerySamples.edited),
    PageMarkKind.missingGlyph => (
      GallerySamples.runMissingGlyph,
      GallerySamples.glyphWarning,
    ),
    PageMarkKind.search ||
    PageMarkKind.searchCurrent => (GallerySamples.runSearch, null),
    PageMarkKind.redactPending => (
      GallerySamples.runRedact,
      GallerySamples.markedForRedaction,
    ),
    PageMarkKind.redactApplied => (
      GallerySamples.runRedact,
      GallerySamples.redacted,
    ),
  };
  return GalleryRow(
    label: SpecName.kind.name,
    children: [
      for (final kind in PageMarkKind.values)
        GallerySpecimen(
          label: kind.name,
          child: GalleryPage(
            child: PageMark(
              kind: kind,
              tooltip: copy(kind).$2,
              char: kind == PageMarkKind.missingGlyph
                  ? GallerySamples.missingChar
                  : null,
              child: TextSpan(text: copy(kind).$1),
            ),
          ),
        ),
    ],
  );
}

/// `SearchReplaceBar`: find only, with replace, no results, the options
/// and the font notice.
Widget searchReplaceBarSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final format = RegionFormat.forRegion(GalleryEnvironment.of(context).region);
  final labels = SearchReplaceBarLabels(
    region: GallerySamples.findAndReplaceRegion,
    find: GallerySamples.find,
    replaceWith: GallerySamples.replaceWith,
    matchCase: GallerySamples.matchCase,
    wholeWord: GallerySamples.wholeWord,
    regex: GallerySamples.regex,
    showReplace: GallerySamples.showReplace,
    hideReplace: GallerySamples.hideReplace,
    previous: GallerySamples.previousMatch,
    next: GallerySamples.nextMatch,
    close: l10n.windowClose,
    replace: l10n.shellToolReplace,
    replaceAll: GallerySamples.replaceAll,
    noResults: GallerySamples.noResults,
    count: (current, total) =>
        GallerySamples.count(format.integer(current), format.integer(total)),
    previousShortcut: GallerySamples.previousMatchKeys,
    nextShortcut: GallerySamples.runKeys,
    closeShortcut: const [GallerySamples.esc],
  );
  Widget bar({
    String query = GallerySamples.query,
    bool showReplace = false,
    int current = 2,
    int total = 9,
    bool matchCase = false,
    String? notice,
  }) => SearchReplaceBar(
    labels: labels,
    query: query,
    replaceWith: showReplace ? GallerySamples.replacement : '',
    showReplace: showReplace,
    current: current,
    total: total,
    matchCase: matchCase,
    notice: notice,
    onQueryChanged: (_) {},
    onReplaceChanged: (_) {},
    onToggleReplace: () {},
    onToggleOption: (_, _) {},
    onPrevious: () {},
    onNext: () {},
    onReplace: () {},
    onReplaceAll: () {},
    onClose: () {},
  );
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(label: SpecName.findOnly.name, child: bar()),
      GallerySpecimen(
        label: SpecName.replaceShown.name,
        child: bar(showReplace: true),
      ),
      GallerySpecimen(
        label: SpecName.noResults.name,
        child: bar(query: GallerySamples.queryNone, current: 0, total: 0),
      ),
      GallerySpecimen(
        label: SpecName.optionHover.name,
        forced: GalleryForced.hover,
        child: bar(),
      ),
      GallerySpecimen(
        label: SpecName.optionFocusVisible.name,
        forced: GalleryForced.focusVisible,
        child: bar(),
      ),
      GallerySpecimen(
        label: SpecName.optionOn.name,
        child: bar(matchCase: true),
      ),
      GallerySpecimen(
        label: SpecName.notice.name,
        child: bar(
          query: GallerySamples.queryNotice,
          current: 1,
          total: 1,
          showReplace: true,
          notice: GallerySamples.searchNotice,
        ),
      ),
    ],
  );
}

/// `TextEditBox`: every state and label placement, on the page.
Widget textEditBoxSection(BuildContext context) {
  final theme = context.ferman;
  final format = RegionFormat.forRegion(GalleryEnvironment.of(context).region);
  final meta = GallerySamples.editMeta(
    GallerySamples.plexSerif,
    format.pointSize(10.5),
  );
  final width = theme.size.panelW;
  Widget box({
    TextEditBoxState state = TextEditBoxState.editing,
    MetaPlacement placement = MetaPlacement.above,
    bool warning = false,
    bool inert = false,
  }) {
    final start = placement == MetaPlacement.margin
        ? theme.size.doctabWMin + theme.space.space12
        : theme.space.space0;
    return GalleryPage(
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: start,
          top: theme.size.editboxMetaH,
          bottom: theme.size.editboxMetaH,
        ),
        child: TextEditBox(
          state: state,
          meta: warning
              ? GallerySamples.editMeta(
                  GallerySamples.garamond,
                  format.pointSize(10.5),
                )
              : meta,
          metaWarning: warning,
          metaPlacement: placement,
          width: width,
          inert: inert,
          semanticLabel: GallerySamples.paragraph,
          onPressed: () {},
          child: const Text(GallerySamples.paragraph),
        ),
      ),
    );
  }

  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          for (final state in TextEditBoxState.values)
            GallerySpecimen(
              label: state.name,
              child: box(state: state),
            ),
          GallerySpecimen(
            label: GalleryLabels.both(
              TextEditBoxState.idle.name,
              GalleryLabels.hover,
            ),
            forced: GalleryForced.hover,
            child: box(state: TextEditBoxState.idle),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: box(state: TextEditBoxState.idle),
          ),
          GallerySpecimen(
            label: SpecName.inertOutsideEdit.name,
            forced: GalleryForced.hover,
            child: box(state: TextEditBoxState.idle, inert: true),
          ),
        ],
      ),
      GalleryRow(
        label: SpecName.metaPlacement.name,
        children: [
          GallerySpecimen(
            label: SpecName.metaWarning.name,
            child: box(warning: true),
          ),
          GallerySpecimen(
            label: SpecName.metaBelow.name,
            child: box(placement: MetaPlacement.below),
          ),
          GallerySpecimen(
            label: SpecName.metaMargin.name,
            child: box(placement: MetaPlacement.margin),
          ),
        ],
      ),
    ],
  );
}

/// `TextCaret`: in a line of page text.
Widget textCaretSection(BuildContext context) => GalleryBody(
  children: [
    GallerySpecimen(
      label: SpecName.blinking.name,
      child: const GalleryPage(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: GallerySamples.caretBefore),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: TextCaret(),
              ),
              TextSpan(text: GallerySamples.caretAfter),
            ],
          ),
        ),
      ),
    ),
    const GalleryNote(GalleryLabels.caretNote),
  ],
);
