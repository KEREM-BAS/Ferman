import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/design/components/annotations/annotation_color.dart'
    as design;
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/editor/block_language.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/format_bar.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
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
/// Input arrives as deltas (`DeltaTextInputClient`). Text an input method is
/// still composing (a Japanese or Korean IME, Turkish dead keys) shows in the
/// field as a preview, underlined as the platform does, but goes to the
/// engine only once the composition ends: one edit, never a step per
/// keystroke of it (ROADMAP §7 step 7). Esc during a composition cancels it,
/// and leaving the field keeps it. Characters the block's
/// font lacks (missing-glyph step 3, a3-3a) get the amber wavy underline
/// on the page's missing-glyph tint, and the frame's label turns amber
/// with the font's name, on the side [metaPlacement] says (f1).
///
/// Drag, double-click and triple-click select inside the field; a selection
/// opens [FormatBar] above it (a3-1c), and ⌘B and ⌘I work while it is open.
/// Esc closes the bar with the selection, then leaves editing.
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
    this.metaPlacement = MetaPlacement.above,
    this.uiDirection = TextDirection.ltr,
    super.key,
  });

  /// The block being edited.
  final ActiveEdit edit;

  /// Its frame on the canvas.
  final Rect frame;

  /// The canvas's points per page point.
  final double scale;

  /// Where the frame's label sits ([metaPlacementFor]).
  final MetaPlacement metaPlacement;

  /// The UI's direction, for the format bar: the canvas is never mirrored.
  final TextDirection uiDirection;

  @override
  ConsumerState<BlockEditor> createState() => _BlockEditorState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ActiveEdit>('edit', edit))
      ..add(DiagnosticsProperty<Rect>('frame', frame))
      ..add(DoubleProperty('scale', scale))
      ..add(EnumProperty<MetaPlacement>('metaPlacement', metaPlacement))
      ..add(EnumProperty<TextDirection>('uiDirection', uiDirection));
  }
}

