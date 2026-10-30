import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/onboarding/onboarding_link.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Bidi;

/// The start screen's files once there are any (a1-4, a1-4b, a1-4c,
/// a1-4-m2): the drop strip, the pinned files, every recent file (pinned
/// ones too, as the boards list them) with search, sort and a grid or a
/// list, and the on-device note with "Clear list".
///
/// Picking a file opens it ([DocumentOpener.openRecent]); one that was
/// moved, renamed or deleted asks what to do (a1-9e): "Remove from list"
/// drops it and "Locate…" shows the system open panel for one file and
/// points the entry to it, which then opens. A recent file's pin button
/// shows while the pointer is over it or the button has focus, and stays
/// in the semantics tree (G118). The search matches the file name, ignoring
/// case in the UI language. Names and folders sort in the UI language's
/// order through the engine's collator; without an engine, by code points.
/// The sort and the view last for the session ([recentLayoutProvider]). The
/// page previews are the boards' placeholder lines until thumbnails come
/// (B118).
class RecentFilesView extends ConsumerStatefulWidget {
  /// The files of the start screen.
  const new({super.key});

  /// The gap between the strip and the sections, as the start screen's
  /// (`gap: 28px`).
  static const double sectionGap = 28;

  /// The pinned files' columns (`repeat(3, …)`).
  static const int pinnedColumns = 3;

  /// The recent files' columns in the grid (`repeat(5, …)`).
  static const int gridColumns = 5;

  /// The drop strip's height (`height: 64px`).
  static const double stripHeight = 64;

  /// The drop strip's side padding (`padding-inline: 20px`).
  static const double stripPadding = 20;

  /// The drop strip's icon (`size={20}`).
  static const double stripIconSize = 20;

  /// The gap between the strip's icon and text (`gap: 14px`).
  static const double stripGap = 14;

  /// The search field's width (`width: 240px`).
  static const double searchWidth = 240;

  /// The sort menu's width (`width: 150px`).
  static const double sortWidth = 150;

  /// The footer's icon (`size={12}`).
  static const double footerIconSize = 12;

  @override
  ConsumerState<RecentFilesView> createState() => _RecentFilesViewState();
}

class _RecentFilesViewState extends ConsumerState<RecentFilesView> {
  final TextEditingController _search = TextEditingController();

  /// The files in the collator's order, for the sort, the whole list and
  /// the locale of [_sortedFor]; while the engine has not answered, the
  /// order before it with the new files appended.
  List<RecentEntry>? _sorted;
  (RecentSort, List<RecentEntry>, String)? _sortedFor;

  /// The recent file that was not found, while a1-9e asks about it.
  RecentEntry? _missing;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final files = ref.watch(recentFilesProvider);
    final (sort, view) = ref.watch(recentLayoutProvider);
    final pinned = [
      for (final file in files)
        if (file.pinned) file,
    ];
    final details = _Details(
      l10n: l10n,
      format: RegionFormat.forRegion(ref.watch(regionProvider).region),
      home: ref.watch(homeDirectoryProvider),
      // shortcut: "Today" and "Yesterday" follow the clock only when the
      // screen rebuilds; a clock provider would move them at midnight.
      now: DateTime.now(),
    );
    final openReason = openFilesDisabledReason(context, ref);
    final casing = LocaleCasing.of(context);
    final query = _folded(casing, _search.text.trim());
    final shown = [
      for (final file in _ordered(sort, files, details))
        if (query.isEmpty || _folded(casing, file.name).contains(query)) file,
    ];

