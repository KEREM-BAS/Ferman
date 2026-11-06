import 'dart:async';
import 'dart:ui' as ui;

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/attachment_save.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/page_thumbnails.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The label of [page] (from 0) of [document]: its page label, else its
/// number in the region's digits.
String pageLabel(OpenedDocument document, int page, RegionFormat format) =>
    (page < document.pages.length ? document.pages[page].label : null) ??
    format.integer(page + 1);

/// A scroll controller for [tab]'s list that starts where the open
/// document's list was left and keeps its offset in the document's
/// [SidebarMemory].
ScrollController _rememberedScroll(WidgetRef ref, SidebarTab tab) {
  final document = ref.read(viewerProvider)?.document;
  if (document == null) return ScrollController();
  final offsets = ref
      .read(documentMemoryProvider(document.id))
      .keep(SidebarMemory.new)
      .offsets;
  final controller = ScrollController(initialScrollOffset: offsets[tab] ?? 0);
  return controller..addListener(() {
    // Not in dispose: the position is detached by then.
    if (controller.hasClients) offsets[tab] = controller.offset;
  });
}

/// The Pages tab (a2-3p): a thumbnail of every page, the reader's page
/// selected; a click or Enter goes to the page, and the arrow keys move
/// between thumbnails ([PageThumbnails]). Badges arrive with their features
/// (f5).
class SidebarPages extends ConsumerStatefulWidget {
  /// The pages of `viewerProvider`'s document.
  const new({super.key});

  /// `FmSidebar` thumbnails: `width="{{ 104 }}"`.
  static const double thumbnailWidth = 104;

  @override
  ConsumerState<SidebarPages> createState() => _SidebarPagesState();
}

