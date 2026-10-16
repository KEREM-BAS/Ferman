import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;

import 'package:ferman/design/components/core/tooltip.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The kinds of [PageMark] (`.fm-mark--selection`, `--edited`,
/// `--missing-glyph`, `--search`, `--search-current`, `--redact-pending`,
/// `--redact-applied`).
enum PageMarkKind {
  /// A selected text run: the `--edit-selection` tint.
  selection,

  /// Text edited since the document was opened: a dotted accent underline
  /// and no fill (the DS additions' fix 3, never yellow).
  edited,

  /// A character the font has no glyph for: an amber tint with a wavy
  /// amber underline.
  missingGlyph,

  /// A search match: the `--search-match` tint.
  search,

  /// The current search match: a stronger orange tint with a 1 px ring.
  searchCurrent,

  /// Text marked for redaction but not yet applied: red stripes with a
  /// 1 px red ring.
  redactPending,

  /// Redacted text: true black, the text no longer drawn.
  redactApplied,
}

/// Inline mark over page text, the design-system `PageMark` component
/// (`components/editing/editing.css`, `.fm-mark`; `PageMark.jsx`):
/// selection, edited text, a missing glyph, a search hit, the current hit,
/// and pending or applied redaction.
///
/// [child] is the marked text run. It is laid out like `Text.rich` in the
/// ambient text style, and the mark is painted on every line fragment the
/// run takes (`box-decoration-break: clone`, [MarkedText]).
///
/// The colours are tuned for the white page and are the same in the light
/// and dark themes (`--edit-selection`, `--edit-mark`, `--glyph-missing`,
/// `--search-match`, `--search-current`, `--redact-pending`,
/// `--redact-applied`). The edited mark uses the DS additions' patch
/// (`fm-additions.css`, fix 3): a 1.5 px dotted `--edit-mark` underline 3 px
/// under the baseline, no fill.
///
/// [tooltip] is the mark's `title`: shown on hover and given to screen
/// readers. The bundle's English defaults ("Edited", "Marked for
/// redaction. Apply redactions to remove it permanently.", "Redacted",
/// and the missing-glyph sentence built from [char]) are localized by the
/// screens and passed in.
///
/// The mark is not interactive. Screen readers hear the run's text with
/// the tooltip; an applied redaction hides its text from them too, so only
/// the tooltip is read.
class PageMark extends StatelessWidget {
  /// Marks [child] as [kind].
  const new({
    required this.child,
    super.key,
    this.kind = PageMarkKind.selection,
    this.tooltip,
    this.char,
  });

  /// `.fm-mark` `border-radius: 1px`.
  static const double radius = 1;

  /// `text-underline-offset: 3px` of the edited and missing-glyph marks.
  static const double underlineOffset = 3;

  /// `text-decoration-thickness: 1.5px` of the edited mark (fix 3).
  static const double editedThickness = 1.5;

  /// `text-decoration-thickness: 1px` of the missing-glyph mark.
  static const double missingGlyphThickness = 1;

  /// `box-shadow: 0 0 0 1px` of the current search match and the pending
  /// redaction.
  static const double ringWidth = 1;

  /// What the run is marked as.
  final PageMarkKind kind;

  /// The mark's tooltip (the bundle's `title`); null shows none.
  final String? tooltip;

  /// The missing character of a [PageMarkKind.missingGlyph] mark. The
  /// bundle builds its English title from it; in Ferman the screen builds
  /// the localized [tooltip] from it, and the widget keeps it for its
  /// diagnostics.
  final String? char;

  /// The marked text run.
  final InlineSpan child;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final page = theme.pageColors;
    final behind = switch (kind) {
      PageMarkKind.selection => MarkPaint.fill(page.editSelection, radius),
      PageMarkKind.edited => null,
      PageMarkKind.missingGlyph => MarkPaint.fill(page.glyphMissingBg, radius),
      PageMarkKind.search => MarkPaint.fill(page.searchMatch, radius),
      PageMarkKind.searchCurrent => (Canvas canvas, MarkFragment fragment) {
        MarkPaint.fill(page.searchCurrent, radius)(canvas, fragment);
        MarkPaint.ring(page.searchCurrentBorder, ringWidth, radius)(
          canvas,
          fragment,
        );
      },
      PageMarkKind.redactPending => (Canvas canvas, MarkFragment fragment) {
        MarkPaint.hatch(theme.hatch.redactPending, radius)(canvas, fragment);
        MarkPaint.ring(page.redactPending, ringWidth, radius)(canvas, fragment);
      },
      PageMarkKind.redactApplied => MarkPaint.fill(page.redactApplied, radius),
    };
    final over = switch (kind) {
      PageMarkKind.edited => MarkPaint.dottedUnderline(
        page.editMark,
        editedThickness,
        underlineOffset,
      ),
      PageMarkKind.missingGlyph => MarkPaint.wavyUnderline(
        page.glyphMissing,
        missingGlyphThickness,
        underlineOffset,
      ),
      _ => null,
    };
    final redacted = kind == PageMarkKind.redactApplied;
    Widget result = Semantics(
      container: true,
      label: redacted ? null : child.toPlainText(),
      tooltip: tooltip,
      child: ExcludeSemantics(
        child: MarkedText(
          text: child,
          paintBehind: behind,
          paintOver: over,
          showText: !redacted,
        ),
      ),
    );
    final message = tooltip;
    if (message != null) {
      result = Tooltip(
        message: message,
        excludeFromSemantics: true,
        child: result,
      );
    }
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<PageMarkKind>(
          'kind',
          kind,
          defaultValue: PageMarkKind.selection,
        ),
      )
      ..add(StringProperty('tooltip', tooltip, defaultValue: null))
      ..add(StringProperty('char', char, defaultValue: null))
      ..add(StringProperty('text', child.toPlainText()));
  }
}

