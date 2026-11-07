import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/shell/document_parts.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_sidebar_tabs.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sidebar on the start side (building block `FmSidebar.dc.html`):
/// `--sidebar-w` wide on the panel surface with a subtle line on its end
/// side, holding the six tabs as an icon-only SegmentedControl over an
/// [IndexedStack] (never a `TabBarView`, ADR 0011), the tab's heading with
/// its count and buttons, and the tab's content.
///
/// With a document open (`viewerProvider`) the tabs show its pages,
/// outline, attachments, layers and signatures ([SidebarPages] and the
/// others), each heading counting its list; the contents are keyed by the
/// document, so another document starts afresh. The shell's placeholder
/// documents keep the M1 sidebar: empty contents, the Pages heading
/// counting their pages. Pages' info button opens f5's badge legend under
/// the heading; Outline's Add bookmark and More (a2-3a) and Attachments'
/// Attach a file (a2-3b) change the document, each disabled with the reason
/// while it cannot change.
class FmSidebar extends ConsumerStatefulWidget {
  /// The sidebar.
  const new({super.key, this.width});

  /// The sidebar's width; null takes its FmWindow width. The shell passes
  /// the width the user dragged it to (B094).
  final double? width;

  /// FmSidebar's heading row: `height: 34px`.
  static const double headingHeight = 34;

  /// The key of [tab]'s content, for tests.
  static ValueKey<String> keyOf(SidebarTab tab) =>
      ValueKey('shell-sidebar-${tab.name}');

  @override
  ConsumerState<FmSidebar> createState() => _FmSidebarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width, defaultValue: null));
  }
}

class _FmSidebarState extends ConsumerState<FmSidebar> {
  /// Whether the badge legend is open (f5).
  bool _legend = false;

