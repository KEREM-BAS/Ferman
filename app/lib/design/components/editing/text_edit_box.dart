import 'dart:math' as math;

import 'package:ferman/design/components/foundation/focus_ring.dart';
import 'package:ferman/design/components/foundation/forced_states.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The states of a [TextEditBox] (`.fm-editbox--idle`, `--hover`,
/// `--selected`, `--editing`).
enum TextEditBoxState {
  /// No frame; a dashed frame while the pointer is over it.
  idle,

  /// The dashed hover frame, drawn without a pointer (boards, goldens).
  hover,

  /// The solid frame with handles and the font label.
  selected,

  /// As [selected], with a faint ink tint: the text is being edited.
  editing,
}

/// Where a [TextEditBox] puts its font label (the DS additions' fix 1,
/// `data-meta-placement`): the first free side wins.
enum MetaPlacement {
  /// Above the frame, at its start edge (the default, only when the space
  /// above is clear).
  above,

  /// Below the frame, at its start edge.
  below,

  /// In the page margin before the frame's start edge.
  margin,
}

/// The frame around an editable text block on the page, the design-system
/// `TextEditBox` component (`components/editing/editing.css`,
/// `.fm-editbox`; `TextEditBox.jsx`; fix 1 in `fm-additions.css`).
///
/// [child] is the block's text. The frame adds 3 px above and below it
/// and 4 px at the sides (`padding: 3px 4px`); the block's text keeps the
/// page ink colour (`--paper-900`) in both themes. [width] fixes the
/// frame's outer width.
///
/// **Layout** (`margin: -4px -5px`): the frame hugs the text. It overhangs
/// the widget's layout slot by 5 px at the sides and 4 px at the top and
/// bottom ([marginX], [marginY]), so wrapping a paragraph in a
/// [TextEditBox] leaves its text (within 1 px) where it was and the block
/// takes no extra room: the slot is the frame less 10 px across and 8 px
/// down (with [width], `width - 10`). The overhang, and the 4 px band the
/// handles reach past the frame, still take the pointer, as long as the
/// parent's own bounds cover them.
///
/// - [TextEditBoxState.idle]: no frame; the pointer shows a 1 px dashed
///   `--edit-box-hover` frame (`.fm-editbox--idle:hover`) and the text
///   cursor;
/// - [TextEditBoxState.hover]: that dashed frame without a pointer;
/// - [TextEditBoxState.selected] and [TextEditBoxState.editing]: a 1.5 px
///   solid `--edit-box` frame, eight 7 px handles ([showHandles], by
///   default in these states) with their resize cursors (mirrored at the
///   corners in right to left) and the [meta] label (such as
///   "IBM Plex Serif · 10.5 pt"); editing adds a faint ink tint. The
///   handles do not resize yet (M3).
///
/// The label is 18 px tall, ink on white (amber with a warning triangle
/// when [metaWarning]) and sits where [metaPlacement] says: above the
/// frame, below it, or in the margin before it.
///
/// **Outside Edit mode** ([inert], the DS additions' `[data-fm-mode]` rule)
/// the frame ignores the pointer: no hover frame, the default cursor, no
/// focus.
///
/// **Keyboard** (not in the bundle; the M3 editing model): the block takes
/// focus; keyboard focus on an idle block shows the dashed frame and the
/// focus ring (G22), page-tuned like the frame (2 px page white, then 2 px
/// `--edit-box`, the layers of `.fm-note-pin:focus-visible`), while the
/// selected and editing frames double as focus.
/// Enter on a selected block asks for [TextEditBoxState.editing] and
/// Escape while editing asks for [TextEditBoxState.selected], through
/// [onStateChanged]; the box is controlled and only changes when [state]
/// does. A click calls [onPressed].
///
/// Page-tuned colours: the frame sits on the white page in both themes.
/// For screen readers the block is focusable and can be tapped (which
/// calls [onPressed]); it is a multiline text field while editing,
/// labelled [semanticLabel] (the block's text).
class TextEditBox extends StatefulWidget {
  /// Frames [child] in [state].
  const new({
    required this.child,
    super.key,
    this.state = TextEditBoxState.editing,
    this.meta,
    this.metaWarning = false,
    this.showHandles,
    this.width,
    this.metaPlacement = MetaPlacement.above,
    this.inert = false,
    this.semanticLabel,
    this.onPressed,
    this.onStateChanged,
    this.focusNode,
    this.autofocus = false,
  });