/// One line fragment of a marked text run: where [MarkedText] paints a
/// mark.
@immutable
final class MarkFragment {
  /// A fragment covering [rect], on the line whose baseline is [baseline].
  const new({required this.rect, required this.baseline});

  /// The run's box on one line: as wide as the run's glyphs there and as
  /// tall as the font's ascent and descent (the CSS content area that an
  /// inline background covers).
  final Rect rect;

  /// The alphabetic baseline of the line, in the same coordinates.
  final double baseline;

  @override
  bool operator ==(Object other) =>
      other is MarkFragment && other.rect == rect && other.baseline == baseline;

  @override
  int get hashCode => Object.hash(rect, baseline);

  @override
  String toString() => 'MarkFragment($rect, baseline: $baseline)';
}

/// Paints part of a mark on one [MarkFragment].
typedef MarkPainter = void Function(Canvas canvas, MarkFragment fragment);

/// The mark painters the page marks share ([PageMark] and the
/// annotations' `Highlight`): fills, rings, stripes and the CSS text
/// decorations.
abstract final class MarkPaint {
  /// A fill of [color] over the fragment, with [radius] corners, widened by
  /// [inflateX] on each side (`.fm-hl` `padding: 0 1px; margin: 0 -1px`),
  /// blended with [blendMode] (the highlight's `mix-blend-mode: multiply`).
  static MarkPainter fill(
    Color color,
    double radius, {
    double inflateX = 0,
    BlendMode blendMode = BlendMode.srcOver,
  }) =>
      (canvas, fragment) => canvas.drawRRect(
        RRect.fromRectAndRadius(
          fragment.rect.inflateX(inflateX),
          Radius.circular(radius),
        ),
        Paint()
          ..color = color
          ..blendMode = blendMode,
      );

