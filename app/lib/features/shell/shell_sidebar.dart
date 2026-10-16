import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sidebar on the start side (building block `FmSidebar.dc.html`):
/// `--sidebar-w` wide on the panel surface with a subtle line on its end
/// side, holding the six tabs as an icon-only SegmentedControl over an
/// [IndexedStack] (never a `TabBarView`, ADR 0011), the tab's heading with
/// its count and buttons, and the tab's content.
///
/// The tabs switch; their content needs an open document (M2), so the
/// content is empty, the Pages heading counts the placeholder document's
/// pages, and the heading buttons are disabled with the future-version
/// tooltip.
class FmSidebar extends ConsumerWidget {
  /// The sidebar.
  const new({super.key});

  /// FmSidebar's heading row: `height: 34px`.
  static const double headingHeight = 34;

  /// The key of [tab]'s content, for tests.
  static ValueKey<String> keyOf(SidebarTab tab) =>
      ValueKey('shell-sidebar-${tab.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final tab = ref.watch(shellSidebarTabProvider);
    final pages = ref.watch(shellDocumentsProvider).active?.pageCount;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final future = futureVersionReason(context);
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );

    IconButton button(IconName icon, String label, {List<String>? shortcut}) =>
        IconButton(
          icon: icon,
          label: label,
          size: IconButtonSize.xs,
          shortcut: shortcut,
          disabledReason: future,
        );

    final buttons = switch (tab) {
      SidebarTab.pages => [button(IconName.info, l10n.shellPageBadgesLegend)],
      SidebarTab.outline => [
        button(
          IconName.plus,
          l10n.shellAddBookmark,
          shortcut: ShellCommand.addBookmark.caps(platform),
        ),
        button(IconName.ellipsis, l10n.shellMore),
      ],
      SidebarTab.attachments => [button(IconName.plus, l10n.shellAttachFile)],
      SidebarTab.layers ||
      SidebarTab.signatures ||
      SidebarTab.search => const <Widget>[],
    };
    final count = tab == SidebarTab.pages && pages != null
        ? format.integer(pages)
        : null;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.shellSidebar,
      child: Container(
        width: theme.size.sidebarW,
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
            Container(
              height: headingHeight,
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
            ),
            Expanded(
              child: IndexedStack(
                index: tab.index,
                sizing: StackFit.expand,
                children: [
                  for (final each in SidebarTab.values)
                    SizedBox.expand(key: keyOf(each)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
