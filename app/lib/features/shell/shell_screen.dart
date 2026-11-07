import 'dart:math' as math;

import 'package:ferman/design/components/components.dart' show FermanMode;
import 'package:ferman/design/window_metrics.dart';
import 'package:ferman/features/comments/comments_panel.dart';
import 'package:ferman/features/editor/edit_history_panel.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/editor/links_panel.dart';
import 'package:ferman/features/editor/review_list.dart';
import 'package:ferman/features/forms/form_panel.dart';
import 'package:ferman/features/organize/crop_panel.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/organize/organize_panel.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/shell/shell_canvas.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/features/shell/shell_mode_bar.dart';
import 'package:ferman/features/shell/shell_pane_resize.dart';
import 'package:ferman/features/shell/shell_panel.dart';
import 'package:ferman/features/shell/shell_region.dart';
import 'package:ferman/features/shell/shell_sidebar.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shell_status_bar.dart';
import 'package:ferman/features/shell/shell_tool_rows.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The editor shell below the title bar (building block `FmWindow.dc.html`,
/// M1 phases H2 to H4): the mode bar, the current mode's tool row, the
/// sidebar, the canvas, the right panel and the status bar. Its title-bar
/// part is `ShellTitleBarContent`, which the router gives the window frame.
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
/// The router shows it at `/editor` once a document opens; the start
/// screen stays at `/`.
class FmWindow extends ConsumerWidget {
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
    final chosen = ref.watch(shellPaneWidthsProvider);
    final active = ref.watch(shellDocumentsProvider).active;
    // A locked tab and an error tab show only the canvas (a1-8, a1-9b,
    // a1-9c: FmWindow with `mode=""` and `status={false}`).
    final bare = active?.bare ?? false;
    // a6-3's tab: the mode bar, tool row and status bar, no side panels.
    final combine = active?.combine ?? false;
    // Edit's Undo history takes the right panel's place (a3-10).
    final history =
        ref.watch(shellModeProvider) == FermanMode.edit &&
        ref.watch(editHistoryOpenProvider);
    // So does the Link tool's list (a3-6).
    final links = ref.watch(linkToolProvider.select((tool) => tool.on));
    // So does Review edits (a3-12).
    final review =
        ref.watch(shellModeProvider) == FermanMode.edit &&
        ref.watch(reviewListProvider.select((list) => list.open));
    // a6-1: Organize's panel is about the selection, once there is one.
    final organizing =
        ref.watch(shellModeProvider) == FermanMode.organize &&
        ref.watch(selectedPagesProvider).isNotEmpty;
    // FmComments is Comment mode's panel (a4-1).
    final comments =
        ref.watch(shellModeProvider) == FermanMode.comment &&
        active?.document != null;
    // FmFormPanel or Fill anything is Fill & Sign's panel (a5-1, a5-4).
    final filling =
        ref.watch(shellModeProvider) == FermanMode.sign &&
        active?.document != null;
    // So does Crop and page size (a6-4).
    final crop = ref.watch(cropShowingProvider);
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
          final widths = shellPaneWidthsIn(
            chosen: chosen,
            shown: shown,
            width: width.isFinite ? width : null,
          );
          final room = width - WindowMetrics.canvasMinWidth;
          // A panel with its resize handle on the canvas side (B094).
          Widget resizable(ShellSide side, Widget pane) {
            final own = side == ShellSide.sidebar
                ? widths.sidebar
                : widths.panel;
            final other = side == ShellSide.sidebar
                ? (shown.panel ? widths.panel : 0)
                : (shown.sidebar ? widths.sidebar : 0);
            return Stack(
              children: [
                pane,
                PositionedDirectional(
                  top: 0,
                  bottom: 0,
                  start: side == ShellSide.panel ? 0 : null,
                  end: side == ShellSide.sidebar ? 0 : null,
                  child: ShellPaneResizeHandle(
                    side: side,
                    width: own,
                    limit: room - other,
                  ),
                ),
              ],
            );
          }

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
                  if (!bare) ...[
                    ShellRegion.modeBar.wrap(const ShellModeBar()),
                    ShellRegion.toolRow.wrap(const ShellToolRows()),
                  ],
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (shown.sidebar && !bare && !combine)
                          ShellRegion.sidebar.wrap(
                            resizable(
                              ShellSide.sidebar,
                              FmSidebar(width: widths.sidebar),
                            ),
                          ),
                        Expanded(
                          // Keyed, so the canvas keeps its state and focus
                          // when the sidebar before it hides or shows.
                          key: _canvasSlot,
                          child: ShellRegion.canvas.wrap(const ShellCanvas()),
                        ),
                        if (shown.panel && !bare && !combine)
                          ShellRegion.panel.wrap(
                            resizable(
                              ShellSide.panel,
                              crop
                                  ? CropPanel(width: widths.panel)
                                  : review
                                  // a3-12 is wider than it, room allowing.
                                  ? ReviewListPanel(
                                      width: math.max(
                                        widths.panel,
                                        math.min(
                                          ReviewListPanel.boardWidth,
                                          room -
                                              (shown.sidebar
                                                  ? widths.sidebar
                                                  : 0),
                                        ),
                                      ),
                                    )
                                  : history
                                  ? EditHistoryPanel(width: widths.panel)
                                  : links
                                  ? LinksPanel(width: widths.panel)
                                  : organizing
                                  ? OrganizePanel(width: widths.panel)
                                  : comments
                                  ? CommentsPanel(width: widths.panel)
                                  : filling
                                  ? FillSignPanel(width: widths.panel)
                                  : FmDocPanel(width: widths.panel),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!bare) ShellRegion.statusBar.wrap(const ShellStatusBar()),
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
