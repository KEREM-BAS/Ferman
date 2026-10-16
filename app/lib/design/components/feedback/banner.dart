import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/feedback/feedback_semantics.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
// The widgets library has its own Banner (the debug ribbon).
import 'package:flutter/widgets.dart' hide Banner, Icon;

/// The colours of a [Banner] (`.fm-banner`, `.fm-banner--success`, …).
enum BannerTone {
  /// Info fill, border and icon; the default.
  info,

  /// Success fill and border, solid success icon.
  success,

  /// Warning fill and border, solid warning icon.
  warning,

  /// Danger fill, border and icon.
  danger,

  /// Sunken surface, subtle border, secondary icon.
  neutral,
}

/// The shape of a [Banner].
enum BannerVariant {
  /// An inline callout with a border and 4 px corners; the default.
  box,

  /// A full-width bar with a bottom border only (`.fm-banner--bar`), the
  /// title and message on one line.
  bar,
}

/// An inline callout or a full-width bar, the design-system `Banner`
/// component (`components/feedback/feedback.css`, `.fm-banner`;
/// `Banner.jsx`). Never the Material banner (ADR 0011).
///
/// It shows [tone]'s 14 px icon (or [icon]), an optional [title] in
/// semibold caption type, the message [child] in caption type, then
/// [actions] (usually small `Button`s) and, with [onDismiss], an extra
/// small Dismiss icon button without a tooltip, named [dismissLabel].
///
/// The banner takes the width of its parent, which must be bounded.
///
/// For screen readers its title and message are its label, and a banner
/// that appears is announced: a danger or warning banner as an alert,
/// assertively (`Banner.jsx` `role="alert"`), the other tones politely, as
/// a live region (`role="status"`). See `FeedbackSemantics` for how each
/// platform gets the assertive announcement.
class Banner extends StatelessWidget {
  /// Creates a banner.
  const new({
    super.key,
    this.tone = BannerTone.info,
    this.variant = BannerVariant.box,
    this.title,
    this.icon,
    this.actions = const [],
    this.onDismiss,
    this.child,
    this.dismissLabel,
  }) : assert(
         onDismiss == null || dismissLabel != null,
         'A dismissible banner needs the localized dismissLabel.',
       );

  /// `Banner.jsx` icon size.
  static const double iconSize = 14;

  /// `.fm-banner__icon` `margin-top: 1px` (box only).
  static const double iconOffset = 1;

  /// `.fm-banner__actions` `margin: -3px -4px -3px 0`: how far the actions
  /// reach into the vertical padding.
  static const double actionsOverhangY = 3;

  /// `.fm-banner__actions` `margin: -3px -4px -3px 0`: how far the actions
  /// reach into the end padding.
  static const double actionsOverhangEnd = 4;

  /// The colours and the default icon.
  final BannerTone tone;

  /// Callout or bar.
  final BannerVariant variant;

  /// The bold first line; null shows none.
  final String? title;

  /// The icon; null shows [tone]'s (info, circle-check, triangle-alert,
  /// circle-alert, info).
  final IconName? icon;

  /// The action buttons at the end.
  final List<Widget> actions;

  /// Called by the Dismiss button; null shows none.
  final VoidCallback? onDismiss;

  /// The message, usually a [Text]; null shows none.
  final Widget? child;

  /// The localized name of the Dismiss button ("Dismiss"); required with
  /// [onDismiss]. Not a design-system prop.
  final String? dismissLabel;

  /// The icon [tone] shows by default (`Banner.jsx` `ICONS`).
  static IconName defaultIconFor(BannerTone tone) => switch (tone) {
    BannerTone.info || BannerTone.neutral => IconName.info,
    BannerTone.success => IconName.circleCheck,
    BannerTone.warning => IconName.triangleAlert,
    BannerTone.danger => IconName.circleAlert,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final (background, border, iconColor) = switch (tone) {
      BannerTone.info => (colors.infoBg, colors.infoBorder, colors.info),
      BannerTone.success => (
        colors.successBg,
        colors.successBorder,
        colors.successSolid,
      ),
      BannerTone.warning => (
        colors.warningBg,
        colors.warningBorder,
        colors.warningSolid,
      ),
      BannerTone.danger => (
        colors.dangerBg,
        colors.dangerBorder,
        colors.danger,
      ),
      BannerTone.neutral => (
        colors.surfaceSunken,
        colors.borderSubtle,
        colors.iconSecondary,
      ),
    };
    final bar = variant == BannerVariant.bar;
    final hasActions = actions.isNotEmpty || onDismiss != null;
    // The actions' negative margins become smaller padding around the row
    // and the same amount around the icon and the body, so every part
    // stays inside the banner (and inside its hit area).
    final overhangY = hasActions ? actionsOverhangY : 0.0;
    final padY = bar ? theme.space.space1_5 : theme.space.space2;
    final padX = bar ? theme.space.space3 : theme.space.space2_5;
    final caption = theme.typography.caption;

    final titleText = title == null
        ? null
        : Text(
            title!,
            style: caption.copyWith(fontWeight: theme.typeScale.weightSemibold),
          );
    final Widget body;
    if (bar) {
      // `.fm-banner--bar .fm-banner__body { gap: 6px }`: between the parts
      // and between the lines when they wrap.
      body = Wrap(
        spacing: theme.space.space1_5,
        runSpacing: theme.space.space1_5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [?titleText, ?child],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.space0_5,
        children: [?titleText, ?child],
      );
    }

    final row = Row(
      crossAxisAlignment: bar
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      spacing: theme.space.space2,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            top: overhangY + (bar ? 0 : iconOffset),
            bottom: overhangY,
          ),
          child: Icon(
            icon ?? defaultIconFor(tone),
            size: iconSize,
            color: iconColor,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: overhangY),
            child: body,
          ),
        ),
        if (hasActions)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: theme.space.space1,
            children: [
              ...actions,
              if (onDismiss != null)
                IconButton(
                  icon: IconName.x,
                  label: dismissLabel ?? '',
                  size: IconButtonSize.xs,
                  showTooltip: false,
                  onPressed: onDismiss,
                ),
            ],
          ),
      ],
    );
    final side = BorderSide(color: border, width: theme.border.borderWidth);
    return FeedbackSemantics(
      alert: tone == BannerTone.danger || tone == BannerTone.warning,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          padX,
          padY - overhangY,
          padX - (hasActions ? actionsOverhangEnd : 0),
          padY - overhangY,
        ),
        decoration: BoxDecoration(
          color: background,
          border: bar ? Border(bottom: side) : Border.fromBorderSide(side),
          borderRadius: bar
              ? null
              : BorderRadius.all(Radius.circular(theme.radius.radiusSm)),
        ),
        child: DefaultTextStyle.merge(
          style: caption.copyWith(color: colors.textPrimary),
          child: row,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<BannerTone>('tone', tone, defaultValue: BannerTone.info),
      )
      ..add(
        EnumProperty<BannerVariant>(
          'variant',
          variant,
          defaultValue: BannerVariant.box,
        ),
      )
      ..add(StringProperty('title', title, defaultValue: null))
      ..add(EnumProperty<IconName>('icon', icon, defaultValue: null))
      ..add(ObjectFlagProperty<VoidCallback>.has('onDismiss', onDismiss))
      ..add(StringProperty('dismissLabel', dismissLabel, defaultValue: null));
  }
}
