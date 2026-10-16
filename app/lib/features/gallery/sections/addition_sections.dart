import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/app_language.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The 12 px spinner of a loading tab and of the saving indicator
/// (FmWindow), the design's `--space-3`.
Widget _smallSpinner(BuildContext context) => Spinner(
  size: context.ferman.space.space3,
  semanticLabel: AppLocalizations.of(context).shellOpening,
);

/// `DocumentTab`: every state, and the strip with the "+N" overflow.
Widget documentTabSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  final env = GalleryEnvironment.of(context);
  final future = futureVersionReason(context);
  DocumentTab tab(
    String name, {
    bool active = false,
    bool unsaved = false,
    bool loading = false,
    IconName icon = IconName.fileText,
  }) => DocumentTab(
    name: name,
    active: active,
    unsaved: unsaved,
    loading: loading,
    icon: icon,
    unsavedLabel: l10n.shellUnsavedChanges,
    closeLabel: l10n.shellCloseDocument,
    closeShortcut: env.caps(ShellCommand.closeDocument),
    onClose: active ? () {} : null,
    closeDisabledReason: future,
    spinner: loading ? _smallSpinner(context) : null,
    onPressed: () {},
  );
  Widget bar(Widget child, {double? width}) => Container(
    width: width ?? theme.size.doctabW + 2 * theme.space.space2,
    height: theme.density.titlebarH,
    alignment: AlignmentDirectional.bottomStart,
    padding: EdgeInsetsDirectional.symmetric(horizontal: theme.space.space2),
    decoration: BoxDecoration(
      color: theme.colors.surfaceSunken,
      border: Border(
        bottom: BorderSide(
          color: theme.colors.borderSubtle,
          width: theme.border.borderWidth,
        ),
      ),
    ),
    child: child,
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(
            label: SpecName.active.name,
            child: bar(tab(GallerySamples.docLease, active: true)),
          ),
          GallerySpecimen(
            label: SpecName.idle.name,
            child: bar(tab(GallerySamples.docInvoice)),
          ),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            child: bar(tab(GallerySamples.docInvoice)),
          ),
          GallerySpecimen(
            label: SpecName.unsaved.name,
            child: bar(tab(GallerySamples.docStatement, unsaved: true)),
          ),
          GallerySpecimen(
            label: GalleryLabels.loading,
            child: bar(tab(GallerySamples.docPlan, loading: true)),
          ),
          GallerySpecimen(
            label: SpecName.locked.name,
            child: bar(tab(GallerySamples.docPayroll, icon: IconName.lock)),
          ),
          GallerySpecimen(
            label: SpecName.repaired.name,
            child: bar(tab(GallerySamples.docRepaired, icon: IconName.wrench)),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: bar(tab(GallerySamples.docLease, active: true)),
          ),
        ],
      ),
      GalleryRow(
        label: SpecName.overflow.name,
        children: [
          GallerySpecimen(
            label: SpecName.overflow.name,
            excludeSemantics: true,
            child: bar(
              width: theme.size.paletteW,
              DocumentTabStrip(
                semanticLabel: l10n.shellOpenDocuments,
                tabs: [
                  tab(GallerySamples.docLease, active: true),
                  tab(GallerySamples.docInvoice),
                  tab(GallerySamples.docStatement, unsaved: true),
                ],
                overflow: Button(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.sm,
                  iconEnd: IconName.chevronDown,
                  disabledReason: future,
                  child: const Text(GallerySamples.moreDocuments),
                ),
                trailing: IconButton(
                  icon: IconName.plus,
                  label: l10n.shellOpenFile,
                  size: IconButtonSize.sm,
                  shortcut: env.caps(ShellCommand.open),
                  disabledReason: future,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// `WindowChrome`: the three platforms, maximized, and the hovers.
Widget windowChromeSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  Widget chrome(
    WindowPlatform platform, {
    bool maximized = false,
    Set<WidgetState> maximizeStates = const {},
  }) => Container(
    height: theme.density.titlebarH,
    decoration: BoxDecoration(
      color: theme.colors.surfaceSunken,
      border: Border.all(
        color: theme.colors.borderSubtle,
        width: theme.border.borderWidth,
      ),
    ),
    child: WindowChrome(
      platform: platform,
      maximized: maximized,
      paintTrafficLights: true,
      maximizeButtonStates: maximizeStates,
      minimizeLabel: l10n.windowMinimize,
      maximizeLabel: l10n.windowMaximize,
      restoreLabel: l10n.windowRestore,
      closeLabel: l10n.windowClose,
      onMinimize: () {},
      onMaximize: () {},
      onClose: () {},
    ),
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: SpecName.platform.name,
        children: [
          for (final platform in WindowPlatform.values)
            GallerySpecimen(label: platform.name, child: chrome(platform)),
          GallerySpecimen(
            label: GalleryLabels.both(
              WindowPlatform.win.name,
              SpecName.maximized.name,
            ),
            child: chrome(WindowPlatform.win, maximized: true),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.hover,
        children: [
          GallerySpecimen(
            label: SpecName.captionHover.name,
            // The platform's hover opens the maximize tooltip; the stage
            // keeps it inside the sample.
            child: GalleryStage(
              width: theme.size.panelW,
              height: theme.density.titlebarH + theme.space.space12,
              child: chrome(
                WindowPlatform.win,
                maximizeStates: GalleryForced.hover,
              ),
            ),
          ),
          GallerySpecimen(
            label: GalleryLabels.allHovered,
            forced: GalleryForced.hover,
            child: chrome(WindowPlatform.win),
          ),
        ],
      ),
    ],
  );
}

/// `SaveIndicator`: every save state, the time in the region's format.
Widget saveIndicatorSection(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final region = GalleryEnvironment.of(context).region;
  String label(SaveState state) => switch (state) {
    SaveState.unsaved => l10n.shellUnsavedChanges,
    SaveState.saved => l10n.shellSavedOnDevice(
      RegionFormat.forRegion(region).time(GallerySamples.savedAt),
    ),
    SaveState.saving => l10n.shellSaving,
    SaveState.error => l10n.shellSaveError,
    SaveState.readOnly => l10n.shellReadOnly,
  };
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      for (final state in SaveState.values)
        GallerySpecimen(
          label: state.name,
          child: SaveIndicator(
            state: state,
            label: label(state),
            savedAt: GallerySamples.savedAt,
            region: region,
            savedLabel: l10n.shellSavedOnDevice,
          ),
        ),
    ],
  );
}

/// `DatePicker`: November 2026 with the lease's start selected.
Widget datePickerSection(BuildContext context) {
  final region = GalleryEnvironment.of(context).region;
  Widget picker({DateTime? value}) => GalleryValue<(DateTime?, DateTime)>(
    initial: (value, GallerySamples.dateMonth),
    builder: (context, current, set) => DatePicker(
      value: current.$1,
      month: current.$2,
      region: region,
      firstDayOfWeek: region.defaultFirstDayOfWeek.weekday,
      formatNote: GallerySamples.dateFormatNote,
      semanticLabel: GallerySamples.chooseDate,
      onChanged: (day) => set((day, current.$2)),
      onMonthChanged: (month) => set((current.$1, month)),
      previousMonthButton: IconButton(
        icon: IconName.chevronLeft,
        label: GallerySamples.previousMonth,
        size: IconButtonSize.sm,
        onPressed: () =>
            set((current.$1, DateTime(current.$2.year, current.$2.month - 1))),
      ),
      nextMonthButton: IconButton(
        icon: IconName.chevronRight,
        label: GallerySamples.nextMonth,
        size: IconButtonSize.sm,
        onPressed: () =>
            set((current.$1, DateTime(current.$2.year, current.$2.month + 1))),
      ),
      todayButton: Button(
        variant: ButtonVariant.ghost,
        size: ButtonSize.sm,
        onPressed: () {},
        child: const Text(GallerySamples.today),
      ),
    ),
  );
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(
        label: GalleryLabels.both(
          GalleryLabels.standard,
          SpecName.outsideMonth.name,
        ),
        child: picker(),
      ),
      GallerySpecimen(
        label: GalleryLabels.selected,
        child: picker(value: GallerySamples.dateValueDay),
      ),
      GallerySpecimen(
        label: GalleryLabels.focusVisible,
        forced: GalleryForced.focusVisible,
        child: picker(value: GallerySamples.dateValueDay),
      ),
    ],
  );
}

/// `MentionList`: the people of the lease, one active.
Widget mentionListSection(BuildContext context) {
  Widget list({int active = 0}) => GalleryValue<int>(
    initial: active,
    builder: (context, value, set) => MentionList(
      people: GallerySamples.people,
      activeIndex: value,
      heading: GallerySamples.peopleInDocument,
      semanticLabel: GallerySamples.mentionSomeone,
      onActiveIndexChanged: set,
      onSelected: (_) {},
      onDismiss: () {},
    ),
  );
  return GalleryRow(
    label: GalleryLabels.state,
    children: [
      GallerySpecimen(label: GalleryLabels.standard, child: list()),
      GallerySpecimen(label: SpecName.active.name, child: list(active: 1)),
      GallerySpecimen(
        label: GalleryLabels.focusVisible,
        forced: GalleryForced.focusVisible,
        child: list(),
      ),
    ],
  );
}

/// `CommentCard`: collapsed, expanded, composing, resolved and focused.
Widget commentCardSection(BuildContext context) {
  final theme = context.ferman;
  const replies = [
    NoteReply(
      author: GallerySamples.mert,
      time: GallerySamples.replyTime,
      text: GallerySamples.replyText,
    ),
    NoteReply(
      author: GallerySamples.deniz,
      time: GallerySamples.replyTime2,
      text: GallerySamples.replyText2,
    ),
  ];
  Widget card({
    bool expanded = false,
    bool composing = false,
    bool resolved = false,
  }) => CommentCard(
    icon: resolved ? IconName.underline : IconName.highlighter,
    chipColor: (resolved ? AnnotationColor.green : AnnotationColor.yellow)
        .resolve(theme),
    author: GallerySamples.ayse,
    time: resolved ? GallerySamples.yesterday : GallerySamples.commentTime,
    quote: resolved
        ? GallerySamples.resolvedQuote
        : GallerySamples.commentQuote,
    text: resolved ? GallerySamples.resolvedText : GallerySamples.commentText,
    replies: resolved ? const [] : replies,
    expanded: expanded,
    composing: composing,
    resolvedBy: resolved ? GallerySamples.resolvedBy : null,
    repliesLabel: resolved ? null : GallerySamples.twoReplies,
    semanticLabel: resolved
        ? GallerySamples.resolvedLabel
        : GallerySamples.commentLabel,
    resolveLabel: GallerySamples.resolve,
    replyLabel: GallerySamples.reply,
    reopenLabel: GallerySamples.reopen,
    replyPlaceholder: GallerySamples.reply,
    onPressed: () {},
    onResolve: () {},
    onReply: (_) {},
    onReopen: () {},
  );
  final width = theme.size.panelW;
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(
            label: GalleryLabels.collapsed,
            width: width,
            child: card(),
          ),
          GallerySpecimen(
            label: GalleryLabels.expanded,
            width: width,
            child: card(expanded: true),
          ),
          GallerySpecimen(
            label: SpecName.composing.name,
            width: width,
            child: ExcludeFocus(child: card(expanded: true, composing: true)),
          ),
          GallerySpecimen(
            label: SpecName.resolved.name,
            width: width,
            child: card(resolved: true),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            width: width,
            child: card(),
          ),
        ],
      ),
      const GalleryNote(GalleryLabels.noFocusNote),
    ],
  );
}