  /// `.fm-editbox` `padding: 3px 4px`, vertical part.
  static const double paddingY = 3;

  /// `.fm-editbox` `padding: 3px 4px`, horizontal part.
  static const double paddingX = 4;

  /// `.fm-editbox` `margin: -4px -5px`, vertical part: how far the frame
  /// overhangs the layout slot at the top and bottom.
  static const double marginY = 4;

  /// `.fm-editbox` `margin: -4px -5px`, horizontal part: how far the frame
  /// overhangs the layout slot at the sides.
  static const double marginX = 5;

  /// The page-tuned focus ring's outer edge, `0 0 0 4px` (as
  /// `.fm-note-pin:focus-visible` and `--focus-ring`).
  static const double focusRingSpread = 4;

  /// The page-tuned focus ring's page-white gap, `0 0 0 2px`.
  static const double focusGapSpread = 2;

  /// `.fm-editbox` `border-radius: 1px`.
  static const double radius = 1;

  /// `.fm-editbox--idle:hover` `outline: 1px dashed`.
  static const double hoverOutlineWidth = 1;

  /// The dashes of the 1 px hover outline as Chromium draws them.
  static const double dashLength = 3;

  /// The gaps between those dashes.
  static const double dashGap = 3;

  /// `.fm-editbox--editing` `background: rgba(58, 96, 198, 0.03)`.
  static const Color editingTint = Color(0x083A60C6);

  /// `.fm-editbox__handle` `width` and `height: 7px`.
  static const double handleSize = 7;

  /// `.fm-editbox__handle` `top`, `left`, `right`, `bottom: -4px`.
  static const double handleOffset = 4;

  /// `.fm-editbox__meta` `bottom: calc(100% + 1px)`: the label's gap to
  /// the frame.
  static const double metaGap = 1;

  /// `.fm-editbox__meta` `inset-inline-start: -1.5px`, lining the label up
  /// with the outside of the frame.
  static const double metaInset = 1.5;

  /// `[data-meta-placement="margin"]` `inset-inline-end: calc(100% + 8px)`.
  static const double metaMarginGap = 8;

  /// `.fm-editbox__meta` `letter-spacing: 0.01em`.
  static const double metaTracking = 0.01;

  /// `TextEditBox.jsx` warning icon size.
  static const double metaIconSize = 10;

  /// `TextEditBox.jsx` warning icon stroke.
  static const double metaIconStroke = 2;

  /// `.fm-editbox__meta` `color: #FFFFFF`.
  static const Color metaForeground = Color(0xFFFFFFFF);

  /// The block's state.
  final TextEditBoxState state;

  /// The font label shown when selected or editing; null shows none.
  final String? meta;

  /// Whether the label warns (amber, with a triangle).
  final bool metaWarning;

  /// Whether the eight handles show; null shows them when selected or
  /// editing.
  final bool? showHandles;

  /// The frame's outer width; null takes the width of [child] and the
  /// padding.
  final double? width;

  /// Where the font label sits (fix 1). Not a design-system prop.
  final MetaPlacement metaPlacement;

  /// Whether the frame is outside Edit mode: no hover frame, no focus, the
  /// default cursor. Not a design-system prop (the design's
  /// `[data-fm-mode]` rule).
  final bool inert;

  /// The block's text for screen readers; null leaves it to [child].
  final String? semanticLabel;

  /// Called when the block is clicked (the bundle's `onClick`).
  final VoidCallback? onPressed;

