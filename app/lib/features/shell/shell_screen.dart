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
/// Focus moves in the drawn order: title bar, mode bar, tool row, sidebar,
/// canvas, right panel, status bar ([ShellRegion]). The canvas has focus
/// when the shell opens. The shortcut table's keys work anywhere in it
/// ([ShellCommandScope]).
///
/// M1 reaches it only at `/debug/shell`, with placeholder documents; the
/// start screen stays at `/`. Narrow windows (G21, phase H6) are not
/// handled yet.
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
    return ShellCommandScope(
      onOpenSettings: onOpenSettings,
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
                  if (sidebarOpen)
                    ShellRegion.sidebar.wrap(const ShellSidebar()),
                  Expanded(
                    // Keyed, so the canvas keeps its state and focus when
                    // the sidebar before it hides or shows.
                    key: _canvasSlot,
                    child: ShellRegion.canvas.wrap(const ShellCanvas()),
                  ),
                  if (panelOpen) ShellRegion.panel.wrap(const ShellPanel()),
                ],
              ),
            ),
            ShellRegion.statusBar.wrap(const ShellStatusBar()),
          ],
        ),
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
