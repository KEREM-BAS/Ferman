import 'package:ferman/design/components/annotations/annotation_color.dart';
import 'package:ferman/design/components/editing/page_mark.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The text-markup kinds of a [Highlight] (`.fm-hl--highlight`,
/// `--underline`, `--strikethrough`, `--squiggly`).
enum HighlightVariant {
  /// A fill behind the text, multiplied with the page.
  highlight,

  /// A 2 px line 2 px under the baseline.
  underline,

  /// A 2 px line through the text.
  strikethrough,

  /// A 1.5 px wave 3 px under the baseline.
  squiggly,
}

/// A text-markup annotation, the design-system `Highlight` component
/// (`components/annotations/annotations.css`, `.fm-hl`; `Highlight.jsx`):
/// a highlight, underline, strikethrough or squiggly line in an annotation
/// colour.
///
/// [child] is the marked text run, laid out like `Text.rich` in the
/// ambient text style; the mark is painted on every line fragment it takes
/// (`box-decoration-break: clone`, [MarkedText]).
///
/// - [HighlightVariant.highlight] fills the run in the colour, widened by
///   1 px on each side with 1 px corners, multiplied with the page
///   (`mix-blend-mode: multiply`), under the text;
/// - [HighlightVariant.underline]: a 2 px line whose top sits 2 px under
///   the baseline;
/// - [HighlightVariant.strikethrough]: a 2 px line through the lowercase
///   letters, over the text;
/// - [HighlightVariant.squiggly]: a 1.5 px wave 3 px under the baseline.
///
/// The colour is [customColor] when given (the bundle also accepts any CSS
/// colour), else [color] from the annotation palette, as the bundle's
/// `COLORS` map it: [AnnotationColor.ink] is `--annot-blue-ink` here,
/// where the tool row's ink swatch is `--annot-ink`. The colours are
/// document colours, the same in both themes.
///
/// Not interactive; screen readers hear the run's text.
class Highlight extends StatelessWidget {
  /// Marks [child] in [color] as [variant].
  const new({
    required this.child,
    super.key,
    this.color = AnnotationColor.yellow,
    this.customColor,
    this.variant = HighlightVariant.highlight,
  });

  /// `.fm-hl` `border-radius: 1px`.
  static const double radius = 1;

  /// `.fm-hl` `padding: 0 1px; margin: 0 -1px`: the fill reaches 1 px past
  /// the text on each side without moving it.
  static const double bleed = 1;

  /// `.fm-hl--underline` and `--strikethrough`
  /// `text-decoration-thickness: 2px`.
  static const double lineThickness = 2;

  /// `.fm-hl--underline` `text-underline-offset: 2px`.
  static const double underlineOffset = 2;

  /// `.fm-hl--squiggly` `text-decoration-thickness: 1.5px`.
  static const double squigglyThickness = 1.5;

  /// `.fm-hl--squiggly` `text-underline-offset: 3px`.
  static const double squigglyOffset = 3;

  /// The annotation colour.
  final AnnotationColor color;

  /// A colour outside the palette; overrides [color]. Not a design-system
  /// prop (the bundle takes any CSS colour in `color`).
  final Color? customColor;

  /// The markup kind.
  final HighlightVariant variant;

  /// The marked text run.
  final InlineSpan child;

  /// The colour of [color] in [theme], as the bundle's `COLORS` map it.
  static Color resolve(AnnotationColor color, FermanTheme theme) =>
      color == AnnotationColor.ink
      ? theme.ramps.annotBlueInk
      : color.resolve(theme);

  @override
  Widget build(BuildContext context) {
    final paint = customColor ?? resolve(color, context.ferman);
    return MarkedText(
      text: child,
      paintBehind: switch (variant) {
        HighlightVariant.highlight => MarkPaint.fill(
          paint,
          radius,
          inflateX: bleed,
          blendMode: BlendMode.multiply,
        ),
        HighlightVariant.underline => MarkPaint.underline(
          paint,
          lineThickness,
          underlineOffset,
        ),
        HighlightVariant.squiggly => MarkPaint.wavyUnderline(
          paint,
          squigglyThickness,
          squigglyOffset,
        ),
        HighlightVariant.strikethrough => null,
      },
      paintOver: variant == HighlightVariant.strikethrough
          ? MarkPaint.strikethrough(paint, lineThickness)
          : null,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        EnumProperty<AnnotationColor>(
          'color',
          color,
          defaultValue: AnnotationColor.yellow,
        ),
      )
      ..add(ColorProperty('customColor', customColor, defaultValue: null))
      ..add(
        EnumProperty<HighlightVariant>(
          'variant',
          variant,
          defaultValue: HighlightVariant.highlight,
        ),
      )
      ..add(StringProperty('text', child.toPlainText()));
  }
}
