import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/design/components/annotations/annotation_color.dart'
    as design;
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/comments/comment_time.dart';
import 'package:ferman/features/shell/shell_labels.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The delete key's cap, as a4-1 shows it.
const List<String> _deleteKey = ['⌫'];

/// a4-1's floating bar over the selected mark: Colour, Stroke width and Opacity
/// where they apply, Open comment and Delete. Each change commits at once.
class CommentStyleBar extends ConsumerStatefulWidget {
  /// The bar of [annotation].
  const new({required this.annotation, super.key});

  /// The selected mark.
  final AnnotationInfo annotation;

  /// a4-1's `hint-size="300px,40px"`, the width its place allows for.
  static const double width = 300;

  /// a4-1 keeps the bar 54 px above the mark's top.
  static const double above = 54;

  /// The room kept at the canvas's edges.
  static const double edge = 8;

  /// The Stroke width choices, in points.
  static const List<double> strokes = [1, 2, 4];

  /// The Opacity choices.
  static const List<double> opacities = [1, 0.6, 0.3];

  /// a4-1's width of the stroke select.
  static const double strokeWidth = 76;

  /// a4-1's width of the opacity select.
  static const double opacityWidth = 72;

  /// Where the bar starts for a mark at [box] on the canvas of size [canvas].
  static double startFor(Rect box, Size canvas) => math.max(
    edge,
    math.min(box.center.dx - width / 2, canvas.width - width - edge),
  );

  /// Its top for a mark at [box]: above it, or inside the canvas's top.
  static double topFor(Rect box) => math.max(edge, box.top - above);

  @override
  ConsumerState<CommentStyleBar> createState() => _CommentStyleBarState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<AnnotationInfo>('annotation', annotation),
    );
  }
}

class _CommentStyleBarState extends ConsumerState<CommentStyleBar> {
  bool _colours = false;

  CommentCommands get _commands => ref.read(commentCommandsProvider.notifier);

  void _change(AnnotationChange change) =>
      unawaited(_commands.update(widget.annotation.handle, change));

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final annotation = widget.annotation;
    final kind = annotation.kind;
    final strokes = {...CommentStyleBar.strokes, annotation.stroke};
    final opacities = {...CommentStyleBar.opacities, annotation.opacity};
    return Toolbar(
      variant: ToolbarVariant.floating,
      semanticLabel: l10n.commentStyleBar(l10n.commentKindName(kind)),
      children: [
        if (hasStyle(kind)) ...[
          Popover(
            open: _colours,
            surface: false,
            onDismiss: () => setState(() => _colours = false),
            anchor: ToolButton(
              icon: IconName.square,
              label: l10n.shellColor,
              showLabel: false,
              hasMenu: true,
              swatch: annotation.color?.color,
              onPressed: () => setState(() => _colours = !_colours),
            ),
            child: Menu(
              semanticLabel: l10n.shellColor,
              autofocus: true,
              items: [
                for (final color in AnnotationTools.palette)
                  MenuItem(
                    id: color.name,
                    label: l10n.annotationColorLabel(color),
                  ),
              ],
              onClose: () => setState(() => _colours = false),
              onSelected: (item) {
                setState(() => _colours = false);
                _change(
                  AnnotationChange(
                    color: markColorOf(
                      design.AnnotationColor.values
                          .byName(item.id ?? '')
                          .resolve(theme),
                    ),
                  ),
                );
              },
            ),
          ),
          if (hasStroke(kind))
            SizedBox(
              width: CommentStyleBar.strokeWidth,
              child: Select<double>(
                size: FieldSize.sm,
                semanticLabel: l10n.commentStrokeWidth,
                value: annotation.stroke,
                options: [
                  for (final stroke in strokes)
                    SelectOption(
                      value: stroke,
                      label: format.pointSize(stroke),
                    ),
                ],
                onChanged: (stroke) =>
                    _change(AnnotationChange(stroke: stroke)),
              ),
            ),
          SizedBox(
            width: CommentStyleBar.opacityWidth,
            child: Select<double>(
              size: FieldSize.sm,
              semanticLabel: l10n.commentOpacity,
              value: annotation.opacity,
              options: [
                for (final opacity in opacities)
                  SelectOption(
                    value: opacity,
                    label: format.percent(opacity * 100),
                  ),
              ],
              onChanged: (opacity) =>
                  _change(AnnotationChange(opacity: opacity)),
            ),
          ),
          const ToolbarSeparator(),
        ],
        IconButton(
          icon: IconName.messageSquare,
          label: l10n.commentOpen,
          size: IconButtonSize.sm,
          onPressed: () => openComment(ref, annotation),
        ),
        IconButton(
          icon: IconName.trash2,
          label: l10n.commentDelete,
          size: IconButtonSize.sm,
          shortcut: _deleteKey,
          onPressed: () => unawaited(_commands.delete(annotation.handle)),
        ),
      ],
    );
  }
}

/// Open comment: a note opens on the page, any other mark in its panel card.
void openComment(WidgetRef ref, AnnotationInfo annotation) {
  ref
      .read(commentSelectionProvider.notifier)
      .select(
        annotation.handle,
        composing: annotation.kind != AnnotationKind.note,
        noteOpen: annotation.kind == AnnotationKind.note,
      );
}

/// G46's context menu on [annotation] at [position] (global): the style bar's
/// actions that have no place of their own on the page.
void showCommentMenu(
  BuildContext context,
  WidgetRef ref,
  AnnotationInfo annotation,
  Offset position, {
  required VoidCallback onEditText,
  required TextDirection direction,
}) {
  final l10n = AppLocalizations.of(context);
  final refusal = ref.read(commentRefusalProvider)?.call(l10n);
  ContextMenuController().show(
    context: context,
    contextMenuBuilder: (context) => CustomSingleChildLayout(
      delegate: DesktopTextSelectionToolbarLayoutDelegate(anchor: position),
      child: Directionality(
        textDirection: direction,
        child: Menu(
          semanticLabel: l10n.commentMenu,
          autofocus: true,
          items: [
            MenuItem(
              id: 'open',
              label: l10n.commentOpen,
              icon: IconName.messageSquare,
            ),
            if (hasOwnText(annotation.kind))
              MenuItem(
                id: 'text',
                label: l10n.commentEditText,
                icon: IconName.type,
                disabled: refusal != null,
                disabledReason: refusal,
              ),
            MenuItem(
              id: 'delete',
              label: l10n.commentDelete,
              icon: IconName.trash2,
              danger: true,
              disabled: refusal != null,
              disabledReason: refusal,
            ),
          ],
          onClose: ContextMenuController.removeAny,
          onSelected: (item) {
            ContextMenuController.removeAny();
            switch (item.id) {
              case 'open':
                openComment(ref, annotation);
              case 'text':
                onEditText();
              case 'delete':
                unawaited(
                  ref
                      .read(commentCommandsProvider.notifier)
                      .delete(annotation.handle),
                );
            }
          },
        ),
      ),
    ),
  );
}
