import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/comments/comment_time.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The chip's tints of FmComments (`CHIP`, `ICOL`): the mark's own colour for
/// the light ones, and a 16 % tint for a dark one, whose icon takes the colour.
const double _chipTint = 0.16;

/// How dark a mark's colour must be for its chip to take the tint.
const double _chipDark = 0.5;

/// The Comments panel, building block `FmComments.dc.html` (a4-1, a4-2): the
/// heading with the count, Filter and sort and More (summary, Flatten, Hide
/// all), the Status control over the filter row, then the threads under each
/// page's heading, and the note on what mentions do.
///
/// Cards are identified by handle: selecting one selects its mark and shows
/// its page; a mark selected on the page expands its card here. An empty
/// document and a filter without matches show EmptyState (G29, G46).
class CommentsPanel extends ConsumerWidget {
  /// The panel, [width] wide.
  const new({super.key, this.width});

  /// The panel's width; null takes `--panel-w`.
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final list = ref.watch(documentAnnotationsProvider).value;
    final threads = ref.watch(documentThreadsProvider);
    final filters = ref.watch(commentFilterProvider);
    final filter = ref.read(commentFilterProvider.notifier);
    final document = ref.watch(openDocumentProvider);
    final refusal = ref.watch(commentRefusalProvider)?.call(l10n);
    final gate = ref.watch(commentGateProvider).value;
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final resolved = threads.where((t) => t.top.resolved).length;
    final open = threads.length - resolved;
    final people = list?.people ?? const <String>[];
    int? pageOf(int handle) => document?.pageIndexOf(handle);
    final shown = filteredThreads(threads, filters, pageOf);
    final caption = theme.typography.caption.copyWith(
      color: theme.colors.textTertiary,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.commentsTitle,
      child: Container(
        width: width ?? theme.size.panelW,
        decoration: BoxDecoration(
          color: theme.colors.surfacePanel,
          border: BorderDirectional(start: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: FmDocPanel.headingHeight,
              padding: EdgeInsetsDirectional.only(
                start: theme.space.space3,
                end: theme.space.space1_5,
              ),
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: Row(
                spacing: theme.space.space2,
                children: [
                  Text(
                    l10n.commentsTitle,
                    style: theme.typography.panelTitle.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  Badge(label: format.integer(threads.length)),
                  const Spacer(),
                  IconButton(
                    icon: IconName.listFilter,
                    label: l10n.commentsFilter,
                    size: IconButtonSize.xs,
                    active: filters.open,
                    onPressed: () =>
                        filter.set(filters.copyWith(open: !filters.open)),
                  ),
                  const _MoreButton(),
                ],
              ),
            ),
            Container(
              padding: EdgeInsetsDirectional.symmetric(
                vertical: theme.space.space2,
                horizontal: theme.space.space2_5,
              ),
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: theme.space.space1_5,
                children: [
                  SegmentedControl<CommentStatus>(
                    fullWidth: true,
                    semanticLabel: l10n.commentsStatus,
                    value: filters.status,
                    onChanged: (status) =>
                        filter.set(filters.copyWith(status: status)),
                    options: [
                      SegmentOption(
                        value: CommentStatus.open,
                        label: l10n.commentsStatusOpen(format.integer(open)),
                      ),
                      SegmentOption(
                        value: CommentStatus.resolved,
                        label: l10n.commentsStatusResolved(
                          format.integer(resolved),
                        ),
                      ),
                      SegmentOption(
                        value: CommentStatus.all,
                        label: l10n.commentsStatusAll(
                          format.integer(threads.length),
                        ),
                      ),
                    ],
                  ),
                  if (filters.open)
                    _FilterRow(
                      filters: filters,
                      authors: {
                        for (final thread in threads) ?thread.top.author,
                      }.toList(),
                    ),
                ],
              ),
            ),
            if (gate == OpGate.keepsSignatures)
              Padding(
                padding: EdgeInsetsDirectional.all(theme.space.space3),
                child: Text(l10n.commentsCertifiedNote, style: caption),
              ),
            if (list?.truncated ?? false)
              Padding(
                padding: EdgeInsetsDirectional.all(theme.space.space3),
                child: Text(l10n.commentsTruncated, style: caption),
              ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: EmptyState(
                        icon: IconName.messageSquare,
                        title: threads.isEmpty
                            ? l10n.commentsEmptyTitle
                            : l10n.commentsNoMatchTitle,
                        body: threads.isEmpty
                            ? l10n.commentsEmptyBody
                            : l10n.commentsNoMatchBody,
                      ),
                    )
                  : _Threads(threads: shown, people: people, refusal: refusal),
            ),
            Container(
              padding: EdgeInsetsDirectional.symmetric(
                vertical: theme.space.space2,
                horizontal: theme.space.space3,
              ),
              decoration: BoxDecoration(border: Border(top: line)),
              child: Text(l10n.commentsFootnote, style: caption),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width));
  }
}

