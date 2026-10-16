import 'dart:math' as math;

import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/interactive.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The drag state of a [PageThumbnail] (`.fm-thumb--dragging`,
/// `.fm-thumb--placeholder`).
enum PageThumbnailState {
  /// At rest.
  idle,

  /// Lifted by a drag: raised, with the drag shadow, 3 % larger.
  dragging,

  /// The empty slot a dragged page left: a dashed outline, no page, no
  /// number.
  placeholder,
}

/// Where a drag would drop pages next to a [PageThumbnail]
/// (`.fm-thumb__drop--*-before`, `--*-after`).
enum DropIndicator {
  /// Before this page.
  before,

  /// After this page.
  after,
}

/// The axis pages flow along around a [PageThumbnail], which sets the drop
/// line's direction.
enum ThumbnailOrientation {
  /// A column (the sidebar): the drop line runs across, above or below.
  vertical,

  /// A row or grid (Organize): the drop line runs down, at the start or
  /// end side.
  horizontal,
}

/// The corner marker of a [PageThumbnail] (`.fm-thumb__marker--edited`,
/// `--comment`); superseded by `ThumbnailBadges` (fix 5).
enum ThumbnailMarker {
  /// Edited: an `--edit-changed` dot.
  edited,

  /// Has comments: an amber dot.
  comment,
}

/// A selectable page preview, the design-system `PageThumbnail` component
/// (`components/pages/pages.css`, `.fm-thumb`; `PageThumbnail.jsx`): the
/// sidebar's Pages list and the Organize grid.
///
/// The page is [width] wide and [aspect] times as tall, on the page colour
/// with a hairline and a small shadow, showing [child] (the rendered page;
/// M1 renders none) or striped placeholder lines. Under it, the page
/// number ([label] when given, such as a roman numeral) in medium tabular
/// caption type. A sideways [rotation] (90 or 270) re-proportions the page
/// and turns the lines, and any rotation adds a `rotate-cw` glyph before
/// the number. The page colour filter (`--page-filter`) applies to the
/// page only.
///
/// [badges] (a `ThumbnailBadges`) sits at the page's top-end corner and
/// moves the placeholder lines aside. [marker] is the bundle's older
/// corner dot, kept because the spec declares it.
///
/// States: hover tints the cell, [selected] fills it with the selection
/// colour, rings the page in the accent and colours the number; keyboard
/// focus shows the focus ring; [state] lifts the cell while dragged or
/// leaves a dashed slot; [dropIndicator] draws the accent drop line with
/// round ends before or after the page, across it in a
/// [ThumbnailOrientation.vertical] list and down its side in a
/// [ThumbnailOrientation.horizontal] row. The drop line and the badges
/// mirror in right to left; the page content never does.
///
/// **Keyboard:** Enter and Space call [onPressed] (select). ArrowUp and
/// ArrowDown move to the thumbnail above or below (not in the bundle).
///
/// For screen readers it is a selectable button (the design's listbox
/// option) named [semanticLabel] (the bundle's English "Page N", localized
/// by the screen), else [label] or the number.
class PageThumbnail extends StatefulWidget {
  /// A thumbnail of page [page].
  const new({
    required this.page,
    super.key,
    this.label,
    this.selected = false,
    this.state = PageThumbnailState.idle,
    this.dropIndicator,
    this.orientation = ThumbnailOrientation.vertical,
    this.marker,
    this.width = 112,
    this.aspect = 1.4142,
    this.rotation = 0,
    this.child,
    this.onPressed,
    this.badges,
    this.semanticLabel,
    this.markerTooltip,
    this.focusNode,
    this.autofocus = false,
  });

  /// `.fm-thumb` `padding: 8px 8px 6px`, bottom.
  static const double paddingBottom = 6;

  /// `.fm-thumb` `gap: 6px` between the page and the number.
  static const double gap = 6;

  /// `.fm-thumb__page` `border-radius: 1px`.
  static const double pageRadius = 1;

  /// `.fm-thumb[aria-selected="true"] .fm-thumb__page`
  /// `box-shadow: 0 0 0 2px var(--accent)`.
  static const double selectedRing = 2;

  /// `.fm-thumb--placeholder .fm-thumb__page` `outline: 1.5px dashed`.
  static const double placeholderOutline = 1.5;

  /// The dashes of that outline as Chromium draws them (`a6-1b`).
  static const double dashLength = 3;

  /// The gaps between those dashes.
  static const double dashGap = 2;

  /// `.fm-thumb--dragging` `transform: scale(1.03)`.
  static const double dragScale = 1.03;

  /// `PageThumbnail.jsx`: a sideways page is `width × aspect × 0.72` wide.
  static const double sidewaysScale = 0.72;

  /// `PageThumbnail.jsx` rotation glyph size.
  static const double rotationIconSize = 10;

  /// `PageThumbnail.jsx` rotation glyph stroke.
  static const double rotationIconStroke = 2;

  /// `.fm-thumb__lines::before` `background: #A9A49B`: the heading bar.
  static const Color headingColor = Color(0xFFA9A49B);

  /// `.fm-thumb__lines::before` `height: 4px`.
  static const double headingHeight = 4;

  /// `.fm-thumb__lines::before` `width: 55%`.
  static const double headingWidth = 0.55;

  /// `.fm-thumb__lines::before` `top: -8%` of the lines box.
  static const double headingTop = 0.08;

  /// `.fm-thumb__lines` `inset: 13% 12% 16%`.
  static const EdgeInsetsDirectional linesInset =
      EdgeInsetsDirectional.fromSTEB(0.12, 0.13, 0.12, 0.16);

  /// `inset-inline: 12% 24%` when badges sit on the page (FmSidebar).
  static const double linesEndWithBadges = 0.24;

  /// `inset: 10% 22%` of the turned lines of a sideways page.
  static const EdgeInsetsDirectional sidewaysLinesInset =
      EdgeInsetsDirectional.fromSTEB(0.22, 0.1, 0.22, 0.1);

  /// `.fm-thumb__marker` `width` and `height: 8px`.
  static const double markerSize = 8;

  /// `.fm-thumb__marker` `top` and `inset-inline-end: 4px`.
  static const double cornerInset = 4;

  /// `.fm-thumb__marker` `box-shadow: 0 0 0 2px var(--page-bg)`.
  static const double markerRing = 2;

  /// `.fm-thumb__drop` thickness (`height: 2px` or `width: 2px`).
  static const double dropThickness = 2;

  /// `.fm-thumb__drop--v-*` `inset-inline: 6px`; `--h-*` `top/bottom: 6px`.
  static const double dropInset = 6;

  /// `.fm-thumb__drop--v-before` `top: -2px`.
  static const double dropOffsetVertical = 2;

  /// `.fm-thumb__drop--h-before` `inset-inline-start: -3px`.
  static const double dropOffsetHorizontal = 3;

  /// `.fm-thumb__drop::before, ::after`: 6 px of content inside a 2 px
  /// border, so the round end is 10 px across and centred on the line's
  /// end (the content-box sizing its offsets assume).
  static const double dropEndSize = 10;

  /// `.fm-thumb__drop::before` `border: 2px solid var(--accent)`.
  static const double dropEndBorder = 2;

  /// The page number.
  final int page;

  /// The page label shown in place of the number (roman numerals and the
  /// like); null shows the number.
  final String? label;

  /// Whether the page is selected.
  final bool selected;

  /// The drag state.
  final PageThumbnailState state;

  /// Where a drop would land; null draws no drop line.
  final DropIndicator? dropIndicator;

  /// The axis of the drop line.
  final ThumbnailOrientation orientation;

  /// The older corner marker; null shows none.
  final ThumbnailMarker? marker;

  /// The page's width before rotation.
  final double width;

  /// The page's height over its width.
  final double aspect;

  /// The page's rotation in degrees: 0, 90, 180 or 270.
  final int rotation;

  /// The rendered page; null draws placeholder lines.
  final Widget? child;

  /// Called when the thumbnail is activated (select).
  final VoidCallback? onPressed;

  /// The page's badges (a `ThumbnailBadges`), at its top-end corner; null
  /// shows none. Not a design-system prop.
  final Widget? badges;

  /// The accessible name, the localized "Page N"; null takes [label] or
  /// the number. Not a design-system prop.
  final String? semanticLabel;

  /// The [marker]'s tooltip (the bundle's English "Edited" and "Has
  /// comments"); null shows none. Not a design-system prop.
  final String? markerTooltip;

  /// The focus node; one is created when null.
  final FocusNode? focusNode;

  /// Whether the thumbnail takes focus when it first appears.
  final bool autofocus;

  /// Whether [rotation] turns the page on its side.
  bool get sideways => rotation % 180 == 90;

  /// The page's size after rotation (`PageThumbnail.jsx`).
  Size get pageSize {
    if (sideways) {
      final w = (width * aspect * sidewaysScale).roundToDouble();
      return Size(w, (w / aspect).roundToDouble());
    }
    return Size(width, (width * aspect).roundToDouble());
  }

  @override
  State<PageThumbnail> createState() => _PageThumbnailState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('page', page))
      ..add(StringProperty('label', label, defaultValue: null))
      ..add(FlagProperty('selected', value: selected, ifTrue: 'selected'))
      ..add(
        EnumProperty<PageThumbnailState>(
          'state',
          state,
          defaultValue: PageThumbnailState.idle,
        ),
      )
      ..add(
        EnumProperty<DropIndicator>(
          'dropIndicator',
          dropIndicator,
          defaultValue: null,
        ),
      )
      ..add(
        EnumProperty<ThumbnailOrientation>(
          'orientation',
          orientation,
          defaultValue: ThumbnailOrientation.vertical,
        ),
      )
      ..add(EnumProperty<ThumbnailMarker>('marker', marker, defaultValue: null))
      ..add(DoubleProperty('width', width, defaultValue: 112))
      ..add(DoubleProperty('aspect', aspect, defaultValue: 1.4142))
      ..add(IntProperty('rotation', rotation, defaultValue: 0))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

/// The focus node of a thumbnail, so the arrow keys find the others.
class _ThumbnailNode extends FocusNode {
  new() : super(debugLabel: 'PageThumbnail');
}

class _PageThumbnailState extends State<PageThumbnail> {
  _ThumbnailNode? _ownNode;

  FocusNode get _node => widget.focusNode ?? (_ownNode ??= _ThumbnailNode());

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  /// ArrowUp and ArrowDown: the nearest thumbnail above or below.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final down = key == LogicalKeyboardKey.arrowDown;
    if (!down && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final node = _node;
    final here = node.rect;
    FocusNode? target;
    var best = double.infinity;
    // A thumbnail's own node, never the badges inside it.
    bool isThumbnail(FocusNode other) =>
        other is _ThumbnailNode ||
        identical(
          other.context?.findAncestorStateOfType<_PageThumbnailState>()?._node,
          other,
        );
    final candidates =
        node.nearestScope?.traversalDescendants.where(isThumbnail) ??
        const <FocusNode>[];
    for (final other in candidates) {
      if (identical(other, node)) continue;
      final rect = other.rect;
      final dy = rect.center.dy - here.center.dy;
      if (down ? dy <= 0 : dy >= 0) continue;
      // Prefer thumbnails in the same column, then the nearest row.
      final inBand = rect.right > here.left && rect.left < here.right;
      final distance =
          (inBand ? 0 : 1e6) +
          dy.abs() +
          (rect.center.dx - here.center.dx).abs() / 1000;
      if (distance < best) {
        best = distance;
        target = other;
      }
    }
    target?.requestFocus();
    return target == null ? KeyEventResult.ignored : KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final theme = context.ferman;
    final colors = theme.colors;
    final placeholder = widget.state == PageThumbnailState.placeholder;
    final dragging = widget.state == PageThumbnailState.dragging;
    final label = widget.label ?? '${widget.page}';
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: FermanInteractive(
        focusNode: _node,
        autofocus: widget.autofocus,
        onPressed: widget.onPressed,
        selected: widget.selected,
        selectable: true,
        semanticLabel: widget.semanticLabel ?? label,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final selected = widget.selected;
          // Later rules win in pages.css: selected over hover over dragging.
          final Color? fill;
          if (selected) {
            fill = colors.surfaceSelected;
          } else if (hovered) {
            fill = colors.surfaceHover;
          } else if (dragging) {
            fill = colors.surfaceRaised;
          } else {
            fill = null;
          }
          final radius = BorderRadius.all(
            Radius.circular(theme.radius.radiusMd),
          );
          Widget cell = Container(
            key: const ValueKey<String>('PageThumbnail.cell'),
            padding: EdgeInsetsDirectional.fromSTEB(
              theme.space.space2,
              theme.space.space2,
              theme.space.space2,
              PageThumbnail.paddingBottom,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              boxShadow: dragging ? theme.elevation.shadowDrag : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: PageThumbnail.gap,
              children: [
                _page(context, theme, selected: selected),
                Visibility.maintain(
                  visible: !placeholder,
                  child: _number(theme, label, selected: selected),
                ),
              ],
            ),
          );
          cell = FocusRing(
            visible: states.contains(WidgetState.focused),
            borderRadius: radius,
            child: cell,
          );
          if (dragging) {
            cell = Transform.scale(scale: PageThumbnail.dragScale, child: cell);
          }
          final indicator = widget.dropIndicator;
          if (indicator == null) return cell;
          return Stack(
            clipBehavior: Clip.none,
            children: [cell, _dropLine(theme, indicator)],
          );
        },
      ),
    );
  }

  Widget _page(
    BuildContext context,
    FermanTheme theme, {
    required bool selected,
  }) {
    final widget = this.widget;
    final colors = theme.colors;
    final size = widget.pageSize;
    final placeholder = widget.state == PageThumbnailState.placeholder;
    const radius = BorderRadius.all(Radius.circular(PageThumbnail.pageRadius));
    if (placeholder) {
      return SizedBox.fromSize(
        key: const ValueKey<String>('PageThumbnail.page'),
        size: size,
        child: CustomPaint(painter: _DashedOutlinePainter(colors.accentBorder)),
      );
    }
    Widget content = DecoratedBox(
      decoration: BoxDecoration(color: theme.pageColors.pageBg),
      child: widget.child ?? _lines(theme),
    );
    final filter = theme.pageColorFilter;
    if (filter != null) {
      content = ColorFiltered(colorFilter: filter, child: content);
    }
    final marker = widget.marker;
    final badges = widget.badges;
    return Container(
      key: const ValueKey<String>('PageThumbnail.page'),
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          ...theme.elevation.shadowSm,
          BoxShadow(
            color: selected ? colors.accent : colors.borderDefault,
            spreadRadius: selected
                ? PageThumbnail.selectedRing
                : theme.border.borderWidth,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (marker != null) _marker(theme, marker),
            if (badges != null)
              PositionedDirectional(
                top: PageThumbnail.cornerInset,
                end: PageThumbnail.cornerInset,
                child: badges,
              ),
          ],
        ),
      ),
    );
  }

  /// The placeholder lines (`.fm-thumb__lines`), turned with the page.
  Widget _lines(FermanTheme theme) {
    final widget = this.widget;
    final sideways = widget.sideways;
    var inset = sideways
        ? PageThumbnail.sidewaysLinesInset
        : PageThumbnail.linesInset;
    if (widget.badges != null && !sideways) {
      inset = inset.copyWith(end: PageThumbnail.linesEndWithBadges);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        Widget lines = CustomPaint(
          painter: _LinesPainter(
            hatch: theme.hatch.thumbLines,
            heading: PageThumbnail.headingColor,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
        );
        if (widget.rotation % 360 != 0) {
          lines = Transform.rotate(
            angle: widget.rotation * math.pi / 180,
            child: lines,
          );
        }
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            inset.start * w,
            inset.top * h,
            inset.end * w,
            inset.bottom * h,
          ),
          child: lines,
        );
      },
    );
  }

  Widget _marker(FermanTheme theme, ThumbnailMarker marker) {
    Widget dot = Container(
      width: PageThumbnail.markerSize,
      height: PageThumbnail.markerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: marker == ThumbnailMarker.edited
            ? theme.pageColors.editChanged
            : theme.ramps.amber500,
        boxShadow: [
          BoxShadow(
            color: theme.pageColors.pageBg,
            spreadRadius: PageThumbnail.markerRing,
          ),
        ],
      ),
    );
    final message = widget.markerTooltip;
    if (message != null) dot = Tooltip(message: message, child: dot);
    return PositionedDirectional(
      top: PageThumbnail.cornerInset,
      end: PageThumbnail.cornerInset,
      child: dot,
    );
  }

  Widget _number(FermanTheme theme, String label, {required bool selected}) {
    final color = selected
        ? theme.colors.textAccent
        : theme.colors.textSecondary;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space1,
        children: [
          if (widget.rotation % 360 != 0)
            Icon(
              IconName.rotateCw,
              size: PageThumbnail.rotationIconSize,
              strokeWidth: PageThumbnail.rotationIconStroke,
              color: color,
            ),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: theme.typography.label.copyWith(
              height: 1,
              color: color,
              fontFeatures: theme.typeScale.numericTabular,
            ),
          ),
        ],
      ),
    );
  }

  /// The accent drop line with round ends (`.fm-thumb__drop`).
  Widget _dropLine(FermanTheme theme, DropIndicator indicator) {
    final colors = theme.colors;
    final before = indicator == DropIndicator.before;
    final vertical = widget.orientation == ThumbnailOrientation.vertical;
    const end = PageThumbnail.dropEndSize;
    const thickness = PageThumbnail.dropThickness;
    Widget roundEnd() => Container(
      width: end,
      height: end,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfacePanel,
        border: Border.all(
          color: colors.accent,
          width: PageThumbnail.dropEndBorder,
        ),
      ),
    );
    final line = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent,
        borderRadius: const BorderRadius.all(Radius.circular(1)),
      ),
    );
    // The round ends overhang the line by half their size.
    const overhang = (end - thickness) / 2;
    final Widget drawn = vertical
        ? SizedBox(
            height: end,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  top: overhang,
                  height: thickness,
                  child: line,
                ),
                PositionedDirectional(
                  start: -end / 2,
                  top: 0,
                  child: roundEnd(),
                ),
                PositionedDirectional(end: -end / 2, top: 0, child: roundEnd()),
              ],
            ),
          )
        : SizedBox(
            width: end,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                PositionedDirectional(
                  top: 0,
                  bottom: 0,
                  start: overhang,
                  width: thickness,
                  child: line,
                ),
                PositionedDirectional(
                  top: -end / 2,
                  start: 0,
                  child: roundEnd(),
                ),
                PositionedDirectional(
                  bottom: -end / 2,
                  start: 0,
                  child: roundEnd(),
                ),
              ],
            ),
          );
    final keyed = ExcludeSemantics(
      child: KeyedSubtree(
        key: const ValueKey<String>('PageThumbnail.drop'),
        child: drawn,
      ),
    );
    if (vertical) {
      return PositionedDirectional(
        start: PageThumbnail.dropInset,
        end: PageThumbnail.dropInset,
        top: before ? -PageThumbnail.dropOffsetVertical - overhang : null,
        bottom: before ? null : -PageThumbnail.dropOffsetVertical - overhang,
        child: keyed,
      );
    }
    return PositionedDirectional(
      top: PageThumbnail.dropInset,
      bottom: PageThumbnail.dropInset,
      start: before ? -PageThumbnail.dropOffsetHorizontal - overhang : null,
      end: before ? null : -PageThumbnail.dropOffsetHorizontal - overhang,
      child: keyed,
    );
  }
}