class _BlockEditorState extends ConsumerState<BlockEditor>
    implements TextSelectionGestureDetectorBuilderDelegate {
  late final _MarkedController _controller;

  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);

  final OverlayPortalController _bar = OverlayPortalController(
    debugLabel: 'FormatBar',
  );
  final FocusScopeNode _barFocus = FocusScopeNode(debugLabel: 'FormatBar');

  /// Whether text is selected, so the bar is open.
  bool _selected = false;

  /// Where the selection starts in the field, for the bar.
  double _barStart = 0;

  /// The selection the bar acts on: the field clears its own while the bar
  /// has the focus, and gets this back after.
  TextSelection? _barSelection;

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
      ..addListener(_changed)
      ..addListener(_selectionChanged);
    _focus.addListener(_focusChanged);
    _barFocus.addListener(_selectionChanged);
    // The canvas has focus from the click, so autofocus would not take it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _focusChanged() {
    // The a3-3b picker, the panel and its language take the focus for a while
    // and give it back.
    if (!_focus.hasFocus &&
        !ref.read(documentEditorProvider).picking &&
        !ref.read(documentEditorProvider).held &&
        !_barFocus.hasFocus &&
        !_editor.panelFocus.hasFocus &&
        !BlockLanguageSection.hasFocus) {
      // A composition the click cut off is kept, before the commit closes.
      _send(_controller.text);
      unawaited(_editor.finish());
    }
  }

  @override
  void didUpdateWidget(BlockEditor old) {
    super.didUpdateWidget(old);
    // A resize broke the lines anew: typing goes on from the new ones. Only
    // that: a keystroke or composition newer than the block stays in the field.
    final text = widget.edit.block.text;
    if (text != old.edit.block.text &&
        text != _sent &&
        _controller.text == _sent &&
        !_composing(_controller.value) &&
        sameWords(text) == sameWords(_sent)) {
      // A style that breaks the lines anew keeps the selection and its bar.
      final selection = _controller.selection;
      _sent = text;
      _controller.value = TextEditingValue(
        text: text,
        selection: selection.copyWith(
          baseOffset: selection.baseOffset.clamp(0, text.length),
          extentOffset: selection.extentOffset.clamp(0, text.length),
        ),
      );
    }
  }

  /// The new box when [handle] was dragged by [by] on the canvas (B016).
  void _resized(Offset handle, Offset by) {
    final frame = widget.edit.block.frame;
    final page = by / widget.scale;
    final next = Rect.fromLTRB(
      frame.left + (handle.dx < 0 ? page.dx : 0),
      frame.top + (handle.dy < 0 ? page.dy : 0),
      frame.right + (handle.dx > 0 ? page.dx : 0),
      frame.bottom + (handle.dy > 0 ? page.dy : 0),
    );
    if (next.width < 1 || next.height < 1) return;
    unawaited(
      _editor.resizeBlock(
        next,
        name: AppLocalizations.of(context).editStepResized(
          RegionFormat.forRegion(ref.read(regionProvider).region)
              .integer(widget.edit.page + 1),
        ),
      ),
    );
  }

  /// Esc: the input method never sees the key, so a composition is cancelled
  /// here and the editor stays; otherwise the editor closes.
  void _endEdit() {
    final value = _controller.value;
    if (!_composing(value)) {
      unawaited(_editor.finish());
      return;
    }
    _controller.value = TextEditingValue(
      text:
          value.composing.textBefore(value.text) +
          value.composing.textAfter(value.text),
      selection: TextSelection.collapsed(offset: value.composing.start),
    );
  }

  bool _composing(TextEditingValue value) =>
      value.isComposingRangeValid && !value.composing.isCollapsed;

  /// Sends the field's text once no input method composes in it.
  void _changed() {
    final value = _controller.value;
    if (!_composing(value)) _send(value.text);
  }

  void _send(String text) {
    if (text == _sent) return;
    _sent = text;
    _editor.type(text);
  }

  /// Opens or closes the bar for the selection, after the frame: the
  /// controller also changes during a build, and the bar needs the new
  /// layout.
  void _selectionChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focus.hasFocus &&
          (_barFocus.hasFocus || ref.read(documentEditorProvider).held)) {
        return;
      }
      final selection = _controller.selection;
      final selected = selection.isValid && !selection.isCollapsed;
      _barSelection = selected ? selection : null;
      final start = selected
          ? editableTextKey.currentState?.renderEditable
                    .getEndpointsForSelection(selection)
                    .first
                    .point
                    .dx ??
                0.0
          : _barStart;
      if (selected != _bar.isShowing) {
        selected ? _bar.show() : _bar.hide();
      }
      if (selected != _selected || start != _barStart) {
        setState(() {
          _selected = selected;
          _barStart = start;
        });
      }
    });
  }

  /// Esc with text selected: the selection and the bar close, and editing
  /// goes on (a3-1c).
  void _closeBar() {
    _barSelection = null;
    _focus.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.selection.extentOffset,
    );
    _selectionChanged();
  }

  /// a3-1c's Highlight and Comment: the typing commits, and what was selected
  /// is marked on the block it left. A comment's card waits in Comment mode.
  // shortcut: the selection reaches the committed block by its offsets, so text
  // reflowed by the typing can mark a little off; carry runs when the engine
  // can name them (B137).
  void _mark({required bool composing}) {
    final selection = _barSelection ?? _controller.selection;
    final edit = widget.edit;
    final frame = edit.block.frame;
    final color = markColorOf(
      design.AnnotationColor.yellow.resolve(context.ferman),
    );
    final document = ref.read(openDocumentProvider)?.id;
    if (document == null || selection.isCollapsed) {
      _barDone();
      return;
    }
    // The engine counts in code points, the field in UTF-16.
    final text = _controller.text;
    final start = text.substring(0, selection.start).runes.length;
    final end = text.substring(0, selection.end).runes.length;
    unawaited(() async {
      final editor = ref.read(documentEditorProvider.notifier);
      final commands = ref.read(commentCommandsProvider.notifier);
      final engine = ref.read(engineServiceProvider);
      final shell = ref.read(shellModeProvider.notifier);
      await editor.finish();
      final page = await engine.textBlocks(document, edit.page);
      final block = blockOver(page.blocks, frame);
      if (block == null) return;
      await commands.markBlockText(
        edit.page,
        block.id,
        start,
        end,
        color,
        composing: composing,
      );
      if (composing) shell.select(FermanMode.comment);
    }());
  }

  /// The bar is done with the focus: the field takes it, and its selection,
  /// back.
  void _barDone() {
    final selection = _barSelection;
    final length = _controller.text.length;
    if (selection != null) {
      _controller.selection = selection.copyWith(
        baseOffset: selection.baseOffset.clamp(0, length),
        extentOffset: selection.extentOffset.clamp(0, length),
      );
    }
    _focus.requestFocus();
  }

  /// A click outside the bar while it has the focus leaves the block, as
  /// one outside the field does.
  void _tappedOutsideBar(PointerDownEvent event) {
    if (_barFocus.hasFocus && !ref.read(documentEditorProvider).held) {
      unawaited(_editor.finish());
    }
  }

  /// Add link on the selection (a3-1c), by the bar's button or ⇧⌘K.
  void _addLink() {
    final selection = _barSelection;
    if (selection == null) return;
    unawaited(
      ref
          .read(linkToolProvider.notifier)
          .addFromEditor(_controller.text, selection),
    );
  }

  /// The selection's format keys and Add link, and Esc, while the bar is open
  /// (G141, G144).
  Map<ShortcutActivator, VoidCallback> _barKeys(BlockStyleInfo? info) {
    if (!_selected) return const {};
    final mac = ref.watch(shortcutPlatformProvider) == ShortcutPlatform.mac;
    void face(BlockFont? font) {
      if (font == null) return;
      restyleBlock(context, ref, BlockStyle(font: font));
    }

    return {
      const SingleActivator(LogicalKeyboardKey.escape): _closeBar,
      SingleActivator(
        LogicalKeyboardKey.keyK,
        meta: mac,
        control: !mac,
        shift: true,
      ): _addLink,
      if (info != null) ...{
        SingleActivator(
          LogicalKeyboardKey.keyB,
          meta: mac,
          control: !mac,
        ): () =>
            face(info.boldToggle),
        SingleActivator(
          LogicalKeyboardKey.keyI,
          meta: mac,
          control: !mac,
        ): () =>
            face(info.italicToggle),
      },
    };
  }

  Widget _barOverlay(BuildContext context, OverlayChildLayoutInfo layout) {
    final info = ref.watch(documentEditorProvider.select((s) => s.style));
    if (info == null) return const SizedBox.shrink();
    return CustomSingleChildLayout(
      delegate: FermanAnchoredLayout(
        anchor: FermanAnchoredLayout.anchorRect(layout).translate(_barStart, 0),
        side: AnchorSide.top,
        alignment: AnchorAlignment.leading,
        gap: FormatBar.gap,
      ),
      child: Directionality(
        textDirection: widget.uiDirection,
        child: FocusScope(
          node: _barFocus,
          // A click on the bar is no click outside the block's field.
          child: TextFieldTapRegion(
            onTapOutside: _tappedOutsideBar,
            child: FormatBar(
              info: info,
              onDone: _barDone,
              onMark: _mark,
              onAddLink: _addLink,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _barFocus
      ..removeListener(_selectionChanged)
      ..dispose();
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    _controller
      ..removeListener(_changed)
      ..removeListener(_selectionChanged)
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
    // A language picked in the panel gives the focus back for typing on.
    ref.listen(documentEditorProvider.select((s) => s.language), (old, next) {
      if (next != null && next != old) _focus.requestFocus();
    });
    // The preview changes with each text applied, so these offsets follow it.
    final marked = ref
        .watch(documentEditorProvider.select((s) => (s.preview, s.markedChars)))
        .$2;
    _controller.marks = missing?.chars ?? _marksOf(_controller.text, marked);
    _controller.markStyle = TextStyle(
      backgroundColor: theme.pageColors.glyphMissingBg,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.wavy,
      decorationColor: theme.pageColors.glyphMissing,
      decorationThickness: PageMark.missingGlyphThickness,
    );
    final rtl = block.direction == BlockDirection.rightToLeft;
    // The frame's bottom inside the field's box.
    final bottom = frame.height + TextEditBox.marginY - TextEditBox.paddingY;
    var field = _gestures.buildGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: _DeltaEditableText(
        key: editableTextKey,
        rendererIgnoresPointer: true,
        controller: _controller,
        focusNode: _focus,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: switch (block.alignment) {
          BlockAlignment.left => rtl ? TextAlign.end : TextAlign.start,
          BlockAlignment.right => rtl ? TextAlign.start : TextAlign.end,
          BlockAlignment.center => TextAlign.center,
          BlockAlignment.justified => TextAlign.justify,
        },
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
        cursorHeight: fontSize * TextCaret.heightEm,
        backgroundCursorColor: theme.colors.borderSubtle,
        selectionColor: theme.pageColors.editSelection,
        onTapOutside: _tappedOutside,
      ),
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
    // The field hides the page's text under it, so it carries the editing
    // tint itself; a dimmed page (Settings › General) dims it too.
    Widget paper = ColoredBox(
      color: Color.alphaBlend(TextEditBox.editingTint, theme.pageColors.pageBg),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: height,
        ),
        child: CallbackShortcuts(
          bindings: _barKeys(
            ref.watch(documentEditorProvider.select((s) => s.style)),
          ),
          child: OverlayPortal.overlayChildLayoutBuilder(
            controller: _bar,
            overlayChildBuilder: _barOverlay,
            child: field,
          ),
        ),
      ),
    );
    final dim = theme.pageColorFilter;
    if (dim != null) paper = ColorFiltered(colorFilter: dim, child: paper);
    // f1: the label starts at the block's start edge, the right in a
    // right-to-left block, whatever the canvas's direction.
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: TextEditBox(
        meta: missing?.font,
        metaWarning: missing != null,
        metaPlacement: widget.metaPlacement,
        onStateChanged: (_) => _endEdit(),
        onHandleDragged: _resized,
        child: paper,
      ),
    );
  }

  /// A click outside the field leaves it, unless it is on the frame's
  /// handles, which reach past this widget's own box.
  void _tappedOutside(PointerDownEvent event) {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      final frame = (box.localToGlobal(Offset.zero) & box.size).inflate(
        TextEditBox.marginX + TextEditBox.handleOffset,
      );
      if (frame.contains(event.position)) return;
    }
    _focus.unfocus();
  }
}

