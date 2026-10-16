import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/feedback/progress_bar.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// Where a background job stands (`.fm-task--paused`, `--done`, `--error`).
enum TaskState {
  /// Working; the default.
  running,

  /// Paused by the user.
  paused,

  /// Finished.
  done,

  /// Failed.
  error,
}

/// The shape of a [TaskProgress].
enum TaskProgressVariant {
  /// A raised card with icon, text, progress and actions; the default.
  card,

  /// One line for the status bar (`.fm-task--inline`).
  inline,
}

/// An action button of a [TaskProgress]: its localized `label` and what it
/// does (`onPressed`).
typedef TaskAction = ({String label, VoidCallback onPressed});

/// A background job's status, the design-system `TaskProgress` component
/// (`components/feedback/feedback.css`, `.fm-task`; `TaskProgress.jsx`).
///
/// [TaskProgressVariant.card], 380 px wide (narrower when its parent is):
/// a 28 px tile with [icon] (circle-check when done, circle-alert on
/// error) in [state]'s colours, the [title] and [detail], a small Cancel
/// icon button (named [cancelLabel]) while running or paused, a
/// [ProgressBar] while running or paused, and the actions at the end:
/// Pause ([pauseLabel], running), Resume ([resumeLabel], paused),
/// [secondaryAction] and [primaryAction].
///
/// [TaskProgressVariant.inline], for the status bar: a 12 px [Spinner]
/// while running (else the state icon), "title · detail", a 96 px
/// progress bar until done, and an extra-small Cancel button.
///
/// Jobs are asynchronous, cancellable and stream progress (ARCHITECTURE);
/// the screen passes the job's [value] (0 to 1) or [indeterminate].
///
/// For screen readers it is a polite live region whose label is the title
/// and the detail; the buttons are separate.
class TaskProgress extends StatelessWidget {
  /// Creates a task status.
  const new({
    required this.title,
    super.key,
    this.detail,
    this.value,
    this.indeterminate = false,
    this.state = TaskState.running,
    this.icon = IconName.scanText,
    this.variant = TaskProgressVariant.card,
    this.onCancel,
    this.onPause,
    this.onResume,
    this.primaryAction,
    this.secondaryAction,
    this.cancelLabel,
    this.pauseLabel,
    this.resumeLabel,
  }) : assert(
         onCancel == null || cancelLabel != null,
         'A cancellable task needs the localized cancelLabel.',
       ),
       assert(
         onPause == null || pauseLabel != null,
         'A pausable task needs the localized pauseLabel.',
       ),
       assert(
         onResume == null || resumeLabel != null,
         'A resumable task needs the localized resumeLabel.',
       );

  /// `.fm-task` `width: 380px`.
  static const double width = 380;

  /// `.fm-task__icon` `width` and `height`.
  static const double tileSize = 28;

  /// `TaskProgress.jsx` card icon size.
  static const double iconSize = 16;

  /// `.fm-task` `padding: 12px 12px 12px 14px`: the start padding.
  static const double paddingStart = 14;

  /// `TaskProgress.jsx` inline spinner size.
  static const double inlineSpinnerSize = 12;

  /// `TaskProgress.jsx` inline icon size.
  static const double inlineIconSize = 14;

  /// `.fm-task--inline .fm-progress` `width: 96px`.
  static const double inlineProgressWidth = 96;

  /// What the job is ("Recognizing text").
  final String title;

  /// Where it is ("Page 14 of 64 · about 2 minutes left"); null shows
  /// none.
  final String? detail;

  /// How much is done, 0 to 1.
  final double? value;

  /// Whether the amount is unknown.
  final bool indeterminate;

  /// Running, paused, done or failed.
  final TaskState state;

  /// The card's icon while running or paused.
  final IconName icon;

  /// Card or status-bar line.
  final TaskProgressVariant variant;

  /// Called by the Cancel button; null shows none.
  final VoidCallback? onCancel;

  /// Called by the Pause button (card, running); null shows none.
  final VoidCallback? onPause;

  /// Called by the Resume button (card, paused); null shows none.
  final VoidCallback? onResume;

  /// The secondary-variant action at the very end (card), such as "Show".
  final TaskAction? primaryAction;

  /// The ghost action before [primaryAction] (card).
  final TaskAction? secondaryAction;

  /// The localized name of the Cancel button ("Cancel"); required with
  /// [onCancel]. Not a design-system prop.
  final String? cancelLabel;

  /// The localized label of the Pause button ("Pause"); required with
  /// [onPause]. Not a design-system prop.
  final String? pauseLabel;

  /// The localized label of the Resume button ("Resume"); required with
  /// [onResume]. Not a design-system prop.
  final String? resumeLabel;

  /// The progress bar's tone for [state] (`TaskProgress.jsx`).
  static ProgressTone toneFor(TaskState state) => switch (state) {
    TaskState.running => ProgressTone.accent,
    TaskState.paused => ProgressTone.paused,
    TaskState.done => ProgressTone.success,
    TaskState.error => ProgressTone.danger,
  };

