import 'package:flutter/widgets.dart';

/// The parts of the shell in their focus order (ROADMAP step 8): Tab moves
/// from the title bar through the mode bar, the tool row, the sidebar, the
/// canvas and the right panel to the status bar, in right to left too.
enum ShellRegion {
  /// The title bar's content: home, document tabs, search and settings.
  titleBar,

  /// The mode bar: sidebar toggle, mode tabs, panel toggle, Save.
  modeBar,

  /// The current mode's tool row.
  toolRow,

  /// The sidebar.
  sidebar,

  /// The document canvas.
  canvas,

  /// The right panel.
  panel,

  /// The status bar.
  statusBar;

  /// The key of the region's subtree, for tests and focus checks.
  ValueKey<ShellRegion> get key => ValueKey(this);

  /// [child] as this region: a [FocusTraversalGroup] at its place in the
  /// shell's order, keyed with [key] so it keeps its state when a region
  /// before it is hidden.
  Widget wrap(Widget child) => FocusTraversalOrder(
    key: key,
    order: NumericFocusOrder(index.toDouble()),
    child: FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: child,
    ),
  );

  /// The region [context] is in, or null outside the shell.
  static ShellRegion? of(BuildContext context) {
    ShellRegion? found;
    context.visitAncestorElements((element) {
      final key = element.widget.key;
      if (key is ValueKey<ShellRegion>) {
        found = key.value;
        return false;
      }
      return true;
    });
    return found;
  }
}
