import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The inline editor over the block being edited (a3-1b): its editing
/// frame, and a multi-line text field with the block's text on the page's
/// white, so the page's own text does not show through while it changes.
///
/// [frame] is the block's frame on the canvas at [scale]. The field opens
/// with the caret where the click put it and takes focus; each change goes
/// to the engine (`DocumentEditor.type`), and losing focus or Esc commits
/// and closes it (`DocumentEditor.finish`). The engine lays the text out
/// again in the block's frame, so lines may come and go. While "Keep and
/// warn" hides lines past the frame (a3-4), the text fades from 60% of the
/// frame's height to 35% under an amber dashed edge at the frame's bottom;
/// the canvas puts "+1 line hidden" beside it. For screen readers the
/// block is a multi-line text field.
///
/// Text an input method is still composing (a Japanese or Korean IME,
/// Turkish dead keys) shows in the field, underlined as the platform does,
/// but goes to the engine only once the composition ends: one edit, never
/// a step per keystroke of it (ROADMAP §7 step 7). Characters the block's
/// font lacks (missing-glyph step 3, a3-3a) get the amber wavy underline
/// on the page's missing-glyph tint, and the frame's label turns amber
/// with the font's name, below the frame.
// shortcut: the field draws the text in the UI font sized from the block's
// lines and leaves the font label (TextEditBox `meta`) out but for a3-3a's
// warning, since the engine's blocks name no font yet; the page shows the
// real result after each commit (G126).
class BlockEditor extends ConsumerStatefulWidget {
  /// The editor of [edit], over [frame].
  const new({
    required this.edit,
    required this.frame,
    required this.scale,
    super.key,
  });

  /// The block being edited.
  final ActiveEdit edit;

  /// Its frame on the canvas.
  final Rect frame;

  /// The canvas's points per page point.
  final double scale;

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ActiveEdit>('edit', edit))
      ..add(DiagnosticsProperty<Rect>('frame', frame))
      ..add(DoubleProperty('scale', scale));
  }
}

class _BlockEditorState extends ConsumerState<BlockEditor> {
  late final _MarkedController _controller;

  /// The text last given to the engine.
  late String _sent;
  final FocusNode _focus = FocusNode(debugLabel: 'BlockEditor');

  DocumentEditor get _editor => ref.read(documentEditorProvider.notifier);

  @override
  void initState() {
    super.initState();
    final text = widget.edit.block.text;
    // The engine counts the caret in code points, the field in UTF-16.
    final offset = String.fromCharCodes(text.runes.take(widget.edit.caret))
        .length;
    _sent = text;
    _controller = _MarkedController(text: text)
      ..selection = TextSelection.collapsed(offset: offset)
      ..addListener(_changed);
    _focus.addListener(_focusChanged);
    // The canvas has focus from the click, so autofocus would not take it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _focusChanged() {
    // The a3-3b picker takes the focus for a while and gives it back.
    if (!_focus.hasFocus && !ref.read(documentEditorProvider).picking) {
      unawaited(_editor.finish());
    }
  }

