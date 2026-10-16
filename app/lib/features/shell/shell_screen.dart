import 'package:ferman/features/shell/shell_canvas.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/features/shell/shell_mode_bar.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_region.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/features/shell/shell_tool_rows.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The editor shell below the title bar (FmWindow, M1 phases H2 to H4): the
/// mode bar, the current mode's tool row, the sidebar, the canvas, the
/// right panel and the status bar. Its title-bar part is
/// `ShellTitleBarContent`, which the router gives the window frame.
///
/// Sizes at 1440 × 900 come from the tokens: mode bar `--modebar-h` (40),
/// tool row `--toolbar-h` (44, plus FmWindow's second 1 px line), sidebar
/// `--sidebar-w` (216), right panel `--panel-w` (264), status bar
/// `--statusbar-h` (26). The mode bar's toggles show and hide the sidebar
/// and the panel.
///
/// **Narrow windows** (G21, phase H6): the shell follows the width it is
/// laid out at, never the platform. The side panels step aside before the
/// canvas gets narrower than `WindowMetrics.canvasMinWidth` ([ShellPanels]:
/// the right panel first, unless the user opened it last); the tool rows
/// hide labels and move tools into their overflow menu (`Toolbar`); the
/// mode tabs fall back to icons when their labels do not fit (`ModeTabs`).
/// The width is recorded in `shellWidthProvider` after each layout, for
/// the toggles' shortcuts.
///
/// Focus moves in the drawn order: title bar, mode bar, tool row, sidebar,
/// canvas, right panel, status bar ([ShellRegion]). The canvas has focus
/// when the shell opens. The shortcut table's keys work anywhere in it
/// ([ShellCommandScope]).
///
/// M1 reaches it only at `/debug/shell`, with placeholder documents; the
/// start screen stays at `/`.
class ShellScreen extends ConsumerWidget {
  /// The shell.
  const new({super.key, this.onOpenSettings});

  /// Opens Settings (⌘, or Ctrl+,); null until the settings route exists.
  final VoidCallback? onOpenSettings;

  static const Key _canvasSlot = ValueKey('shell-canvas-slot');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarOpen = ref.watch(shellSidebarOpenProvider);
    final panelOpen = ref.watch(shellPanelOpenProvider);
    final preferred = ref.watch(shellPanelPreferenceProvider);
    return ShellCommandScope(
      onOpenSettings: onOpenSettings,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final shown = ShellPanels.resolve(
            width: width.isFinite ? width : null,
            sidebarOpen: sidebarOpen,
            panelOpen: panelOpen,
            preferred: preferred,
          );
          if (width.isFinite && ref.read(shellWidthProvider) != width) {
            // Not during the build: providers change between frames.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                ref.read(shellWidthProvider.notifier).measured(width);
              }
            });
          }
          return ShellPanelsScope(
            panels: shown,
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShellRegion.modeBar.wrap(const ShellModeBar()),
                  ShellRegion.toolRow.wrap(const ShellToolRows()),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (shown.sidebar)
                          ShellRegion.sidebar.wrap(const ShellSidebar()),
                        Expanded(
                          // Keyed, so the canvas keeps its state and focus
                          // when the sidebar before it hides or shows.
                          key: _canvasSlot,
                          child: ShellRegion.canvas.wrap(const ShellCanvas()),
                        ),
                        if (shown.panel)
                          ShellRegion.panel.wrap(const ShellPanel()),
                      ],
                    ),
                  ),
                  ShellRegion.statusBar.wrap(const ShellStatusBar()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      ObjectFlagProperty<VoidCallback>.has('onOpenSettings', onOpenSettings),
    );
  }
}
