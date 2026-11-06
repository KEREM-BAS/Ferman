import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [row] as a [TaskProgress] of [variant].
TaskProgress taskProgressOf(
  BackgroundJob row,
  AppLocalizations l10n,
  RegionFormat format,
  BackgroundJobsNotifier jobs, {
  TaskProgressVariant variant = TaskProgressVariant.card,
}) => TaskProgress(
  variant: variant,
  icon: row.icon,
  title: row.title(l10n),
  detail: row.detail(l10n, format),
  value: row.value,
  indeterminate: row.active && row.value == null,
  state: row.state,
  cancelLabel: l10n.findCancel,
  onCancel: row.active ? () => jobs.askCancel(row) : null,
  pauseLabel: l10n.taskPause,
  onPause: row.state == TaskState.running
      ? () => unawaited(jobs.pause(row))
      : null,
  resumeLabel: l10n.taskResume,
  onResume: row.state == TaskState.paused
      ? () => unawaited(jobs.resume(row))
      : null,
  primaryAction: row.state == TaskState.done && row.output != null
      ? (label: l10n.taskShow, onPressed: () => unawaited(jobs.show(row)))
      : null,
  secondaryAction: row.active
      ? null
      : (label: l10n.taskDismiss, onPressed: () => jobs.dismiss(row.id)),
);

/// The background task drawer (a11-6b), 400 px wide at the canvas's bottom
/// end: its header with the close button, then a row per job, or the empty
/// state G49 asks for. The canvas places it, and leaves it out while closed.
class TaskDrawer extends ConsumerWidget {
  /// The drawer.
  const new({super.key});

  /// The board's `width:400px`.
  static const double width = 400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final rows = ref.watch(backgroundJobsProvider.select((jobs) => jobs.rows));
    final jobs = ref.read(backgroundJobsProvider.notifier);
    return Align(
      alignment: AlignmentDirectional.bottomEnd,
      child: Semantics(
        container: true,
        label: l10n.tasksTitle,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: theme.colors.surfaceRaised,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusLg),
            ),
            boxShadow: theme.elevation.shadowPopover,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: theme.space.space3,
                  vertical: theme.space.space2_5,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colors.borderSubtle,
                      width: theme.border.borderWidth,
                    ),
                  ),
                ),
                child: Row(
                  spacing: theme.space.space2,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tasksTitle,
                        style: theme.typography.panelTitle.copyWith(
                          color: theme.colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: IconName.chevronDown,
                      label: l10n.tasksClose,
                      size: IconButtonSize.xs,
                      onPressed: jobs.closeDrawer,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: EdgeInsetsDirectional.only(
                          bottom: theme.space.space6,
                        ),
                        child: EmptyState(
                          icon: IconName.listChecks,
                          title: l10n.tasksEmptyTitle,
                          body: l10n.tasksEmptyBody,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsetsDirectional.all(
                          theme.space.space2_5,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: theme.space.space2,
                          children: [
                            for (final row in rows)
                              taskProgressOf(row, l10n, format, jobs),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status bar's task line, which opens the drawer (a11-6b: "Opened from
/// the status bar task"). A focus stop with its ring.
class TaskDrawerOpener extends StatefulWidget {
  /// The line [child] that calls [onPressed], named [label].
  const new({
    required this.label,
    required this.onPressed,
    required this.child,
    super.key,
  });

  /// What it does, for screen readers.
  final String label;

  /// Opens or closes the drawer.
  final VoidCallback onPressed;

  /// The task line.
  final Widget child;

  @override
  State<TaskDrawerOpener> createState() => _TaskDrawerOpenerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(ObjectFlagProperty<VoidCallback>.has('onPressed', onPressed));
  }
}

class _TaskDrawerOpenerState extends State<TaskDrawerOpener> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Semantics(
      button: true,
      label: widget.label,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: FocusRing(
            visible: _focused,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusSm),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The question before a running task is cancelled (G49).
class CancelTaskDialog extends ConsumerWidget {
  /// The question about [row].
  const new(this.row, {super.key});

  /// The task.
  final BackgroundJob row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final jobs = ref.read(backgroundJobsProvider.notifier);
    return Dialog(
      icon: row.icon,
      title: l10n.taskCancelTitle(row.title(l10n)),
      description: l10n.taskCancelBody,
      onClose: jobs.keepRunning,
      closeLabel: l10n.saveAsClose,
      cancelAction: Button(
        autofocus: true,
        onPressed: jobs.keepRunning,
        child: Text(l10n.taskKeepRunning),
      ),
      actions: [
        Button(
          variant: ButtonVariant.danger,
          onPressed: () => unawaited(jobs.confirmCancel()),
          child: Text(l10n.taskCancelConfirm),
        ),
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BackgroundJob>('row', row));
  }
}

/// Quitting with jobs running (decision 30, G49): lists them and asks;
/// cancelling leaves no partial file.
class QuitTasksDialog extends ConsumerWidget {
  /// The question about [rows].
  const new(this.rows, {super.key});

  /// The jobs running.
  final List<BackgroundJob> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final jobs = ref.read(backgroundJobsProvider.notifier);
    return Dialog(
      icon: IconName.listChecks,
      title: l10n.tasksQuitTitle(rows.length, format.integer(rows.length)),
      description: l10n.tasksQuitBody,
      onClose: () => jobs.answerQuit(quit: false),
      closeLabel: l10n.saveAsClose,
      cancelAction: Button(
        autofocus: true,
        onPressed: () => jobs.answerQuit(quit: false),
        child: Text(l10n.tasksQuitKeep),
      ),
      actions: [
        Button(
          variant: ButtonVariant.danger,
          onPressed: () => jobs.answerQuit(quit: true),
          child: Text(l10n.tasksQuitConfirm),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.space1,
        children: [
          for (final row in rows)
            Text(
              row.title(l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.copyWith(
                color: theme.colors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<BackgroundJob>('rows', rows));
  }
}