  /// Called with the state the keyboard asks for: editing on Enter while
  /// selected, selected on Escape while editing. Not a design-system prop.
  final ValueChanged<TextEditBoxState>? onStateChanged;

  /// The block's focus node; one is created when null.
  final FocusNode? focusNode;

  /// Whether the block takes focus when it first appears.
  final bool autofocus;

  /// The block's text.
  final Widget child;

  /// Whether the handles show for [state] and [showHandles].
  bool get handlesShown =>
      showHandles ??
      (state == TextEditBoxState.selected || state == TextEditBoxState.editing);

  /// Whether the label shows: a [meta] text while selected or editing.
  bool get metaShown =>
      meta != null &&
      (state == TextEditBoxState.selected || state == TextEditBoxState.editing);

  @override
  State<TextEditBox> createState() => _TextEditBoxState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<TextEditBoxState>(
          'state',
          state,
          defaultValue: TextEditBoxState.editing,
        ),
      )
      ..add(StringProperty('meta', meta, defaultValue: null))
      ..add(FlagProperty('metaWarning', value: metaWarning, ifTrue: 'warning'))
      ..add(
        FlagProperty(
          'showHandles',
          value: showHandles,
          ifTrue: 'handles',
          ifFalse: 'no handles',
        ),
      )
      ..add(DoubleProperty('width', width, defaultValue: null))
      ..add(
        EnumProperty<MetaPlacement>(
          'metaPlacement',
          metaPlacement,
          defaultValue: MetaPlacement.above,
        ),
      )
      ..add(FlagProperty('inert', value: inert, ifTrue: 'inert'))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

/// How a [TextEditBox] frame is stroked.
enum _FrameStyle { none, dashed, solid }

class _EditIntent extends Intent {
  const new();
}

class _EndEditIntent extends Intent {
  const new();
}

/// A [CallbackAction] that is only enabled when [enabled] is true, so a
/// disabled key falls through to the text field or the app.
class _GatedAction<T extends Intent> extends CallbackAction<T> {
  new({required super.onInvoke, required this.enabled});

  final bool enabled;

  @override
  bool isEnabled(T intent) => enabled;
}