  /// A [width] ring of [color] just outside the fragment
  /// (`box-shadow: 0 0 0 1px`).
  static MarkPainter ring(Color color, double width, double radius) =>
      (canvas, fragment) => canvas.drawRRect(
        RRect.fromRectAndRadius(
          fragment.rect.inflate(width / 2),
          Radius.circular(radius + width / 2),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );

  /// The stripes of [hatch] over the fragment (a CSS
  /// `repeating-linear-gradient` with hard stops), restarted on every line
  /// fragment as `box-decoration-break: clone` does.
  static MarkPainter hatch(FermanHatch hatch, double radius) =>
      (canvas, fragment) {
        final rect = fragment.rect;
        final period = hatch.stripes.fold<double>(0, (sum, s) => sum + s.width);
        if (period <= 0) return;
        final angle = hatch.angle * math.pi / 180;
        // CSS: 0deg points up, 90deg right; y grows downwards.
        final direction = Offset(math.sin(angle), -math.cos(angle));
        final length =
            (rect.width * math.sin(angle)).abs() +
            (rect.height * math.cos(angle)).abs();
        final start = rect.center - direction * (length / 2);
        final colors = <Color>[];
        final stops = <double>[];
        var at = 0.0;
        for (final stripe in hatch.stripes) {
          colors.addAll([stripe.color, stripe.color]);
          stops.addAll([at / period, (at + stripe.width) / period]);
          at += stripe.width;
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
          Paint()
            ..shader = ui.Gradient.linear(
              start,
              start + direction * period,
              colors,
              stops,
              TileMode.repeated,
            ),
        );
      };

  /// A solid [thickness] line of [color] whose top edge sits [offset]
  /// under the baseline (`text-decoration: underline`,
  /// `text-underline-offset`).
  static MarkPainter underline(Color color, double thickness, double offset) =>
      (canvas, fragment) => canvas.drawRect(
        Rect.fromLTWH(
          fragment.rect.left,
          fragment.baseline + offset,
          fragment.rect.width,
          thickness,
        ),
        Paint()..color = color,
      );

  /// A solid [thickness] line of [color] through the middle of the
  /// lowercase letters (`text-decoration: line-through`): centred
  /// [strikeRatio] of the ascent above the baseline, the usual strikeout
  /// position of the IBM Plex faces.
  static MarkPainter strikethrough(Color color, double thickness) =>
      (canvas, fragment) {
        final ascent = fragment.baseline - fragment.rect.top;
        final centre = fragment.baseline - ascent * strikeRatio;
        canvas.drawRect(
          Rect.fromLTWH(
            fragment.rect.left,
            centre - thickness / 2,
            fragment.rect.width,
            thickness,
          ),
          Paint()..color = color,
        );
      };

  /// Round dots of [thickness] spaced one dot apart, [offset] under the
  /// baseline (`text-decoration: underline dotted`,
  /// `text-decoration-skip-ink: none`).
  static MarkPainter dottedUnderline(
    Color color,
    double thickness,
    double offset,
  ) => (canvas, fragment) {
    final paint = Paint()..color = color;
    final y = fragment.baseline + offset + thickness / 2;
    final rect = fragment.rect;
    for (
      var x = rect.left + thickness / 2;
      x <= rect.right - thickness / 2;
      x += thickness * 2
    ) {
      canvas.drawCircle(Offset(x, y), thickness / 2, paint);
    }
  };

  /// A wave of [thickness] and [color], [offset] under the baseline
  /// (`text-decoration: underline wavy`): [wavePeriod] times the thickness
  /// long and as high as two thicknesses.
  static MarkPainter wavyUnderline(
    Color color,
    double thickness,
    double offset,
  ) => (canvas, fragment) {
    final rect = fragment.rect;
    final amplitude = thickness;
    final half = math.max(thickness, 1) * wavePeriod / 2;
    final y = fragment.baseline + offset + amplitude;
    final path = Path()..moveTo(rect.left, y);
    var up = true;
    for (var x = rect.left; x < rect.right; x += half) {
      final end = math.min(x + half, rect.right);
      path.quadraticBezierTo(
        (x + end) / 2,
        up ? y - amplitude * 2 : y + amplitude * 2,
        end,
        y,
      );
      up = !up;
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = color,
    );
  };

  /// The strikeout position as a share of the ascent above the baseline.
  static const double strikeRatio = 0.28;

  /// The length of one wave of a wavy underline, in thicknesses.
  static const double wavePeriod = 4;
}

extension on Rect {
  Rect inflateX(double delta) =>
      Rect.fromLTRB(left - delta, top, right + delta, bottom);
}

/// A text run laid out like `Text.rich` in the ambient [DefaultTextStyle],
/// with a mark painted behind and over each of its line fragments: the
/// building block of [PageMark] and the annotations' `Highlight`. Not a
/// design-system component.
///
/// [paintBehind] runs before the text and [paintOver] after it, once per
/// line the run takes ([MarkFragment]), so a mark breaks with the text as
/// CSS `box-decoration-break: clone` does. [showText] false paints only
/// the mark (an applied redaction).
///
/// [text] may hold text spans only, no widget spans. For screen readers
/// the run is one text node with its plain text.
class MarkedText extends StatelessWidget {
  /// Lays out [text] and marks it.
  const new({
    required this.text,
    super.key,
    this.paintBehind,
    this.paintOver,
    this.showText = true,
  });

  /// The text run; text spans only.
  final InlineSpan text;

  /// Paints under the text on each line fragment; null paints nothing.
  final MarkPainter? paintBehind;

  /// Paints over the text on each line fragment; null paints nothing.
  final MarkPainter? paintOver;

  /// Whether the text itself is painted.
  final bool showText;

  @override
  Widget build(BuildContext context) {
    assert(
      text.visitChildren((span) => span is! PlaceholderSpan),
      'MarkedText takes text spans only.',
    );
    final style = DefaultTextStyle.of(context);
    return _MarkedTextLeaf(
      text: TextSpan(style: style.style, children: [text]),
      textAlign: style.textAlign ?? TextAlign.start,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      paintBehind: paintBehind,
      paintOver: paintOver,
      showText: showText,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text.toPlainText()))
      ..add(FlagProperty('showText', value: showText, ifFalse: 'text hidden'));
  }
}

class _MarkedTextLeaf extends LeafRenderObjectWidget {
  const new({
    required this.text,
    required this.textAlign,
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.paintBehind,
    required this.paintOver,
    required this.showText,
  });

  final InlineSpan text;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final MarkPainter? paintBehind;
  final MarkPainter? paintOver;
  final bool showText;

