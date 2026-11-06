import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:go_router/go_router.dart';

/// The sections of the phone's navigation bar (FmPhone `tab`).
enum PhoneTab {
  /// The start screen.
  home,

  /// The file browser (a13-3), not built yet.
  files,

  /// Scan to PDF, not built yet.
  scan,

  /// Settings.
  settings,
}

/// A phone screen, the screen part of the design's `FmPhone` in its Material
/// form (G129): the top app bar when [title] is set, [child], and the
/// navigation bar when [tab] is set. The device around it (bezel, status bar,
/// gesture bar) belongs to the browser or the system, so it is left out.
class FmPhone extends StatelessWidget {
  /// A phone screen around [child].
  const new({
    required this.child,
    super.key,
    this.title,
    this.onBack,
    this.actions = const [],
    this.tab,
  });

  /// The app bar's height (`height: 64px`).
  static const double topBarHeight = 64;

  /// The navigation bar's height (`height: 80px`).
  static const double navBarHeight = 80;

  /// The title's start padding with a back button (`--titlePad`) …
  static const double titlePadWithBack = 4;

  /// … and without one.
  static const double titlePad = 16;

  /// The title's size and line height (`font: 400 22px/28px`).
  static const double titleSize = 22;

  /// The title's line height.
  static const double titleHeight = 28 / 22;

  /// The screen; it fills what the bars leave.
  final Widget child;

  /// The top app bar's title; null leaves the bar out (first run's steps).
  final String? title;

  /// Called by the back arrow; null shows none (`nav="none"`).
  final VoidCallback? onBack;

  /// The controls at the bar's end, `IconButton`s of the large size or text
  /// buttons.
  final List<Widget> actions;

  /// The section shown as current; null leaves the navigation bar out.
  final PhoneTab? tab;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final name = title;
    final back = onBack;
    final current = tab;
    return ColoredBox(
      color: colors.surfacePanel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (name != null)
            Container(
              height: topBarHeight,
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space1,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.borderSubtle,
                    width: theme.border.borderWidth,
                  ),
                ),
              ),
              child: Row(
                spacing: theme.space.space1,
                children: [
                  if (back != null)
                    IconButton(
                      icon: IconName.arrowLeft,
                      label: AppLocalizations.of(context).onboardingBack,
                      size: IconButtonSize.lg,
                      showTooltip: false,
                      onPressed: back,
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: back == null ? titlePad : titlePadWithBack,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.prose.copyWith(
                            fontSize: titleSize,
                            height: titleHeight,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          Expanded(child: child),
          if (current != null) _NavBar(current: current),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('title', title))
      ..add(ObjectFlagProperty<VoidCallback>.has('onBack', onBack))
      ..add(EnumProperty<PhoneTab>('tab', tab));
  }
}

class _NavBar extends StatelessWidget {
  const new({required this.current});

  final PhoneTab current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget item(
      PhoneTab tab,
      IconName icon,
      String label, {
      VoidCallback? onPressed,
      Feature? feature,
    }) => Expanded(
      child: _NavItem(
        icon: icon,
        label: label,
        selected: tab == current,
        // Going to the section you are in does nothing, as on the boards.
        onPressed: tab == current ? () {} : onPressed,
        disabledReason: feature?.disabledReason(context),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.phoneSections,
      child: Container(
        height: FmPhone.navBarHeight,
        color: context.ferman.colors.surfaceRaised,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            item(
              PhoneTab.home,
              IconName.house,
              l10n.phoneTabHome,
              onPressed: () => context.go(Routes.start),
            ),
            item(
              PhoneTab.files,
              IconName.folder,
              l10n.phoneTabFiles,
              feature: Feature.phoneFiles,
            ),
            item(
              PhoneTab.scan,
              IconName.scan,
              l10n.phoneTabScan,
              feature: Feature.scanToPdf,
            ),
            item(
              PhoneTab.settings,
              IconName.settings,
              l10n.phoneTabSettings,
              onPressed: () => unawaited(context.push(Routes.settings)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<PhoneTab>('current', current));
  }
}

class _NavItem extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.disabledReason,
  });

  /// The width of the indicator behind the icon (`56px`, `height: 32px`).
  static const double indicatorWidth = 56;

  /// The indicator's height.
  static const double indicatorHeight = 32;

  /// The icon's stroke when selected (`--sw: 2.1`) …
  static const double strokeSelected = 2.1;

  /// … and otherwise (`--sw: 1.6`).
  static const double stroke = 1.6;

  /// The label's size (`12px`).
  static const double labelSize = 12;

  final IconName icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    return FermanInteractive(
      onPressed: onPressed,
      disabledReason: disabledReason,
      selected: selected,
      tooltipSide: TooltipSide.top,
      builder: (context, states, _) {
        final disabled = states.contains(WidgetState.disabled);
        final color = selected
            ? colors.textAccent
            : disabled
            ? colors.textDisabled
            : colors.textSecondary;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: theme.space.space1,
          children: [
            Container(
              width: indicatorWidth,
              height: indicatorHeight,
              alignment: AlignmentDirectional.center,
              decoration: BoxDecoration(
                color: selected
                    ? colors.accentSubtle
                    : states.contains(WidgetState.pressed) ||
                          states.contains(WidgetState.hovered)
                    ? colors.surfaceHover
                    : null,
                borderRadius: BorderRadius.all(
                  Radius.circular(theme.radius.radiusMd),
                ),
              ),
              child: Icon(
                icon,
                size: theme.density.iconLg,
                color: disabled ? colors.iconDisabled : color,
                strokeWidth: selected ? strokeSelected : stroke,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(
                fontSize: labelSize,
                fontWeight: selected
                    ? theme.typeScale.weightSemibold
                    : theme.typeScale.weightMedium,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<IconName>('icon', icon))
      ..add(StringProperty('label', label))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(ObjectFlagProperty<VoidCallback>.has('onPressed', onPressed))
      ..add(StringProperty('disabledReason', disabledReason));
  }
}