  /// Sends the field's text once no input method composes in it.
  void _changed() {
    final value = _controller.value;
    if (value.isComposingRangeValid && !value.composing.isCollapsed) return;
    if (value.text == _sent) return;
    _sent = value.text;
    _editor.type(value.text);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    _controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  /// a3-4's mask: opaque to 60% of the frame, 35% at its bottom.
  static const double fadeFrom = 0.6;

  /// a3-4's `rgba(0,0,0,.35)` at the frame's bottom and past it.
  static const double fadedAlpha = 0.35;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final block = widget.edit.block;
    final frame = widget.frame;
    final lines = math.max(block.lines.length, 1);
    final pitch = frame.height / lines;
    final glyphs = (block.lines.firstOrNull?.bbox.height ?? 0) * widget.scale;
    final fontSize = math
        .max((glyphs > 0 ? glyphs : pitch) / TextCaret.heightEm, 1)
        .toDouble();
    final width =
        frame.width + 2 * (TextEditBox.marginX - TextEditBox.paddingX);
    final height =
        frame.height + 2 * (TextEditBox.marginY - TextEditBox.paddingY);
    final hidden = ref.watch(
      documentEditorProvider.select((s) => s.keptHidden > 0),
    );
    final missing = ref.watch(documentEditorProvider.select((s) => s.glyphs));
    _controller.marks = missing?.chars ?? const [];
    _controller.markStyle = TextStyle(
      backgroundColor: theme.pageColors.glyphMissingBg,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.wavy,
      decorationColor: theme.pageColors.glyphMissing,
      decorationThickness: PageMark.missingGlyphThickness,
    );
    // The frame's bottom inside the field's box.
    final bottom = frame.height + TextEditBox.marginY - TextEditBox.paddingY;
    Widget field = EditableText(
      controller: _controller,
      focusNode: _focus,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textDirection: block.direction == BlockDirection.rightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      style: theme.typography.body.copyWith(
        fontSize: fontSize,
        height: pitch / fontSize,
        color: theme.ramps.paper900,
      ),
      strutStyle: StrutStyle(
        fontSize: fontSize,
        height: pitch / fontSize,
        forceStrutHeight: true,
      ),
      cursorColor: theme.pageColors.editCaret,
      cursorWidth: TextCaret.width,
      backgroundCursorColor: theme.colors.borderSubtle,
      selectionColor: theme.pageColors.editSelection,
    );
    if (hidden) {
      final ink = theme.ramps.paper900;
      field = Stack(
        clipBehavior: Clip.none,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ink,
                ink,
                ink.withValues(alpha: fadedAlpha),
              ],
              stops: [
                0,
                (bottom * fadeFrom / bounds.height).clamp(0, 1),
                (bottom / bounds.height).clamp(0, 1),
              ],
            ).createShader(bounds),
            child: field,
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            top: bottom,
            child: CustomPaint(
              key: const ValueKey<String>('BlockEditor.overflowEdge'),
              size: Size.fromHeight(theme.border.borderWidthStrong),
              painter: _DashedEdge(
                color: theme.pageColors.overflowMark,
                width: theme.border.borderWidthStrong,
              ),
            ),
          ),
        ],
      );
    }
    return TextEditBox(
      // a3-3a: nothing above the frame is free, so the label flips below.
      meta: missing?.font,
      metaWarning: missing != null,
      metaPlacement: MetaPlacement.below,
      onStateChanged: (_) => unawaited(_editor.finish()),
      child: ColoredBox(
        color: theme.pageColors.pageBg,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: width,
            maxWidth: width,
            minHeight: height,
          ),
          child: field,
        ),
      ),
    );
  }
}

/// The field's controller, marking the characters of [marks] with
/// [markStyle] while nothing is composed.
class _MarkedController extends TextEditingController {
  new({super.text});

  List<MissingChar> marks = const [];
  TextStyle? markStyle;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final text = this.text;
    final marked = [
      for (final mark in marks)
        if (mark.at >= 0 &&
            text.startsWith(mark.text, mark.at) &&
            mark.text.isNotEmpty)
          mark,
    ]..sort((a, b) => a.at.compareTo(b.at));
    if (marked.isEmpty || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final children = <TextSpan>[];
    var at = 0;
    for (final mark in marked) {
      if (mark.at < at) continue;
      if (mark.at > at) {
        children.add(TextSpan(text: text.substring(at, mark.at)));
      }
      at = mark.at + mark.text.length;
      children.add(TextSpan(text: mark.text, style: markStyle));
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }
}

/// a3-4's `border-bottom: 1.5px dashed var(--overflow-mark)`, dashed as the
/// TextEditBox hover frame is.
class _DashedEdge extends CustomPainter {
  const new({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    final y = width / 2;
    for (
      var x = 0.0;
      x < size.width;
      x += TextEditBox.dashLength + TextEditBox.dashGap
    ) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + TextEditBox.dashLength, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedEdge old) =>
      old.color != color || old.width != width;
}
