import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/feedback/feedback_semantics.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The icon colour of a [Toast] (`.fm-toast--success`, …).
enum ToastTone {
  /// The secondary icon colour; the default.
  neutral,

  /// The solid success colour.
  success,

  /// The solid warning colour.
  warning,

  /// The danger colour.
  danger,
}

/// The one action a [Toast] offers: its localized `label` and what it does
/// (`onPressed`).
typedef ToastAction = ({String label, VoidCallback onPressed});

/// A floating notice, the design-system `Toast` component
/// (`components/feedback/feedback.css`, `.fm-toast`; `Toast.jsx`). Never
/// the Material snack bar (ADR 0011).
///
/// A 380 px raised card (narrower when its parent is) with [tone]'s 16 px
/// icon (or [icon]), a [title] of four words or fewer, a [message], then
/// at most one [action] as a small ghost `Button` in the accent colour and,
/// with [onClose], a small Dismiss icon button without a tooltip, named
/// [closeLabel]. It rises in over `--dur-slow` (at once under reduced
/// motion).
///
/// The toast stack (bottom end, above the status bar, `.fm-toast-region`)
/// and the timing (errors stay until dismissed, the rest leave after six
/// seconds unless hovered or focused, `a11-6`) belong to the screen that
/// shows toasts.
///
/// For screen readers its label is the title and the message. A danger
/// toast is an alert, announced assertively when it appears (`Toast.jsx`
/// `role="alert"`, `aria-live="assertive"`; the `a11-6` note "Errors …
/// are announced assertively"); the other tones are a polite live region
/// (`role="status"`). See `FeedbackSemantics` for how each platform gets
/// the assertive announcement.
class Toast extends StatelessWidget {
  /// Creates a toast.
  const new({
    super.key,
    this.tone = ToastTone.neutral,
    this.title,
    this.message,
    this.icon,
    this.action,
    this.onClose,
    this.closeLabel,
  }) : assert(
         onClose == null || closeLabel != null,
         'A closable toast needs the localized closeLabel.',
       );

  /// `.fm-toast` `width: 380px`.
  static const double width = 380;

  /// `Toast.jsx` icon size.
  static const double iconSize = 16;

  /// `.fm-toast__icon` `margin-top: 1px`.
  static const double iconOffset = 1;

  /// `.fm-toast__actions` `margin-top: -4px; margin-bottom: -4px`.
  static const double actionsOverhang = 4;

  /// `fm-rise-in`: the toast rises from 4 px below.
  static const double riseDistance = 4;

  /// `.fm-toast` `padding: 10px 6px 10px 12px`: the end padding.
  static const double paddingEnd = 6;

  /// The colour of the icon and its default glyph.
  final ToastTone tone;

  /// The bold first line; null shows none.
  final String? title;

  /// The second line; null shows none.
  final String? message;

  /// The icon; null shows [tone]'s (info, circle-check, triangle-alert,
  /// circle-alert).
  final IconName? icon;

  /// The one action; null shows none.
  final ToastAction? action;

  /// Called by the Dismiss button; null shows none.
  final VoidCallback? onClose;

  /// The localized name of the Dismiss button ("Dismiss"); required with
  /// [onClose]. Not a design-system prop.
  final String? closeLabel;

  /// The icon [tone] shows by default (`Toast.jsx` `ICONS`).
  static IconName defaultIconFor(ToastTone tone) => switch (tone) {
    ToastTone.neutral => IconName.info,
    ToastTone.success => IconName.circleCheck,
    ToastTone.warning => IconName.triangleAlert,
    ToastTone.danger => IconName.circleAlert,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final iconColor = switch (tone) {
      ToastTone.neutral => colors.iconSecondary,
      ToastTone.success => colors.successSolid,
      ToastTone.warning => colors.warningSolid,
      ToastTone.danger => colors.danger,
    };
    final padY = theme.space.space2_5;
    // The actions' negative margins become smaller padding around the row
    // and the same amount around the icon and the body.
    const overhang = actionsOverhang;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.space.space2_5,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            top: overhang + iconOffset,
            bottom: overhang,
          ),
          // iconSize, the Icon default.
          child: Icon(icon ?? defaultIconFor(tone), color: iconColor),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: overhang),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: theme.space.space0_5,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: theme.typography.bodyStrong.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                if (message != null)
                  Text(
                    message!,
                    style: theme.typography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.space.space0_5,
          children: [
            if (action case final action?)
              Button(
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                onPressed: action.onPressed,
                child: Text(
                  action.label,
                  style: TextStyle(color: colors.textAccent),
                ),
              ),
            if (onClose != null)
              IconButton(
                icon: IconName.x,
                label: closeLabel ?? '',
                size: IconButtonSize.sm,
                showTooltip: false,
                onPressed: onClose,
              ),
          ],
        ),
      ],
    );
    final card = SizedBox(
      width: width,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          theme.space.space3,
          padY - overhang,
          paddingEnd,
          padY - overhang,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.all(
            Radius.circular(theme.radius.radiusMd),
          ),
          boxShadow: theme.elevation.shadowPopover,
        ),
        child: row,
      ),
    );
    return FeedbackSemantics(
      alert: tone == ToastTone.danger,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: theme.motion.durSlow,
        curve: theme.motion.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * riseDistance),
            child: child,
          ),
        ),
        child: card,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<ToastTone>('tone', tone, defaultValue: ToastTone.neutral),
      )
      ..add(StringProperty('title', title, defaultValue: null))
      ..add(StringProperty('message', message, defaultValue: null))
      ..add(EnumProperty<IconName>('icon', icon, defaultValue: null))
      ..add(StringProperty('action', action?.label, defaultValue: null))
      ..add(ObjectFlagProperty<VoidCallback>.has('onClose', onClose))
      ..add(StringProperty('closeLabel', closeLabel, defaultValue: null));
  }
}