class _TextEditBoxState extends State<TextEditBox> {
  bool _hovered = false;
  bool _focusVisible = false;
  bool _focused = false;
  FocusNode? _ownNode;

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'TextEditBox'));

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  static const Map<ShortcutActivator, Intent> _shortcuts = {
    SingleActivator(LogicalKeyboardKey.enter): _EditIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): _EditIntent(),
    SingleActivator(LogicalKeyboardKey.escape): _EndEditIntent(),
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final page = theme.pageColors;
    final widget = this.widget;
    final state = widget.state;
    final forced = FermanForcedStates.of(context);
    final focusVisible =
        !widget.inert &&
        (_focusVisible || forced.contains(WidgetState.focused));
    final hovered =
        !widget.inert && (_hovered || forced.contains(WidgetState.hovered));
    final frame = switch (state) {
      TextEditBoxState.idle =>
        hovered || focusVisible ? _FrameStyle.dashed : _FrameStyle.none,
      TextEditBoxState.hover => _FrameStyle.dashed,
      TextEditBoxState.selected ||
      TextEditBoxState.editing => _FrameStyle.solid,
    };
    const radius = BorderRadius.all(Radius.circular(TextEditBox.radius));
    Widget box = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: TextEditBox.paddingY,
        horizontal: TextEditBox.paddingX,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: theme.ramps.paper900),
        child: widget.child,
      ),
    );
    box = DecoratedBox(
      decoration: BoxDecoration(
        color: state == TextEditBoxState.editing
            ? TextEditBox.editingTint
            : null,
        borderRadius: radius,
      ),
      child: box,
    );
    box = CustomPaint(
      foregroundPainter: _FramePainter(
        style: frame,
        color: frame == _FrameStyle.solid ? page.editBox : page.editBoxHover,
        width: frame == _FrameStyle.solid
            ? theme.border.borderWidthStrong
            : TextEditBox.hoverOutlineWidth,
      ),
      child: box,
    );
    if (widget.width != null) {
      box = SizedBox(width: widget.width, child: box);
    }
    // Keyboard focus on a block without a solid frame shows the ring too:
    // page-tuned (2 px page white, then 2 px --edit-box, the layers of
    // `.fm-note-pin:focus-visible`), because the page is white in both
    // themes. Always in the tree, so focus never rebuilds the block.
    box = CustomPaint(
      painter: FocusRingPainter(
        layers: [
          BoxShadow(
            color: page.editBox,
            spreadRadius: TextEditBox.focusRingSpread,
          ),
          BoxShadow(
            color: page.pageBg,
            spreadRadius: TextEditBox.focusGapSpread,
          ),
        ],
        borderRadius: radius,
        progress: focusVisible && frame != _FrameStyle.solid ? 1 : 0,
      ),
      child: box,
    );
    final meta = widget.meta;
    box = Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        if (widget.metaShown && meta != null) _metaLabel(context, meta),
      ],
    );
    final editing = state == TextEditBoxState.editing;
    final inert = widget.inert;
    // The block's own node carries its focus and tap, as FermanInteractive
    // does: Focus's semantics would merge into the node above instead.
    box = Semantics(
      container: true,
      textField: editing,
      multiline: editing ? true : null,
      focusable: !inert,
      focused: inert ? null : _focused,
      label: widget.semanticLabel,
      onFocus: inert ? null : _node.requestFocus,
      onTap: inert ? null : widget.onPressed,
      child: box,
    );
    box = FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      enabled: !inert,
      includeFocusSemantics: false,
      shortcuts: _shortcuts,
      actions: {
        _EditIntent: _GatedAction<_EditIntent>(
          enabled:
              state == TextEditBoxState.selected &&
              widget.onStateChanged != null,
          onInvoke: (_) =>
              widget.onStateChanged?.call(TextEditBoxState.editing),
        ),
        _EndEditIntent: _GatedAction<_EndEditIntent>(
          enabled: editing && widget.onStateChanged != null,
          onInvoke: (_) =>
              widget.onStateChanged?.call(TextEditBoxState.selected),
        ),
      },
      onFocusChange: (value) => setState(() => _focused = value),
      onShowFocusHighlight: (value) => setState(() => _focusVisible = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      mouseCursor: inert ? MouseCursor.defer : SystemMouseCursors.text,
      child: box,
    );
    // The handles reach 4 px past the frame (`top: -4px` and so on). The
    // frame sits inside a 4 px band so they take the pointer there too;
    // the band itself, between the handles, does not.
    Widget result = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(TextEditBox.handleOffset),
          child: box,
        ),
        if (widget.handlesShown)
          ..._handles(context, page.editBox, page.editHandleFill),
      ],
    );
    result = GestureDetector(
      excludeFromSemantics: true,
      onTap: inert ? null : widget.onPressed,
      child: result,
    );
    // `margin: -4px -5px`, plus the handle band: the layout slot is the
    // frame less the CSS margins.
    return _NegativeMargin(
      horizontal: TextEditBox.marginX + TextEditBox.handleOffset,
      vertical: TextEditBox.marginY + TextEditBox.handleOffset,
      child: result,
    );
  }

  /// The eight handles: corners and edge midpoints (`data-h`), centred on
  /// the frame line, with their resize cursors (`cursor: nwse-resize` and
  /// so on). The handles themselves are symmetric; the corner cursors
  /// follow the corner they end up at in right to left.
  List<Widget> _handles(BuildContext context, Color border, Color fill) {
    final inert = widget.inert;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Top-start and bottom-end lie on one diagonal, top-end and
    // bottom-start on the other; which is which depends on the direction.
    final startDiagonal = rtl
        ? SystemMouseCursors.resizeUpRightDownLeft
        : SystemMouseCursors.resizeUpLeftDownRight;
    final endDiagonal = rtl
        ? SystemMouseCursors.resizeUpLeftDownRight
        : SystemMouseCursors.resizeUpRightDownLeft;
    Widget handle(MouseCursor cursor) => MouseRegion(
      cursor: inert ? MouseCursor.defer : cursor,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey<String>('TextEditBox.handle'),
          width: TextEditBox.handleSize,
          height: TextEditBox.handleSize,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(
              color: border,
              width: context.ferman.border.borderWidth,
            ),
            borderRadius: const BorderRadius.all(
              Radius.circular(TextEditBox.radius),
            ),
          ),
        ),
      ),
    );
    Widget centredX(MouseCursor cursor) =>
        Center(heightFactor: 1, child: handle(cursor));
    Widget centredY(MouseCursor cursor) =>
        Center(widthFactor: 1, child: handle(cursor));
    const upDown = SystemMouseCursors.resizeUpDown;
    const leftRight = SystemMouseCursors.resizeLeftRight;
    // At 0 in the handle band: 4 px outside the frame.
    return [
      PositionedDirectional(top: 0, start: 0, child: handle(startDiagonal)),
      PositionedDirectional(top: 0, start: 0, end: 0, child: centredX(upDown)),
      PositionedDirectional(top: 0, end: 0, child: handle(endDiagonal)),
      PositionedDirectional(
        top: 0,
        bottom: 0,
        end: 0,
        child: centredY(leftRight),
      ),
      PositionedDirectional(bottom: 0, end: 0, child: handle(startDiagonal)),
      PositionedDirectional(
        bottom: 0,
        start: 0,
        end: 0,
        child: centredX(upDown),
      ),
      PositionedDirectional(bottom: 0, start: 0, child: handle(endDiagonal)),
      PositionedDirectional(
        top: 0,
        bottom: 0,
        start: 0,
        child: centredY(leftRight),
      ),
    ];
  }

  /// The font label (`.fm-editbox__meta`), placed per
  /// [TextEditBox.metaPlacement].
  Widget _metaLabel(BuildContext context, String meta) {
    final theme = context.ferman;
    final warning = widget.metaWarning;
    final background = warning
        ? theme.ramps.amber500
        : theme.pageColors.editBox;
    final foreground = warning
        ? theme.ramps.paper950
        : TextEditBox.metaForeground;
    final height = theme.size.editboxMetaH;
    final corner = Radius.circular(theme.radius.radiusXs);
    final borderRadius = switch (widget.metaPlacement) {
      MetaPlacement.above => BorderRadius.vertical(top: corner),
      MetaPlacement.below => BorderRadius.vertical(bottom: corner),
      MetaPlacement.margin => BorderRadius.all(corner),
    };
    final size = theme.typeScale.size2xs;
    final label = Container(
      key: const ValueKey<String>('TextEditBox.meta'),
      height: height,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space1_5,
      ),
      decoration: BoxDecoration(color: background, borderRadius: borderRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space1,
        children: [
          if (warning)
            Icon(
              IconName.triangleAlert,
              size: TextEditBox.metaIconSize,
              strokeWidth: TextEditBox.metaIconStroke,
              color: foreground,
            ),
          Text(
            meta,
            maxLines: 1,
            softWrap: false,
            style: theme.typography.label.copyWith(
              fontSize: size,
              height: 1,
              fontWeight: theme.typeScale.weightMedium,
              letterSpacing: TextEditBox.metaTracking * size,
              color: foreground,
              fontFeatures: theme.typeScale.numericTabular,
            ),
          ),
        ],
      ),
    );
    const gap = TextEditBox.metaGap;
    return switch (widget.metaPlacement) {
      MetaPlacement.above => PositionedDirectional(
        top: -(height + gap),
        start: -TextEditBox.metaInset,
        child: label,
      ),
      MetaPlacement.below => PositionedDirectional(
        bottom: -(height + gap),
        start: -TextEditBox.metaInset,
        child: label,
      ),
      // Its end edge 8 px before the frame's start edge.
      MetaPlacement.margin => PositionedDirectional(
        top: -TextEditBox.metaInset,
        start: -TextEditBox.metaMarginGap,
        child: FractionalTranslation(
          translation: Offset(
            Directionality.of(context) == TextDirection.rtl ? 1 : -1,
            0,
          ),
          child: label,
        ),
      ),
    };
  }
}

