import 'dart:async';

import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The General pane of Settings, board a11-1 (Windows a11-1w).
///
/// Theme (Match system, Light, Dark) works: it restyles the app at once and
/// is stored (`themeModeProvider`). The rest is drawn as designed and
/// disabled with "Available in a future version" until its milestone
/// (G10): PDF pages in dark theme (Paper white and Dimmed in M2, Dark
/// reading mode in P2), the page layout and zoom for new documents and
/// reopening documents (M2, with the viewer) and the default PDF app (M2,
/// a1-3). Their values are the defaults the design draws.
///
/// The design's "Preview opens PDFs on this Mac." needs the system's
/// default-app lookup, which comes with the button in M2; until then the
/// row says what the button does, in a1-3's words. On Windows it names
/// Windows Settings › Default apps, where Windows lets people choose the
/// app (a11-1w note, G16; [defaultAppText]). The zoom option "100%" is
/// written as the region writes percentages (G34).
///
/// A theme that cannot be stored still applies; Settings says so
/// (`settingsSaveFailedProvider`).
class GeneralPane extends ConsumerWidget {
  /// The pane.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final reason = futureVersionReason(context);
    final mode = ref.watch(themeModeProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _sectionGap,
      children: [
        // The track spans the pane, its segments at the start (a11-1).
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: theme.space.space2,
          children: [
            Field.labelOf(context, l10n.settingsTheme),
            SegmentedControl<AppThemeMode>(
              semanticLabel: l10n.settingsTheme,
              value: mode,
              options: [
                SegmentOption(
                  value: AppThemeMode.system,
                  label: l10n.settingsThemeSystem,
                ),
                SegmentOption(
                  value: AppThemeMode.light,
                  label: l10n.settingsThemeLight,
                ),
                SegmentOption(
                  value: AppThemeMode.dark,
                  label: l10n.settingsThemeDark,
                ),
              ],
              onChanged: (mode) {
                final failure = ref.read(settingsSaveFailedProvider.notifier);
                unawaited(
                  ref
                      .read(themeModeProvider.notifier)
                      .select(mode)
                      .then((stored) => failure.record(stored: stored)),
                );
              },
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space2,
          children: [
            Field.labelOf(context, l10n.settingsPageTheme),
            for (final (value, label, description) in [
              (
                _PageLook.paper,
                l10n.settingsPagePaper,
                l10n.settingsPagePaperDescription,
              ),
              (
                _PageLook.dimmed,
                l10n.settingsPageDimmed,
                l10n.settingsPageDimmedDescription,
              ),
              (
                _PageLook.dark,
                l10n.settingsPageDark,
                l10n.settingsPageDarkDescription,
              ),
            ])
              Radio<_PageLook>(
                value: value,
                groupValue: _PageLook.paper,
                label: label,
                description: description,
                disabled: true,
                disabledReason: reason,
              ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space3,
          children: [
            Expanded(
              child: Select<String>(
                label: l10n.settingsPageLayout,
                size: FieldSize.sm,
                value: 'scroll',
                options: [
                  SelectOption(
                    value: 'scroll',
                    label: l10n.settingsPageLayoutScroll,
                  ),
                  SelectOption(
                    value: 'single',
                    label: l10n.settingsPageLayoutSingle,
                  ),
                  SelectOption(
                    value: 'spread',
                    label: l10n.settingsPageLayoutSpread,
                  ),
                ],
                disabled: true,
                disabledReason: reason,
              ),
            ),
            Expanded(
              child: Select<String>(
                label: l10n.settingsZoom,
                size: FieldSize.sm,
                value: 'fitWidth',
                options: [
                  SelectOption(
                    value: 'fitWidth',
                    label: l10n.settingsZoomFitWidth,
                  ),
                  SelectOption(
                    value: 'fitPage',
                    label: l10n.settingsZoomFitPage,
                  ),
                  SelectOption(
                    value: 'actual',
                    label: bidiIsolate(format.percent(100)),
                  ),
                ],
                disabled: true,
                disabledReason: reason,
              ),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Switch(
            label: l10n.settingsReopen,
            value: true,
            disabled: true,
            disabledReason: reason,
          ),
        ),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: _calloutPaddingX,
            vertical: _calloutPaddingY,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusMd),
            ),
          ),
          child: Row(
            spacing: theme.space.space3,
            children: [
              Expanded(
                child: Text(defaultAppText(l10n), style: theme.typography.body),
              ),
              Button(
                size: ButtonSize.sm,
                disabledReason: reason,
                child: Text(l10n.settingsMakeDefault),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The default-app row's text for the system the app runs on, the one
  /// place it is chosen (G16): on Windows it names Windows Settings ›
  /// Default apps, elsewhere it says what the button does (a1-3).
  static String defaultAppText(AppLocalizations l10n) =>
      switch (defaultTargetPlatform) {
        TargetPlatform.windows => l10n.settingsDefaultAppWindows,
        _ => l10n.settingsDefaultApp,
      };

  /// The gap between the groups (`gap: 18px`).
  static const double _sectionGap = 18;

  /// The default-app row's padding (`padding: 12px 14px`): horizontal …
  static const double _calloutPaddingX = 14;

  /// … and vertical.
  static const double _calloutPaddingY = 12;
}

/// The choices of PDF pages in dark theme (a11-1): drawn; Paper white and
/// Dimmed are built in M2, Dark reading mode in P2.
enum _PageLook { paper, dimmed, dark }