  @override
  _RenderMarkedText createRenderObject(BuildContext context) =>
      _RenderMarkedText(
        text: text,
        textAlign: textAlign,
        textDirection: textDirection,
        textScaler: textScaler,
        locale: locale,
        paintBehind: paintBehind,
        paintOver: paintOver,
        showText: showText,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMarkedText renderObject,
  ) {
    renderObject.update(
      text: text,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      paintBehind: paintBehind,
      paintOver: paintOver,
      showText: showText,
    );
  }
}

class _RenderMarkedText extends RenderBox {
  new({
    required InlineSpan text,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required Locale? locale,
    required this._paintBehind,
    required this._paintOver,
    required this._showText,
  }) : _painter = TextPainter(
         text: text,
         textAlign: textAlign,
         textDirection: textDirection,
         textScaler: textScaler,
         locale: locale,
       );

  final TextPainter _painter;
  List<MarkFragment>? _fragments;
  MarkPainter? _paintBehind;
  MarkPainter? _paintOver;
  bool _showText;

  /// Takes the widget's new configuration, invalidating only what changed.
  void update({
    required InlineSpan text,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required Locale? locale,
    required MarkPainter? paintBehind,
    required MarkPainter? paintOver,
    required bool showText,
  }) {
    final comparison =
        _painter.text?.compareTo(text) ?? RenderComparison.layout;
    var relayout = comparison == RenderComparison.layout;
    if (comparison != RenderComparison.identical) {
      _painter.text = text;
      markNeedsSemanticsUpdate();
    }
    if (_painter.textAlign != textAlign) {
      _painter.textAlign = textAlign;
      relayout = true;
    }
    if (_painter.textDirection != textDirection) {
      _painter.textDirection = textDirection;
      relayout = true;
      markNeedsSemanticsUpdate();
    }
    if (_painter.textScaler != textScaler) {
      _painter.textScaler = textScaler;
      relayout = true;
    }
    if (_painter.locale != locale) {
      _painter.locale = locale;
      relayout = true;
    }
    _paintBehind = paintBehind;
    _paintOver = paintOver;
    _showText = showText;
    if (relayout) {
      _fragments = null;
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  void _layout(double maxWidth) {
    _painter.layout(maxWidth: maxWidth);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _layout(double.infinity);
    return _painter.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _layout(double.infinity);
    return _painter.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _layout(width);
    return _painter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    _layout(constraints.maxWidth);
    return constraints.constrain(_painter.size);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    _layout(constraints.maxWidth);
    return _painter.computeDistanceToActualBaseline(baseline);
  }

  @override
  void performLayout() {
    _layout(constraints.maxWidth);
    _fragments = null;
    size = constraints.constrain(_painter.size);
  }

  /// The run's boxes merged per line, with each line's baseline.
  List<MarkFragment> _computeFragments() {
    final length =
        _painter.text?.toPlainText(includeSemanticsLabels: false).length ?? 0;
    if (length == 0) return const [];
    // The default box height, `BoxHeightStyle.tight`: the font's ascent
    // to descent, the CSS content area an inline background covers.
    final boxes = _painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: length),
    );
    final lines = _painter.computeLineMetrics();
    final byLine = <int, Rect>{};
    for (final box in boxes) {
      final rect = box.toRect();
      if (rect.width <= 0) continue;
      final centre = rect.center.dy;
      var line = 0;
      var best = double.infinity;
      for (var i = 0; i < lines.length; i++) {
        final metrics = lines[i];
        final top = metrics.baseline - metrics.ascent;
        final bottom = metrics.baseline + metrics.descent;
        final distance = centre < top
            ? top - centre
            : (centre > bottom ? centre - bottom : 0.0);
        if (distance < best) {
          best = distance;
          line = i;
        }
      }
      byLine[line] = byLine[line]?.expandToInclude(rect) ?? rect;
    }
    final keys = byLine.keys.toList()..sort();
    return [
      for (final key in keys)
        MarkFragment(
          rect: byLine[key]!,
          baseline: key < lines.length
              ? lines[key].baseline
              : byLine[key]!.bottom,
        ),
    ];
  }

  /// The line fragments of the run, for tests.
  @visibleForTesting
  List<MarkFragment> get fragments => _fragments ??= _computeFragments();

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    _layout(constraints.maxWidth);
    final canvas = context.canvas;
    final behind = _paintBehind;
    final over = _paintOver;
    if (behind != null) {
      canvas
        ..save()
        ..translate(offset.dx, offset.dy);
      for (final fragment in fragments) {
        behind(canvas, fragment);
      }
      canvas.restore();
    }
    if (_showText) _painter.paint(canvas, offset);
    if (over != null) {
      canvas
        ..save()
        ..translate(offset.dx, offset.dy);
      for (final fragment in fragments) {
        over(canvas, fragment);
      }
      canvas.restore();
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _painter.text?.toPlainText() ?? ''
      ..textDirection = _painter.textDirection;
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}
