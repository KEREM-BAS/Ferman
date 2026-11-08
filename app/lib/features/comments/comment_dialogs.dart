import 'dart:async';

import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/comments/comment_time.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/save/file_exists.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// a4-4's preview column, its box and the page beside the comments.
const double _previewWidth = 260;
const double _previewHeight = 350;
const double _previewPad = 14;
const double _previewPageWidth = 96;
const double _previewGap = 10;

/// a4-4's gaps: between its two columns, and between the rows of the first.
const double _columnsGap = 22;
const double _rowsGap = 14;

/// a4-4's layout cards: their sketch and its parts.
const double _sketchHeight = 76;
const double _sketchPad = 6;
const double _sketchGap = 4;
const double _sketchBar = 5;

/// A preview marker's side (summary.rs draws 12 pt markers on its pages).
const double _markerSide = 12;

/// A marker number's line: as tall as its text.
const double _markerLeading = 1;

/// The preview's text, as the board sets it: 8 px on 1.35, headings 9 px.
const double _previewText = 8;
const double _previewLeading = 1.35;
const double _previewHeading = 9;

/// The PDF layouts in a4-4's order.
const List<SummaryFormat> _layouts = [
  SummaryFormat.pageAndComments,
  SummaryFormat.commentsOnly,
  SummaryFormat.pageThenList,
];

/// The threads a summary with these choices holds, in its order, and the page
/// of each, as indices.
List<(int, CommentThread)> summaryThreads(
  List<CommentThread> threads,
  int? Function(int page) pageOf, {
  required bool open,
  required bool resolved,
  required SummarySort sort,
}) {
  final shown = [
    for (final thread in threads)
      if ((thread.top.resolved ? resolved : open) &&
          pageOf(thread.top.page) != null)
        (pageOf(thread.top.page)!, thread),
  ];
  int when((int, CommentThread) each) =>
      each.$2.top.created?.millisecondsSinceEpoch ?? 0;
  // A stable sort: the file's order breaks ties, as the engine's does.
  mergeSort(
    shown,
    compare: (a, b) => switch (sort) {
      SummarySort.page => a.$1.compareTo(b.$1),
      SummarySort.date => when(a).compareTo(when(b)),
      SummarySort.author => switch ((a.$2.top.author ?? '').compareTo(
        b.$2.top.author ?? '',
      )) {
        0 => a.$1.compareTo(b.$1),
        final order => order,
      },
    },
  );
  return shown;
}

/// a4-4: the comment summary's format, layout, contents, order and paper, with
/// a preview, written as a job once the save panel says where.
class CommentSummaryDialog extends ConsumerStatefulWidget {
  /// The dialog, for the open document.
  const new({super.key});

  @override
  ConsumerState<CommentSummaryDialog> createState() =>
      _CommentSummaryDialogState();
}

class _CommentSummaryDialogState extends ConsumerState<CommentSummaryDialog> {
  bool _csv = false;
  SummaryFormat _layout = SummaryFormat.pageAndComments;
  bool _open = true;
  bool _replies = true;
  bool _resolved = false;
  bool _emptyPages = false;
  SummarySort _sort = SummarySort.page;
  late PaperSize _paper = ref.read(regionProvider).paperSize;

