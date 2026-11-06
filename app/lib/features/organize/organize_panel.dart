import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/shell/document_properties.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// a6-1's page menu on the selection at [position] (global).
void showPageMenu(BuildContext context, WidgetRef ref, Offset position) {
  final l10n = AppLocalizations.of(context);
  final direction = Directionality.of(context);
  final platform = ref.read(shortcutPlatformProvider);
  final format = RegionFormat.forRegion(ref.read(regionProvider).region);
  final count = ref.read(selectedPagesProvider).length;
  final shown = format.integer(count);
  final commands = ref.read(pageCommandsProvider.notifier);
  final refusal = ref.read(organizeRefusalProvider)?.call(l10n);
  final deleteRefusal = ref.read(deleteRefusalProvider)?.call(l10n);
  final dialogs = Feature.organizeDialogs.disabledReason(context);
  MenuItem dialog(String label, IconName icon, {List<String>? shortcut}) =>
      MenuItem(
        label: label,
        icon: icon,
        shortcut: shortcut,
        disabled: true,
        disabledReason: dialogs,
      );
  ContextMenuController().show(
    context: context,
    contextMenuBuilder: (context) => CustomSingleChildLayout(
      delegate: DesktopTextSelectionToolbarLayoutDelegate(anchor: position),
      child: Directionality(
        textDirection: direction,
        child: Menu(
          semanticLabel: l10n.organizePagesCount(count, shown),
          autofocus: true,
          items: [
            MenuItem.section(l10n.organizePagesCount(count, shown)),
            MenuItem(
              id: 'left',
              label: l10n.shellToolRotateLeft,
              icon: IconName.rotateCcw,
              shortcut: ShellCommand.rotateLeft.caps(platform),
              disabled: refusal != null,
              disabledReason: refusal,
            ),
            MenuItem(
              id: 'right',
              label: l10n.shellToolRotateRight,
              icon: IconName.rotateCw,
              shortcut: ShellCommand.rotateRight.caps(platform),
              disabled: refusal != null,
              disabledReason: refusal,
            ),
            MenuItem(
              id: 'duplicate',
              label: l10n.shellToolDuplicate,
              icon: IconName.copy,
              shortcut: ShellCommand.duplicatePages.caps(platform),
              disabled: refusal != null,
              disabledReason: refusal,
            ),
            dialog(
              l10n.organizeMenuExtract,
              IconName.fileOutput,
              shortcut: ShellCommand.extractPages.caps(platform),
            ),
            const MenuItem.divider(),
            dialog(l10n.organizeMenuInsertBlank, IconName.filePlus2),
            dialog(l10n.organizeMenuInsertFile, IconName.folderOpen),
            dialog(l10n.organizeMenuReplace, IconName.replace),
            const MenuItem.divider(),
            MenuItem(
              id: 'delete',
              label: l10n.organizeMenuDelete(count, shown),
              icon: IconName.trash2,
              shortcut: ShellCommand.deletePages.caps(platform),
              disabled: deleteRefusal != null,
              disabledReason: deleteRefusal,
            ),
          ],
          onClose: ContextMenuController.removeAny,
          onSelected: (item) {
            ContextMenuController.removeAny();
            unawaited(switch (item.id) {
              'left' => commands.rotate(-1),
              'right' => commands.rotate(1),
              'duplicate' => commands.duplicate(),
              'delete' => commands.delete(),
              _ => Future<void>.value(),
            });
          },
        ),
      ),
    ),
  );
}

/// a6-1's right panel while pages are selected: what they are, the commands
/// on them, and what to insert after the last. The heading names the count.
class OrganizePanel extends ConsumerWidget {
  /// The panel, [width] wide.
  const new({required this.width, super.key});

  /// The panel's width.
  final double width;

  /// `grid-template-columns: 84px minmax(0, 1fr)`.
  static const double factLabelWidth = 84;

