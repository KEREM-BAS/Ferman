import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/app/theme_mode.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/settings/phone_settings.dart';
import 'package:ferman/features/settings/settings_save_failure.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/default_app.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The General pane of Settings, board a11-1 (Windows a11-1w).
///
/// Theme (Match system, Light, Dark) works: it restyles the app at once and
/// is stored (`themeModeProvider`), as do Reopen documents from last time
/// (B079, `DocumentOpener.reopenLast`), PDF pages in dark theme (Paper
/// white or Dimmed, B078), and the page layout and zoom a document opens
/// with (B035, B034; `viewerProvider`). The rest is drawn as designed and
/// disabled with "Available in a future version" until its milestone
/// (G10), through its feature in the feature registry ([Feature]): Dark
/// reading mode (P2) and the default PDF app on Windows and Linux (B101,
/// B102).
///
/// On macOS the row names the app that opens PDF files now, as a11-1 draws
/// it ("Preview opens PDFs on this Mac.", [pdfHandlerProvider]), and the
/// button asks macOS to make Ferman that app (B080); once Ferman is, the
/// row says so and the button goes. Where the system does not say, the
/// row says what the button does, in a1-3's words. On Windows it names
/// Windows Settings › Default apps, where Windows lets people choose the
/// app (a11-1w note, G16; [defaultAppText]). The zoom option "100%" is
/// written as the region writes percentages (G34).
///
/// A theme that cannot be stored still applies; Settings says so
/// (`settingsSaveFailedProvider`).
///
/// At phone width (G129) everything stacks in one column, with touch bands
/// on the small controls; the default-app row goes, since no phone board
/// draws it and a browser cannot make itself the PDF app.
class GeneralPane extends ConsumerWidget {
  /// The pane.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final handler = ref.watch(pdfHandlerProvider).value;
    final settings = ref.watch(settingsProvider);
    final feature = defaultAppFeature;
    final phone = WindowMetrics.isPhone(context);
    Widget band(Widget control) =>
        phone ? PhoneHitTarget(child: control) : control;

    final layout = Select<NewDocumentLayout>(
      label: l10n.settingsPageLayout,
      size: FieldSize.sm,
      value: settings.pageLayout,
      options: [
        SelectOption(
          value: NewDocumentLayout.scroll,
          label: l10n.settingsPageLayoutScroll,
        ),
        SelectOption(
          value: NewDocumentLayout.single,
          label: l10n.settingsPageLayoutSingle,
        ),
        SelectOption(
          value: NewDocumentLayout.spread,
          label: l10n.settingsPageLayoutSpread,
        ),
      ],
      onChanged: (layout) => unawaited(
        changeSetting(ref, (current) => current.copyWith(pageLayout: layout)),
      ),
    );
    final zoom = Select<NewDocumentZoom>(
      label: l10n.settingsZoom,
      size: FieldSize.sm,
      value: settings.zoom,
      options: [
        SelectOption(
          value: NewDocumentZoom.fitWidth,
          label: l10n.settingsZoomFitWidth,
        ),
        SelectOption(
          value: NewDocumentZoom.fitPage,
          label: l10n.settingsZoomFitPage,
        ),
        SelectOption(
          value: NewDocumentZoom.actual,
          label: bidiIsolate(format.percent(100)),
        ),
      ],
      onChanged: (zoom) => unawaited(
        changeSetting(ref, (current) => current.copyWith(zoom: zoom)),
      ),
    );

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
            band(
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
                PageLook.paper,
                l10n.settingsPagePaper,
                l10n.settingsPagePaperDescription,
              ),
              (
                PageLook.dimmed,
                l10n.settingsPageDimmed,
                l10n.settingsPageDimmedDescription,
              ),
            ])
              band(
                Radio<PageLook?>(
                  value: value,
                  groupValue: settings.pageLook,
                  label: label,
                  description: description,
                  onChanged: (look) => unawaited(
                    changeSetting(
                      ref,
                      (current) => current.copyWith(pageLook: look),
                    ),
                  ),
                ),
              ),
            band(
              Radio<PageLook?>(
                value: null,
                groupValue: settings.pageLook,
                label: l10n.settingsPageDark,
                description: l10n.settingsPageDarkDescription,
                disabled: true,
                disabledReason: Feature.darkReadingMode.disabledReason(context),
              ),
            ),
          ],
        ),
        if (phone)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.space.space3,
            children: [layout, zoom],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: theme.space.space3,
            children: [
              Expanded(child: layout),
              Expanded(child: zoom),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: band(
            Switch(
              label: l10n.settingsReopen,
              value: ref.watch(
                settingsProvider.select((settings) => settings.reopenDocuments),
              ),
              onChanged: (reopen) => unawaited(
                changeSetting(
                  ref,
                  (settings) => settings.copyWith(reopenDocuments: reopen),
                ),
              ),
            ),
          ),
        ),
        if (!phone)
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
                  child: Text(switch (handler) {
                    PdfHandler(ferman: true) => l10n.settingsDefaultAppFerman,
                    PdfHandler(:final name) => l10n.settingsDefaultAppOther(
                      bidiIsolate(name),
                    ),
                    null => defaultAppText(l10n),
                  }, style: theme.typography.body),
                ),
                if (handler?.ferman != true)
                  Button(
                    size: ButtonSize.sm,
                    onPressed: feature == null
                        ? () => unawaited(makeFermanDefault(ref))
                        : null,
                    disabledReason: feature?.disabledReason(context),
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

  /// The feature that still keeps the default-app button disabled on the
  /// system the app runs on, null on macOS, where it works (B080): each
  /// system makes Ferman the default in its own way and in its own
  /// milestone (B101, B102).
  static Feature? get defaultAppFeature => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => null,
    TargetPlatform.windows => Feature.defaultAppWindows,
    _ => Feature.defaultAppLinux,
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