/// More: export summary, Flatten, Hide all (FmComments's `ellipsis`).
class _MoreButton extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends ConsumerState<_MoreButton> {
  bool _open = false;

  void _close() => setState(() => _open = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = ref.watch(commentsShownProvider).visible;
    final any = ref.watch(documentThreadsProvider).isNotEmpty;
    return Popover(
      open: _open,
      surface: false,
      onDismiss: _close,
      anchor: IconButton(
        icon: IconName.ellipsis,
        label: l10n.commentsMore,
        size: IconButtonSize.xs,
        onPressed: () => setState(() => _open = !_open),
      ),
      child: Menu(
        semanticLabel: l10n.commentsMore,
        autofocus: true,
        items: [
          MenuItem(
            id: 'summary',
            label: l10n.commentsExportSummary,
            icon: IconName.fileOutput,
            disabled: !any,
            disabledReason: any ? null : l10n.commentsEmptyTitle,
          ),
          MenuItem(
            id: 'flatten',
            label: l10n.commentsFlatten,
            icon: IconName.layers,
            disabled: true,
            disabledReason: Feature.flattenComments.disabledReason(context),
          ),
          MenuItem(
            id: 'hide',
            label: shown ? l10n.commentsHideAll : l10n.shellShowComments,
            icon: shown ? IconName.eyeOff : IconName.eye,
          ),
        ],
        onClose: _close,
        onSelected: (item) {
          _close();
          switch (item.id) {
            case 'summary':
              unawaited(
                ref.read(commentCommandsProvider.notifier).exportSummary(),
              );
            case 'hide':
              unawaited(
                ref.read(commentsShownProvider.notifier).show(visible: !shown),
              );
          }
        },
      ),
    );
  }
}

/// Author, Type and Sort (a4-2).
class _FilterRow extends ConsumerWidget {
  const new({required this.filters, required this.authors});

  final CommentFilters filters;
  final List<String> authors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final filter = ref.read(commentFilterProvider.notifier);
    return Row(
      spacing: theme.space.space1_5,
      children: [
        Expanded(
          child: Select<String?>(
            size: FieldSize.sm,
            semanticLabel: l10n.commentsFilterAuthor,
            value: filters.author,
            options: [
              SelectOption(value: null, label: l10n.commentsAllPeople),
              for (final author in authors)
                SelectOption(value: author, label: author),
            ],
            onChanged: (author) =>
                filter.set(filters.copyWith(author: () => author)),
          ),
        ),
        Expanded(
          child: Select<CommentTypeFilter>(
            size: FieldSize.sm,
            semanticLabel: l10n.commentsFilterType,
            value: filters.type,
            options: [
              for (final type in CommentTypeFilter.values)
                SelectOption(value: type, label: l10n.commentTypeName(type)),
            ],
            onChanged: (type) => filter.set(filters.copyWith(type: type)),
          ),
        ),
        Expanded(
          child: Select<CommentSort>(
            size: FieldSize.sm,
            semanticLabel: l10n.commentsFilterSort,
            value: filters.sort,
            options: [
              for (final sort in CommentSort.values)
                SelectOption(value: sort, label: l10n.commentSortName(sort)),
            ],
            onChanged: (sort) => filter.set(filters.copyWith(sort: sort)),
          ),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<CommentFilters>('filters', filters))
      ..add(IterableProperty<String>('authors', authors));
  }
}

/// The cards, under each page's heading in page order.
class _Threads extends ConsumerWidget {
  const new({
    required this.threads,
    required this.people,
    required this.refusal,
  });

