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
    final sidebarOpen = ref.watch(shellSidebarOpenProvider);
    final panelOpen = ref.watch(shellPanelOpenProvider);
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
            active: sidebarOpen,
            shortcut: ShellCommand.toggleSidebar.caps(platform),
            onPressed: () =>
                ref.read(shellSidebarOpenProvider.notifier).toggle(),
          ),
          // The tabs take the room they need and scroll when the bar is too
          // narrow; the rest of the room is FmWindow's `flex: 1` spacer.
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
            active: panelOpen,
            shortcut: ShellCommand.togglePanel.caps(platform),
            onPressed: () => ref.read(shellPanelOpenProvider.notifier).toggle(),
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