    final missing = _missing;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RecentFilesView.sectionGap,
      children: [
        const _DropStrip(),
        if (pinned.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space2_5,
            children: [
              Text(l10n.startPinned, style: theme.typography.panelTitle),
              _Rows(
                columns: RecentFilesView.pinnedColumns,
                gap: theme.space.space3,
                children: [
                  for (final file in pinned)
                    _PinnedCard(
                      key: ValueKey(file.path),
                      file: file,
                      label: details.label(file, details.location(file)),
                      meta: details.pinnedMeta(file),
                      openReason: openReason,
                      onOpen: () => _open(file),
                      onUnpin: () => _pin(file, pinned: false),
                    ),
                ],
              ),
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.space3,
          children: [
            _header(context, l10n, sort, view),
            if (shown.isEmpty)
              Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  vertical: theme.space.space6,
                ),
                child: Text(
                  l10n.startNoRecentMatch(_search.text.trim()),
                  textAlign: TextAlign.center,
                  style: theme.typography.body.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
              )
            else if (view == RecentView.grid)
              _Rows(
                columns: RecentFilesView.gridColumns,
                gap: theme.space.space4,
                children: [
                  for (final file in shown)
                    _RecentCard(
                      key: ValueKey(file.path),
                      file: file,
                      label: details.label(file, details.when(file)),
                      meta: details.meta(file),
                      openReason: openReason,
                      onOpen: () => _open(file),
                      onPin: () => _pin(file, pinned: !file.pinned),
                    ),
                ],
              )
            else
              _RecentTable(
                files: shown,
                details: details,
                openReason: openReason,
                onOpen: _open,
                onPin: (file) => _pin(file, pinned: !file.pinned),
              ),
          ],
        ),
        _footer(context, l10n),
      ],
    );
    return Stack(
      children: [
        content,
        if (missing != null) _missingDialog(l10n, missing, details),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    RecentSort sort,
    RecentView view,
  ) {
    final theme = context.ferman;
    final layout = ref.read(recentLayoutProvider.notifier);
    return Row(
      spacing: theme.space.space2_5,
      children: [
        Text(l10n.startRecent, style: theme.typography.panelTitle),
        const Spacer(),
        SizedBox(
          width: RecentFilesView.searchWidth,
          child: TextField(
            size: FieldSize.sm,
            icon: IconName.search,
            controller: _search,
            placeholder: l10n.startSearchRecent,
            semanticLabel: l10n.startSearchRecent,
          ),
        ),
        SizedBox(
          width: RecentFilesView.sortWidth,
          child: Select<RecentSort>(
            size: FieldSize.sm,
            value: sort,
            semanticLabel: l10n.startSort,
            options: [
              SelectOption(
                value: RecentSort.opened,
                label: l10n.startSortOpened,
              ),
              SelectOption(value: RecentSort.name, label: l10n.startSortName),
              SelectOption(
                value: RecentSort.location,
                label: l10n.startSortLocation,
              ),
            ],
            onChanged: layout.sortBy,
          ),
        ),
        SegmentedControl<RecentView>(
          semanticLabel: l10n.startView,
          value: view,
          options: [
            SegmentOption(
              value: RecentView.grid,
              icon: IconName.layoutGrid,
              tooltip: l10n.startViewGrid,
            ),
            SegmentOption(
              value: RecentView.list,
              icon: IconName.list,
              tooltip: l10n.startViewList,
            ),
          ],
          onChanged: layout.show,
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, AppLocalizations l10n) {
    final theme = context.ferman;
    final caption = theme.typography.caption.copyWith(
      color: theme.colors.textTertiary,
    );
    return Row(
      spacing: theme.space.space1_5,
      children: [
        Icon(
          IconName.hardDrive,
          size: RecentFilesView.footerIconSize,
          strokeWidth: theme.border.borderWidth * 2,
          color: theme.colors.textTertiary,
        ),
        Text(l10n.startRecentFooter, style: caption),
        OnboardingLink(
          label: l10n.startClearList,
          style: theme.typography.caption,
          onPressed: () => unawaited(
            ref
                .read(recentFilesProvider.notifier)
                .clear()
                .catchError((Object _) {}),
          ),
        ),
      ],
    );
  }

  /// a1-9e: the file of [entry] was moved, renamed or deleted. Closing it
  /// (its button, Escape, the scrim) keeps the file in the list (G118).
  Widget _missingDialog(
    AppLocalizations l10n,
    RecentEntry entry,
    _Details details,
  ) {
    void close() => setState(() => _missing = null);
    return Dialog(
      icon: IconName.fileSearch,
      title: l10n.startMissingTitle(bidiIsolate(entry.name)),
      description: l10n.startMissingDescription(
        bidiIsolate(details.location(entry)),
      ),
      onClose: close,
      closeLabel: l10n.startMissingClose,
      actions: [
        Button(
          onPressed: () {
            close();
            unawaited(
              ref
                  .read(recentFilesProvider.notifier)
                  .remove(entry.path)
                  .catchError((Object _) {}),
            );
          },
          child: Text(l10n.startMissingRemove),
        ),
        Button(
          variant: ButtonVariant.primary,
          onPressed: () {
            close();
            unawaited(_locate(entry, l10n.openPdfFilter));
          },
          child: Text(l10n.startMissingLocate),
        ),
      ],
    );
  }

  /// Shows the open panel for the one file of [entry] where it is now,
  /// points the entry there with a bookmark made while the panel's grant
  /// holds, and opens it.
  Future<void> _locate(RecentEntry entry, String filterLabel) async {
    final path = await ref
        .read(filePickerServiceProvider)
        .openPdf(filterLabel: filterLabel);
    if (path == null || !mounted) return;
    final bookmark = await ref.read(fileAccessProvider).bookmark(path);
    await ref
        .read(recentFilesProvider.notifier)
        .relocate(
          entry.path,
          to: path,
          name: fileName(path),
          bookmark: bookmark,
          sameFile: false,
        )
        .catchError((Object _) {});
    await ref.read(documentOpenerProvider.notifier).open([path]);
  }

  /// [files] in [sort]'s order: as stored for the last opened, else the
  /// collator's order once the engine has answered; until then the
  /// previous order, with files new to it appended in the stored order.
  List<RecentEntry> _ordered(
    RecentSort sort,
    List<RecentEntry> files,
    _Details details,
  ) {
    if (sort == RecentSort.opened) return files;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sortedFor = _sortedFor;
    if (sortedFor != null &&
        sortedFor.$1 == sort &&
        identical(sortedFor.$2, files) &&
        sortedFor.$3 == locale) {
      return _sorted ?? files;
    }
    final key = (sort, files, locale);
    final previous = sortedFor?.$1 == sort ? _sorted : null;
    _sortedFor = key;
    final paths = {for (final file in files) file.path: file};
    final kept = previous == null
        ? <RecentEntry>[]
        : [for (final file in previous) ?paths[file.path]];
    final keptPaths = {for (final file in kept) file.path};
    final provisional = [
      ...kept,
      for (final file in files)
        if (!keptPaths.contains(file.path)) file,
    ];
    _sorted = provisional;
    final texts = [
      for (final file in files)
        if (sort == RecentSort.name) file.name else details.location(file),
    ];
    unawaited(
      _collate(locale, texts).then((order) {
        if (!mounted || !identical(_sortedFor, key)) return;
        setState(() => _sorted = [for (final i in order) files[i]]);
      }),
    );
    return provisional;
  }

  /// The order of [texts] from the engine's collator, or by code points
  /// when the engine cannot answer.
  Future<List<int>> _collate(String locale, List<String> texts) async {
    try {
      final order = await ref
          .read(engineServiceProvider)
          .collationOrder(locale, texts);
      if (order.length == texts.length) return order;
    } on EngineUnavailableException {
      // By code points below.
    } on EngineException {
      // By code points below.
    }
    return [for (var i = 0; i < texts.length; i++) i]..sort((a, b) {
      final byText = texts[a].compareTo(texts[b]);
      return byText != 0 ? byText : a.compareTo(b);
    });
  }

  void _open(RecentEntry file) => unawaited(
    ref.read(documentOpenerProvider.notifier).openRecent(file).then((found) {
      if (!found && mounted) setState(() => _missing = file);
    }),
  );

  void _pin(RecentEntry file, {required bool pinned}) => unawaited(
    ref
        .read(recentFilesProvider.notifier)
        .pin(file.path, pinned: pinned)
        .catchError((Object _) {}),
  );
}

/// [text] lowercased in the UI language for the search, without the
/// combining dot that "İ" leaves in languages other than Turkish and
/// Azerbaijani, so "İMAR" matches "imar" in every language.
String _folded(LocaleCasing casing, String text) =>
    casing.lower(text).replaceAll('̇', '');

/// The direction of [text]'s first strong character, as the boards' `dir`
/// of `auto` gives a file name; null when it has none.
TextDirection? _directionOf(String text) {
  if (Bidi.startsWithRtl(text)) return TextDirection.rtl;
  if (Bidi.startsWithLtr(text)) return TextDirection.ltr;
  return null;
}

/// What a recent file's card and row say about it, in the UI language and
/// the region's formats.
final class _Details {
  const new({
    required this.l10n,
    required this.format,
    required this.home,
    required this.now,
  });

  final AppLocalizations l10n;
  final RegionFormat format;
  final String? home;
  final DateTime now;

  /// When it was opened: "Today 14:32", "Yesterday 18:20" or the date,
  /// counted in calendar days, so a clock change does not move it.
  String when(RecentEntry file) {
    final opened = file.opened.toLocal();
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(opened.year, opened.month, opened.day)).inDays;
    return switch (days) {
      0 => l10n.startOpenedToday(format.time(opened)),
      1 => l10n.startOpenedYesterday(format.time(opened)),
      _ => format.date(opened),
    };
  }

  /// Its page count ("3 pages"), or null when not known.
  String? pages(RecentEntry file) {
    final count = file.pages;
    return count == null ? null : l10n.startPages(count, format.integer(count));
  }

  /// The folder it is in, the home directory shown as "~".
  String location(RecentEntry file) {
    final path = file.path;
    final end = path.length - fileName(path).length;
    var folder = end > 1 ? path.substring(0, end - 1) : path.substring(0, end);
    final home = this.home;
    if (home != null && (folder == home || folder.startsWith('$home/'))) {
      folder = '~${folder.substring(home.length)}';
    }
    return folder;
  }

  /// The grid card's line: "Today 14:32 · 3 pages".
  String meta(RecentEntry file) => [when(file), ?pages(file)].join(' · ');

  /// The pinned card's line: "~/Belgeler/Ev · 3 pages".
  String pinnedMeta(RecentEntry file) =>
      [location(file), ?pages(file)].join(' · ');

  /// What a screen reader says for a card or row: the name, [line], the
  /// page count and the badge, once.
  String label(RecentEntry file, String line) => [
    file.name,
    line,
    ?pages(file),
    if (file.signed) l10n.startBadgeSigned,
  ].join(', ');
}

/// [children] in rows of [columns] equal cells, [gap] apart, the last row
/// keeping the cells' width (`grid-template-columns: repeat(n, 1fr)`).
class _Rows extends StatelessWidget {
  const new({required this.columns, required this.gap, required this.children});

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: gap,
    children: [
      for (var start = 0; start < children.length; start += columns)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: [
              for (var i = start; i < start + columns; i++)
                Expanded(
                  child: i < children.length
                      ? children[i]
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
    ],
  );
}

/// The drop strip above the files (FmStart's dashed 64 px strip): a1-6's
/// overlay takes the drop itself (`FileDrop`).
class _DropStrip extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    return CustomPaint(
      foregroundPainter: DropZoneBorderPainter(
        color: theme.colors.borderStrong,
        width: theme.border.borderWidthStrong,
        radius: theme.radius.radiusXl,
        dashed: true,
      ),
      child: SizedBox(
        height: RecentFilesView.stripHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: RecentFilesView.stripPadding,
          ),
          child: Row(
            spacing: RecentFilesView.stripGap,
            children: [
              Icon(
                IconName.upload,
                size: RecentFilesView.stripIconSize,
                color: theme.colors.iconSecondary,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.space0_5,
                  children: [
                    Text(
                      l10n.startDropStripTitle,
                      style: theme.typography.bodyStrong.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.startDropStripSubtitle,
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page in paper white with the placeholder lines, [width] × [height],
/// ringed in the default border (`box-shadow: 0 0 0 1px`), with the small
/// shadow when [raised].
class _Page extends StatelessWidget {
  const new({required this.width, required this.height, this.raised = false});

  final double width;
  final double height;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Paper white in both themes, as the boards draw page previews.
        color: theme.ramps.paper0,
        boxShadow: [
          if (raised) ...theme.elevation.shadowSm,
          BoxShadow(
            color: theme.colors.borderDefault,
            spreadRadius: theme.border.borderWidth,
          ),
        ],
      ),
      child: const PageLines(),
    );
  }
}

/// The name in body-strong, in the direction of its first strong
/// character, and the line under it in the tertiary caption, each on one
/// line with an ellipsis.
class _NameAndMeta extends StatelessWidget {
  const new({required this.name, required this.meta});

  final String name;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space0_5,
      children: [
        Text(
          name,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
          textDirection: _directionOf(name),
          style: theme.typography.bodyStrong,
        ),
        Text(
          meta,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.caption.copyWith(
            color: theme.colors.textTertiary,
            fontFeatures: theme.typeScale.numericTabular,
          ),
        ),
      ],
    );
  }
}

/// The pin button of a file: active ("Unpin") when it is [pinned], always
/// shown when [shown], else only while [visible] (the pointer is over its
/// card or row) or while it has focus. Hidden, it takes no pointer and
/// stays in the semantics tree, so the keyboard and screen readers reach
/// it (G118).
class _PinButton extends StatefulWidget {
  const new({
    required this.pinned,
    required this.visible,
    required this.onPressed,
    this.shown = false,
  });

  final bool pinned;
  final bool visible;
  final bool shown;
  final VoidCallback onPressed;

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
  final FocusNode _focus = FocusNode(debugLabel: 'Recent file pin');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = widget.shown || widget.visible || _focus.hasFocus;
    return IgnorePointer(
      ignoring: !shown,
      child: Opacity(
        opacity: shown ? 1 : 0,
        alwaysIncludeSemantics: true,
        child: IconButton(
          icon: IconName.pin,
          label: widget.pinned ? l10n.startUnpin : l10n.startPin,
          size: IconButtonSize.xs,
          active: widget.pinned,
          focusNode: _focus,
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

/// The badges of a recent file: the neutral "Signed" of a1-4-m2 when it
/// carried signatures.
Widget? _badge(BuildContext context, RecentEntry file) => file.signed
    ? Badge(
        label: AppLocalizations.of(context).startBadgeSigned,
        icon: IconName.signature,
      )
    : null;

/// A pinned file (FmStart `pinned`): a small page, the name and the
/// location with the page count, and the active pin that unpins it, which
/// sits beside the card's own control, so its focus is its own.
class _PinnedCard extends StatelessWidget {
  const new({
    required this.file,
    required this.label,
    required this.meta,
    required this.openReason,
    required this.onOpen,
    required this.onUnpin,
    super.key,
  });

  /// The small page (`26px` × `36px`).
  static const double pageWidth = 26;
  static const double pageHeight = 36;

  final RecentEntry file;
  final String label;
  final String meta;
  final String? openReason;
  final VoidCallback onOpen;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final pinSlot = theme.density.controlHXs;
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        FermanInteractive(
          onPressed: onOpen,
          disabled: openReason != null,
          disabledReason: openReason,
          semanticLabel: label,
          builder: (context, states, _) {
            final radius = BorderRadius.all(
              Radius.circular(theme.radius.radiusMd),
            );
            return FocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: radius,
              child: Container(
                padding: EdgeInsetsDirectional.fromSTEB(
                  theme.space.space3,
                  theme.space.space2_5,
                  theme.space.space3 * 2 + pinSlot,
                  theme.space.space2_5,
                ),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceRaised,
                  borderRadius: radius,
                  border: Border.all(color: theme.colors.borderSubtle),
                ),
                child: ExcludeSemantics(
                  child: Row(
                    spacing: theme.space.space3,
                    children: [
                      const _Page(width: pageWidth, height: pageHeight),
                      Expanded(
                        child: _NameAndMeta(name: file.name, meta: meta),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        PositionedDirectional(
          end: theme.space.space3,
          child: _PinButton(
            pinned: true,
            visible: true,
            shown: true,
            onPressed: onUnpin,
          ),
        ),
      ],
    );
  }
}

/// A recent file in the grid (FmStart `recent`, a1-4): the first page on
/// the sunken well, the name, when it was opened with its page count, and
/// its badge, with its pin button over the well's top end.
class _RecentCard extends StatefulWidget {
  const new({
    required this.file,
    required this.label,
    required this.meta,
    required this.openReason,
    required this.onOpen,
    required this.onPin,
    super.key,
  });

  /// The well (`height: 150px`) …
  static const double wellHeight = 150;

  /// … and the page on it (`93px` × `132px`).
  static const double pageWidth = 93;
  static const double pageHeight = 132;

  final RecentEntry file;
  final String label;
  final String meta;
  final String? openReason;
  final VoidCallback onOpen;
  final VoidCallback onPin;

  @override
  State<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends State<_RecentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final file = widget.file;
    final badge = _badge(context, file);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          FermanInteractive(
            onPressed: widget.onOpen,
            disabled: widget.openReason != null,
            disabledReason: widget.openReason,
            semanticLabel: widget.label,
            builder: (context, states, _) {
              final radius = BorderRadius.all(
                Radius.circular(theme.radius.radiusMd),
              );
              // The whole card, its pin included, keeps the hover fill.
              final hovered = _hovered || states.contains(WidgetState.hovered);
              return FocusRing(
                visible: states.contains(WidgetState.focused),
                borderRadius: radius,
                child: Container(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    theme.space.space2,
                    theme.space.space2,
                    theme.space.space2,
                    theme.space.space2_5,
                  ),
                  decoration: BoxDecoration(
                    color: hovered && widget.openReason == null
                        ? theme.colors.surfaceHover
                        : null,
                    borderRadius: radius,
                  ),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: theme.space.space2,
                      children: [
                        Container(
                          height: _RecentCard.wellHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colors.surfaceSunken,
                            borderRadius: BorderRadius.all(
                              Radius.circular(theme.radius.radiusSm),
                            ),
                            border: Border.all(
                              color: theme.colors.borderSubtle,
                            ),
                          ),
                          child: const _Page(
                            width: _RecentCard.pageWidth,
                            height: _RecentCard.pageHeight,
                            raised: true,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.symmetric(
                            horizontal: theme.space.space0_5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: theme.space.space0_5,
                            children: [
                              _NameAndMeta(name: file.name, meta: widget.meta),
                              if (badge != null)
                                Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    top: theme.space.space1,
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: badge,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          PositionedDirectional(
            top: theme.space.space3,
            end: theme.space.space3,
            child: _PinButton(
              pinned: file.pinned,
              visible: _hovered,
              onPressed: widget.onPin,
            ),
          ),
        ],
      ),
    );
  }
}

/// The recent files as a table (a1-4c): name, location, pages, when, and
/// the badge, on the raised surface with a header row.
class _RecentTable extends StatelessWidget {
  const new({
    required this.files,
    required this.details,
    required this.openReason,
    required this.onOpen,
    required this.onPin,
  });

  /// Column widths: `minmax(0, 2.4fr) minmax(0, 1.6fr) 90px 150px 120px`.
  static const int nameFlex = 24;
  static const int locationFlex = 16;
  static const double pagesWidth = 90;
  static const double openedWidth = 150;
  static const double badgeWidth = 120;

  /// A row's height (`height: 40px`).
  static const double rowHeight = 40;

  final List<RecentEntry> files;
  final _Details details;
  final String? openReason;
  final ValueChanged<RecentEntry> onOpen;
  final ValueChanged<RecentEntry> onPin;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final label = theme.typography.label.copyWith(
      color: theme.colors.textTertiary,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
        border: Border.all(color: theme.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.space.space4,
              vertical: theme.space.space2,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colors.borderSubtle),
              ),
            ),
            child: _cells(
              theme,
              name: Text(l10n.startSortName, style: label),
              location: Text(l10n.startSortLocation, style: label),
              pages: Text(l10n.startColumnPages, style: label),
              opened: Text(l10n.startColumnOpened, style: label),
              badge: const SizedBox.shrink(),
            ),
          ),
          for (final file in files)
            _RecentRow(
              key: ValueKey(file.path),
              file: file,
              details: details,
              openReason: openReason,
              onOpen: () => onOpen(file),
              onPin: () => onPin(file),
            ),
        ],
      ),
    );
  }
}

/// The five cells of a table row, 16 px apart.
Widget _cells(
  FermanTheme theme, {
  required Widget name,
  required Widget location,
  required Widget pages,
  required Widget opened,
  required Widget badge,
}) => Row(
  spacing: theme.space.space4,
  children: [
    Expanded(flex: _RecentTable.nameFlex, child: name),
    Expanded(flex: _RecentTable.locationFlex, child: location),
    SizedBox(width: _RecentTable.pagesWidth, child: pages),
    SizedBox(width: _RecentTable.openedWidth, child: opened),
    SizedBox(width: _RecentTable.badgeWidth, child: badge),
  ],
);

/// A recent file's row in the table, with its pin button at its end while
/// the pointer is over it, beside the row's own control.
class _RecentRow extends StatefulWidget {
  const new({
    required this.file,
    required this.details,
    required this.openReason,
    required this.onOpen,
    required this.onPin,
    super.key,
  });

  final RecentEntry file;
  final _Details details;
  final String? openReason;
  final VoidCallback onOpen;
  final VoidCallback onPin;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final file = widget.file;
    final details = widget.details;
    final badge = _badge(context, file);
    final secondary = theme.typography.body.copyWith(
      color: theme.colors.textSecondary,
      fontFeatures: theme.typeScale.numericTabular,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        alignment: AlignmentDirectional.centerEnd,
        children: [
          FermanInteractive(
            onPressed: widget.onOpen,
            disabled: widget.openReason != null,
            disabledReason: widget.openReason,
            semanticLabel: details.label(
              file,
              '${details.location(file)}, ${details.when(file)}',
            ),
            builder: (context, states, _) => FocusRing(
              visible: states.contains(WidgetState.focused),
              style: FocusRingStyle.inset,
              child: Container(
                height: _RecentTable.rowHeight,
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.space.space4,
                ),
                decoration: BoxDecoration(
                  color:
                      (_hovered || states.contains(WidgetState.hovered)) &&
                          widget.openReason == null
                      ? theme.colors.surfaceHover
                      : null,
                  border: Border(
                    bottom: BorderSide(color: theme.colors.borderSubtle),
                  ),
                ),
                child: ExcludeSemantics(
                  child: _cells(
                    theme,
                    name: Row(
                      spacing: theme.space.space2_5,
                      children: [
                        Icon(
                          IconName.fileText,
                          color: theme.colors.iconSecondary,
                        ),
                        Expanded(
                          child: Text(
                            file.name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            textDirection: _directionOf(file.name),
                            style: theme.typography.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                    location: Text(
                      details.location(file),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.start,
                      style: secondary,
                    ),
                    pages: Text(
                      file.pages == null
                          ? ''
                          : details.format.integer(file.pages!),
                      style: secondary,
                    ),
                    opened: Text(
                      details.when(file),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: secondary,
                    ),
                    badge: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: badge ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: theme.space.space4,
            child: _PinButton(
              pinned: file.pinned,
              visible: _hovered,
              onPressed: widget.onPin,
            ),
          ),
        ],
      ),
    );
  }
}
