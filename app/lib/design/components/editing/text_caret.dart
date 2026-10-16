import 'dart:async';

import 'package:ferman/design/theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The text caret drawn over page text and in the comment compose field,
/// the design-system `TextCaret` component
/// (`components/editing/editing.css`, `.fm-caret`; `TextEditBox.jsx`).
///
/// A 1.5 px bar of `--edit-caret` (ink 700, page-tuned, the same in both
/// themes), 1.15 em tall for the ambient font size and sinking 0.2 em
/// below the baseline (`vertical-align: -0.2em`). It takes no width in the
/// line: the bar straddles its position (`margin: 0 -0.75px`). Inside text,
/// place it in a `WidgetSpan` aligned to the baseline.
///
/// It blinks in hard steps: shown for the first half of every
/// [blinkPeriod] and hidden for the second (`fm-caret` keyframes,
/// `steps(1)`). Under reduced motion (the zero durations of
/// `context.ferman.motion`) it stays solid (COMPONENTS.md, decision 12).
///
/// It is decorative and excluded from semantics.
class TextCaret extends StatefulWidget {
  /// Creates a caret.
  const new({super.key});

  /// `.fm-caret` `animation: fm-caret 1.05s steps(1) infinite`. A literal
  /// keyframe timing with no duration token.
  static const Duration blinkPeriod = Duration(milliseconds: 1050);

  /// `.fm-caret` `width: 1.5px`.
  static const double width = 1.5;

  /// `.fm-caret` `height: 1.15em`, in ems of the ambient font size.
  static const double heightEm = 1.15;

  /// `.fm-caret` `vertical-align: -0.2em`: how far the bar reaches below
  /// the baseline, in ems.
  static const double descentEm = 0.2;

  /// The font size when the ambient text style sets none (Flutter's
  /// default).
  static const double fallbackFontSize = 14;

  @override
  State<TextCaret> createState() => _TextCaretState();
}

class _TextCaretState extends State<TextCaret> {
  Timer? _timer;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = context.ferman.motion.durBase == Duration.zero;
    if (reduced) {
      _timer?.cancel();
      _timer = null;
      _visible = true;
    } else {
      _timer ??= Timer.periodic(
        TextCaret.blinkPeriod ~/ 2,
        (_) => setState(() => _visible = !_visible),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final fontSize = MediaQuery.textScalerOf(context)
        .scale(style.fontSize ?? TextCaret.fallbackFontSize);
    return ExcludeSemantics(
      child: _CaretBar(
        color: context.ferman.pageColors.editCaret,
        fontSize: fontSize,
        visible: _visible,
      ),
    );
  }
}

class _CaretBar extends LeafRenderObjectWidget {
  const new({
    required this.color,
    required this.fontSize,
    required this.visible,
  });

  final Color color;
  final double fontSize;
  final bool visible;

  @override
  RenderCaretBar createRenderObject(BuildContext context) =>
      RenderCaretBar(color: color, fontSize: fontSize, visible: visible);

  @override
  void updateRenderObject(BuildContext context, RenderCaretBar renderObject) {
    renderObject.update(color: color, fontSize: fontSize, visible: visible);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('color', color))
      ..add(DoubleProperty('fontSize', fontSize))
      ..add(FlagProperty('visible', value: visible, ifFalse: 'hidden'));
  }
}

/// The render object of a [TextCaret]: zero wide, [TextCaret.heightEm]
/// tall, with its baseline [TextCaret.descentEm] above its bottom, painting
/// the bar centred on its position while [visible].
class RenderCaretBar extends RenderBox {
  /// Creates the bar.
  new({required this._color, required this._fontSize, required this._visible});

  Color _color;
  double _fontSize;
  bool _visible;

  /// Whether the bar is painted (the shown half of the blink).
  bool get visible => _visible;

  /// Takes a new colour, font size and visibility.
  void update({
    required Color color,
    required double fontSize,
    required bool visible,
  }) {
    if (_fontSize != fontSize) {
      _fontSize = fontSize;
      markNeedsLayout();
    }
    if (_color != color || _visible != visible) {
      _color = color;
      _visible = visible;
      markNeedsPaint();
    }
  }

  double get _height => _fontSize * TextCaret.heightEm;

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(0, _height));

  @override
  void performLayout() {
    size = constraints.constrain(Size(0, _height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _height - _fontSize * TextCaret.descentEm;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _height - _fontSize * TextCaret.descentEm;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_visible) return;
    context.canvas.drawRect(
      Rect.fromLTWH(
        offset.dx - TextCaret.width / 2,
        offset.dy,
        TextCaret.width,
        size.height,
      ),
      Paint()..color = _color,
    );
  }
}
