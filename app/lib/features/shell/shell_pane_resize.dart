import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The drag handle on the canvas-side edge of the sidebar or the right
/// panel (B094, G21): no board draws one, so it is invisible over the
/// panel's border and shows the column-resize cursor. Dragging it sets the
/// panel's width ([ShellPaneWidths]) up to [limit], the most the canvas
/// leaves it now. Screen readers increase and decrease the width in steps.
class ShellPaneResizeHandle extends ConsumerWidget {
  /// A handle for [side], [width] wide now.
  const new({
    required this.side,
    required this.width,
    required this.limit,
    super.key,
  });

  /// The panel the handle resizes.
  final ShellSide side;

  /// The panel's width now.
  final double width;

  /// The widest the panel can be in the window now.
  final double limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final widths = ref.read(shellPaneWidthsProvider.notifier);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The sidebar grows towards the end, the panel towards the start.
    final towardsEnd = (side == ShellSide.sidebar) != rtl;
    void resize(double to) => widths.resize(side, to < limit ? to : limit);
    final step = theme.space.space4;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final least = ShellPaneWidths.minWidth(side);
    // A window too narrow for more leaves the limit below the minimum.
    final most = limit < least ? least : limit;
    String px(double value) => format.integer(value.clamp(least, most).round());
    return Semantics(
      container: true,
      value: px(width),
      increasedValue: px(width + step),
      decreasedValue: px(width - step),
      label: side == ShellSide.sidebar
          ? l10n.shellResizeSidebar
          : l10n.shellResizePanel,
      onIncrease: () => resize(width + step),
      onDecrease: () => resize(width - step),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => resize(
            width + (towardsEnd ? details.delta.dx : -details.delta.dx),
          ),
          child: SizedBox(width: theme.space.space1_5),
        ),
      ),
    );
  }
}