/// Paints the placeholder lines: [hatch] stripes down the box and the
/// heading bar above them at the start side (`.fm-thumb__lines`).
class _LinesPainter extends CustomPainter {
  const new({required this.hatch, required this.heading, required this.rtl});

  final FermanHatch hatch;
  final Color heading;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final period = hatch.stripes.fold<double>(0, (sum, s) => sum + s.width);
    if (period > 0) {
      for (var y = 0.0; y < size.height; y += period) {
        var at = y;
        for (final stripe in hatch.stripes) {
          final bottom = math.min(at + stripe.width, size.height);
          if (stripe.color.a > 0 && bottom > at) {
            canvas.drawRect(
              Rect.fromLTRB(0, at, size.width, bottom),
              Paint()..color = stripe.color,
            );
          }
          at += stripe.width;
        }
      }
    }
    final barWidth = size.width * PageThumbnail.headingWidth;
    final top = -size.height * PageThumbnail.headingTop;
    canvas.drawRect(
      Rect.fromLTWH(
        rtl ? size.width - barWidth : 0,
        top,
        barWidth,
        PageThumbnail.headingHeight,
      ),
      Paint()..color = heading,
    );
  }

  @override
  bool shouldRepaint(_LinesPainter oldDelegate) =>
      oldDelegate.hatch != hatch ||
      oldDelegate.heading != heading ||
      oldDelegate.rtl != rtl;
}

/// Paints the placeholder slot's dashed outline: 1.5 px, 1 px inside the
/// box (`outline-offset: -1px`).
class _DashedOutlinePainter extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const width = PageThumbnail.placeholderOutline;
    // `outline-offset: -1px`: the outline's outer edge 0.5 px outside.
    final rect = (Offset.zero & size).inflate(width / 2 - 1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    for (final metric in (Path()..addRect(rect)).computeMetrics()) {
      for (
        var at = 0.0;
        at < metric.length;
        at += PageThumbnail.dashLength + PageThumbnail.dashGap
      ) {
        canvas.drawPath(
          metric.extractPath(
            at,
            math.min(at + PageThumbnail.dashLength, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