  bool get _active => state == TaskState.running || state == TaskState.paused;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: variant == TaskProgressVariant.inline
        ? _inline(context)
        : _card(context),
  );

  Widget _inline(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final features = [
      ...theme.typeScale.featuresUi,
      ...theme.typeScale.numericTabular,
    ];
    return DefaultTextStyle.merge(
      style: theme.typography.caption.copyWith(
        color: colors.textSecondary,
        fontFeatures: features,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space2,
        children: [
          if (state == TaskState.running)
            const Spinner(size: inlineSpinnerSize)
          else
            Icon(switch (state) {
              TaskState.done => IconName.circleCheck,
              TaskState.error => IconName.circleAlert,
              TaskState.running || TaskState.paused => IconName.pause,
            }, size: inlineIconSize),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: TextStyle(color: colors.textPrimary),
                ),
                if (detail != null) TextSpan(text: ' · $detail'),
              ],
            ),
            softWrap: false,
          ),
          if (state != TaskState.done)
            SizedBox(
              width: inlineProgressWidth,
              child: ProgressBar(
                value: value,
                indeterminate: indeterminate,
                tone: toneFor(state),
              ),
            ),
          if (onCancel != null && state != TaskState.done)
            IconButton(
              icon: IconName.x,
              label: cancelLabel ?? '',
              size: IconButtonSize.xs,
              onPressed: onCancel,
            ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final (tileColor, iconColor) = switch (state) {
      TaskState.running => (colors.accentSubtle, colors.textAccent),
      TaskState.paused => (colors.surfaceSunken, colors.iconSecondary),
      TaskState.done => (colors.successBg, colors.success),
      TaskState.error => (colors.dangerBg, colors.danger),
    };
    final stateIcon = switch (state) {
      TaskState.done => IconName.circleCheck,
      TaskState.error => IconName.circleAlert,
      TaskState.running || TaskState.paused => icon,
    };
    final actions = [
      if (state == TaskState.running && onPause != null)
        Button(
          size: ButtonSize.sm,
          variant: ButtonVariant.ghost,
          icon: IconName.pause,
          onPressed: onPause,
          child: Text(pauseLabel ?? ''),
        ),
      if (state == TaskState.paused && onResume != null)
        Button(
          size: ButtonSize.sm,
          onPressed: onResume,
          child: Text(resumeLabel ?? ''),
        ),
      if (secondaryAction case final action?)
        Button(
          size: ButtonSize.sm,
          variant: ButtonVariant.ghost,
          onPressed: action.onPressed,
          child: Text(action.label),
        ),
      if (primaryAction case final action?)
        Button(
          size: ButtonSize.sm,
          onPressed: action.onPressed,
          child: Text(action.label),
        ),
    ];
    final radiusSm = BorderRadius.all(Radius.circular(theme.radius.radiusSm));
    return SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          paddingStart,
          theme.space.space3,
          theme.space.space3,
          theme.space.space3,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusMd),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.space2_5,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: theme.space.space2_5,
              children: [
                Container(
                  width: tileSize,
                  height: tileSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: radiusSm,
                  ),
                  // iconSize, the Icon default.
                  child: Icon(stateIcon, color: iconColor),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: theme.space.space0_5,
                    children: [
                      Text(
                        title,
                        style: theme.typography.bodyStrong.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          style: theme.typography.caption.copyWith(
                            color: colors.textSecondary,
                            fontFeatures: [
                              ...theme.typeScale.featuresUi,
                              ...theme.typeScale.numericTabular,
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (onCancel != null && _active)
                  IconButton(
                    icon: IconName.x,
                    label: cancelLabel ?? '',
                    size: IconButtonSize.sm,
                    onPressed: onCancel,
                  ),
              ],
            ),
            if (_active)
              ProgressBar(
                value: value,
                indeterminate: indeterminate,
                tone: toneFor(state),
              ),
            if (actions.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: theme.space.space1_5,
                children: actions,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('title', title))
      ..add(StringProperty('detail', detail, defaultValue: null))
      ..add(DoubleProperty('value', value, defaultValue: null))
      ..add(
        FlagProperty(
          'indeterminate',
          value: indeterminate,
          ifTrue: 'indeterminate',
        ),
      )
      ..add(
        EnumProperty<TaskState>(
          'state',
          state,
          defaultValue: TaskState.running,
        ),
      )
      ..add(
        EnumProperty<IconName>('icon', icon, defaultValue: IconName.scanText),
      )
      ..add(
        EnumProperty<TaskProgressVariant>(
          'variant',
          variant,
          defaultValue: TaskProgressVariant.card,
        ),
      )
      ..add(ObjectFlagProperty<VoidCallback>.has('onCancel', onCancel))
      ..add(ObjectFlagProperty<VoidCallback>.has('onPause', onPause))
      ..add(ObjectFlagProperty<VoidCallback>.has('onResume', onResume))
      ..add(
        StringProperty(
          'primaryAction',
          primaryAction?.label,
          defaultValue: null,
        ),
      )
      ..add(
        StringProperty(
          'secondaryAction',
          secondaryAction?.label,
          defaultValue: null,
        ),
      );
  }
}
