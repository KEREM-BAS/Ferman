import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/app/router.dart';
import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/settings/settings_pane.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings' top level on a phone, board a13-15: grouped rows, each going to
/// its pane on a route of its own, so the browser's back button leaves the
/// pane too. The rows are the panes of [SettingsPane] in their order, plus
/// the board's About and licence; those not built yet are disabled with
/// their reason (G129).
class PhoneSettingsList extends ConsumerWidget {
  /// The list.
  const new({super.key});

  /// The content's padding (`padding: 6px 16px`): vertical …
  static const double paddingY = 6;

  /// … and horizontal.
  static const double paddingX = 16;

  /// The gap between the groups (`gap: 22px`).
  static const double groupGap = 22;

  /// The gap under a group's title (`gap: 6px`).
  static const double titleGap = 6;

  /// A group title's size (`font: 400 13px/1`).
  static const double titleSize = 13;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    final mode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);

    Widget paneRow(SettingsPane pane, {String? value}) => PhoneSettingsRow(
      icon: pane.icon,
      label: pane.label(l10n),
      value: value,
      disabledReason: pane.feature?.disabledReason(context),
      onPressed: pane.available
          // `extra`: this pane sits on the list (FmSettings.aboveList).
          ? () =>
                context.push<void>(Routes.settingsPane(pane.path), extra: true)
          : null,
    );

    final groups = <(String?, List<Widget>)>[
      (
        null,
        [
          paneRow(
            SettingsPane.general,
            value: switch (mode) {
              AppThemeMode.system => l10n.settingsThemeSystem,
              AppThemeMode.light => l10n.settingsThemeLight,
              AppThemeMode.dark => l10n.settingsThemeDark,
            },
          ),
          paneRow(SettingsPane.language, value: language.endonym),
          paneRow(SettingsPane.editing),
          paneRow(SettingsPane.fonts),
        ],
      ),
      (
        l10n.settingsPhoneGroupDocuments,
        [
          paneRow(SettingsPane.signatures),
          paneRow(SettingsPane.ocr),
          paneRow(SettingsPane.ai),
        ],
      ),
      (
        l10n.settingsPanePrivacy,
        [
          paneRow(SettingsPane.privacy, value: l10n.settingsPhonePrivacyValue),
          paneRow(SettingsPane.updates),
          PhoneSettingsRow(
            icon: IconName.info,
            label: l10n.settingsPhoneAbout,
            disabledReason: Feature.aboutAndLicence.disabledReason(context),
          ),
        ],
      ),
      (null, [paneRow(SettingsPane.shortcuts), paneRow(SettingsPane.advanced)]),
    ];

    return ColoredBox(
      color: theme.colors.surfaceSunken,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: paddingX,
          vertical: paddingY,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: groupGap,
          children: [
            for (final (title, rows) in groups)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: titleGap,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: paddingX,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(
                          casing.upper(title),
                          style: theme.typography.body.copyWith(
                            fontSize: titleSize,
                            color: theme.colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.all(
                      Radius.circular(theme.radius.radiusLg),
                    ),
                    child: ColoredBox(
                      color: theme.colors.surfaceRaised,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, row) in rows.indexed)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                border: index == rows.length - 1
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                          color: theme.colors.borderSubtle,
                                          width: theme.border.borderWidth,
                                        ),
                                      ),
                              ),
                              child: row,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A row of [PhoneSettingsList] (a13-15): the icon on its accent tile, the
/// name, the value and the chevron. A row with no [onPressed] is disabled
/// and says why ([disabledReason]).
class PhoneSettingsRow extends StatelessWidget {
  /// A row.
  const new({
    required this.icon,
    required this.label,
    super.key,
    this.value,
    this.onPressed,
    this.disabledReason,
  });

  /// The row's least height (`min-height: 48px`).
  static const double minHeight = 48;

  /// The row's side padding (`padding: 0 14px`).
  static const double paddingX = 14;

  /// The row's vertical padding when a name wraps; the board's names fit.
  static const double paddingY = 6;

  /// The gap between its parts (`gap: 12px`).
  static const double gap = 12;

  /// The tile's side (`width: 30px`).
  static const double tileSize = 30;

  /// The tile's radius (`border-radius: 7px`).
  static const double tileRadius = 7;

  /// The icons' size (`size: 18`).
  static const double iconSize = 18;

  /// The tile icon's stroke (`stroke-width: 2`).
  static const double iconStroke = 2;

  /// The text's size (`font: 400 16px/1`).
  static const double textSize = 16;

  /// The value's largest width, so the name keeps its room; the board's
  /// longest value, "No data collected", fits on one line.
  static const double valueMaxWidth = 140;

