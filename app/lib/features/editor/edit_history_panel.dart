import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/review_list.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows a3-10's Undo history panel, or hides it (Edit › Edit history),
/// opening the right panel's place for it when it was closed.
void toggleEditHistory(WidgetRef ref) {
  final open = !ref.read(editHistoryOpenProvider);
  ref.read(editHistoryOpenProvider.notifier).show(open: open);
  if (open) ref.read(reviewListProvider.notifier).show(open: false);
  if (open && !ref.read<ShellPanels>(shellPanelsProvider).panel) {
    toggleShellSide(ref, ShellSide.panel);
  }
}

/// Edit's Undo history panel (a3-10), in the right panel's place: a 40 px
/// heading "Edit history" with Close history, then every step of the open
/// document's history, oldest first, after "Opened" and the file's name:
/// its name and the time it was committed. The step the document stands
/// at is selected (`--surface-selected`, an accent dot), the steps undone
/// are greyed and can be redone; a click on a step undoes or redoes to it
/// (`DocumentEditor.goTo`). The note at the bottom says how it works.
class EditHistoryPanel extends ConsumerWidget {
  /// The panel, [width] wide (null: `--panel-w`).
  const new({super.key, this.width});

  /// The width the user dragged the right panel to (B094).
  final double? width;

  /// a3-10: the heading's `height: 40px`.
  static const double headingHeight = 40;

  /// a3-10: a step's dot, `width: 10px`.
  static const double dotSize = 10;

  /// a3-10: the ring around a step's dot, `box-shadow: 0 0 0 2px`.
  static const double dotRing = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final history = ref.watch(documentEditorProvider).history;
    final name = ref.watch(shellDocumentsProvider).active?.name;
    final editor = ref.read(documentEditorProvider.notifier);
    final line = BorderSide(
      color: theme.colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final rows = [
      if (name != null)
        _Step(
          label: l10n.editHistoryOpened(bidiIsolate(name)),
          state: history.current == 0 ? _StepState.current : _StepState.done,
          onPressed: () => unawaited(editor.goTo(0)),
        ),
      for (final (index, step) in history.steps.indexed)
        _Step(
          label: step.name,
          meta: format.time(step.time),
          state: index + 1 == history.current
              ? _StepState.current
              : index < history.current
              ? _StepState.done
              : _StepState.undone,
          onPressed: () => unawaited(editor.goTo(index + 1)),
        ),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.shellEditHistory,
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
              height: headingHeight,
              padding: EdgeInsetsDirectional.only(
                start: theme.space.space3,
                end: theme.space.space1_5,
              ),
              decoration: BoxDecoration(border: Border(bottom: line)),
              child: Row(
                spacing: theme.space.space2,
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        l10n.shellEditHistory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.panelTitle.copyWith(
                          color: theme.colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: IconName.x,
                    label: l10n.editHistoryClose,
                    size: IconButtonSize.xs,
                    onPressed: () => ref
                        .read(editHistoryOpenProvider.notifier)
                        .show(open: false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: l10n.editHistorySteps,
                child: ListView(
                  padding: EdgeInsetsDirectional.all(theme.space.space1_5),
                  children: [
                    for (final (index, row) in rows.indexed)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          top: index == 0 ? 0 : theme.border.borderWidth,
                        ),
                        child: row,
                      ),
                  ],
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
                l10n.editHistoryNote,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.textTertiary,
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
    properties.add(DoubleProperty('width', width, defaultValue: null));
  }
}

/// Where a step stands: applied, the one the document is at, or undone.
enum _StepState { done, current, undone }

/// One row of the history (a3-10): the dot, the step's name and its time.
class _Step extends StatelessWidget {
  const new({
    required this.label,
    required this.state,
    required this.onPressed,
    this.meta,
  });

  final String label;
  final String? meta;
  final _StepState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final current = state == _StepState.current;
    final meta = this.meta;
    return FermanInteractive(
      onPressed: onPressed,
      selected: current,
      selectable: true,
      semanticLabel: meta == null ? label : '$label, $meta',
      builder: (context, states, _) => Container(
        padding: EdgeInsetsDirectional.all(theme.space.space2),
        decoration: BoxDecoration(
          color: current ? colors.surfaceSelected : null,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusSm),
          ),
        ),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space2_5,
            children: [
              Container(
                width: EditHistoryPanel.dotSize,
                height: EditHistoryPanel.dotSize,
                margin: EdgeInsetsDirectional.only(top: theme.space.space1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (state) {
                    _StepState.current => colors.accent,
                    _StepState.done => colors.iconSecondary,
                    _StepState.undone => colors.borderStrong,
                  },
                  boxShadow: [
                    BoxShadow(
                      color: colors.surfacePanel,
                      spreadRadius: EditHistoryPanel.dotRing,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: theme.space.space0_5,
                  children: [
                    Text(
                      label,
                      style: theme.typography.body.copyWith(
                        color: state == _StepState.undone
                            ? colors.textDisabled
                            : colors.textPrimary,
                      ),
                    ),
                    if (meta != null)
                      Text(
                        meta,
                        style: theme.typography.caption.copyWith(
                          color: colors.textTertiary,
                          fontFeatures: const [FontFeature.tabularFigures()],
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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(StringProperty('meta', meta, defaultValue: null))
      ..add(EnumProperty<_StepState>('state', state))
      ..add(ObjectFlagProperty<VoidCallback>.has('onPressed', onPressed));
  }
}