/// `ThumbnailBadges`: each badge on the page, all of them, focus and the
/// legend.
Widget thumbnailBadgesSection(BuildContext context) {
  const tooltips = {
    ThumbnailBadge.edited: GallerySamples.editedSinceOpened,
    ThumbnailBadge.comments: GallerySamples.badgeComments,
    ThumbnailBadge.formFields: GallerySamples.badgeFields,
    ThumbnailBadge.signature: GallerySamples.badgeSignature,
    ThumbnailBadge.warnings: GallerySamples.badgeWarnings,
  };
  final entries = {
    for (final (index, badge) in ThumbnailBadge.values.indexed)
      badge: (
        name: GallerySamples.legendEntries[index].$1,
        description: GallerySamples.legendEntries[index].$2,
      ),
  };
  return GalleryBody(
    children: [
      GalleryRow(
        label: SpecName.badge.name,
        children: [
          for (final badge in ThumbnailBadge.values)
            GallerySpecimen(
              label: badge.name,
              child: GalleryPage(
                uiDirection: true,
                child: ThumbnailBadges(badges: {badge}, tooltips: tooltips),
              ),
            ),
          GallerySpecimen(
            label: GalleryLabels.both(
              SpecName.edited.name,
              SpecName.neutralChip.name,
            ),
            child: GalleryPage(
              uiDirection: true,
              child: ThumbnailBadges(
                badges: ThumbnailBadge.values.toSet(),
                tooltips: tooltips,
              ),
            ),
          ),
          const GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: GalleryPage(
              uiDirection: true,
              child: ThumbnailBadges(
                badges: {ThumbnailBadge.comments, ThumbnailBadge.warnings},
                tooltips: tooltips,
              ),
            ),
          ),
        ],
      ),
      GalleryRow(
        label: SpecName.legendOpen.name,
        children: [
          GallerySpecimen(
            label: SpecName.legendOpen.name,
            child: ThumbnailBadgeLegend(
              title: GallerySamples.legendTitle,
              entries: entries,
              footnote: GallerySamples.legendFootnote,
            ),
          ),
        ],
      ),
    ],
  );
}

