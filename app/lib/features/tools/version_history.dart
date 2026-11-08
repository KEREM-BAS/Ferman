import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_canvas.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/tools/compress_panel.dart';
import 'package:ferman/features/tools/printed_page.dart';
import 'package:ferman/features/tools/tools_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens Version history (a9-8): Tools mode with the timeline.
void showVersionHistory(WidgetRef ref) {
  ref.read(shellModeProvider.notifier).select(FermanMode.tools);
  ref.read(toolsPanelProvider.notifier).show(ToolsPanel.versions);
}

/// When [version] was made, as a9-8 writes it: the time today, the date
/// before.
String versionTime(VersionInfo version, RegionFormat format, DateTime now) {
  final made = DateTime.fromMillisecondsSinceEpoch(version.time);
  return made.year == now.year && made.month == now.month && made.day == now.day
      ? format.time(made)
      : format.date(made);
}

/// a9-8 in place of the sidebar, canvas and panel: the version chosen, read
/// only, with its bar, or the current document, and the timeline beside it.
class VersionHistoryView extends ConsumerWidget {
  /// The view.
  const new({super.key});

  /// The timeline's width (`grid-template-columns:… 360px`).
  static const double panelWidth = 360;

  /// The page's width on the board (DocKira, 794 px).
  static const double pageWidth = 794;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final preview = ref.watch(versionPreviewProvider);
    final versions = ref.watch(documentVersionsProvider).value ?? const [];
    final chosen = versions
        .where((version) => version.id == preview?.version)
        .firstOrNull;
    final opened = preview?.document;
    final Widget main;
    if (preview == null) {
      main = const ShellCanvas();
    } else {
      final time = chosen == null
          ? ''
          : versionTime(chosen, format, DateTime.now());
      main = ColoredBox(
        color: theme.colors.surfaceCanvas,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Banner(
              variant: BannerVariant.bar,
              icon: IconName.history,
              title: l10n.versionViewing(time),
              actions: [
                Button(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.sm,
                  onPressed: ref.read(versionPreviewProvider.notifier).back,
                  child: Text(l10n.versionBack),
                ),
                Button(
                  size: ButtonSize.sm,
                  onPressed: chosen == null
                      ? null
                      : () => _askRestore(ref, chosen, time),
                  child: Text(l10n.versionRestoreThis),
                ),
              ],
              child: Text(l10n.versionReadOnly),
            ),
            Expanded(
              child: switch ((opened, preview.error)) {
                (final opened?, _) => ListView.builder(
                  padding: EdgeInsetsDirectional.all(theme.space.space6),
                  itemCount: opened.pages.length,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: theme.space.space6,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: pageWidth,
                        child: PrintedPage(
                          document: opened.id,
                          handle: opened.pageHandle(index),
                          page: opened.pages[index],
                        ),
                      ),
                    ),
                  ),
                ),
                (null, final error?) => Center(
                  child: Text(
                    engineMessage(l10n, error, ''),
                    style: theme.typography.body.copyWith(
                      color: theme.colors.textSecondary,
                    ),
                  ),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: main),
        const VersionHistoryPanel(width: panelWidth),
      ],
    );
  }
}

/// Asks before [version] becomes the file again (decision 27).
void _askRestore(WidgetRef ref, VersionInfo version, String time) {
  final dialog = ref.read(organizeDialogProvider.notifier);
  dialog.show(
    Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Dialog(
          icon: IconName.rotateCcw,
          title: l10n.versionRestoreTitle(time),
          description: l10n.versionRestoreBody,
          onClose: dialog.close,
          closeLabel: l10n.organizeCancel,
          cancelAction: Button(
            onPressed: dialog.close,
            child: Text(l10n.organizeCancel),
          ),
          actions: [
            Button(
              variant: ButtonVariant.primary,
              onPressed: () {
                dialog.close();
                ref.read(versionPreviewProvider.notifier).back();
                unawaited(
                  ref
                      .read(documentSaverProvider.notifier)
                      .restoreVersion(version.id),
                );
              },
              child: Text(l10n.versionRestore),
            ),
          ],
        );
      },
    ),
  );
}

/// a9-8's timeline: Now while there are unsaved edits, then each version,
/// newest first; the chosen one shows Restore… and Compare with current
/// (P3, B027). Its foot says how long versions are kept (ADR 0022).
class VersionHistoryPanel extends ConsumerWidget {
  /// The timeline.
  const new({super.key, this.width});

  /// Its width; null takes the panel's.
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final document = ref.watch(openDocumentProvider);
    final tab = ref.watch(shellDocumentsProvider).active;
    final versions = ref.watch(documentVersionsProvider).value ?? const [];
    final preview = ref.watch(versionPreviewProvider);
    final now = DateTime.now();
    final unsaved = tab?.unsaved ?? false;
    final edits = tab?.editCount ?? 0;
    final count = versions.length;
    final caption = theme.typography.caption;