  void _export() {
    ref.read(organizeDialogProvider.notifier).close();
    unawaited(
      ref
          .read(commentCommandsProvider.notifier)
          .exportSummary(
            _csv ? SummaryFormat.csv : _layout,
            open: _open,
            resolved: _resolved,
            replies: _replies,
            emptyPages: _emptyPages,
            sort: _sort,
            paper: _paper,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final dialog = ref.read(organizeDialogProvider.notifier);
    final threads = ref.watch(documentThreadsProvider);
    final resolvedCount = threads.where((t) => t.top.resolved).length;
    final openCount = threads.length - resolvedCount;
    return Dialog(
      title: l10n.summaryTitle,
      size: DialogSize.lg,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: _open || _resolved ? _export : null,
          child: Text(l10n.summaryExport),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _columnsGap,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _rowsGap,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.space1_5,
                  children: [
                    Field.labelOf(context, l10n.summaryFormat),
                    SegmentedControl<bool>(
                      semanticLabel: l10n.summaryFormat,
                      value: _csv,
                      options: [
                        SegmentOption(value: false, label: l10n.saveAsPdf),
                        SegmentOption(value: true, label: l10n.summaryCsv),
                      ],
                      onChanged: (csv) => setState(() => _csv = csv),
                    ),
                  ],
                ),
                Semantics(
                  container: true,
                  label: l10n.summaryLayout,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: theme.space.space2,
                    children: [
                      for (final layout in _layouts)
                        Expanded(
                          child: _LayoutCard(
                            layout: layout,
                            checked: _layout == layout,
                            disabled: _csv,
                            onPressed: () => setState(() => _layout = layout),
                          ),
                        ),
                    ],
                  ),
                ),
                _Pairs(
                  children: [
                    Checkbox(
                      checked: _open,
                      label: l10n.summaryOpen(format.integer(openCount)),
                      onChanged: (value) => setState(() => _open = value),
                    ),
                    Checkbox(
                      checked: _replies,
                      label: l10n.summaryReplies,
                      onChanged: (value) => setState(() => _replies = value),
                    ),
                    Checkbox(
                      checked: _resolved,
                      label: l10n.summaryResolved(
                        format.integer(resolvedCount),
                      ),
                      onChanged: (value) => setState(() => _resolved = value),
                    ),
                    Checkbox(
                      checked: _emptyPages,
                      label: l10n.summaryEmptyPages,
                      // A CSV has a row per comment, so no page shows bare.
                      disabled: _csv,
                      onChanged: (value) => setState(() => _emptyPages = value),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.space2_5,
                  children: [
                    Expanded(
                      child: Select<SummarySort>(
                        size: FieldSize.sm,
                        label: l10n.summarySortBy,
                        value: _sort,
                        options: [
                          SelectOption(
                            value: SummarySort.page,
                            label: l10n.summarySortPage,
                          ),
                          SelectOption(
                            value: SummarySort.date,
                            label: l10n.commentColumnDate,
                          ),
                          SelectOption(
                            value: SummarySort.author,
                            label: l10n.commentColumnAuthor,
                          ),
                        ],
                        onChanged: (sort) => setState(() => _sort = sort),
                      ),
                    ),
                    Expanded(
                      child: Select<PaperSize>(
                        size: FieldSize.sm,
                        label: l10n.summaryPaper,
                        value: _paper,
                        disabled: _csv,
                        options: [
                          SelectOption(
                            value: PaperSize.a4,
                            label: l10n.regionPaperA4,
                          ),
                          SelectOption(
                            value: PaperSize.letter,
                            label: l10n.regionPaperLetter,
                          ),
                        ],
                        onChanged: (paper) => setState(() => _paper = paper),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: _previewWidth,
            child: _SummaryPreview(
              layout: _csv ? SummaryFormat.csv : _layout,
              open: _open,
              resolved: _resolved,
              replies: _replies,
              emptyPages: _emptyPages,
              sort: _sort,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two columns of [children], row by row (the board's 2 × 2 checkboxes).
class _Pairs extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final space = context.ferman.space;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: space.space2,
      children: [
        for (var i = 0; i < children.length; i += 2)
          Row(
            spacing: space.space4,
            children: [
              Expanded(child: children[i]),
              Expanded(
                child: children.elementAtOrNull(i + 1) ?? const SizedBox(),
              ),
            ],
          ),
      ],
    );
  }
}

/// One of a4-4's layouts: a sketch of the page and its comments, its name and
/// what it does, a radio of the Layout group.
class _LayoutCard extends StatelessWidget {
  const new({
    required this.layout,
    required this.checked,
    required this.disabled,
    required this.onPressed,
  });

  final SummaryFormat layout;
  final bool checked;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final (label, sub) = switch (layout) {
      SummaryFormat.commentsOnly => (
        l10n.summaryCommentsOnly,
        l10n.summaryCommentsOnlyHint,
      ),
      SummaryFormat.pageThenList => (
        l10n.summaryPageThenList,
        l10n.summaryPageThenListHint,
      ),
      _ => (l10n.summaryPageAndComments, l10n.summaryPageAndCommentsHint),
    };
    final radius = BorderRadius.circular(theme.radius.radiusMd);
    Widget bar(Color color, double widthFactor) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: SizedBox(
        height: _sketchBar,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(theme.radius.radiusXs),
          ),
        ),
      ),
    );
    final page = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.pageColors.pageBg,
        border: Border.all(
          color: colors.borderDefault,
          width: theme.border.borderWidth,
        ),
      ),
      child: const SizedBox.expand(),
    );
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _sketchGap,
      children: [
        bar(colors.borderStrong, 1),
        bar(colors.borderDefault, 0.7),
        bar(colors.borderStrong, 1),
        bar(colors.borderDefault, 0.6),
      ],
    );
    return FermanInteractive(
      onPressed: onPressed,
      disabled: disabled,
      checked: checked,
      inMutuallyExclusiveGroup: true,
      activateOnEnter: false,
      semanticLabel: '$label, $sub',
      builder: (context, states, _) => FocusRing(
        visible: states.contains(WidgetState.focused),
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: radius,
            border: Border.all(
              color: checked ? colors.accent : colors.borderDefault,
              width: checked
                  ? theme.border.borderWidthStrong
                  : theme.border.borderWidth,
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.all(theme.space.space2_5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space2,
              children: [
                SizedBox(
                  height: _sketchHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(
                        theme.radius.radiusSm,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(_sketchPad),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: _sketchGap,
                        children: switch (layout) {
                          SummaryFormat.commentsOnly => [Expanded(child: list)],
                          SummaryFormat.pageThenList => [Expanded(child: page)],
                          _ => [Expanded(child: page), Expanded(child: list)],
                        },
                      ),
                    ),
                  ),
                ),
                Text(
                  label,
                  style: theme.typography.bodyStrong.copyWith(
                    color: disabled ? colors.textDisabled : colors.textPrimary,
                  ),
                ),
                Text(
                  sub,
                  style: theme.typography.caption.copyWith(
                    color: disabled
                        ? colors.textDisabled
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// a4-4's preview: the first page of the summary the choices give, on white,
/// with the page's numbered markers beside its comments.
// shortcut: the page shows as a blank sheet with its markers, not its picture,
// and only the summary's first page shows (B211); draw both once the engine
// renders a summary page for a preview.
class _SummaryPreview extends ConsumerWidget {
  const new({
    required this.layout,
    required this.open,
    required this.resolved,
    required this.replies,
    required this.emptyPages,
    required this.sort,
  });

  final SummaryFormat layout;
  final bool open;
  final bool resolved;
  final bool replies;
  final bool emptyPages;
  final SummarySort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(openDocumentProvider);
    final name = ref.watch(shellDocumentsProvider).active?.name ?? '';
    final ink = theme.ramps.paper900;
    final base = theme.typography.caption.copyWith(
      fontSize: _previewText,
      height: _previewLeading,
      color: ink,
    );
    final strong = base.copyWith(fontWeight: theme.typeScale.weightSemibold);
    final shown = summaryThreads(
      ref.watch(documentThreadsProvider),
      (page) => document?.pageIndexOf(page),
      open: open,
      resolved: resolved,
      sort: sort,
    );
    // The page a summary starts with: the first with a comment, or the first
    // of all when bare pages show too.
    final first = emptyPages || shown.isEmpty ? 0 : shown.first.$1;
    final onPage = layout == SummaryFormat.csv
        ? shown
        : [
            for (final each in shown)
              if (each.$1 == first) each,
          ];
    String when(AnnotationInfo annotation) =>
        switch (annotation.created ?? annotation.modified) {
          final at? => format.dateTime(at),
          null => '',
        };
    final entries = <Widget>[
      if (layout == SummaryFormat.csv)
        Text(
          [
            l10n.commentColumnPage,
            l10n.commentColumnType,
            l10n.commentColumnAuthor,
            l10n.commentColumnDate,
            l10n.commentColumnText,
          ].join(','),
          style: strong,
        )
      else
        Text(
          '${bidiIsolate(name)} · '
          '${l10n.sidebarPage(format.integer(first + 1))}',
          style: strong.copyWith(fontSize: _previewHeading),
        ),
      if (onPage.isEmpty) Text(l10n.commentsEmptyTitle, style: base),
      for (final (index, (page, thread)) in onPage.indexed)
        if (layout == SummaryFormat.csv)
          Text(
            [
              format.integer(page + 1),
              l10n.commentKindName(thread.top.kind),
              thread.top.author ?? '',
              when(thread.top),
              thread.top.contents ?? '',
            ].join(','),
            style: base,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        else
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: [
                    format.integer(index + 1),
                    ?thread.top.author,
                  ].join(' · '),
                  style: strong,
                ),
                if (when(thread.top) case final at when at.isNotEmpty)
                  TextSpan(text: ' · $at'),
                if (thread.top.contents case final text?)
                  TextSpan(text: '\n$text'),
                if (replies)
                  for (final reply in thread.replies)
                    TextSpan(
                      text:
                          '\n↳ ${reply.author ?? ''}: ${reply.contents ?? ''}',
                      style: base.copyWith(color: theme.ramps.paper700),
                    ),
              ],
            ),
            style: base,
          ),
    ];
    final pageInfo = document?.pages.elementAtOrNull(first);
    final picture =
        layout == SummaryFormat.pageAndComments ||
        layout == SummaryFormat.pageThenList;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2,
      children: entries,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space2,
      children: [
        Field.labelOf(context, l10n.summaryPreview),
        SizedBox(
          height: _previewHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.pageColors.pageBg,
              boxShadow: theme.elevation.shadowPage,
            ),
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(_previewPad),
                child: OverflowBox(
                  alignment: AlignmentDirectional.topStart,
                  maxHeight: double.infinity,
                  child: switch ((picture, pageInfo)) {
                    (true, final page?)
                        when layout == SummaryFormat.pageAndComments =>
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: _previewGap,
                        children: [
                          SizedBox(
                            width: _previewPageWidth,
                            child: _PreviewPage(
                              page: page,
                              threads: onPage,
                              format: format,
                            ),
                          ),
                          Expanded(child: list),
                        ],
                      ),
                    (true, final page?) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: _previewGap,
                      children: [
                        _PreviewPage(
                          page: page,
                          threads: onPage,
                          format: format,
                        ),
                        list,
                      ],
                    ),
                    _ => list,
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<SummaryFormat>('layout', layout))
      ..add(FlagProperty('open', value: open, ifTrue: 'open'))
      ..add(FlagProperty('resolved', value: resolved, ifTrue: 'resolved'))
      ..add(FlagProperty('replies', value: replies, ifTrue: 'replies'))
      ..add(FlagProperty('emptyPages', value: emptyPages, ifTrue: 'empty'))
      ..add(EnumProperty<SummarySort>('sort', sort));
  }
}

/// A preview's page: its outline at the page's shape, with a numbered marker
/// at each comment, never mirrored.
class _PreviewPage extends StatelessWidget {
  const new({required this.page, required this.threads, required this.format});

  final PageInfo page;
  final List<(int, CommentThread)> threads;
  final RegionFormat format;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final number = theme.typography.caption.copyWith(
      fontSize: _previewText - 1,
      height: _markerLeading,
      fontWeight: theme.typeScale.weightSemibold,
      color: theme.ramps.paper900,
    );
    return AspectRatio(
      aspectRatio: page.width / page.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.ramps.paper200,
            width: theme.border.borderWidth,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / page.width;
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  for (final (index, (_, thread)) in threads.indexed)
                    PositionedDirectional(
                      start: (thread.top.rect.left * scale).clamp(
                        0,
                        constraints.maxWidth - _markerSide,
                      ),
                      top: (thread.top.rect.top * scale).clamp(
                        0,
                        constraints.maxHeight - _markerSide,
                      ),
                      child: SizedBox.square(
                        dimension: _markerSide,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                thread.top.color?.color ??
                                theme.ramps.annotYellow,
                            borderRadius: BorderRadius.circular(
                              theme.radius.radiusXs,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              format.integer(index + 1),
                              style: number,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// a4-5b: flattens all comments, or only the resolved ones, into the pages,
/// keeping a commented copy beside the original by default (G146).
class FlattenCommentsDialog extends ConsumerStatefulWidget {
  /// The dialog for [document].
  const new({required this.document, super.key});

  /// The document.
  final OpenedDocument document;

  @override
  ConsumerState<FlattenCommentsDialog> createState() =>
      _FlattenCommentsDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<OpenedDocument>('document', document));
  }
}

class _FlattenCommentsDialogState extends ConsumerState<FlattenCommentsDialog> {
  bool _resolvedOnly = false;
  bool _keepCopy = true;

  /// The copy's path: the first free name beside the original; null until
  /// known, or for a document with no file.
  String? _copy;

  ShellDocument? get _tab => ref
      .read(shellDocumentsProvider)
      .documents
      .where((tab) => tab.document?.id == widget.document.id)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    unawaited(_findCopy());
  }

  Future<void> _findCopy() async {
    final path = _tab?.path;
    if (path == null) return;
    final l10n = lookupAppLocalizations(ref.read(appLocaleProvider));
    final stem = fileName(path)
        .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
    final folder = folderOf(path);
    String name(int number) => number == 1
        ? '${l10n.flattenCopyName(stem)}.pdf'
        : '${l10n.flattenCopyNameNumbered(stem, number)}.pdf';
    var number = 1;
    while (await fileExists(pathIn(folder, name(number)))) {
      number++;
    }
    if (mounted) setState(() => _copy = pathIn(folder, name(number)));
  }

  /// Whether a copy is written first: never for a document with no file.
  bool get _keep => _keepCopy && _tab?.path != null;

  void _flatten(List<int> handles, String step) {
    final copy = _keep ? _copy : null;
    final name = _tab?.name ?? '';
    final jobs = ref.read(backgroundJobsProvider.notifier);
    final id = widget.document.id;
    afterSigned(
      ref,
      widget.document,
      () => unawaited(
        jobs.flattenComments(id, name, handles, step: step, copy: copy),
      ),
    );
    ref.read(organizeDialogProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final dialog = ref.read(organizeDialogProvider.notifier);
    final threads = ref.watch(documentThreadsProvider);
    final resolved = [
      for (final thread in threads)
        if (thread.top.resolved) thread.top.handle,
    ];
    final all = [for (final thread in threads) thread.top.handle];
    final handles = _resolvedOnly ? resolved : all;
    final count = handles.length;
    final copy = _copy;
    return Dialog(
      title: l10n.flattenTitle(count, format.integer(count)),
      description: l10n.flattenBody,
      icon: IconName.layers,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          // The copy's name comes first: a kept copy is never left out.
          onPressed: count > 0 && (!_keep || copy != null)
              ? () => _flatten(handles, l10n.commentStepFlatten)
              : null,
          child: Text(l10n.flattenAction(count, format.integer(count))),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space2_5,
        children: [
          Radio<bool>(
            value: false,
            groupValue: _resolvedOnly,
            label: l10n.flattenAll(all.length, format.integer(all.length)),
            onChanged: (value) => setState(() => _resolvedOnly = value),
          ),
          Radio<bool>(
            value: true,
            groupValue: _resolvedOnly,
            label: l10n.flattenResolved(
              resolved.length,
              format.integer(resolved.length),
            ),
            disabled: resolved.isEmpty,
            onChanged: (value) => setState(() => _resolvedOnly = value),
          ),
          Checkbox(
            checked: _keep,
            label: l10n.flattenKeepCopy,
            description: copy == null
                ? null
                : l10n.flattenKeepCopyHint(bidiIsolate(fileName(copy))),
            disabled: _tab?.path == null,
            onChanged: (value) => setState(() => _keepCopy = value),
          ),
        ],
      ),
    );
  }
}
