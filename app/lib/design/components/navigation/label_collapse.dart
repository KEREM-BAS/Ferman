import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Tells a tool inside a narrow `Toolbar` row whether its label is hidden
/// behind its icon (G21). The toolbar puts one around each item; a
/// `ToolButton` reads it to draw icon-only and to show its label as the
/// tooltip. Not exported from the component library: an implementation
/// detail of `navigation/`.
class CollapsedLabelScope extends InheritedWidget {
  /// Hides the label of the tool in [child] when [hidden].
  const new({required this.hidden, required super.child, super.key});

  /// Whether the label is hidden.
  final bool hidden;

  /// Whether the toolbar around [context] hides its label; false outside a
  /// toolbar.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CollapsedLabelScope>()
          ?.hidden ??
      false;

  @override
  bool updateShouldNotify(CollapsedLabelScope oldWidget) =>
      hidden != oldWidget.hidden;
}

/// The parts of a [CollapsibleLabel].
enum CollapsibleLabelSlot {
  /// The icon before the label.
  leading,

  /// The label.
  label,

  /// The menu caret after the label.
  trailing,
}

/// An icon, a label and a caret in a row that can hide its label behind
/// the icon: the content of a `ToolButton` and of a mode tab (G21).
///
/// It is drawn **full** ([leading] when [leadingInFull], [label],
/// [trailing], [gap] and [trailingGap] apart, inside [fullPadding] on each
/// side) or **compact** ([leading] and [trailing] only, inside
/// [compactPadding]). It is compact when [compact] is set or [label] is
/// null, and also when its parent gives it less width than the full row
/// needs: a row that runs out of room collapses it in the same frame,
/// before the owner hears about it and rebuilds it compact. A row without
/// [leading], or without a label, cannot collapse.
///
/// While the owner hides the label it passes its text as [hiddenLabel] and
/// no [label]: the row measures it as a `Text` of it would be laid out
/// here, so the full width stays known without hidden text in the tree.
/// The maximum intrinsic width is the full row's and the minimum the
/// compact row's; that is how `Toolbar` and `ModeTabs` measure their items.
/// A part the row does not show is neither painted, hit-tested nor given to
/// semantics.
///
/// Not exported from the component library.
class CollapsibleLabel
    extends
        SlottedMultiChildRenderObjectWidget<CollapsibleLabelSlot, RenderBox> {
  /// A row of [leading], [label] and [trailing].
  const new({
    super.key,
    this.leading,
    this.label,
    this.trailing,
    this.hiddenLabel,
    this.compact = false,
    this.leadingInFull = true,
    this.fullPadding = 0,
    this.compactPadding = 0,
    this.gap = 0,
    this.trailingGap = 0,
  });

  /// The icon; shown compact, and full when [leadingInFull].
  final Widget? leading;

  /// The label; shown full only.
  final Widget? label;

  /// The caret; always shown.
  final Widget? trailing;

  /// The text of the label while the owner hides it ([label] null), so the
  /// full width stays known.
  final String? hiddenLabel;

  /// Whether the row is drawn compact even when it has room.
  final bool compact;

  /// Whether the full row shows [leading] (a mode tab without icons shows
  /// it only compact).
  final bool leadingInFull;

  /// The space at each side of the full row.
  final double fullPadding;

  /// The space at each side of the compact row.
  final double compactPadding;

  /// The space between [leading] and [label].
  final double gap;

  /// The space before [trailing].
  final double trailingGap;

  @override
  Iterable<CollapsibleLabelSlot> get slots => CollapsibleLabelSlot.values;

  @override
  Widget? childForSlot(CollapsibleLabelSlot slot) => switch (slot) {
    CollapsibleLabelSlot.leading => leading,
    CollapsibleLabelSlot.label => label,
    CollapsibleLabelSlot.trailing => trailing,
  };

  /// [hiddenLabel] as a `Text` would lay it out at [context]: the default
  /// text style, bold when the system asks for bold text.
  TextSpan? _hiddenSpan(BuildContext context) {
    final text = hiddenLabel;
    if (text == null || label != null) return null;
    var style = DefaultTextStyle.of(context).style;
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return TextSpan(text: text, style: style);
  }

  @override
  RenderCollapsibleLabel createRenderObject(BuildContext context) =>
      RenderCollapsibleLabel(
        compact: compact,
        leadingInFull: leadingInFull,
        fullPadding: fullPadding,
        compactPadding: compactPadding,
        gap: gap,
        trailingGap: trailingGap,
        textDirection: Directionality.of(context),
        hiddenLabel: _hiddenSpan(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCollapsibleLabel renderObject,
  ) {
    renderObject
      ..compact = compact
      ..leadingInFull = leadingInFull
      ..fullPadding = fullPadding
      ..compactPadding = compactPadding
      ..gap = gap
      ..trailingGap = trailingGap
      ..textDirection = Directionality.of(context)
      ..hiddenLabel = _hiddenSpan(context)
      ..textScaler = MediaQuery.textScalerOf(context)
      ..locale = Localizations.maybeLocaleOf(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('compact', value: compact, ifTrue: 'compact'))
      ..add(StringProperty('hiddenLabel', hiddenLabel, defaultValue: null))
      ..add(
        FlagProperty(
          'leadingInFull',
          value: leadingInFull,
          ifFalse: 'leading only when compact',
        ),
      );
  }
}

/// The render object of [CollapsibleLabel].
class RenderCollapsibleLabel extends RenderBox
    with SlottedContainerRenderObjectMixin<CollapsibleLabelSlot, RenderBox> {
  /// A row laid out as [CollapsibleLabel] describes.
  new({
    required this._compact,
    required this._leadingInFull,
    required this._fullPadding,
    required this._compactPadding,
    required this._gap,
    required this._trailingGap,
    required this._textDirection,
    required this._hiddenLabel,
    required this._textScaler,
    required this._locale,
  });

  /// Whether the row is drawn compact even when it has room.
  bool get compact => _compact;
  bool _compact;
  set compact(bool value) {
    if (value == _compact) return;
    _compact = value;
    markNeedsLayout();
  }

  /// Whether the full row shows the leading part.
  bool get leadingInFull => _leadingInFull;
  bool _leadingInFull;
  set leadingInFull(bool value) {
    if (value == _leadingInFull) return;
    _leadingInFull = value;
    markNeedsLayout();
  }

  /// The space at each side of the full row.
  double get fullPadding => _fullPadding;
  double _fullPadding;
  set fullPadding(double value) {
    if (value == _fullPadding) return;
    _fullPadding = value;
    markNeedsLayout();
  }

  /// The space at each side of the compact row.
  double get compactPadding => _compactPadding;
  double _compactPadding;
  set compactPadding(double value) {
    if (value == _compactPadding) return;
    _compactPadding = value;
    markNeedsLayout();
  }

  /// The space between the leading part and the label.
  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  /// The space before the trailing part.
  double get trailingGap => _trailingGap;
  double _trailingGap;
  set trailingGap(double value) {
    if (value == _trailingGap) return;
    _trailingGap = value;
    markNeedsLayout();
  }

  /// The direction the row runs in.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _resetPainter();
    markNeedsLayout();
  }

  /// The hidden label, measured for the full width.
  TextSpan? get hiddenLabel => _hiddenLabel;
  TextSpan? _hiddenLabel;
  set hiddenLabel(TextSpan? value) {
    if (value == _hiddenLabel) return;
    final old = _hiddenLabel;
    _hiddenLabel = value;
    // A colour change (a hover or toggle animation) cannot change the
    // measured width, and the hidden label is never painted: only a change
    // that affects layout measures again.
    if (old == null ||
        value == null ||
        value.compareTo(old).index >= RenderComparison.layout.index) {
      _resetPainter();
      markNeedsLayout();
    }
  }

  /// How the hidden label's text is scaled.
  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _resetPainter();
    markNeedsLayout();
  }

  /// The locale the hidden label is measured in.
  Locale? get locale => _locale;
  Locale? _locale;
  set locale(Locale? value) {
    if (value == _locale) return;
    _locale = value;
    _resetPainter();
    markNeedsLayout();
  }

  TextPainter? _painter;

  void _resetPainter() {
    _painter?.dispose();
    _painter = null;
  }

  RenderBox? get _leading => childForSlot(CollapsibleLabelSlot.leading);
  RenderBox? get _label => childForSlot(CollapsibleLabelSlot.label);
  RenderBox? get _trailing => childForSlot(CollapsibleLabelSlot.trailing);

  /// Whether the row has a label, shown or hidden.
  bool get _hasLabel => _label != null || _hiddenLabel != null;

  /// Whether the row can be drawn both ways.
  bool get _collapsible => _leading != null && _hasLabel;

  /// Whether the last layout drew the row compact. Tests read it.
  bool get isCompact => _drawnCompact;
  bool _drawnCompact = false;

  /// The width of the label: the shown one, or the hidden one as measured.
  double _labelWidth(double height) {
    final label = _label;
    if (label != null) return label.getMaxIntrinsicWidth(height);
    final span = _hiddenLabel;
    if (span == null) return 0;
    final painter = _painter ??= TextPainter(
      text: span,
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: 1,
    )..layout();
    return painter.maxIntrinsicWidth;
  }

  /// The parts of the full or compact row, in logical order, with the
  /// space before each; the label's place is null while it is hidden.
  List<(RenderBox?, double)> _parts({required bool compact}) {
    final leading = _leading;
    final trailing = _trailing;
    final parts = <(RenderBox?, double)>[];
    final asCompact = compact || !_hasLabel;
    if (leading != null && (asCompact || leadingInFull)) {
      parts.add((leading, 0));
    }
    if (!asCompact) parts.add((_label, parts.isEmpty ? 0 : gap));
    if (trailing != null) {
      parts.add((trailing, parts.isEmpty ? 0 : trailingGap));
    }
    return parts;
  }

  double _padding({required bool compact}) =>
      compact || !_hasLabel ? compactPadding : fullPadding;

  double _width({required bool compact, required double height}) {
    var width = 2 * _padding(compact: compact);
    for (final (child, space) in _parts(compact: compact)) {
      width +=
          space +
          (child == null || child == _label
              ? _labelWidth(height)
              : child.getMaxIntrinsicWidth(height));
    }
    return width;
  }

  double _fullWidth(double height) => _width(compact: false, height: height);

  @override
  double computeMinIntrinsicWidth(double height) =>
      _width(compact: _collapsible, height: height);

  @override
  double computeMaxIntrinsicWidth(double height) => _fullWidth(height);

  double _intrinsicHeight(double Function(RenderBox child) heightOf) {
    var height = 0.0;
    for (final child in children) {
      height = math.max(height, heightOf(child));
    }
    return height;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight((c) => c.getMinIntrinsicHeight(double.infinity));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight((c) => c.getMaxIntrinsicHeight(double.infinity));

  /// Whether a row given [constraints] is drawn compact.
  bool _isCompactFor(BoxConstraints constraints) {
    if (!_collapsible) return false;
    if (compact || _label == null) return true;
    if (!constraints.hasBoundedWidth) return false;
    // A hair of tolerance for rounding in the parent's arithmetic.
    return constraints.maxWidth < _fullWidth(constraints.maxHeight) - 0.01;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final compact = _isCompactFor(constraints);
    final childConstraints = BoxConstraints(maxHeight: constraints.maxHeight);
    var width = 2 * _padding(compact: compact);
    var height = 0.0;
    for (final (child, space) in _parts(compact: compact)) {
      if (child == null) continue;
      final size = child.getDryLayout(childConstraints);
      width += space + size.width;
      height = math.max(height, size.height);
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    final compact = _isCompactFor(constraints);
    _drawnCompact = compact;
    // Every part is laid out, shown or not, so each has a size.
    final childConstraints = BoxConstraints(maxHeight: constraints.maxHeight);
    for (final child in children) {
      child.layout(childConstraints, parentUsesSize: true);
    }
    final parts = [
      for (final (child, space) in _parts(compact: compact))
        if (child != null) (child, space),
    ];
    final padding = _padding(compact: compact);
    var width = 2 * padding;
    var height = 0.0;
    for (final (child, space) in parts) {
      width += space + child.size.width;
      height = math.max(height, child.size.height);
    }
    size = constraints.constrain(Size(width, height));
    // Centred when the box is wider than the row.
    final rtl = textDirection == TextDirection.rtl;
    var x = padding + math.max(0, size.width - width) / 2;
    for (final child in children) {
      (child.parentData! as BoxParentData).offset = Offset.zero;
    }
    for (final (child, space) in parts) {
      x += space;
      final dy = (size.height - child.size.height) / 2;
      final dx = rtl ? size.width - x - child.size.width : x;
      (child.parentData! as BoxParentData).offset = Offset(dx, dy);
      x += child.size.width;
    }
  }

  List<RenderBox> get _shown => [
    for (final (child, _) in _parts(compact: _drawnCompact)) ?child,
  ];

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in _shown) {
      final data = child.parentData! as BoxParentData;
      context.paintChild(child, offset + data.offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in _shown.reversed) {
      final data = child.parentData! as BoxParentData;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    _shown.forEach(visitor);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    for (final child in _shown) {
      final distance = child.getDistanceToActualBaseline(baseline);
      if (distance != null) {
        return distance + (child.parentData! as BoxParentData).offset.dy;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _resetPainter();
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty('compact', value: compact, ifTrue: 'compact'))
      ..add(FlagProperty('drawn', value: _drawnCompact, ifTrue: 'compact'))
      ..add(EnumProperty<TextDirection>('textDirection', textDirection));
  }
}