    Widget row({
      required String title,
      required String time,
      required String detail,
      required Color dot,
      required bool selected,
      required bool last,
      VoidCallback? onPressed,
      VersionInfo? version,
    }) {
      final body = Container(
        padding: EdgeInsetsDirectional.only(
          start: theme.space.space2_5,
          end: theme.space.space2_5,
          top: theme.space.space2_5,
          bottom: theme.space.space3,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colors.surfaceSelected : null,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusMd),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space2_5,
          children: [
            SizedBox(
              width: _VersionLayout.railWidth,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: _VersionLayout.dotTop,
                    ),
                    child: Container(
                      width: _VersionLayout.dot,
                      height: _VersionLayout.dot,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colors.surfacePanel,
                          width: _VersionLayout.dotRing,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _VersionLayout.lineGap,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: theme.space.space2,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.typography.bodyStrong.copyWith(
                            color: theme.colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: caption.copyWith(
                          color: theme.colors.textTertiary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: caption.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  if (selected && version != null)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        top: theme.space.space1,
                      ),
                      child: Wrap(
                        spacing: theme.space.space1_5,
                        runSpacing: theme.space.space1_5,
                        children: [
                          Button(
                            size: ButtonSize.sm,
                            icon: IconName.rotateCcw,
                            onPressed: () => _askRestore(ref, version, time),
                            child: Text(l10n.versionRestoreShort),
                          ),
                          Button(
                            size: ButtonSize.sm,
                            variant: ButtonVariant.ghost,
                            icon: IconName.gitCompare,
                            disabledReason: Feature.compare.disabledReason(
                              context,
                            ),
                            child: Text(l10n.versionCompare),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
      // The rail runs down to the next row's dot.
      return Semantics(
        selected: selected,
        button: onPressed != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Stack(
            children: [
              if (!last)
                PositionedDirectional(
                  start:
                      theme.space.space2_5 +
                      (_VersionLayout.railWidth - _VersionLayout.rail) / 2,
                  top: _VersionLayout.railTop,
                  bottom: -theme.space.space2_5,
                  child: Container(
                    width: _VersionLayout.rail,
                    color: theme.colors.borderDefault,
                  ),
                ),
              body,
            ],
          ),
        ),
      );
    }

    final rows = <Widget>[
      if (unsaved)
        row(
          title: l10n.versionNow,
          time: l10n.versionUnsaved,
          detail: l10n.versionNowDetail(edits, format.integer(edits)),
          dot: theme.colors.warningSolid,
          selected: preview == null,
          last: versions.isEmpty,
          onPressed: ref.read(versionPreviewProvider.notifier).back,
        ),
      for (final (index, version) in versions.indexed)
        row(
          title: switch (version.kind) {
            VersionKind.opened => l10n.versionOpened,
            VersionKind.saved => l10n.versionSaved,
            VersionKind.signed => l10n.versionSigned,
            VersionKind.unsaved => l10n.versionUnsavedWork,
            VersionKind.restored => l10n.versionRestored,
          },
          time: versionTime(version, format, now),
          detail: switch (version) {
            VersionInfo(edits: 0, kind: VersionKind.opened) =>
              l10n.versionOpenedDetail,
            VersionInfo(edits: 0) => '',
            VersionInfo(:final edits, :final names) when names.isNotEmpty =>
              l10n.versionEditsNamed(
                edits,
                format.integer(edits),
                names.join(', '),
              ),
            VersionInfo(:final edits) => l10n.versionEdits(
              edits,
              format.integer(edits),
            ),
          },
          dot: switch (version.kind) {
            VersionKind.signed => theme.colors.successSolid,
            _ when preview?.version == version.id => theme.colors.accent,
            _ => theme.colors.iconSecondary,
          },
          selected: preview?.version == version.id,
          last: index == versions.length - 1,
          version: version,
          onPressed: document == null
              ? null
              : () => unawaited(
                  ref
                      .read(versionPreviewProvider.notifier)
                      .select(document.id, version.id),
                ),
        ),
    ];
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    return ToolsPanelFrame(
      title: l10n.versionTitle,
      trailing: l10n.versionCount(count, format.integer(count)),
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: rows.isEmpty
                ? Padding(
                    padding: EdgeInsetsDirectional.all(theme.space.space3),
                    child: Text(
                      l10n.versionNone,
                      style: caption.copyWith(
                        color: theme.colors.textSecondary,
                      ),
                    ),
                  )
                : Semantics(
                    container: true,
                    label: l10n.versionList,
                    child: ListView(
                      padding: EdgeInsetsDirectional.only(
                        start: theme.space.space2_5,
                        end: theme.space.space2_5,
                        top: theme.space.space2_5,
                      ),
                      children: rows,
                    ),
                  ),
          ),
          Container(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.space.space3,
              vertical: theme.space.space2_5,
            ),
            decoration: BoxDecoration(border: Border(top: line)),
            child: Text(
              l10n.versionKept,
              style: caption.copyWith(color: theme.colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('width', width));
  }
}

/// a9-8's measures that are not tokens.
abstract final class _VersionLayout {
  /// The rail's column (`grid-template-columns:22px …`).
  static const double railWidth = 22;

  /// The dot (`width:12px;height:12px`) …
  static const double dot = 12;

  /// … below the row's top (`margin-top:3px`) …
  static const double dotTop = 3;

  /// … with its ring (`box-shadow:0 0 0 3px`).
  static const double dotRing = 3;

  /// The rail (`width:2px`) …
  static const double rail = 2;

  /// … from the dot's middle (`top:14px` in the row's 10 px padding).
  static const double railTop = 24;

  /// The gap between the row's lines (`gap:3px`).
  static const double lineGap = 3;
}