  /// Whether the Outline tab's More menu is open.
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final keys = ref.watch(shortcutBindingsProvider);
    final tab = ref.watch(shellSidebarTabProvider);
    final document = ref.watch(viewerProvider.select((v) => v?.document));
    final pages =
        document?.pages.length ??
        ref.watch(shellDocumentsProvider).active?.pageCount;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );

    final organize = document == null
        ? null
        : ref.watch(organizeRefusalProvider)?.call(l10n);
    final modify = document == null
        ? null
        : ref.watch(modifyRefusalProvider)?.call(l10n);

    IconButton button(
      IconName icon,
      String label, {
      required String? refusal,
      VoidCallback? onPressed,
      List<String>? shortcut,
      bool? active,
    }) => IconButton(
      icon: icon,
      label: label,
      size: IconButtonSize.xs,
      shortcut: shortcut,
      active: active,
      onPressed: refusal == null ? onPressed : null,
      disabledReason: refusal,
    );

    final buttons = switch (tab) {
      SidebarTab.pages => [
        button(
          IconName.info,
          l10n.shellPageBadgesLegend,
          refusal: null,
          active: _legend,
          onPressed: () => setState(() => _legend = !_legend),
        ),
      ],
      SidebarTab.outline => [
        button(
          IconName.plus,
          l10n.shellAddBookmark,
          refusal: organize,
          shortcut: keys.caps(ShellCommand.addBookmark),
          // The shell's placeholder documents take no change.
          onPressed: document == null ? null : () => addBookmark(ref),
        ),
        Popover(
          open: _more,
          surface: false,
          onDismiss: () => setState(() => _more = false),
          anchor: button(
            IconName.ellipsis,
            l10n.shellMore,
            refusal: organize,
            active: _more,
            // Without a bookmark to act on, its items are disabled.
            onPressed: () => setState(() => _more = !_more),
          ),
          child: _outlineMenu(context, l10n, document),
        ),
      ],
      SidebarTab.attachments => [
        button(
          IconName.plus,
          l10n.shellAttachFile,
          refusal: modify,
          onPressed: document == null
              ? null
              : () => unawaited(attachFile(ref, l10n, document.id)),
        ),
      ],
      SidebarTab.layers ||
      SidebarTab.signatures ||
      SidebarTab.search => const <Widget>[],
    };
    final listed = switch (tab) {
      SidebarTab.pages => pages,
      SidebarTab.attachments => document?.attachments.length,
      SidebarTab.layers => document?.layers.length,
      SidebarTab.signatures => document?.signatures.length,
      SidebarTab.search => ref.watch(
        findProvider.select((find) => find.matches.length),
      ),
      SidebarTab.outline => null,
    };
    final count = listed != null && listed > 0 ? format.integer(listed) : null;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.shellSidebar,
      child: Container(
        width: widget.width ?? theme.size.sidebarW,
        decoration: BoxDecoration(
          color: theme.colors.surfacePanel,
          border: BorderDirectional(end: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsetsDirectional.all(theme.space.space2),
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: SegmentedControl<SidebarTab>(
                semanticLabel: l10n.shellSidebar,
                fullWidth: true,
                value: tab,
                onChanged: ref.read(shellSidebarTabProvider.notifier).select,
                options: [
                  for (final each in SidebarTab.values)
                    SegmentOption(
                      value: each,
                      icon: each.icon,
                      tooltip: l10n.sidebarTabLabel(each),
                    ),
                ],
              ),
            ),
            Popover(
              open: _legend && tab == SidebarTab.pages,
              surface: false,
              onDismiss: () => setState(() => _legend = false),
              anchor: _heading(context, tab, count, buttons),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: theme.space.space2_5,
                ),
                child: ThumbnailBadgeLegend(
                  title: l10n.sidebarLegendTitle,
                  footnote: l10n.sidebarLegendFootnote,
                  entries: {
                    ThumbnailBadge.edited: (
                      name: l10n.sidebarLegendEdited,
                      description: l10n.sidebarLegendEditedBody,
                    ),
                    ThumbnailBadge.comments: (
                      name: l10n.sidebarLegendComments,
                      description: l10n.sidebarLegendCommentsBody,
                    ),
                    ThumbnailBadge.formFields: (
                      name: l10n.sidebarLegendFields,
                      description: l10n.sidebarLegendFieldsBody,
                    ),
                    ThumbnailBadge.signature: (
                      name: l10n.sidebarLegendSignature,
                      description: l10n.sidebarLegendSignatureBody,
                    ),
                    ThumbnailBadge.warnings: (
                      name: l10n.sidebarLegendWarnings,
                      description: l10n.sidebarLegendWarningsBody,
                    ),
                  },
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: tab.index,
                sizing: StackFit.expand,
                children: [
                  for (final each in SidebarTab.values)
                    KeyedSubtree(
                      key: FmSidebar.keyOf(each),
                      child: switch ((document, each)) {
                        (null, _) => const SizedBox.expand(),
                        (final open?, SidebarTab.search) => SidebarSearch(
                          key: ValueKey(open.id),
                        ),
                        (final open?, SidebarTab.pages) => SidebarPages(
                          key: ValueKey(open.id),
                        ),
                        (final open?, SidebarTab.outline) => SidebarOutline(
                          key: ValueKey(open.id),
                        ),
                        (_, SidebarTab.attachments) =>
                          const SidebarAttachments(),
                        (_, SidebarTab.layers) => const SidebarLayers(),
                        (_, SidebarTab.signatures) => const SidebarSignatures(),
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The Outline tab's More menu (a2-3a, its items not drawn): what can be
  /// done to the selected bookmark, or else the reader's section.
  Widget _outlineMenu(
    BuildContext context,
    AppLocalizations l10n,
    OpenedDocument? document,
  ) {
    final outline = document?.outline ?? const <OutlineEntry>[];
    final current = ref.watch(viewerProvider.select((v) => v?.currentPage));
    final index =
        ref.watch(outlineSelectedProvider) ??
        (current == null ? null : outlineItemAt(outline, current));
    final target = index != null && index < outline.length ? index : null;
    final items = keptOutline(outline);
    MenuItem item(OutlineAction action, String label, IconName icon) =>
        MenuItem(
          id: action.name,
          label: label,
          icon: icon,
          danger: action == OutlineAction.delete,
          disabled: target == null || action.on(items, target) == null,
        );
    return Menu(
      semanticLabel: l10n.shellMore,
      autofocus: true,
      onClose: () => setState(() => _more = false),
      onSelected: (selected) {
        setState(() => _more = false);
        if (document == null || target == null) return;
        runOutlineAction(
          ref,
          l10n,
          document,
          OutlineAction.values.byName(selected.id!),
          target,
        );
      },
      items: [
        item(OutlineAction.rename, l10n.outlineRename, IconName.pencil),
        const MenuItem.divider(),
        item(OutlineAction.nest, l10n.outlineNest, IconName.arrowRight),
        item(OutlineAction.unnest, l10n.outlineUnnest, IconName.arrowLeft),
        item(OutlineAction.moveUp, l10n.outlineMoveUp, IconName.arrowUp),
        item(OutlineAction.moveDown, l10n.outlineMoveDown, IconName.arrowDown),
        const MenuItem.divider(),
        item(OutlineAction.delete, l10n.outlineDelete, IconName.trash2),
      ],
    );
  }

  /// The tab's heading: its title, count and [buttons].
  Widget _heading(
    BuildContext context,
    SidebarTab tab,
    String? count,
    List<Widget> buttons,
  ) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    return Container(
      height: FmSidebar.headingHeight,
      padding: EdgeInsetsDirectional.only(
        start: theme.space.space3,
        end: theme.space.space1_5,
      ),
      child: Row(
        spacing: theme.space.space1_5,
        children: [
          // The title and count, then FmSidebar's `flex: 1` spacer.
          Expanded(
            child: Row(
              spacing: theme.space.space1_5,
              children: [
                Flexible(
                  child: Text(
                    l10n.sidebarTabLabel(tab),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.panelTitle.copyWith(
                      color: theme.colors.textPrimary,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    count,
                    style: theme.typography.caption.copyWith(
                      color: theme.colors.textTertiary,
                      fontFeatures: theme.typeScale.numericTabular,
                    ),
                  ),
              ],
            ),
          ),
          ...buttons,
        ],
      ),
    );
  }
}
