import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The mode bar under the title bar (FmWindow lines 36–43): `--modebar-h`
/// tall on the panel surface with a subtle line below, holding the sidebar
/// toggle, the eight mode tabs, the AI button (only when AI is on), the
/// panel toggle and Save.
///
/// Save follows the active document (fix 4): with no unsaved changes it is
/// disabled with "No changes to save" (FmWindow `saveTip`); with unsaved
/// changes it would save, which comes in M3, so until then it is disabled
/// with the future-version tooltip.
class ShellModeBar extends ConsumerWidget {
  /// The mode bar.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final platform = ref.watch(shortcutPlatformProvider);
    final mode = ref.watch(shellModeProvider);
    // What the shell shows: a panel that stepped aside in a narrow window
    // reads as off, and its toggle brings it back (G21).
    final shown =
        ShellPanelsScope.maybeOf(context) ??
        ref.watch<ShellPanels>(shellPanelsProvider);
    final aiOn = ref.watch(shellAiEnabledProvider);
    final active = ref.watch(shellDocumentsProvider).active;
    final future = futureVersionReason(context);
    final unsaved = active?.unsaved ?? false;
    return Container(
      height: theme.density.modebarH,
      padding: EdgeInsetsDirectional.only(
        start: theme.space.space2,
        end: theme.space.space2_5,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfacePanel,
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
          IconButton(
            icon: IconName.panelLeft,
            label: l10n.shellToggleSidebar,
            size: IconButtonSize.sm,
            active: shown.sidebar,
            shortcut: ShellCommand.toggleSidebar.caps(platform),
            // Too narrow for the sidebar beside the document: disabled with
            // the reason (G21, G22).
            disabledReason: shown.sidebarAvailable
                ? null
                : l10n.shellWindowTooNarrow,
            onPressed: shown.sidebarAvailable
                ? () => toggleShellSide(ref, ShellSide.sidebar, shown: shown)
                : null,
          ),
          // The tabs take the room they need, fall back to icons when their
          // labels do not fit and scroll when even the icons do not (G21);
          // the rest of the room is FmWindow's `flex: 1` spacer.
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ModeTabs(
                value: mode,
                labelOf: l10n.modeLabel,
                semanticLabel: l10n.shellModeLabel,
                onChanged: ref.read(shellModeProvider.notifier).select,
              ),
            ),
          ),
          if (aiOn)
            IconButton(
              icon: IconName.sparkles,
              label: l10n.shellAiAssistant,
              size: IconButtonSize.sm,
              active: false,
              disabledReason: future,
            ),
          IconButton(
            icon: IconName.panelRight,
            label: l10n.shellTogglePanel,
            size: IconButtonSize.sm,
            active: shown.panel,
            shortcut: ShellCommand.togglePanel.caps(platform),
            disabledReason: shown.panelAvailable
                ? null
                : l10n.shellWindowTooNarrow,
            onPressed: shown.panelAvailable
                ? () => toggleShellSide(ref, ShellSide.panel, shown: shown)
                : null,
          ),
          Button(
            variant: ButtonVariant.primary,
            size: ButtonSize.sm,
            icon: IconName.save,
            disabledReason: unsaved ? future : l10n.shellNoChangesToSave,
            child: Text(l10n.shellSave),
          ),
        ],
      ),
    );
  }
}