/// `FmNumber`: the states, and the design's region card (English, Turkish,
/// German, Arabic).
Widget fmNumberSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  final region = GalleryEnvironment.of(context).region;
  final unit = LengthUnit.point.symbol;
  Widget number({
    double initial = 10.5,
    String? error,
    Region? inRegion,
    String? label,
    String? unitSymbol,
    double? width,
  }) => GalleryValue<double>(
    initial: initial,
    builder: (context, value, set) => FmNumber(
      value: value,
      unit: unitSymbol ?? unit,
      label: label ?? l10n.regionExampleFontSize,
      error: error,
      region: inRegion ?? region,
      width: width ?? theme.size.thumbW,
      onChanged: set,
    ),
  );
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(label: GalleryLabels.standard, child: number()),
          GallerySpecimen(
            label: GalleryLabels.hover,
            forced: GalleryForced.hover,
            child: number(),
          ),
          GallerySpecimen(
            label: GalleryLabels.focusVisible,
            forced: GalleryForced.focusVisible,
            child: number(),
          ),
          GallerySpecimen(
            label: GalleryLabels.error,
            child: number(initial: 0, error: GallerySamples.fmNumberError),
          ),
        ],
      ),
      GalleryRow(
        label: SpecName.region.name,
        children: [
          for (final (name, sample, value, symbol) in [
            (AppLanguage.english.endonym, Region.unitedStates, 10.5, unit),
            (AppLanguage.turkish.endonym, Region.turkiye, 10.5, unit),
            (
              GallerySamples.deutsch,
              Region.forCode('DE'),
              1234.5,
              LengthUnit.millimetre.symbol,
            ),
            (AppLanguage.arabic.endonym, Region.forCode('SA'), 10.5, unit),
          ])
            GallerySpecimen(
              label: sample.code,
              child: number(
                initial: value,
                inRegion: sample,
                label: name,
                unitSymbol: symbol,
                width: theme.size.thumbW + theme.space.space2,
              ),
            ),
        ],
      ),
      const GalleryNote(GalleryLabels.fmNumberRtlNote),
    ],
  );
}