/// Each character of [marked] in [text], at its offset in UTF-16 code units.
List<MissingChar> _marksOf(String text, String marked) {
  if (marked.isEmpty) return const [];
  final marks = <MissingChar>[];
  var at = 0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (marked.contains(char)) marks.add(MissingChar(text: char, at: at));
    at += char.length;
  }
  return marks;
}

/// The first free side for the label of the block framed at [frame] (f1):
/// above, then below, else the margin. A side is free when the [room] the
/// label and its gaps take past the frame's outer edge stays on [page] and
/// meets none of [others]. All in canvas coordinates; the editor asks on
/// every build, so the answer follows the frame as it moves or grows.
// shortcut: [others] are the page's text blocks and tinted cells; the engine
// names no images or vector marks yet, so a label may touch one (upgrade when
// `PageBlocks` lists them).
MetaPlacement metaPlacementFor({
  required Rect frame,
  required Rect page,
  required Iterable<Rect> others,
  required double room,
}) {
  final left = frame.left - TextEditBox.marginX;
  final right = frame.right + TextEditBox.marginX;
  final top = frame.top - TextEditBox.marginY;
  final bottom = frame.bottom + TextEditBox.marginY;
  bool free(Rect side) =>
      side.top >= page.top &&
      side.bottom <= page.bottom &&
      !others.any(side.overlaps);
  if (free(Rect.fromLTRB(left, top - room, right, top))) {
    return MetaPlacement.above;
  }
  if (free(Rect.fromLTRB(left, bottom, right, bottom + room))) {
    return MetaPlacement.below;
  }
  return MetaPlacement.margin;
}