  final List<CommentThread> threads;
  final List<String> people;
  final String? refusal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(openDocumentProvider);
    final sort = ref.watch(commentFilterProvider.select((f) => f.sort));
    final selected = ref.watch(commentSelectionProvider);
    final counts = <int, int>{};
    for (final thread in threads) {
      counts.update(thread.top.page, (n) => n + 1, ifAbsent: () => 1);
    }
    int? last;
    final rows = <Widget>[];
    for (final thread in threads) {
      final top = thread.top;
      final page = document?.pageIndexOf(top.page) ?? 0;
      if (sort == CommentSort.page && top.page != last) {
        last = top.page;
        rows.add(
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              theme.space.space1,
              theme.space.space1_5,
              theme.space.space1,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.sidebarPage(format.integer(page + 1)),
                  style: theme.typography.label.copyWith(
                    color: theme.colors.textTertiary,
                  ),
                ),
                Text(
                  format.integer(counts[top.page] ?? 0),
                  style: theme.typography.label.copyWith(
                    color: theme.colors.textTertiary,
                    fontFeatures: theme.typeScale.numericTabular,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final isSelected = selected?.handle == top.handle;
      rows.add(
        _Card(
          key: ValueKey<int>(top.handle),
          thread: thread,
          page: page,
          people: people,
          expanded: isSelected,
          composing: isSelected && selected!.composing && refusal == null,
        ),
      );
    }
    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(
        theme.space.space2,
        theme.space.space1_5,
        theme.space.space2,
        theme.space.space3,
      ),
      children: [
        for (final (i, row) in rows.indexed)
          Padding(
            padding: EdgeInsetsDirectional.only(
              top: i == 0 ? 0 : theme.space.space1_5,
            ),
            child: row,
          ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty<CommentThread>('threads', threads))
      ..add(IterableProperty<String>('people', people))
      ..add(StringProperty('refusal', refusal));
  }
}

class _Card extends ConsumerWidget {
  const new({
    required this.thread,
    required this.page,
    required this.people,
    required this.expanded,
    required this.composing,
    super.key,
  });

  final CommentThread thread;
  final int page;
  final List<String> people;
  final bool expanded;
  final bool composing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final commands = ref.read(commentCommandsProvider.notifier);
    final top = thread.top;
    final author = top.author ?? '';
    final kind = l10n.commentKindName(top.kind);
    final count = thread.replies.length;
    final color = top.color?.color;
    final dark = color != null && color.computeLuminance() < _chipDark;
    final by = top.resolvedBy ?? '';
    final at = switch (top.resolvedAt) {
      final moment? => format.time(moment),
      null => '',
    };
    final quote = top.quote ?? kind;
    final text = top.contents ?? '';
    return CommentCard(
      icon: commentIcon(top.kind),
      chipColor: color == null
          ? theme.colors.surfaceSunken
          : dark
          ? color.withValues(alpha: _chipTint)
          : color,
      iconColor: dark ? color : null,
      author: author,
      time: commentTime(top, format, l10n),
      quote: top.quote == null ? quote : l10n.commentQuote(quote),
      text: text.isEmpty ? null : text,
      replies: [
        for (final reply in thread.replies)
          NoteReply(
            author: reply.author ?? '',
            time: commentTime(reply, format, l10n),
            text: reply.contents ?? '',
            mentions: reply.mentions,
          ),
      ],
      expanded: expanded,
      composing: composing,
      resolvedBy: top.resolved
          ? l10n.commentResolvedBy(bidiIsolate(by), at)
          : null,
      repliesLabel: l10n.commentReplies(count, format.integer(count)),
      semanticLabel: l10n.commentCardLabel(
        bidiIsolate(author),
        kind,
        format.integer(page + 1),
        top.resolved ? 1 : 0,
        count,
        format.integer(count),
      ),
      resolveLabel: l10n.commentResolve,
      replyLabel: l10n.commentReply,
      reopenLabel: l10n.commentReopen,
      replyPlaceholder: l10n.commentReply,
      people: people,
      peopleLabel: l10n.commentPeople,
      onPressed: () {
        ref
            .read(commentSelectionProvider.notifier)
            .select(top.handle, composing: true);
        ref.read(viewerProvider.notifier).goToPage(page);
      },
      onResolve: () => unawaited(commands.resolve(top.handle, resolved: true)),
      onReopen: () => unawaited(commands.resolve(top.handle, resolved: false)),
      onReply: (text) => unawaited(commands.reply(thread, text)),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<CommentThread>('thread', thread))
      ..add(IntProperty('page', page))
      ..add(IterableProperty<String>('people', people))
      ..add(FlagProperty('expanded', value: expanded, ifTrue: 'expanded'))
      ..add(FlagProperty('composing', value: composing, ifTrue: 'composing'));
  }
}

/// a4-5's notice at the top of the canvas: how many comments are hidden, with
/// Show comments.
class CommentsHiddenNotice extends ConsumerWidget {
  /// The notice.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final count = ref.watch(documentThreadsProvider).length;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          theme.space.space3,
          theme.space.space1_5,
          theme.space.space1_5,
          theme.space.space1_5,
        ),
        decoration: BoxDecoration(
          color: theme.colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusMd),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.space.space2_5,
          children: [
            Icon(
              IconName.eyeOff,
              size: theme.density.iconMd,
              color: theme.colors.iconSecondary,
            ),
            Text(
              l10n.commentsHidden(count, format.integer(count)),
              style: theme.typography.body.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
            Button(
              size: ButtonSize.sm,
              onPressed: () => unawaited(
                ref.read(commentsShownProvider.notifier).show(visible: true),
              ),
              child: Text(l10n.shellShowComments),
            ),
          ],
        ),
      ),
    );
  }
}
