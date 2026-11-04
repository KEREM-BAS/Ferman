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
/// and closes it (`DocumentEditor.finish`). The field keeps the block's
/// number of lines: a line feed typed or deleted is refused, as the engine
/// does not reflow yet (W2). For screen readers the block is a multi-line
/// text field.
// shortcut: the field draws the text in the UI font sized from the block's
// lines and leaves the font label (TextEditBox `meta`) out, since the
// engine's blocks name no font yet; the page shows the real result after
// each commit (G126).
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
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode(debugLabel: 'BlockEditor');

  DocumentEditor get _editor => ref.read(documentEditorProvider.notifier);

  @override
  void initState() {
    super.initState();
    final text = widget.edit.block.text;
    // The engine counts the caret in code points, the field in UTF-16.
    final offset = String.fromCharCodes(text.runes.take(widget.edit.caret))
        .length;
    _controller = TextEditingController(text: text)
      ..selection = TextSelection.collapsed(offset: offset);
    _focus.addListener(_focusChanged);
    // The canvas has focus from the click, so autofocus would not take it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _focusChanged() {
    if (!_focus.hasFocus) unawaited(_editor.finish());
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Refuses a change that adds or removes a line.
  static TextEditingValue _sameLines(
    TextEditingValue old,
    TextEditingValue next,
  ) => '\n'.allMatches(next.text).length == '\n'.allMatches(old.text).length
      ? next
      : old;

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
    return TextEditBox(
      onStateChanged: (_) => unawaited(_editor.finish()),
      child: ColoredBox(
        color: theme.pageColors.pageBg,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: width,
            maxWidth: width,
            minHeight: height,
          ),
          child: EditableText(
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
            inputFormatters: const [
              TextInputFormatter.withFunction(_sameLines),
            ],
            onChanged: _editor.type,
          ),
        ),
      ),
    );
  }
}
