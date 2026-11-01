import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Takes files dropped on the window (a1-6, G105): while files are dragged
/// over it, a1-6's overlay covers [child], the screen below the title bar,
/// and a drop opens each file in a new tab ([DocumentOpener.open]). The
/// [titleBar] above, with the document tabs, takes drops too.
///
/// Files arrive through desktop_drop, which names them only once they are
/// dropped (G117): the overlay shows no count and no row per file. a1-6's
/// "Combine into one PDF" target is disabled until combining ships (B104),
/// so a drop anywhere opens tabs.
///
/// Nothing is taken where [enabled] is false (first run, Settings) or while
/// opening is disabled ([openFilesDisabledReason]: the engine's problem,
/// the web build). The widget stays in the tree either way, so the title
/// bar keeps its state when the screen below changes.
class FileDrop extends ConsumerStatefulWidget {
  /// Takes drops on [titleBar] and [child] while [enabled].
  const new({
    required this.enabled,
    required this.child,
    super.key,
    this.titleBar,
  });

  /// Whether this screen takes drops: the start screen and the editor.
  final bool enabled;

  /// The title bar above [child]; null where the system draws it.
  final Widget? titleBar;

  /// The screen the overlay covers.
  final Widget child;

  @override
  ConsumerState<FileDrop> createState() => _FileDropState();
}

class _FileDropState extends ConsumerState<FileDrop> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final enabled =
        widget.enabled && openFilesDisabledReason(context, ref) == null;
    final content = Stack(
      fit: StackFit.expand,
      children: [widget.child, if (enabled && _over) const _DropOverlay()],
    );
    final bar = widget.titleBar;
    return DropTarget(
      enable: enabled,
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) => unawaited(
        ref.read(documentOpenerProvider.notifier).open([
          for (final file in details.files) file.path,
        ]),
      ),
      child: bar == null
          ? content
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar,
                Expanded(child: content),
              ],
            ),
    );
  }
}

/// a1-6's overlay (FmStart `dragOver`): a dashed accent frame on the
/// accent-subtle fill, 16 px inside the screen, with the upload tile, the
/// headline and its line, and the two targets. "Open in tabs" keeps the
/// accent ring, as the only target that works; "Combine into one PDF" is
/// disabled, its line the future-version reason (G10, B104).
class _DropOverlay extends StatelessWidget {
  const new();

  /// The gap between the head and the targets (`gap: 28px`).
  static const double gap = 28;

  /// The frame's dashed border (`border: 2px dashed`) …
  static const double borderWidth = 2;

  /// … which Chromium draws as 6 px dashes …
  static const double dashLength = 6;

  /// … with 4 px gaps (the `a1-6` render).
  static const double dashGap = 4;

  /// The upload icon (`size={28}`).
  static const double iconSize = 28;

  /// A target's width (`repeat(2, 300px)`).
  static const double targetWidth = 300;

  /// A target's padding (`padding: 18px`).
  static const double targetPadding = 18;

  /// A target's icon (`size={20}`).
  static const double targetIconSize = 20;

  /// A target's title (`font: 600 15px/20px`).
  static const double targetTitleSize = 15;

  /// … and its line height.
  static const double targetTitleHeight = 20;

  /// The ring of the target under the pointer (`0 0 0 2px var(--accent)`).
  static const double ringWidth = 2;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final radiusXl = BorderRadius.all(Radius.circular(theme.radius.radiusXl));
    return Semantics(
      container: true,
      liveRegion: true,
      child: ColoredBox(
        color: colors.surfacePanel,
        child: Padding(
          padding: EdgeInsetsDirectional.all(theme.space.space4),
          child: CustomPaint(
            foregroundPainter: DropZoneBorderPainter(
              color: colors.accent,
              width: borderWidth,
              radius: theme.radius.radiusXl,
              dashed: true,
              dashLength: dashLength,
              dashGap: dashGap,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accentSubtle,
                borderRadius: radiusXl,
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: gap,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: theme.space.space2_5,
                        children: [
                          Container(
                            width: DropZone.tileSize,
                            height: DropZone.tileSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surfaceRaised,
                              borderRadius: BorderRadius.all(
                                Radius.circular(theme.radius.radiusLg),
                              ),
                              boxShadow: theme.elevation.shadowSm,
                            ),
                            child: Icon(
                              IconName.upload,
                              size: iconSize,
                              color: colors.textAccent,
                            ),
                          ),
                          Text(
                            l10n.dropOverlayTitle,
                            textAlign: TextAlign.center,
                            style: theme.typography.headline,
                          ),
                          Text(
                            l10n.dropOverlayHint,
                            textAlign: TextAlign.center,
                            style: theme.typography.prose.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: theme.space.space4,
                        runSpacing: theme.space.space4,
                        children: [
                          _target(
                            context,
                            icon: IconName.files,
                            title: l10n.dropOverlayTabs,
                            line: l10n.dropOverlayTabsDescription,
                          ),
                          _target(
                            context,
                            icon: IconName.merge,
                            title: l10n.dropOverlayCombine,
                            line: Feature.combineDropped.disabledReason(
                              context,
                            ),
                            disabled: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _target(
    BuildContext context, {
    required IconName icon,
    required String title,
    required String line,
    bool disabled = false,
  }) {
    final theme = context.ferman;
    final colors = theme.colors;
    return Container(
      width: targetWidth,
      padding: const EdgeInsetsDirectional.all(targetPadding),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusLg)),
        // CSS paints the first shadow on top, Flutter the last: the ring
        // comes last.
        boxShadow: disabled
            ? [
                BoxShadow(
                  color: colors.borderDefault,
                  spreadRadius: theme.border.borderWidth,
                ),
              ]
            : [
                ...theme.elevation.shadowPopover,
                BoxShadow(color: colors.accent, spreadRadius: ringWidth),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.space2,
        children: [
          Row(
            spacing: theme.space.space2_5,
            children: [
              Icon(
                icon,
                size: targetIconSize,
                color: disabled ? colors.iconDisabled : colors.textAccent,
              ),
              Flexible(
                child: Text(
                  title,
                  style: theme.typography.body.copyWith(
                    fontSize: targetTitleSize,
                    height: targetTitleHeight / targetTitleSize,
                    fontWeight: theme.typeScale.weightSemibold,
                    color: disabled ? colors.textDisabled : colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            line,
            style: theme.typography.caption.copyWith(
              color: disabled ? colors.textDisabled : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