  /// "4, 5, 6": the longest selection listed page by page.
  static const int listedPages = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final region = ref.watch(regionProvider);
    final format = RegionFormat.forRegion(region.region);
    final tab = ref.watch(shellDocumentsProvider).active;
    final document = ref.watch(openDocumentProvider);
    final selected = ref.watch(selectedPagesProvider);
    if (document == null || tab == null || selected.isEmpty) {
      return SizedBox(width: width);
    }
    final indices = [
      for (final handle in selected) ?document.pageIndexOf(handle),
    ];
    final pages = [for (final index in indices) document.pages[index]];
    final facts = DocumentFacts.of(context, ref, tab);
    final sizes = {for (final page in pages) facts.sizeOf(page)};
    final rotations = {for (final page in pages) page.rotation};
    final labels = [for (final page in pages) ?page.label];
    final numbers = indices.length <= listedPages
        ? [for (final index in indices) format.integer(index + 1)].join(', ')
        : pageRanges(indices, format);
    final refusal = ref.watch(organizeRefusalProvider)?.call(l10n);
    final deleteRefusal = ref.watch(deleteRefusalProvider)?.call(l10n);
    final commands = ref.read(pageCommandsProvider.notifier);
    final dialogs = Feature.organizeDialogs.disabledReason(context);
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );

    Widget fact(String label, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2,
      children: [
        SizedBox(
          width: factLabelWidth,
          child: Text(
            label,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textPrimary,
              fontFeatures: theme.typeScale.numericTabular,
            ),
          ),
        ),
      ],
    );

    Widget command(
      IconName icon,
      String label, {
      Future<void> Function()? onPressed,
      String? disabledReason,
    }) => Button(
      size: ButtonSize.sm,
      icon: icon,
      fullWidth: true,
      disabled: onPressed == null,
      disabledReason: disabledReason,
      onPressed: onPressed == null ? null : () => unawaited(onPressed()),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    Widget pair(Widget a, Widget b) => Row(
      spacing: theme.space.space1_5,
      children: [
        Expanded(child: a),
        Expanded(child: b),
      ],
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.organizePanelLabel,
      child: Container(
        width: width,
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
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: Text(
                l10n.organizePanelTitle(
                  selected.length,
                  format.integer(selected.length),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.panelTitle.copyWith(
                  color: theme.colors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanelSection(
                      title: l10n.organizePanelPages,
                      collapsible: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: theme.space.space1_5,
                        children: [
                          fact(
                            l10n.organizePanelPages,
                            labels.isEmpty
                                ? numbers
                                : l10n.organizePanelPagesLabels(
                                    numbers,
                                    bidiIsolate(
                                      labels.length == 1
                                          ? labels.single
                                          : '${labels.first}–${labels.last}',
                                    ),
                                  ),
                          ),
                          fact(
                            l10n.organizePanelSize,
                            sizes.length == 1
                                ? sizes.single
                                : l10n.organizePanelMixed,
                          ),
                          fact(
                            l10n.organizePanelRotation,
                            rotations.length == 1
                                ? '${format.integer(rotations.single)}°'
                                : l10n.organizePanelMixed,
                          ),
                        ],
                      ),
                    ),
                    PanelSection(
                      title: l10n.organizePanelCommands,
                      collapsible: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: theme.space.space1_5,
                        children: [
                          pair(
                            command(
                              IconName.rotateCcw,
                              l10n.shellToolRotateLeft,
                              onPressed: refusal != null
                                  ? null
                                  : () => commands.rotate(-1),
                              disabledReason: refusal,
                            ),
                            command(
                              IconName.rotateCw,
                              l10n.shellToolRotateRight,
                              onPressed: refusal != null
                                  ? null
                                  : () => commands.rotate(1),
                              disabledReason: refusal,
                            ),
                          ),
                          pair(
                            command(
                              IconName.copy,
                              l10n.shellToolDuplicate,
                              onPressed: refusal != null
                                  ? null
                                  : commands.duplicate,
                              disabledReason: refusal,
                            ),
                            command(
                              IconName.fileOutput,
                              l10n.organizePanelExtract,
                              disabledReason: dialogs,
                            ),
                          ),
                          pair(
                            command(
                              IconName.replace,
                              l10n.organizePanelReplace,
                              disabledReason: dialogs,
                            ),
                            command(
                              IconName.trash2,
                              l10n.shellToolDelete,
                              onPressed: deleteRefusal != null
                                  ? null
                                  : commands.delete,
                              disabledReason: deleteRefusal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PanelSection(
                      title: l10n.organizePanelInsertAfter(
                        format.integer(indices.last + 1),
                      ),
                      collapsible: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: theme.space.space1_5,
                        children: [
                          command(
                            IconName.filePlus2,
                            l10n.organizePanelBlankPage,
                            disabledReason: dialogs,
                          ),
                          command(
                            IconName.folderOpen,
                            l10n.organizePanelFromFile,
                            disabledReason: dialogs,
                          ),
                          command(
                            IconName.scan,
                            l10n.organizePanelFromScanner,
                            disabledReason: Feature.scanToPdf.disabledReason(
                              context,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
