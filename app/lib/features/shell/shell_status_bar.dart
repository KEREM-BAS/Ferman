import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The status bar (FmWindow `<footer>`, lines 168–178): `--statusbar-h`
/// tall on the panel surface with a subtle line above, in the caption
/// style with tabular figures.
///
/// At the start: the previous and next page buttons with "Page 1 of 3",
/// and the zoom out and in buttons around "100%", written as the region
/// writes percentages ("%100" for Türkiye, G34) (shown while the active
/// document's page count is known; the buttons need a rendered document,
/// so they are disabled with the future-version tooltip until M2, through
/// the feature registry's [Feature.pageNavigation] and [Feature.zoom]).
/// Then the
/// text language of the selection when there is one ([language], FmWindow
/// `statusLang`; none in M1). At the end, the active document's save state
/// through `SaveIndicator`, the saved time in the region's format; nothing
/// while the document is still opening. Region values keep their own order
/// in right-to-left text ([bidiIsolate]: "2:32 PM" never splits).
class ShellStatusBar extends ConsumerWidget {
  /// The status bar.
  const new({super.key, this.language});

  /// The language of the selected text (FmWindow `statusLang`), or null to
  /// leave it out.
  final String? language;

  /// FmWindow's zoom readout: `min-width: 40px`.
  static const double zoomTextWidth = 40;

  /// FmWindow's language mark: a 12 px `languages` glyph at stroke 2.
  static const double markSize = 12;

  /// The stroke of [markSize] glyphs.
  static const double markStroke = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final document = ref.watch(shellDocumentsProvider).active;
    final region = ref.watch(regionProvider).region;
    final format = RegionFormat.forRegion(region);
    final pages = document?.pageCount;
    final saveState = document?.saveState;

    IconButton button(
      Feature feature,
      IconName icon,
      String label,
      ShellCommand command,
    ) => IconButton(
      icon: icon,
      label: label,
      size: IconButtonSize.xs,
      tooltipSide: TooltipSide.top,
      shortcut: command.caps(platform),
      disabledReason: feature.disabledReason(context),
    );

    final language = this.language;
    return Container(
      height: theme.density.statusbarH,
      padding: EdgeInsetsDirectional.only(
        start: theme.space.space2,
        end: theme.space.space3,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfacePanel,
        border: Border(
          top: BorderSide(
            color: theme.colors.borderSubtle,
            width: theme.border.borderWidth,
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: theme.typography.caption.copyWith(
          color: theme.colors.textSecondary,
          fontFeatures: theme.typeScale.numericTabular,
        ),
        maxLines: 1,
        softWrap: false,
        child: Row(
          spacing: theme.space.space3,
          children: [
            if (pages != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space0_5,
                children: [
                  button(
                    Feature.pageNavigation,
                    IconName.chevronUp,
                    l10n.shellPreviousPage,
                    ShellCommand.previousPage,
                  ),
                  button(
                    Feature.pageNavigation,
                    IconName.chevronDown,
                    l10n.shellNextPage,
                    ShellCommand.nextPage,
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: theme.space.space1,
                    ),
                    child: Text(
                      l10n.shellPageOf(
                        format.integer(1),
                        format.integer(pages),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space0_5,
                children: [
                  button(
                    Feature.zoom,
                    IconName.minus,
                    l10n.shellZoomOut,
                    ShellCommand.zoomOut,
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: zoomTextWidth),
                    child: Text(
                      bidiIsolate(format.percent(100)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  button(
                    Feature.zoom,
                    IconName.plus,
                    l10n.shellZoomIn,
                    ShellCommand.zoomIn,
                  ),
                ],
              ),
            ],
            if (language != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: theme.space.space1_5,
                children: [
                  Icon(
                    IconName.languages,
                    size: markSize,
                    strokeWidth: markStroke,
                    color: theme.colors.textSecondary,
                  ),
                  Text(language),
                ],
              ),
            const Spacer(),
            if (saveState != null)
              SaveIndicator(
                state: saveState,
                savedAt: document?.savedAt,
                region: region,
                savedLabel: (time) =>
                    l10n.shellSavedOnDevice(bidiIsolate(time)),
                label: switch (saveState) {
                  SaveState.unsaved => l10n.shellUnsavedChanges,
                  SaveState.saved => l10n.shellSavedOnDevice(
                    switch (document?.savedAt) {
                      final at? => bidiIsolate(format.time(at)),
                      null => '',
                    },
                  ),
                  SaveState.saving => l10n.shellSaving,
                  SaveState.error => l10n.shellSaveError,
                  SaveState.readOnly => l10n.shellReadOnly,
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('language', language, defaultValue: null));
  }
}