class _SidebarPagesState extends ConsumerState<SidebarPages>
    with PageThumbnails {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = _rememberedScroll(ref, SidebarTab.pages);
    startThumbnails();
  }

  @override
  void dispose() {
    _scroll.dispose();
    stopThumbnails();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(viewerProvider.select((v) => v?.document));
    final current = ref.watch(viewerProvider.select((v) => v?.currentPage));
    // a3-4's warning badge: lines "Keep and warn" hides, by page.
    final hidden = <int, int>{};
    for (final mark in ref.watch(
      documentEditorProvider.select((s) => s.hidden),
    )) {
      hidden[mark.page] = (hidden[mark.page] ?? 0) + mark.lines;
    }
    if (document == null) return const SizedBox.shrink();
    final viewer = ref.read(viewerProvider.notifier);
    final invalidated = ref.watch(
      documentEditorProvider.select((s) => s.history.signatureInvalidated),
    );
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsetsDirectional.only(
        top: theme.space.space1,
        bottom: theme.space.space3,
      ),
      itemCount: document.pages.length,
      // Each thumbnail moves with its page, and its bitmap with it.
      findChildIndexCallback: (key) =>
          key is ValueKey<int> ? document.pageIndexOf(key.value) : null,
      itemBuilder: (context, index) {
        final page = document.pages[index];
        final label = pageLabel(document, index, format);
        final handle = document.pageHandle(index);
        return Padding(
          key: ValueKey(handle),
          padding: EdgeInsetsDirectional.only(
            top: index == 0 ? 0 : theme.space.space1_5,
          ),
          child: Center(
            child: ThumbnailReporter(
              handle: handle,
              onBuilt: thumbnailBuilt,
              onGone: thumbnailGone,
              child: PageThumbnail(
                page: index + 1,
                label: label,
                width: SidebarPages.thumbnailWidth,
                aspect: page.width > 0 ? page.height / page.width : 1,
                selected: index == current,
                semanticLabel: l10n.sidebarPage(label),
                onPressed: () => viewer.goToPage(index),
                badges: switch (hidden[index]) {
                  final lines? => ThumbnailBadges(
                    badges: const {ThumbnailBadge.warnings},
                    tooltips: {
                      ThumbnailBadge.warnings: l10n.editOverflowHidden(
                        lines,
                        format.integer(lines),
                      ),
                    },
                  ),
                  // a3-16b: the signature's page once a change breaks it.
                  null
                      when invalidated &&
                          document.signatures.any(
                            (field) => field.signed && field.page == index,
                          ) =>
                    ThumbnailBadges(
                      badges: const {ThumbnailBadge.warnings},
                      tooltips: {
                        ThumbnailBadge.warnings: l10n.signedBannerTitle(1),
                      },
                    ),
                  null => null,
                },
                child: switch (thumbnailOf(handle)) {
                  final image? => RawImage(image: image, fit: BoxFit.fill),
                  // A blank page until the thumbnail arrives, never the
                  // placeholder lines, which would look like content.
                  null => const SizedBox.expand(),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The Outline tab (a2-3o, a2-3a): the bookmarks, nested, each parent open
/// as the document says until the reader toggles it with its chevron or
/// the arrow keys (→ opens, ← closes, mirrored in right to left). The
/// current section, the last shown bookmark at or before the reader's
/// page, is tinted. A click or Enter goes to the bookmark's page.
class SidebarOutline extends ConsumerStatefulWidget {
  /// The outline of `viewerProvider`'s document.
  const new({super.key});

  /// `height:28px`.
  static const double rowHeight = 28;

  /// The space between rows: `gap:1px`.
  static const double rowGap = 1;

  /// Each level's indent: `8 + depth * 18` px.
  static const double indent = 18;

  /// The chevron: `size 12`, `stroke-width 2`.
  static const double chevronSize = 12;

  /// The chevron's stroke.
  static const double chevronStroke = 2;

  @override
  ConsumerState<SidebarOutline> createState() => _SidebarOutlineState();
}

class _SidebarOutlineState extends ConsumerState<SidebarOutline> {
  /// The parents the reader closed or opened against the document's state,
  /// kept with the document.
  late final Set<int> _toggled = switch (ref.read(viewerProvider)?.document) {
    final document? =>
      ref
          .read(documentMemoryProvider(document.id))
          .keep(SidebarMemory.new)
          .outlineToggled,
    null => {},
  };

  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = _rememberedScroll(ref, SidebarTab.outline);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(viewerProvider.select((v) => v?.document));
    final current = ref.watch(viewerProvider.select((v) => v?.currentPage));
    if (document == null) return const SizedBox.shrink();
    final outline = document.outline;
    if (outline.isEmpty) {
      return EmptyState(
        icon: IconName.listTree,
        title: l10n.sidebarNoBookmarks,
        body: l10n.sidebarNoBookmarksBody,
      );
    }
    bool isParent(int index) =>
        index + 1 < outline.length &&
        outline[index + 1].depth > outline[index].depth;
    bool isOpen(int index) => outline[index].open != _toggled.contains(index);

    // The rows shown: everything but the children of closed parents.
    final rows = <int>[];
    int? closedDepth;
    for (var index = 0; index < outline.length; index++) {
      final depth = outline[index].depth;
      if (closedDepth != null && depth > closedDepth) continue;
      closedDepth = isParent(index) && !isOpen(index) ? depth : null;
      rows.add(index);
    }
    final currentRow = current == null
        ? null
        : rows.lastWhere(
            (index) => (outline[index].page ?? current + 1) <= current,
            orElse: () => -1,
          );

    void toggle(int index) => setState(() {
      if (!_toggled.remove(index)) _toggled.add(index);
    });

    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsetsDirectional.symmetric(
        vertical: theme.space.space0_5,
        horizontal: theme.space.space1_5,
      ),
      itemCount: rows.length,
      itemBuilder: (context, row) {
        final index = rows[row];
        final entry = outline[index];
        final parent = isParent(index);
        final open = parent && isOpen(index);
        final isCurrent = index == currentRow;
        final page = entry.page;
        final color = isCurrent
            ? theme.colors.textAccent
            : theme.colors.textPrimary;
        final forward = rtl
            ? LogicalKeyboardKey.arrowLeft
            : LogicalKeyboardKey.arrowRight;
        final back = rtl
            ? LogicalKeyboardKey.arrowRight
            : LogicalKeyboardKey.arrowLeft;
        return Padding(
          padding: EdgeInsetsDirectional.only(
            top: row == 0 ? 0 : SidebarOutline.rowGap,
          ),
          child: CallbackShortcuts(
            bindings: {
              if (parent && !open)
                SingleActivator(forward): () => toggle(index),
              if (parent && open) SingleActivator(back): () => toggle(index),
            },
            child: Semantics(
              expanded: parent ? open : null,
              child: FermanInteractive(
                semanticLabel: entry.title,
                selected: isCurrent,
                onPressed: page == null
                    ? null
                    : () => ref.read(viewerProvider.notifier).goToPage(page),
                builder: (context, states, _) => FocusRing(
                  visible: states.contains(WidgetState.focused),
                  style: FocusRingStyle.inset,
                  borderRadius: BorderRadius.circular(theme.radius.radiusSm),
                  child: Container(
                    height: SidebarOutline.rowHeight,
                    padding: EdgeInsetsDirectional.only(
                      start:
                          theme.space.space2 +
                          entry.depth * SidebarOutline.indent,
                      end: theme.space.space2,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.colors.surfaceSelected
                          : states.contains(WidgetState.hovered)
                          ? theme.colors.surfaceHover
                          : null,
                      borderRadius: BorderRadius.circular(
                        theme.radius.radiusSm,
                      ),
                    ),
                    child: Row(
                      spacing: theme.space.space1_5,
                      children: [
                        SizedBox.square(
                          dimension: SidebarOutline.chevronSize,
                          child: parent
                              ? GestureDetector(
                                  onTap: () => toggle(index),
                                  child: RotatedBox(
                                    // Closed points to the reading end.
                                    quarterTurns: open ? 0 : (rtl ? 1 : 3),
                                    child: Icon(
                                      IconName.chevronDown,
                                      size: SidebarOutline.chevronSize,
                                      strokeWidth: SidebarOutline.chevronStroke,
                                      color: theme.colors.iconSecondary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            // The document's own text keeps its direction
                            // in a right-to-left UI: "4.1 Yıllık artış".
                            bidiIsolate(entry.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.body.copyWith(color: color),
                          ),
                        ),
                        if (page != null)
                          Text(
                            pageLabel(document, page, format),
                            style: theme.typography.body.copyWith(
                              color: theme.colors.textTertiary,
                              fontFeatures: theme.typeScale.numericTabular,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A caption under a tab's list (a2-3b, a2-3c).
class _Note extends StatelessWidget {
  const new(this.text, {required this.padding});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.typography.caption.copyWith(
          color: theme.colors.textTertiary,
        ),
      ),
    );
  }
}

/// A raised card of the Attachments and Signatures tabs.
class _Card extends StatelessWidget {
  const new({required this.padding, required this.child});

  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Container(
      padding: EdgeInsetsDirectional.all(padding),
      decoration: BoxDecoration(
        color: theme.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(theme.radius.radiusMd),
        border: Border.all(
          color: theme.colors.borderSubtle,
          width: theme.border.borderWidth,
        ),
      ),
      child: child,
    );
  }
}

/// The icon of an attachment's file type (a2-3b).
IconName _fileIcon(String name) {
  final dot = name.lastIndexOf('.');
  final extension = dot < 0
      ? ''
      : LocaleCasing.root.lower(name.substring(dot + 1));
  return switch (extension) {
    'xls' || 'xlsx' || 'ods' || 'csv' || 'numbers' => IconName.fileSpreadsheet,
    'png' ||
    'jpg' ||
    'jpeg' ||
    'gif' ||
    'tif' ||
    'tiff' ||
    'bmp' ||
    'webp' ||
    'heic' => IconName.fileImage,
    _ => IconName.fileText,
  };
}

/// The Attachments tab (a2-3b): each embedded file with its size and date.
/// Embedded files are never opened; Save attachment as… writes one where
/// the system save panel says ([AttachmentSaver], B110).
class SidebarAttachments extends ConsumerWidget {
  /// The attachments of `viewerProvider`'s document.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(viewerProvider.select((v) => v?.document));
    final files = document?.attachments;
    if (files == null) return const SizedBox.shrink();
    if (files.isEmpty) {
      return EmptyState(
        icon: IconName.paperclip,
        title: l10n.sidebarNoAttachments,
        body: l10n.sidebarNoAttachmentsBody,
      );
    }
    return ListView(
      padding: EdgeInsetsDirectional.symmetric(
        vertical: theme.space.space0_5,
        horizontal: theme.space.space2,
      ),
      children: [
        for (final (index, file) in files.indexed) ...[
          _Card(
            padding: theme.space.space2,
            child: Row(
              spacing: theme.space.space2_5,
              children: [
                Icon(_fileIcon(file.name), color: theme.colors.iconSecondary),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.bodyStrong.copyWith(
                          color: theme.colors.textPrimary,
                        ),
                      ),
                      Text(
                        [
                          if (file.size case final size?) format.fileSize(size),
                          if (file.modified case final date?) format.date(date),
                        ].join(' · '),
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.textTertiary,
                          fontFeatures: theme.typeScale.numericTabular,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: IconName.download,
                  label: l10n.sidebarSaveAttachment,
                  size: IconButtonSize.xs,
                  onPressed: () => unawaited(
                    ref
                        .read(attachmentSaverProvider.notifier)
                        .save(document!.id, index, file.name),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: theme.space.space1_5),
        ],
        _Note(
          l10n.sidebarAttachmentsNote,
          padding: EdgeInsetsDirectional.symmetric(
            vertical: theme.space.space1,
            horizontal: theme.space.space0_5,
          ),
        ),
      ],
    );
  }
}

/// The Layers tab (a2-3c): each layer as the document shows it by
/// default, dimmed when hidden, with a lock when the document locks it.
class SidebarLayers extends ConsumerWidget {
  /// The layers of `viewerProvider`'s document.
  const new({super.key});

  /// `height:30px`.
  static const double rowHeight = 30;

  /// The lock: `size 12`, `stroke-width 2`.
  static const double lockSize = 12;

  /// The lock's stroke.
  static const double lockStroke = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final document = ref.watch(viewerProvider.select((v) => v?.document));
    final visible = ref.watch(
      layerVisibilityProvider.select((s) => s?.visible),
    );
    if (document == null) return const SizedBox.shrink();
    final layers = document.layers;
    if (layers.isEmpty) {
      return EmptyState(
        icon: IconName.layers,
        title: l10n.sidebarNoLayers,
        body: l10n.sidebarNoLayersBody,
      );
    }
    Widget row(int index, Layer layer) {
      final shown = visible != null && index < visible.length
          ? visible[index]
          : layer.visible;
      // A locked layer's state is the document's to keep (§8.11.4.3).
      final reason = !document.layersSwitchable
          ? Feature.layerVisibility.disabledReason(context)
          : layer.locked
          ? l10n.sidebarLayerLocked
          : null;
      return Container(
        height: rowHeight,
        margin: const EdgeInsetsDirectional.only(bottom: SidebarOutline.rowGap),
        padding: EdgeInsetsDirectional.only(
          start: theme.space.space1,
          end: theme.space.space2,
        ),
        child: Row(
          spacing: theme.space.space1_5,
          children: [
            IconButton(
              icon: shown ? IconName.eye : IconName.eyeOff,
              label: shown ? l10n.sidebarHideLayer : l10n.sidebarShowLayer,
              size: IconButtonSize.xs,
              disabledReason: reason,
              onPressed: reason == null
                  ? () => unawaited(
                      ref
                          .read(layerVisibilityProvider.notifier)
                          .show(index, visible: !shown),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                layer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.copyWith(
                  color: shown
                      ? theme.colors.textPrimary
                      : theme.colors.textTertiary,
                ),
              ),
            ),
            if (layer.locked)
              Icon(
                IconName.lock,
                size: lockSize,
                strokeWidth: lockStroke,
                color: theme.colors.iconSecondary,
                semanticLabel: l10n.sidebarLayerLocked,
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsetsDirectional.symmetric(
        vertical: theme.space.space0_5,
        horizontal: theme.space.space1_5,
      ),
      children: [
        for (final (index, layer) in layers.indexed) row(index, layer),
        _Note(
          l10n.sidebarLayersNote,
          padding: EdgeInsetsDirectional.symmetric(
            vertical: theme.space.space2,
            horizontal: theme.space.space1_5,
          ),
        ),
      ],
    );
  }
}

/// The Signatures tab in a2-14's neutral state (G31): each signature field
/// with the signer's name as the file writes it, when it was signed and its
/// page, never a validity colour or check until signatures are checked
/// (P3).
class SidebarSignatures extends ConsumerWidget {
  /// The signature fields of `viewerProvider`'s document.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(viewerProvider.select((v) => v?.document));
    if (document == null) return const SizedBox.shrink();
    final fields = document.signatures;
    if (fields.isEmpty) {
      return EmptyState(
        icon: IconName.signature,
        title: l10n.sidebarNoSignatures,
        body: l10n.sidebarNoSignaturesBody,
      );
    }
    return ListView(
      padding: EdgeInsetsDirectional.symmetric(
        vertical: theme.space.space0_5,
        horizontal: theme.space.space2,
      ),
      children: [
        for (final field in fields) ...[
          _Card(
            padding: theme.space.space2_5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space1,
              children: [
                Row(
                  spacing: theme.space.space2,
                  children: [
                    Icon(IconName.signature, color: theme.colors.iconSecondary),
                    Expanded(
                      child: Text(
                        field.signed
                            ? field.signer ?? field.field
                            : field.field,
                        style: theme.typography.bodyStrong.copyWith(
                          color: theme.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  field.signed
                      ? l10n.sidebarSignatureCheckingLater
                      : l10n.sidebarEmptySignatureField,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textSecondary,
                  ),
                ),
                if ([
                      if (field.signedAt case final date?)
                        format.dateTime(date),
                      if (field.page case final page?)
                        l10n.sidebarPage(pageLabel(document, page, format)),
                    ].join(' · ')
                    case final meta when meta.isNotEmpty)
                  Text(
                    meta,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textTertiary,
                      fontFeatures: theme.typeScale.numericTabular,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: theme.space.space2),
        ],
      ],
    );
  }
}

/// The Search results tab (a2-3e, a2-4b): the query, a summary, and every
/// match so far grouped by page, its line as a snippet with the match
/// marked, the current one tinted; a click goes to it, and ↑ and ↓ move
/// through the results from one of them. A search that found nothing shows
/// a2-3m's empty state, or its "No text to search" in a document without
/// a text layer. It shares `findProvider` with the
/// find bar, so typing in either searches.
class SidebarSearch extends ConsumerStatefulWidget {
  /// The results of `findProvider`.
  const new({super.key});

  /// Characters of the line kept before a match (`…aylık kira`).
  static const int before = 16;

  /// Characters kept after it.
  static const int after = 28;

  /// `font: 400 12px/17px var(--font-doc-sample)`.
  static const double snippetSize = 12;

  /// The snippet's line height.
  static const double snippetHeight = 17 / 12;

  @override
  ConsumerState<SidebarSearch> createState() => _SidebarSearchState();
}

class _SidebarSearchState extends ConsumerState<SidebarSearch> {
  late final ScrollController _scroll;

  /// The results' focus, by index, so ↑ and ↓ move it with the current one.
  final List<FocusNode> _results = [];

  FocusNode _result(int index) {
    while (_results.length <= index) {
      _results.add(FocusNode(debugLabel: 'Search result'));
    }
    return _results[index];
  }

  /// Makes the result [by] away from the current one current and focuses
  /// it; the list builds its neighbours, so the node is attached.
  void _move(int by) {
    final find = ref.read(findProvider);
    final index = find.current + by;
    if (index < 0 || index >= find.matches.length) return;
    ref.read(findProvider.notifier).select(index);
    final node = _result(index)..requestFocus();
    if (node.context case final context?) {
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: by > 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll = _rememberedScroll(ref, SidebarTab.search);
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _results) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final find = ref.watch(findProvider);
    final notifier = ref.read(findProvider.notifier);
    final pages = {for (final match in find.matches) match.page}.length;
    final field = Padding(
      padding: EdgeInsetsDirectional.only(
        start: theme.space.space2,
        end: theme.space.space2,
        bottom: theme.space.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: theme.space.space1_5,
        children: [
          _QueryField(
            query: find.query,
            label: l10n.sidebarSearchField,
            onChanged: notifier.setQuery,
          ),
          if (find.matches.isNotEmpty)
            Text(
              l10n.sidebarSearchSummary(
                find.matches.length,
                format.integer(find.matches.length),
                pages,
                format.integer(pages),
              ),
              style: theme.typography.caption.copyWith(
                color: theme.colors.textTertiary,
              ),
            ),
        ],
      ),
    );
    if (find.done && find.hasQuery && find.matches.isEmpty) {
      return Column(
        children: [
          field,
          Expanded(
            child: find.textless
                ? EmptyState(
                    icon: IconName.scanText,
                    title: l10n.sidebarSearchNoTextTitle,
                    body: l10n.sidebarSearchNoTextBody,
                    action: Button(
                      size: ButtonSize.sm,
                      icon: IconName.scanText,
                      disabled: true,
                      disabledReason: Feature.ocr.disabledReason(context),
                      child: Text(l10n.shellToolRecognizeText),
                    ),
                  )
                : EmptyState(
                    icon: IconName.search,
                    title: l10n.findNoneTitle(find.query.trim()),
                    body:
                        (find.options.ignoreAccents
                        ? l10n.findNoneBody
                        : l10n.findNoneBodyExact)(
                          find.pages,
                          format.integer(find.pages),
                        ),
                  ),
          ),
        ],
      );
    }
    final rows = <Widget>[];
    for (final (index, match) in find.matches.indexed) {
      if (index == 0 || find.matches[index - 1].page != match.page) {
        final count = find.matches.where((m) => m.page == match.page).length;
        rows.add(
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              theme.space.space1_5,
              theme.space.space2,
              theme.space.space1_5,
              theme.space.space0_5,
            ),
            child: Semantics(
              header: true,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      LocaleCasing.of(
                        context,
                      ).upper(l10n.sidebarPage(format.integer(match.page + 1))),
                      style: theme.typography.label.copyWith(
                        color: theme.colors.textTertiary,
                      ),
                    ),
                  ),
                  Text(
                    format.integer(count),
                    style: theme.typography.label.copyWith(
                      color: theme.colors.textTertiary,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      rows.add(
        _Result(
          match: match,
          current: index == find.current,
          focusNode: _result(index),
          // A click focuses the result too, so ↑ and ↓ go on from it.
          onPressed: () {
            notifier.select(index);
            _result(index).requestFocus();
          },
        ),
      );
    }
    return Column(
      children: [
        field,
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  _move(1),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  _move(-1),
            },
            child: ListView(
              controller: _scroll,
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space1_5,
              ),
              children: rows,
            ),
          ),
        ),
      ],
    );
  }
}

/// The tab's search field, which follows the find bar's query.
class _QueryField extends StatefulWidget {
  const new({
    required this.query,
    required this.label,
    required this.onChanged,
  });

  final String query;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_QueryField> createState() => _QueryFieldState();
}

class _QueryFieldState extends State<_QueryField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );

  @override
  void didUpdateWidget(_QueryField old) {
    super.didUpdateWidget(old);
    if (widget.query != _controller.text) _controller.text = widget.query;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    size: FieldSize.sm,
    icon: IconName.search,
    semanticLabel: widget.label,
    controller: _controller,
    onChanged: widget.onChanged,
  );
}

/// One result: its line around the match, the match marked.
class _Result extends StatelessWidget {
  const new({
    required this.match,
    required this.current,
    required this.focusNode,
    required this.onPressed,
  });

  final SearchMatch match;
  final bool current;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final line = match.snippet;
    final start = match.snippetStart.clamp(0, line.length);
    final end = match.snippetEnd.clamp(start, line.length);
    final from = (start - SidebarSearch.before).clamp(0, start);
    final to = (end + SidebarSearch.after).clamp(end, line.length);
    final pre = '${from > 0 ? '…' : ''}${line.substring(from, start)}';
    final post = '${line.substring(end, to)}${to < line.length ? '…' : ''}';
    final style = TextStyle(
      fontFamily: theme.typography.body.fontFamily,
      fontFamilyFallback: theme.typography.body.fontFamilyFallback,
      fontSize: SidebarSearch.snippetSize,
      height: SidebarSearch.snippetHeight,
      color: theme.colors.textSecondary,
    );
    return FermanInteractive(
      onPressed: onPressed,
      selected: current,
      focusNode: focusNode,
      semanticLabel: match.bookmark
          ? AppLocalizations.of(context).sidebarSearchBookmark(line)
          : line,
      builder: (context, states, _) => Container(
        padding: EdgeInsetsDirectional.symmetric(
          vertical: theme.space.space1_5,
          horizontal: theme.space.space2,
        ),
        decoration: BoxDecoration(
          color: current
              ? theme.colors.surfaceSelected
              : states.contains(WidgetState.hovered)
              ? theme.colors.surfaceHover
              : null,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusSm),
          ),
        ),
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              // A match in a bookmark's title (Look in › Bookmarks, B114).
              if (match.bookmark)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: theme.space.space1,
                    ),
                    child: Icon(
                      IconName.bookmark,
                      size: theme.density.iconSm,
                      color: theme.colors.iconSecondary,
                    ),
                  ),
                ),
              TextSpan(text: pre),
              TextSpan(
                text: line.substring(start, end),
                style: TextStyle(
                  background: Paint()..color = theme.pageColors.searchMatch,
                  color: theme.colors.textPrimary,
                ),
              ),
              TextSpan(text: post),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