/// An [EditableText] whose input connection speaks the delta model, the rest
/// of it as is.
class _DeltaEditableText extends EditableText {
  new({
    required super.controller,
    required super.focusNode,
    required super.style,
    required super.cursorColor,
    required super.backgroundCursorColor,
    super.key,
    super.rendererIgnoresPointer,
    super.textAlign,
    super.cursorHeight,
    super.onTapOutside,
    super.maxLines,
    super.keyboardType,
    super.textDirection,
    super.strutStyle,
    super.cursorWidth,
    super.selectionColor,
  });

  // flutter_test's enterText and find.byType match the exact EditableText.
  @override
  Type get runtimeType => EditableText;

  @override
  EditableTextState createState() => _DeltaEditableTextState();
}

class _DeltaEditableTextState extends EditableTextState
    implements DeltaTextInputClient {
  @override
  TextInputConfiguration get textInputConfiguration =>
      super.textInputConfiguration.copyWith(enableDeltaModel: true);

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    // A delta is relative to the platform's text, which is the truth when a
    // change from here has not reached it yet.
    updateEditingValue(
      deltas.fold(
        currentTextEditingValue,
        (value, delta) => delta.apply(
          value.text == delta.oldText
              ? value
              : TextEditingValue(text: delta.oldText),
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