/// Strokes the frame as a CSS `outline` with no offset: just outside the
/// box, solid or dashed.
class _FramePainter extends CustomPainter {
  const new({required this.style, required this.color, required this.width});

  final _FrameStyle style;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (style == _FrameStyle.none) return;
    final rect = (Offset.zero & size).inflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    if (style == _FrameStyle.solid) {
      canvas.drawRect(rect, paint);
      return;
    }
    for (final metric in (Path()..addRect(rect)).computeMetrics()) {
      for (
        var at = 0.0;
        at < metric.length;
        at += TextEditBox.dashLength + TextEditBox.dashGap
      ) {
        canvas.drawPath(
          metric.extractPath(
            at,
            math.min(at + TextEditBox.dashLength, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.width != width;
}

/// Lays [child] out [horizontal] wider at each side and [vertical] taller
/// at the top and bottom than its own slot, overhanging it, as a CSS
/// negative margin does. Equal margins at both ends, so it needs no
/// direction.
class _NegativeMargin extends SingleChildRenderObjectWidget {
  const new({
    required this.horizontal,
    required this.vertical,
    required super.child,
  });

  final double horizontal;
  final double vertical;

  @override
  _RenderNegativeMargin createRenderObject(BuildContext context) =>
      _RenderNegativeMargin(horizontal: horizontal, vertical: vertical);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNegativeMargin renderObject,
  ) {
    renderObject
      ..horizontal = horizontal
      ..vertical = vertical;
  }
}

class _RenderNegativeMargin extends RenderShiftedBox {
  new({required this._horizontal, required this._vertical}) : super(null);

  double _horizontal;
  double _vertical;

  double get horizontal => _horizontal;
  set horizontal(double value) {
    if (value == _horizontal) return;
    _horizontal = value;
    markNeedsLayout();
  }

  double get vertical => _vertical;
  set vertical(double value) {
    if (value == _vertical) return;
    _vertical = value;
    markNeedsLayout();
  }

  /// [constraints] grown by the margins: the child's constraints.
  BoxConstraints _grow(BoxConstraints constraints) {
    final dx = 2 * _horizontal;
    final dy = 2 * _vertical;
    return BoxConstraints(
      minWidth: constraints.minWidth + dx,
      maxWidth: constraints.maxWidth + dx,
      minHeight: constraints.minHeight + dy,
      maxHeight: constraints.maxHeight + dy,
    );
  }

  /// The slot for a child of [childSize]: the child less the margins.
  Size _shrink(BoxConstraints constraints, Size childSize) =>
      constraints.constrain(
        Size(
          math.max(0, childSize.width - 2 * _horizontal),
          math.max(0, childSize.height - 2 * _vertical),
        ),
      );

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    0,
    (child?.getMinIntrinsicWidth(height + 2 * _vertical) ?? 0) -
        2 * _horizontal,
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    0,
    (child?.getMaxIntrinsicWidth(height + 2 * _vertical) ?? 0) -
        2 * _horizontal,
  );

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    0,
    (child?.getMinIntrinsicHeight(width + 2 * _horizontal) ?? 0) -
        2 * _vertical,
  );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
    0,
    (child?.getMaxIntrinsicHeight(width + 2 * _horizontal) ?? 0) -
        2 * _vertical,
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _shrink(constraints, child.getDryLayout(_grow(constraints)));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_grow(constraints), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(
      -_horizontal,
      -_vertical,
    );
    size = _shrink(constraints, child.size);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The overhang takes the pointer too: test against the child's box,
    // not this slot.
    final child = this.child;
    if (child == null) return false;
    final offset = (child.parentData! as BoxParentData).offset;
    if (!(offset & child.size).contains(position)) return false;
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