  /// The same under [narrowWindow], where that value takes two lines and the
  /// name keeps a whole word.
  static const double valueMaxWidthNarrow = 110;

  /// The window width under which [valueMaxWidthNarrow] applies.
  static const double narrowWindow = 360;

  /// The pane's icon.
  final IconName icon;

  /// The pane's name.
  final String label;

  /// The current value, at the end; null shows none.
  final String? value;

  /// Opens the pane; null disables the row.
  final VoidCallback? onPressed;

  /// Why the row is disabled.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return FermanInteractive(
      onPressed: onPressed,
      disabledReason: disabledReason,
      semanticLabel: current == null ? label : '$label, $current',
      builder: (context, states, _) {
        final theme = context.ferman;
        final colors = theme.colors;
        final disabled = states.contains(WidgetState.disabled);
        final style = theme.typography.body.copyWith(fontSize: textSize);
        return FocusRing(
          visible: states.contains(WidgetState.focused),
          style: FocusRingStyle.inset,
          child: Container(
            constraints: const BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: paddingX,
              vertical: paddingY,
            ),
            color: states.contains(WidgetState.pressed)
                ? colors.surfaceHover
                : null,
            child: Row(
              spacing: gap,
              children: [
                Container(
                  width: tileSize,
                  height: tileSize,
                  alignment: AlignmentDirectional.center,
                  decoration: BoxDecoration(
                    // A row not built yet must not read as a working one.
                    color: disabled ? colors.surfaceSunken : colors.accent,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(tileRadius),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    strokeWidth: iconStroke,
                    color: disabled ? colors.iconDisabled : colors.textOnAccent,
                  ),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      style: style.copyWith(
                        color: disabled
                            ? colors.textDisabled
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (current != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width < narrowWindow
                          ? valueMaxWidthNarrow
                          : valueMaxWidth,
                    ),
                    child: ExcludeSemantics(
                      child: Text(
                        current,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: style.copyWith(color: colors.textTertiary),
                      ),
                    ),
                  ),
                Icon(
                  IconName.chevronRight,
                  size: iconSize,
                  flipRtl: true,
                  color: disabled ? colors.iconDisabled : colors.textTertiary,
                ),
              ],
            ),
          ),
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
      ..add(StringProperty('value', value))
      ..add(ObjectFlagProperty<VoidCallback>.has('onPressed', onPressed))
      ..add(StringProperty('disabledReason', disabledReason));
  }
}

/// A heading of a phone pane (a13-15b: `font: 500 14px/1`, the accent text).
class PhoneSettingsHead extends StatelessWidget {
  /// The heading [label].
  const new(this.label, {super.key});

  /// The drawn size.
  static const double size = 14;

  /// The heading's text.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Semantics(
      header: true,
      child: Text(
        label,
        style: theme.typography.body.copyWith(
          fontSize: size,
          fontWeight: theme.typeScale.weightMedium,
          color: theme.colors.textAccent,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
  }
}

/// Makes a control smaller than a finger answer to a band at least
/// `density.hitMin` tall: the Switch (26 px at touch density), the segments
/// of a SegmentedControl (38 px) and a Radio's row. A touch anywhere in the
/// band lands on the control at the same inline position.
class PhoneHitTarget extends SingleChildRenderObjectWidget {
  /// The band around [child].
  const new({required Widget super.child, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderPhoneHitTarget(context.ferman.density.hitMin);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPhoneHitTarget renderObject,
  ) {
    renderObject.minHeight = context.ferman.density.hitMin;
  }
}

/// The render object of [PhoneHitTarget].
class RenderPhoneHitTarget extends RenderShiftedBox {
  /// A band at least [minHeight] tall, its child added later.
  new(this._minHeight) : super(null);

  double _minHeight;

  /// The band's least height.
  double get minHeight => _minHeight;
  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  double _atLeast(double height) => height < _minHeight ? _minHeight : height;

  @override
  void performLayout() {
    final content = child!
      ..layout(constraints.copyWith(minHeight: 0), parentUsesSize: true);
    size = constraints.constrain(
      Size(content.size.width, _atLeast(content.size.height)),
    );
    (content.parentData! as BoxParentData).offset = Offset(
      0,
      (size.height - content.size.height) / 2,
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _atLeast(super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _atLeast(super.computeMaxIntrinsicHeight(width));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final inner = child!.getDryLayout(constraints.copyWith(minHeight: 0));
    return constraints.constrain(Size(inner.width, _atLeast(inner.height)));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final content = child!;
    return result.addWithPaintOffset(
      offset: (content.parentData! as BoxParentData).offset,
      position: Offset(position.dx, size.height / 2),
      hitTest: (result, transformed) =>
          content.hitTest(result, position: transformed),
    );
  }
}
