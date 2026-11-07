import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_overlay.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/editor/block_editor.dart';
import 'package:ferman/features/editor/edit_callouts.dart';
import 'package:ferman/features/editor/edit_marks.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/link_popover.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/forms/fill_anything.dart';
import 'package:ferman/features/forms/form_overlay.dart';
import 'package:ferman/features/forms/form_state.dart';
import 'package:ferman/features/stamps/mark_placement_overlay.dart';
import 'package:ferman/features/viewer/find_state.dart';
import 'package:ferman/features/viewer/not_editable.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/features/viewer/viewer_layout.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pages of the open document on the canvas (a2-1a to a2-1d, a2-13,
/// a2-15), drawn from the engine's tiles through one engine view.
///
/// Each frame whose wanted set changes sends it with a new generation:
/// the tiles in view at the zoom's bucket, nearest the centre first, the
/// tiles half a window beyond, and each page's preview thumbnail. A page
/// shows its thumbnail and any tiles of other buckets, scaled, until its
/// sharp tiles arrive, so it sharpens in place without moving (G30). A
/// page that fails to render shows a2-13's placeholder with Try again; the
/// other pages keep working. When layers show or hide, every bitmap goes
/// stale and is asked for again; each stays until its new one arrives.
///
/// The wheel scrolls, and zooms with ⌘ or Ctrl; a trackpad scrolls and
/// pinches. With [tools] the View row's pointer tools apply: Hand drags
/// the pages, Marquee zoom drags a rectangle to zoom into (a2-2), and
/// Select selects text by dragging over its blocks (B106): the selection
/// shows highlighted and the context menu's Copy copies it, as ⌘C or
/// Ctrl+C on the canvas does (`canvasSelectionProvider`).
///
/// With [edit] (Edit mode) only the block under the pointer shows its
/// dashed frame, with the I-beam and "Click to edit · …" (a3-1a); text
/// that cannot be edited shows the not-allowed cursor and its reason, and
/// the Edit panel its callout (a3-19, `editCalloutProvider`). A click on
/// an editable block opens its inline editor ([BlockEditor], a3-1b) with
/// the caret where the engine puts it (`documentEditorProvider`); a click
/// anywhere else commits and closes it. After each commit, undo or redo
/// every page is drawn again and its blocks asked for again.
/// The pages' blocks come from the engine as the pointer reaches them,
/// and their frames are hit-tested here (ARCHITECTURE §3.5).
///
/// It sits inside the canvas's left-to-right [Directionality]: pages never
/// mirror (ADR 0014).
class DocumentView extends ConsumerStatefulWidget {
  /// The pages of `viewerProvider`'s document.
  const new({
    required this.uiDirection,
    super.key,
    this.tools = true,
    this.edit = false,
    this.comment = false,
    this.fill = false,
  });

  /// The UI's direction, for the copy on a failed page.
  final TextDirection uiDirection;

  /// Whether the View row's pointer tools apply (View mode).
  final bool tools;

  /// Whether Edit mode's hover frames apply.
  final bool edit;

  /// Whether Comment mode's layer applies (a4-1, [CommentOverlay]); its text
  /// tools mark what the Select tool's dragging selects.
  final bool comment;

  /// Whether Fill & Sign's layers apply: the form's fields ([FormOverlay],
  /// a5-1) or Fill anything's ([FillAnythingOverlay], a5-4).
  final bool fill;

  /// How far outside a block's frame, in points, the pointer still finds
  /// it.
  static const double blockSlack = 2;

  /// How many characters of a block's first line its hover tooltip names.
  static const int tipChars = 24;

  /// How far a press may move and still be a click on a link.
  static const double clickSlop = 4;

  /// The height a3-6's popover needs under a link, or it opens over it.
  static const double linkPopoverRoom = 290;

  /// The decoded bitmaps kept, in bytes.
  static const int cacheBytes = 256 << 20;

  @override
  ConsumerState<DocumentView> createState() => _DocumentViewState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty('uiDirection', uiDirection))
      ..add(FlagProperty('tools', value: tools, ifFalse: 'no tools'))
      ..add(FlagProperty('edit', value: edit, ifTrue: 'edit'))
      ..add(FlagProperty('comment', value: comment, ifTrue: 'comment'))
      ..add(FlagProperty('fill', value: fill, ifTrue: 'fill'));
  }
}

class _DocumentViewState extends ConsumerState<DocumentView> {
  late final EngineService _engine = ref.read(engineServiceProvider);
  EngineView? _view;
  StreamSubscription<ViewUpdate>? _updates;

  /// Decoded bitmaps, oldest first.
  final Map<RenderItem, ui.Image> _images = {};
  int _bytes = 0;

  /// Bitmaps drawn before their page last changed, and the render key each
  /// page must have now.
  final Set<RenderItem> _stale = {};
  final CurrentKeys _keys = CurrentKeys();

  /// Pages that failed to render, until Try again.
  final Set<int> _failed = {};

  /// Whether the view itself could not open: every page shows the
  /// placeholder.
  bool _viewFailed = false;

  int _generation = 0;
  List<WantedItem> _wanted = const [];
  bool _requestScheduled = false;

  /// The trackpad pinch's scale so far.
  double _pinch = 1;

  /// A marquee's corners on the canvas while it is drawn.
  Offset? _marqueeStart;
  Offset? _marqueeEnd;

  /// Whether the Hand tool is dragging.
  bool _grabbing = false;

  /// Each page's text blocks once the engine sent them, and the pages
  /// asked for.
  final Map<int, PageBlocks> _blocks = {};
  final Set<int> _asked = {};

  /// What the pointer is over: a page, the block there, and where.
  _Target? _hover;

  /// Whether Alt (Option) is held: every editable block shows its frame
  /// (a3-1a).
  bool _revealing = false;

  /// The inline editor's key, new for each block edited, and its edit.
  GlobalKey _editorKey = GlobalKey();

  /// The text box of [CommentOverlay]'s draft.
  final GlobalKey _commentDraftKey = GlobalKey();
  final GlobalKey _linkPopover = GlobalKey();

  /// Where a press that may be a click on a link began.
  Offset? _press;
  ActiveEdit? _keyed;

  /// Where a text selection started: its page and position.
  (int, BlockPosition)? _anchor;

  /// Whether the primary button is down with the Select tool.
  bool _selecting = false;

  /// Counts the selection's requests, so an older reply never wins.
  int _selectRequest = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _keys.raise(ref.read(layerVisibilityProvider)?.renderKey ?? 0);
    ref.listenManual(layerVisibilityProvider.select((s) => s?.renderKey ?? 0), (
      _,
      key,
    ) {
      _keys.raise(key);
      _stale.addAll(_images.keys);
      _request(force: true);
    });
    // Show comments: every page is drawn again (a4-5).
    _keys.raise(ref.read(commentsShownProvider).renderKey);
    ref.listenManual(commentsShownProvider.select((s) => s.renderKey), (
      _,
      key,
    ) {
      _keys.raise(key);
      _stale.addAll(_images.keys);
      _request(force: true);
    });
    // A commit, undo or redo changed the pages: draw them and read their
    // text again.
    ref.listenManual(documentEditorProvider.select((s) => s.renderKey), (
      _,
      key,
    ) {
      if (key == null) return;
      final pages = ref.read(documentEditorProvider).changedPages;
      _keys.raise(key, pages: pages);
      _stale.addAll(
        _images.keys.where(
          (item) => pages == null || pages.contains(item.page),
        ),
      );
      _blocks.clear();
      _asked.clear();
      // Every page changed, and they may have moved: what is kept by page
      // number names another page now.
      if (pages == null) {
        setState(_failed.clear);
        _clearText();
      }
      _request(force: true);
    });
    // The owner password lifts Restricted: ask the engine for the blocks
    // again.
    ref.listenManual(
      openDocumentProvider.select((d) => d?.security?.restricted),
      (_, _) {
        _blocks.clear();
        _asked.clear();
        ref.read(editCalloutProvider.notifier).show(null);
        if (_hover case _Target(:final local)) _hoverAt(_targetAt(local));
      },
    );
    SemanticsBinding.instance.addSemanticsEnabledListener(_semanticsChanged);
    unawaited(_open());
  }

  void _semanticsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(DocumentView old) {
    super.didUpdateWidget(old);
    if (old.edit != widget.edit ||
        old.tools != widget.tools ||
        old.comment != widget.comment ||
        old.fill != widget.fill) {
      _clearText();
    }
    // Leaving Edit mode commits the typing (the coalescing rule).
    if (old.edit && !widget.edit) {
      unawaited(ref.read(documentEditorProvider.notifier).finish());
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    SemanticsBinding.instance.removeSemanticsEnabledListener(_semanticsChanged);
    ContextMenuController.removeAny();
    unawaited(_updates?.cancel());
    final view = _view;
    if (view != null) {
      // The document may be closed already, which closed the view.
      unawaited(_engine.closeView(view.id).catchError((Object _) {}));
    }
    for (final image in _images.values) {
      image.dispose();
    }
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final alt = HardwareKeyboard.instance.isAltPressed;
    if (alt != _revealing) setState(() => _revealing = alt);
    return false;
  }

  Future<void> _open() async {
    final document = ref.read(viewerProvider)?.document;
    if (document == null) return;
    try {
      final view = await _engine.openView(document.id);
      if (!mounted) {
        unawaited(_engine.closeView(view.id).catchError((Object _) {}));
        return;
      }
      _view = view;
      _updates = view.updates.listen(_receive);
      setState(() => _viewFailed = false);
      _request(force: true);
    } on Object {
      if (mounted) setState(() => _viewFailed = true);
    }
  }

  void _receive(ViewUpdate update) {
    switch (update) {
      case FailedItem(:final item):
        setState(() => _failed.add(item.page));
      // A bitmap from before its page last changed is not shown again.
      case RenderedItem(:final item, :final renderKey)
          when _keys.isCurrent(item.page, renderKey):
        ui.decodeImageFromPixels(
          update.pixels,
          update.width,
          update.height,
          ui.PixelFormat.bgra8888,
          (image) {
            if (!mounted) {
              image.dispose();
              return;
            }
            setState(() {
              final old = _images.remove(item);
              if (old != null) {
                _bytes -= _sizeOf(old);
                old.dispose();
              }
              _images[item] = image;
              _bytes += _sizeOf(image);
              // The page may have changed while it decoded.
              if (!_keys.isCurrent(item.page, renderKey)) {
                _stale.add(item);
              } else {
                _stale.remove(item);
              }
              _evict();
            });
          },
          rowBytes: update.stride,
        );
      case RenderedItem():
      // From before its page last changed: asked for again already.
    }
  }

  static int _sizeOf(ui.Image image) => image.width * image.height * 4;

  /// Drops the oldest bitmaps nobody wants while the cache is over budget.
  void _evict() {
    if (_bytes <= DocumentView.cacheBytes) return;
    final wanted = {for (final entry in _wanted) entry.item};
    for (final item in _images.keys.toList()) {
      if (_bytes <= DocumentView.cacheBytes) break;
      if (wanted.contains(item)) continue;
      final image = _images.remove(item);
      if (image == null) continue;
      _stale.remove(item);
      _bytes -= _sizeOf(image);
      image.dispose();
    }
  }

  /// Sends the wanted set after this frame when it changed.
  void _scheduleRequest() {
    if (_requestScheduled) return;
    _requestScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestScheduled = false;
      if (mounted) _request();
    });
  }

  void _request({bool force = false}) {
    final view = _view;
    final state = ref.read(viewerProvider);
    if (view == null || state == null || state.viewport.isEmpty) return;
    final visible = state.visible;
    final wanted = wantedItems(
      placement: state.placement,
      pages: state.pageSizes,
      scale: state.scale,
      ratio: engineRatio(MediaQuery.devicePixelRatioOf(context)),
      visible: visible,
      prefetch: visible.inflate(state.viewport.shortestSide / 2),
    )..removeWhere((entry) => _failed.contains(entry.item.page));
    if (!force && _same(wanted, _wanted)) return;
    _wanted = wanted;
    // Bitmaps already here are not asked for again, unless stale.
    final missing = [
      for (final entry in wanted)
        if (!_images.containsKey(entry.item) || _stale.contains(entry.item))
          entry,
    ];
    unawaited(
      _engine
          .requestView(view.id, ++_generation, missing)
          .catchError((Object _) {}),
    );
  }

  static bool _same(List<WantedItem> a, List<WantedItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].item != b[i].item || a[i].priority != b[i].priority) {
        return false;
      }
    }
    return true;
  }

  void _retry(int page) {
    if (_viewFailed) {
      setState(() => _viewFailed = false);
      unawaited(_open());
      return;
    }
    setState(() => _failed.remove(page));
    _request(force: true);
  }

  // Pointer input.

  Viewer get _viewer => ref.read(viewerProvider.notifier);

  ViewerTool get _tool => widget.tools
      ? (ref.read(viewerProvider)?.tool ?? ViewerTool.select)
      : ViewerTool.select;

  static bool get _zoomKey =>
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isControlPressed;

  void _signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      if (_zoomKey) {
        _viewer.zoomBy(
          math.pow(2, -scroll.scrollDelta.dy / 240).toDouble(),
          scroll.localPosition,
        );
      } else {
        _viewer.scrollBy(scroll.scrollDelta);
      }
    });
  }

  void _panZoom(PointerPanZoomUpdateEvent event) {
    if (_zoomKey) {
      _viewer.zoomBy(
        math.pow(2, event.panDelta.dy / 240).toDouble(),
        event.localPosition,
      );
      return;
    }
    _viewer.scrollBy(-event.panDelta);
    final factor = event.scale / _pinch;
    _pinch = event.scale;
    if (factor != 1) _viewer.zoomBy(factor, event.localPosition);
  }

  void _down(PointerDownEvent event) {
    // A click in the open editor, or in a comment's text being typed, is the
    // text field's.
    if (widget.edit && _inEditor(event.position)) return;
    if (widget.comment && _inCommentDraft(event.position)) return;
    if (_inLinkPopover(event.position)) return;
    // Fill & Sign's layers have the pointer and give focus themselves, so a
    // click in a field never takes it from the field's own editor.
    if (widget.fill) {
      ContextMenuController.removeAny();
      return;
    }
    Focus.maybeOf(context)?.requestFocus();
    // Comment mode's layer, nearer the pointer, has just opened its own menu.
    if (!widget.comment || event.buttons != kSecondaryMouseButton) {
      ContextMenuController.removeAny();
    }
    // A click follows a link, or marks it with the Link tool (a3-6); in Comment
    // mode a click is the comment tools'.
    _press =
        event.buttons == kPrimaryButton &&
            (_linkTool ||
                (!widget.edit &&
                    !widget.comment &&
                    !widget.fill &&
                    _tool != ViewerTool.marquee))
        ? event.localPosition
        : null;
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event.buttons == kSecondaryMouseButton) {
      if (_selectsText) _showMenu(event.position);
      return;
    }
    if (event.buttons != kPrimaryMouseButton) return;
    if (_linkTool) {
      ref.read(linkToolProvider.notifier).mark(null);
      _selecting = true;
      unawaited(_startSelection(_targetAt(event.localPosition)));
      return;
    }
    if (widget.edit) {
      unawaited(_openEditor(_targetAt(event.localPosition)));
      return;
    }
    // Comment mode's layer has the pointer, but for text marks.
    if (widget.comment && !_marking) return;
    switch (_tool) {
      case ViewerTool.hand:
        setState(() => _grabbing = true);
      case ViewerTool.marquee:
        setState(() => _marqueeStart = _marqueeEnd = event.localPosition);
      case ViewerTool.select:
        _selecting = true;
        unawaited(_startSelection(_targetAt(event.localPosition)));
    }
  }

  void _move(PointerMoveEvent event) {
    if (_grabbing) {
      _viewer.scrollBy(-event.delta);
    } else if (_marqueeStart != null) {
      setState(() => _marqueeEnd = event.localPosition);
    } else if (_selecting) {
      final target = _targetAt(event.localPosition);
      _hoverAt(target);
      unawaited(_extendSelection(target));
    }
  }

  void _up(PointerEvent event) {
    final press = _press;
    _press = null;
    if (press != null &&
        event is PointerUpEvent &&
        (event.localPosition - press).distance <= DocumentView.clickSlop) {
      unawaited(_clickedLink(press));
    }
    final start = _marqueeStart;
    final end = _marqueeEnd;
    if (start != null && end != null && event is PointerUpEvent) {
      _viewer.zoomToRect(Rect.fromPoints(start, end));
    }
    if (_selecting && _marking && event is PointerUpEvent) {
      unawaited(_finishMark(event.localPosition));
    }
    _selecting = false;
    setState(() {
      _grabbing = false;
      _marqueeStart = _marqueeEnd = null;
    });
  }

  /// A click at [local]: follows the link there, or marks it with the Link
  /// tool. The engine says which link it is.
  Future<void> _clickedLink(Offset local) async {
    final target = _targetAt(local);
    final document = ref.read(viewerProvider)?.document;
    if (target == null || document == null) return;
    final LinkInfo? link;
    try {
      link = await _engine.linkAt(
        document.id,
        document.pageHandle(target.page),
        target.point,
      );
    } on EngineException {
      return;
    }
    if (!mounted || link == null) return;
    final tool = ref.read(linkToolProvider.notifier);
    _linkTool ? tool.mark(link.handle) : tool.follow(link);
  }

  /// Whether the Link tool is on.
  bool get _linkTool => widget.edit && ref.read(linkToolProvider).on;

  /// Whether [position] (global) is over the Link tool's popover.
  bool _inLinkPopover(Offset position) {
    final box = _linkPopover.currentContext?.findRenderObject();
    return box is RenderBox &&
        box.hasSize &&
        (Offset.zero & box.size).contains(box.globalToLocal(position));
  }

  // Text: blocks, hover, caret and selection.

  /// Whether the pointer selects text: View mode with Select chosen, the Link
  /// tool, or Comment mode with a text mark's tool.
  bool get _selectsText =>
      _linkTool || (widget.tools && _tool == ViewerTool.select) || _marking;

  /// Whether the pointer selects text to mark (a4-1).
  bool get _marking =>
      widget.comment &&
      ref.read(commentToolProvider).marksText &&
      ref.read(commentsShownProvider).visible &&
      ref.read(commentRefusalProvider) == null;

  /// The drag ended: what it selected becomes the tool's mark.
  Future<void> _finishMark(Offset local) async {
    final tools = ref.read(commentToolProvider);
    final color = markColorOf(tools.color.resolve(context.ferman));
    await _extendSelection(_targetAt(local));
    if (!mounted) return;
    final selection = ref.read(canvasSelectionProvider);
    final kind = textMarkKind(tools.tool);
    if (selection == null || kind == null) return;
    ref.read(canvasSelectionProvider.notifier).select(null);
    await ref
        .read(commentCommandsProvider.notifier)
        .markText(kind, selection, color);
  }

  /// The page, its block and the point in page space under [local], a
  /// position on the canvas; null off the pages.
  _Target? _targetAt(Offset local) {
    final state = ref.read(viewerProvider);
    if (state == null) return null;
    final onCanvas = local + state.offset;
    for (final (page, rect) in state.placement.rects.indexed) {
      if (rect == null || !rect.contains(onCanvas)) continue;
      final point = (onCanvas - rect.topLeft) / state.scale;
      final blocks = _blocksOf(page);
      final block = blocks?.blocks
          .where(
            (block) =>
                block.frame.inflate(DocumentView.blockSlack).contains(point),
          )
          .firstOrNull;
      return _Target(
        page: page,
        point: point,
        local: local,
        block: block,
        empty: blocks?.empty,
      );
    }
    return null;
  }

  /// [page]'s blocks, asking the engine for them the first time; null
  /// until they arrive. A page whose text cannot be read has none.
  PageBlocks? _blocksOf(int page) {
    final known = _blocks[page];
    if (known != null || !_asked.add(page)) return known;
    final document = ref.read(viewerProvider)?.document.id;
    if (document == null) return null;
    unawaited(
      _engine
          .textBlocks(document, page)
          .catchError((Object _) => const PageBlocks())
          .then((blocks) {
            if (!mounted) return;
            setState(() => _blocks[page] = blocks);
            // The pointer may be waiting over the page for them.
            if (_hover case _Target(page: final over, :final local)
                when over == page) {
              _hoverAt(_targetAt(local));
            }
          }),
    );
    return null;
  }

  void _hoverAt(_Target? target) {
    if (!widget.edit && !_selectsText) {
      if (_hover != null) setState(() => _hover = null);
      return;
    }
    setState(() => _hover = target);
    if (!widget.edit || _linkTool || target == null) return;
    // Pointing at empty space keeps the last callout, so the pointer can go
    // over to the panel to read it.
    final reason = target.block != null
        ? target.block!.notEditable
        : target.empty;
    if (target.block != null || reason != null) {
      ref.read(editCalloutProvider.notifier).show(reason);
    }
  }

  /// Whether [position] (global) is over the open inline editor.
  bool _inEditor(Offset position) {
    final box = _editorKey.currentContext?.findRenderObject();
    return box is RenderBox &&
        box.hasSize &&
        (Offset.zero & box.size)
            .inflate(TextEditBox.marginX + TextEditBox.handleOffset)
            .contains(box.globalToLocal(position));
  }

  /// Whether [position] (global) is over a comment's text being typed.
  bool _inCommentDraft(Offset position) {
    final box = _commentDraftKey.currentContext?.findRenderObject();
    return box is RenderBox &&
        box.hasSize &&
        (Offset.zero & box.size).contains(box.globalToLocal(position));
  }

  /// Opens the inline editor on [target]'s block with the engine's caret
  /// there; off an editable block, commits and closes the open one.
  Future<void> _openEditor(_Target? target) async {
    final editor = ref.read(documentEditorProvider.notifier);
    final block = target?.block;
    final document = ref.read(viewerProvider)?.document.id;
    if (target == null ||
        block == null ||
        block.notEditable != null ||
        document == null) {
      await editor.finish();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.read(regionProvider).region);
    final name = l10n.editStepText(format.integer(target.page + 1));
    var caret = 0;
    try {
      caret = (await _engine.caretAt(
        document,
        target.page,
        block.id,
        target.point,
      )).index;
    } on Object {
      // The caret starts at the block's start.
    }
    if (!mounted) return;
    await editor.open(target.page, block, caret: caret, name: name);
  }

  Future<void> _startSelection(_Target? target) async {
    _anchor = null;
    _selectRequest++;
    setState(() {});
    ref.read(canvasSelectionProvider.notifier).select(null);
    final block = target?.block;
    final document = ref.read(viewerProvider)?.document.id;
    if (target == null || block == null || document == null) return;
    try {
      final caret = await _engine.caretAt(
        document,
        target.page,
        block.id,
        target.point,
      );
      if (!mounted || !_selecting) return;
      _anchor = (
        target.page,
        BlockPosition(block: block.id, index: caret.index),
      );
    } on Object {
      // A block the engine no longer has selects nothing.
    }
  }

  /// Extends the selection to [target] on the anchor's page.
  // shortcut: a selection stays on the page it started on; select across
  // pages when someone needs it.
  Future<void> _extendSelection(_Target? target) async {
    final anchor = _anchor;
    final block = target?.block;
    final document = ref.read(viewerProvider)?.document.id;
    if (anchor == null ||
        target == null ||
        block == null ||
        target.page != anchor.$1 ||
        document == null) {
      return;
    }
    final request = ++_selectRequest;
    try {
      final caret = await _engine.caretAt(
        document,
        target.page,
        block.id,
        target.point,
      );
      final selection = await _engine.selection(
        document,
        target.page,
        anchor.$2,
        BlockPosition(block: block.id, index: caret.index),
      );
      if (!mounted || request != _selectRequest) return;
      ref
          .read(canvasSelectionProvider.notifier)
          .select(
            PageSelection(
              page: target.page,
              quads: selection.quads,
              text: selection.text,
              language: block.language,
            ),
          );
    } on Object {
      // Keeps the last selection.
    }
  }

  void _clearText() {
    _anchor = null;
    _selecting = false;
    _selectRequest++;
    _hover = null;
    ContextMenuController.removeAny();
    // Riverpod forbids changing a provider while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(canvasSelectionProvider.notifier).select(null);
    });
  }

  final ContextMenuController _menu = ContextMenuController();

  /// The Select tool's context menu at [position] (global): Copy, enabled
  /// with a selection.
  void _showMenu(Offset position) {
    final selection = ref.read(canvasSelectionProvider);
    final l10n = AppLocalizations.of(context);
    final mac =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    _menu.show(
      context: context,
      contextMenuBuilder: (context) => CustomSingleChildLayout(
        delegate: DesktopTextSelectionToolbarLayoutDelegate(anchor: position),
        child: Directionality(
          textDirection: widget.uiDirection,
          child: Menu(
            semanticLabel: l10n.viewerTextMenu,
            autofocus: true,
            items: [
              MenuItem(
                id: 'copy',
                label: l10n.fieldCopy,
                shortcut: [if (mac) '⌘' else 'Ctrl', 'C'],
                disabled: selection == null,
              ),
            ],
            onClose: ContextMenuController.removeAny,
            onSelected: (_) {
              ContextMenuController.removeAny();
              copySelection(ref.read(canvasSelectionProvider));
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final state = ref.watch(viewerProvider);
    final find = ref.watch(findProvider);
    if (state == null) return const SizedBox.shrink();
    _scheduleRequest();
    final hover = _hover;
    final hoverReason = hover?.block != null
        ? hover!.block!.notEditable
        : hover?.empty;
    final linkTool = ref.watch(linkToolProvider);
    final linkOn = widget.edit && linkTool.on;
    final commentTools = ref.watch(commentToolProvider);
    final fillTool = widget.fill
        ? ref
              .watch(fillToolsStateProvider)
              .effective(ref.watch(documentFormProvider).value)
        : null;
    final placing =
        widget.comment &&
        commentTools.tool.hasMenu &&
        ref.watch(commentsShownProvider).visible &&
        ref.watch(commentRefusalProvider) == null;
    final overLink = switch (hover) {
      final over? when _selectsText =>
        linkOver(
              ref.watch(documentLinksProvider).value?.links ?? const [],
              state.document.pageHandle(over.page),
              over.point,
            ) !=
            null,
      _ => false,
    };
    final cursor = overLink
        ? SystemMouseCursors.click
        : linkOn
        ? hover?.block != null
              ? SystemMouseCursors.text
              : MouseCursor.defer
        : widget.edit
        ? hover?.block != null && hoverReason == null
              ? SystemMouseCursors.text
              : hover != null && hoverReason != null
              ? SystemMouseCursors.forbidden
              : MouseCursor.defer
        : switch (_tool) {
            ViewerTool.hand =>
              _grabbing ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
            ViewerTool.marquee => SystemMouseCursors.precise,
            ViewerTool.select when _selectsText && hover?.block != null =>
              SystemMouseCursors.text,
            ViewerTool.select => MouseCursor.defer,
          };
    final selection = ref.watch(canvasSelectionProvider);
    final start = _marqueeStart;
    final end = _marqueeEnd;
    final marquee = start == null || end == null
        ? null
        : Rect.fromPoints(start, end);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        if (viewport != state.viewport) {
          // Resizing changes a fitted zoom: after this build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _viewer.resize(viewport);
          });
        }
        return Listener(
          onPointerSignal: _signal,
          onPointerPanZoomStart: (_) => _pinch = 1,
          onPointerPanZoomUpdate: _panZoom,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: MouseRegion(
            cursor: cursor,
            onHover: (event) => _hoverAt(_targetAt(event.localPosition)),
            onExit: (_) {
              if (_hover != null) setState(() => _hover = null);
            },
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PagesPainter(
                        state: state,
                        images: _images,
                        failed: _viewFailed ? null : _failed,
                        page: BoxDecoration(
                          color: theme.pageColors.pageBg,
                          boxShadow: theme.elevation.shadowPage,
                        ),
                        filter: theme.pageColorFilter,
                        marquee: marquee,
                        marqueeColor: theme.colors.borderFocus,
                        marqueeFill: theme.colors.accentSubtle,
                        matches: find.open ? find.matches : const [],
                        current: find.currentMatch,
                        matchColor: theme.pageColors.searchMatch,
                        currentColor: theme.pageColors.searchCurrent,
                        currentBorder: theme.pageColors.searchCurrentBorder,
                        selection: selection,
                        selectionColor: theme.pageColors.editSelection,
                      ),
                    ),
                  ),
                  for (final (page, rect) in state.placement.rects.indexed)
                    if (rect != null &&
                        rect.overlaps(state.visible) &&
                        (_viewFailed || _failed.contains(page)))
                      PositionedDirectional(
                        start: rect.left - state.offset.dx,
                        top: rect.top - state.offset.dy,
                        width: rect.width,
                        height: rect.height,
                        child: Directionality(
                          textDirection: widget.uiDirection,
                          child: _FailedPage(
                            page: page,
                            onRetry: () => _retry(page),
                          ),
                        ),
                      ),
                  if (linkOn)
                    ..._linkLayer(context, state, linkTool)
                  else if (widget.edit)
                    ..._editLayer(context, state),
                  if (widget.comment)
                    Positioned.fill(
                      child: CommentOverlay(
                        view: state,
                        uiDirection: widget.uiDirection,
                        draftKey: _commentDraftKey,
                      ),
                    ),
                  if (widget.fill)
                    Positioned.fill(
                      child: fillTool == FillTool.fields
                          ? FormOverlay(
                              view: state,
                              uiDirection: widget.uiDirection,
                            )
                          : FillAnythingOverlay(view: state),
                    ),
                  // Shapes and stamps, inside the Listener so the wheel still
                  // scrolls. shortcut: with Keep tool selected it covers the
                  // style bar of the mark just placed, until Esc; upgrade if
                  // anyone styles marks in a row.
                  if (placing)
                    Positioned.fill(
                      child: MarkPlacementOverlay(
                        tool: commentTools.tool,
                        color: commentTools.color,
                        onFinished: () => ref
                            .read(commentToolProvider.notifier)
                            .pick(AnnotationTool.select),
                      ),
                    ),
                  if (marquee != null &&
                      marquee.longestSide >= Viewer.marqueeMinimum)
                    PositionedDirectional(
                      start: marquee.right + theme.space.space2,
                      top: marquee.bottom + theme.space.space2,
                      child: _MarqueeLabel(zoom: state.marqueeZoom(marquee)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The box [box] of [page] (page space) on the canvas, or null when the
  /// page is not placed.
  Rect? _onCanvas(ViewerState state, int page, Rect box) {
    final rect = state.placement.rects.elementAtOrNull(page);
    if (rect == null) return null;
    return Rect.fromLTRB(
      rect.left + box.left * state.scale,
      rect.top + box.top * state.scale,
      rect.left + box.right * state.scale,
      rect.top + box.bottom * state.scale,
    ).shift(-state.offset);
  }

  /// The marks of the lines the steps that apply changed (f3), on the pages
  /// in view.
  List<EditMark> _editMarks(ViewerState state, EditorState editor) {
    final size = context.ferman.size;
    return [
      for (final edited in editor.edited)
        if (state.placement.rects.elementAtOrNull(edited.page) case final rect?
            when rect.overlaps(state.visible))
          if (blockOver(
                _blocksOf(edited.page)?.blocks ?? const <TextBlock>[],
                edited.frame,
              )
              case final block?)
            if (_onCanvas(state, edited.page, block.frame) case final frame?)
              for (final line in changedLines(edited.before, block.lines))
                if (_onCanvas(state, edited.page, line.bbox) case final box?)
                  editMark(
                    line: box,
                    frame: frame,
                    baseline:
                        rect.topLeft +
                        line.baselineStart * state.scale -
                        state.offset,
                    direction: block.direction,
                    barGap: size.editMarkBarGap,
                    barWidth: size.editMarkBarW,
                  ),
    ];
  }

  /// The Link tool's faint outlines, the marked one solid, and the Edit link
  /// popover by it (a3-6), in the UI's direction, inside the canvas.
  List<Widget> _linkLayer(
    BuildContext context,
    ViewerState state,
    LinkToolState tool,
  ) {
    final theme = context.ferman;
    final colors = theme.pageColors;
    final viewport = state.viewport;
    final gap = theme.space.space2;
    final links = ref.watch(documentLinksProvider).value?.links ?? const [];
    final refusal = ref.watch(linkRefusalProvider);
    Rect? box(int handle, Rect rect) =>
        switch (state.document.pageIndexOf(handle)) {
          final index? => _onCanvas(state, index, rect),
          null => null,
        };
    final draft = tool.draft;
    final marked = links.where((link) => link.handle == tool.selected);
    final anchor = draft != null
        ? box(draft.page, draft.rect)
        : marked.isEmpty
        ? null
        : box(marked.first.page, marked.first.rect);
    final width = math.min(LinkPopover.width, viewport.width - 2 * gap);
    // Under the link, or over it when the popover would not fit.
    final over =
        anchor != null &&
        anchor.bottom + DocumentView.linkPopoverRoom > viewport.height;
    return [
      for (final link in links)
        if (box(link.page, link.rect) case final at?
            when at.overlaps(Offset.zero & viewport))
          PositionedDirectional(
            start: at.left,
            top: at.top,
            width: at.width,
            height: at.height,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: link.handle == tool.selected
                        ? colors.editBox
                        : colors.editBoxHover,
                    width: link.handle == tool.selected
                        ? theme.border.borderWidthStrong
                        : theme.border.borderWidth,
                  ),
                ),
              ),
            ),
          ),
      if (anchor != null && refusal == null)
        PositionedDirectional(
          start: anchor.left.clamp(
            gap,
            math.max(gap, viewport.width - width - gap),
          ),
          width: width,
          top: over ? null : anchor.bottom + gap,
          bottom: over
              ? math.max(gap, viewport.height - anchor.top + gap)
              : null,
          child: Directionality(
            textDirection: widget.uiDirection,
            child: KeyedSubtree(
              key: _linkPopover,
              child: LinkPopover(
                key: ValueKey<int?>(draft == null ? tool.selected : null),
                link: draft == null ? marked.first : null,
              ),
            ),
          ),
        ),
    ];
  }

  /// Edit mode's edit marks (f3); hover frame, inline editor and tooltip
  /// (a3-1a, a3-1b, a3-19); the tint of the table cells that depend on the
  /// edited one (a3-9); and "+1 line hidden" beside each block whose last
  /// lines "Keep and warn" hides (a3-4, a3-18), at the end of its line in its
  /// own direction.
  List<Widget> _editLayer(BuildContext context, ViewerState state) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final hover = _hover;
    final block = hover?.block;
    final editorState = ref.watch(documentEditorProvider);
    final active = editorState.active;
    final dependents = active == null
        ? const <Rect>[]
        : [
            for (final cell
                in editorState.preview?.dependents ?? const <DependentCell>[])
              ?_onCanvas(state, active.page, cell.frame),
          ];
    final marks = ref.watch(settingsProvider.select((s) => s.markEdited))
        ? _editMarks(state, editorState)
        : const <EditMark>[];
    final hidden = [
      for (final mark in editorState.hidden)
        if (active?.page != mark.page ||
            !(active?.block.frame.overlaps(mark.frame) ?? false))
          (mark.page, mark.frame, mark.direction, mark.lines),
      if (active != null && editorState.keptHidden > 0)
        (
          active.page,
          active.block.frame,
          active.block.direction,
          editorState.keptHidden,
        ),
    ];
    if (!identical(active, _keyed)) {
      _keyed = active;
      if (!(active?.followed ?? false)) _editorKey = GlobalKey();
    }
    final editing = active == null
        ? null
        : _onCanvas(state, active.page, active.block.frame);
    final editingPage = active == null
        ? null
        : state.placement.rects
              .elementAtOrNull(active.page)
              ?.shift(-state.offset);
    // The block being edited shows its editor, not the hover frame and tip.
    final onEditor =
        hover != null &&
        active?.page == hover.page &&
        active?.block.id == block?.id;
    final frame = hover == null || block == null || onEditor
        ? null
        : _onCanvas(state, hover.page, block.frame);
    final reason = block != null ? block.notEditable : hover?.empty;
    final revealed = !_revealing
        ? const <Rect>[]
        : [
            for (final (page, rect) in state.placement.rects.indexed)
              if (rect != null && rect.overlaps(state.visible))
                for (final each
                    in _blocksOf(page)?.blocks ?? const <TextBlock>[])
                  if (each.notEditable == null &&
                      (active?.page != page || active?.block.id != each.id))
                    ?_onCanvas(state, page, each.frame),
          ];
    final String? tip;
    if (onEditor) {
      tip = null;
    } else if (block != null && reason == null) {
      final first = block.lines.firstOrNull?.text ?? '';
      final runes = first.runes;
      tip = l10n.editHoverTip(
        bidiIsolate(
          runes.length > DocumentView.tipChars
              ? '${String.fromCharCodes(runes.take(DocumentView.tipChars))}…'
              : first,
        ),
      );
    } else {
      tip = reason == null ? null : notEditableTip(l10n, reason);
    }
    // For a screen reader the visible pages' blocks are nodes in reading
    // order, the open one its editor. Nobody else pays for asking the
    // engine ahead of the pointer.
    final language = ref.watch(openDocumentProvider.select((d) => d?.language));
    var order = 0.0;
    double? editorOrder;
    final reading = <Widget>[];
    if (SemanticsBinding.instance.semanticsEnabled) {
      for (final (page, rect) in state.placement.rects.indexed) {
        if (rect == null || !rect.overlaps(state.visible)) continue;
        for (final block in _blocksOf(page)?.blocks ?? const <TextBlock>[]) {
          if (active?.page == page && active?.block.id == block.id) {
            editorOrder = order++;
            continue;
          }
          final at = _onCanvas(state, page, block.frame);
          if (at == null) continue;
          final rtl = block.direction == BlockDirection.rightToLeft;
          final locked = block.notEditable;
          reading.add(
            PositionedDirectional(
              start: at.left,
              top: at.top,
              width: at.width,
              height: at.height,
              child: Semantics(
                key: ValueKey<String>('DocumentView.block.$page.${block.id}'),
                container: true,
                sortKey: OrdinalSortKey(order++),
                localeForSubtree: documentLocale(block.language),
                label: block.text,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                hint: locked == null ? null : notEditableTip(l10n, locked),
                onTap: locked != null
                    ? null
                    : () => unawaited(
                        _openEditor(
                          _Target(
                            page: page,
                            point: rtl
                                ? block.frame.topRight
                                : block.frame.topLeft,
                            local: at.topLeft,
                            block: block,
                          ),
                        ),
                      ),
                child: const SizedBox.expand(),
              ),
            ),
          );
        }
      }
    }
    return [
      if (marks.isNotEmpty)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey<String>('DocumentView.editMarks'),
              painter: EditMarksPainter(
                marks: marks,
                color: theme.pageColors.editMark,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              ),
            ),
          ),
        ),
      for (final cell in dependents)
        PositionedDirectional(
          start: cell.left,
          top: cell.top,
          child: IgnorePointer(
            child: SizedBox(
              key: const ValueKey<String>('DocumentView.dependentCell'),
              width: cell.width,
              height: cell.height,
              child: ColoredBox(color: theme.pageColors.glyphMissingBg),
            ),
          ),
        ),
      for (final (page, box, direction, lines) in hidden)
        if (_onCanvas(state, page, box) case final at?)
          PositionedDirectional(
            top: at.bottom + HiddenLinesStatus.drop - HiddenLinesStatus.height,
            start: direction == BlockDirection.rightToLeft
                ? at.left - HiddenLinesStatus.gap
                : at.right + HiddenLinesStatus.gap,
            child: IgnorePointer(
              child: FractionalTranslation(
                translation: Offset(
                  direction == BlockDirection.rightToLeft ? -1 : 0,
                  0,
                ),
                child: HiddenLinesStatus(lines: lines),
              ),
            ),
          ),
      // The box's layout slot is the block's frame: its own negative margin
      // makes the overhang.
      for (final dashed in [
        ...revealed,
        if (frame != null && reason == null && !_revealing) frame,
      ])
        PositionedDirectional(
          start: dashed.left,
          top: dashed.top,
          child: IgnorePointer(
            child: TextEditBox(
              state: TextEditBoxState.hover,
              inert: true,
              child: SizedBox(
                width:
                    dashed.width +
                    2 * (TextEditBox.marginX - TextEditBox.paddingX),
                height:
                    dashed.height +
                    2 * (TextEditBox.marginY - TextEditBox.paddingY),
              ),
            ),
          ),
        ),
      if ((active != null && editing != null && editingPage != null) ||
          reading.isNotEmpty)
        // The keys sort among themselves only in a group of their own.
        Positioned.fill(
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            localeForSubtree: documentLocale(language),
            child: Stack(
              children: [
                ...reading,
                if (active != null && editing != null && editingPage != null)
                  // Around the Stack, not the editor: the frame's handles
                  // overhang the editor's slot, and a node of that size would
                  // stop their hit tests.
                  Positioned.fill(
                    child: Semantics(
                      container: true,
                      sortKey: OrdinalSortKey(editorOrder ?? order),
                      child: Stack(
                        children: [
                          PositionedDirectional(
                            start: editing.left,
                            top: editing.top,
                            child: BlockEditor(
                              key: _editorKey,
                              edit: active,
                              frame: editing,
                              scale: state.scale,
                              uiDirection: widget.uiDirection,
                              metaPlacement: metaPlacementFor(
                                frame: editing,
                                page: editingPage,
                                others: [
                                  for (final each
                                      in _blocksOf(active.page)?.blocks ??
                                          const <TextBlock>[])
                                    if (each.id != active.block.id)
                                      ?_onCanvas(
                                        state,
                                        active.page,
                                        each.frame,
                                      ),
                                  ...dependents,
                                ],
                                room:
                                    theme.size.editboxMetaH +
                                    2 * TextEditBox.metaGap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (hover != null && tip != null)
        PositionedDirectional(
          start: hover.local.dx + theme.space.space2,
          top: hover.local.dy + theme.space.space4,
          child: IgnorePointer(
            child: Directionality(
              textDirection: widget.uiDirection,
              child: _PointerTip(text: tip, locked: reason != null),
            ),
          ),
        ),
    ];
  }
}

/// What the pointer is over: [page], with [point] in its page space,
/// [local] on the canvas, the [block] there, and why a page without
/// blocks has no text ([empty]).
@immutable
class _Target {
  const new({
    required this.page,
    required this.point,
    required this.local,
    this.block,
    this.empty,
  });

  final int page;
  final Offset point;
  final Offset local;
  final TextBlock? block;
  final NotEditableReason? empty;
}

/// Copies [selection]'s text to the clipboard; nothing without one.
void copySelection(PageSelection? selection) {
  if (selection == null || selection.text.isEmpty) return;
  unawaited(Clipboard.setData(ClipboardData(text: selection.text)));
}

/// Paints the visible pages: the page and its shadow, the preview, then
/// the tiles from the bucket farthest from the zoom's to its own, so the
/// sharpest lands on top; then the search's matches (a2-4a), the current
/// one orange with a 1 px ring, the others yellow.
class _PagesPainter extends CustomPainter {
  new({
    required this.state,
    required this.images,
    required this.failed,
    required this.page,
    required this.filter,
    required this.marquee,
    required this.marqueeColor,
    required this.marqueeFill,
    required this.matches,
    required this.current,
    required this.matchColor,
    required this.currentColor,
    required this.currentBorder,
    required this.selection,
    required this.selectionColor,
  });

  final ViewerState state;
  final Map<RenderItem, ui.Image> images;

  /// The failed pages, painted blank; null when every page is.
  final Set<int>? failed;
  final BoxDecoration page;
  final ColorFilter? filter;
  final Rect? marquee;
  final Color marqueeColor;
  final Color marqueeFill;
  final List<SearchMatch> matches;
  final SearchMatch? current;
  final Color matchColor;
  final Color currentColor;
  final Color currentBorder;
  final PageSelection? selection;
  final Color selectionColor;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = state.visible;
    final bucket = zoomBucket(state.scale);
    final decoration = page.createBoxPainter();
    final byPage = <int, List<MapEntry<RenderItem, ui.Image>>>{};
    for (final entry in images.entries) {
      (byPage[entry.key.page] ??= []).add(entry);
    }
    final pixels = Paint()
      ..filterQuality = FilterQuality.medium
      // Tiles meet edge to edge; antialiased edges would show seams.
      ..isAntiAlias = false;
    canvas
      ..save()
      ..translate(-visible.left, -visible.top);
    for (final (index, rect) in state.placement.rects.indexed) {
      if (rect == null || !rect.overlaps(visible)) continue;
      decoration.paint(
        canvas,
        rect.topLeft,
        ImageConfiguration(size: rect.size),
      );
      final failed = this.failed;
      if (failed == null || failed.contains(index)) continue;
      final entries = byPage[index] ?? [];
      int rank(RenderItem item) => switch (item) {
        ThumbnailItem() => 1 << 20,
        TileItem(:final zoomBucket) => (zoomBucket - bucket).abs(),
      };
      entries.sort((a, b) => rank(b.key).compareTo(rank(a.key)));
      if (filter != null) {
        canvas.saveLayer(rect, Paint()..colorFilter = filter);
      }
      canvas
        ..save()
        ..clipRect(rect);
      for (final MapEntry(key: item, value: image) in entries) {
        final source =
            Offset.zero & Size(image.width.toDouble(), image.height.toDouble());
        final target = switch (item) {
          ThumbnailItem() => rect,
          TileItem(
            :final zoomBucket,
            :final devicePixelRatio,
            :final column,
            :final row,
          ) =>
            () {
              final toCanvas =
                  state.scale / (bucketScale(zoomBucket) * devicePixelRatio);
              return Rect.fromLTWH(
                rect.left + column * tileSize * toCanvas,
                rect.top + row * tileSize * toCanvas,
                image.width * toCanvas,
                image.height * toCanvas,
              );
            }(),
        };
        canvas.drawImageRect(image, source, target, pixels);
      }
      for (final match in matches) {
        if (match.page != index) continue;
        final mark = Paint()
          ..color = identical(match, current) ? currentColor : matchColor;
        for (final box in match.rects) {
          final area = Rect.fromLTRB(
            rect.left + box.left * state.scale,
            rect.top + box.top * state.scale,
            rect.left + box.right * state.scale,
            rect.top + box.bottom * state.scale,
          );
          canvas.drawRect(area, mark);
          if (identical(match, current)) {
            canvas.drawRect(
              area,
              Paint()
                ..color = currentBorder
                ..style = PaintingStyle.stroke,
            );
          }
        }
      }
      if (selection case PageSelection(:final page, :final quads)
          when page == index) {
        final mark = Paint()..color = selectionColor;
        for (final box in quads) {
          canvas.drawRect(
            Rect.fromLTRB(
              rect.left + box.left * state.scale,
              rect.top + box.top * state.scale,
              rect.left + box.right * state.scale,
              rect.top + box.bottom * state.scale,
            ),
            mark,
          );
        }
      }
      canvas.restore();
      if (filter != null) canvas.restore();
    }
    canvas.restore();
    final marquee = this.marquee;
    if (marquee != null && marquee.longestSide >= Viewer.marqueeMinimum) {
      canvas.drawRect(marquee, Paint()..color = marqueeFill);
      _dashed(canvas, marquee, Paint()..color = marqueeColor);
    }
  }

  /// a2-2's dashed marquee outline: 4 px dashes, 1 px wide.
  static void _dashed(Canvas canvas, Rect rect, Paint paint) {
    const dash = 4.0;
    void line(Offset from, Offset to) {
      final length = (to - from).distance;
      final step = (to - from) / length;
      for (var at = 0.0; at < length; at += 2 * dash) {
        final end = math.min(at + dash, length);
        canvas.drawRect(
          Rect.fromPoints(
            from + step * at,
            from + step * end + const Offset(1, 1),
          ),
          paint,
        );
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.bottomLeft, rect.bottomRight);
    line(rect.topLeft, rect.bottomLeft);
    line(rect.topRight, rect.bottomRight);
  }

  @override
  bool shouldRepaint(_PagesPainter old) => true;
}

/// a2-13's placeholder for a page that failed to render: the `file-x`
/// glyph on a sunken square, "Ferman couldn't draw page N.", a plain
/// reason and Try again.
class _FailedPage extends ConsumerWidget {
  const new({required this.page, required this.onRetry});

  final int page;
  final VoidCallback onRetry;

  /// a2-13: the glyph's square, the glyph and the reason's width.
  static const double markBox = 44;
  static const double markSize = 22;
  static const double bodyWidth = 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space2_5,
        children: [
          Container(
            width: markBox,
            height: markBox,
            decoration: BoxDecoration(
              color: theme.colors.surfaceSunken,
              borderRadius: BorderRadius.all(
                Radius.circular(theme.radius.radiusMd),
              ),
            ),
            child: Icon(
              IconName.fileX,
              size: markSize,
              color: theme.colors.iconSecondary,
            ),
          ),
          Text(
            l10n.viewerPageFailed(format.integer(page + 1)),
            textAlign: TextAlign.center,
            style: theme.typography.bodyStrong.copyWith(
              color: theme.ramps.paper900,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: bodyWidth),
            child: Text(
              l10n.viewerPageFailedReason,
              textAlign: TextAlign.center,
              style: theme.typography.caption.copyWith(
                color: theme.ramps.paper700,
              ),
            ),
          ),
          Button(
            size: ButtonSize.sm,
            icon: IconName.refreshCw,
            onPressed: onRetry,
            child: Text(l10n.viewerTryAgain),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('page', page))
      ..add(ObjectFlagProperty<VoidCallback>.has('onRetry', onRetry));
  }
}

/// a2-2's label beside a marquee: "Release to zoom to 180%" on the
/// tooltip's inverse surface.
class _MarqueeLabel extends ConsumerWidget {
  const new({required this.zoom});

  final double zoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.space.space2,
        vertical: theme.space.space1,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfaceInverse,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusSm)),
        boxShadow: theme.elevation.shadowSm,
      ),
      child: Text(
        l10n.viewerMarqueeZoom(
          bidiIsolate(format.percent((zoom * 100).round())),
        ),
        softWrap: false,
        style: theme.typography.caption.copyWith(
          color: theme.colors.textInverse,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('zoom', zoom));
  }
}

/// The tooltip beside the pointer on page text (a3-1a, a3-19): caption
/// type on the tooltip's inverse surface, with a lock for text that cannot
/// be edited.
class _PointerTip extends StatelessWidget {
  const new({required this.text, required this.locked});

  final String text;
  final bool locked;

  /// a3-19: the lock's size and stroke (`size="{{ 12 }}"`,
  /// `stroke-width="{{ 2 }}"`).
  static const double lockSize = 12;
  static const double lockStroke = 2;

  /// a3-19's `padding: 5px 9px`; a3-1a's plain tip is 4 px 8 px.
  static const double lockPaddingX = 9;
  static const double lockPaddingY = 5;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return Container(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: locked ? lockPaddingX : theme.space.space2,
        vertical: locked ? lockPaddingY : theme.space.space1,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surfaceInverse,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusSm)),
        boxShadow: locked ? theme.elevation.shadowPopover : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: theme.space.space1_5,
        children: [
          if (locked)
            Icon(
              IconName.lock,
              size: lockSize,
              strokeWidth: lockStroke,
              color: theme.colors.textInverse,
            ),
          Text(
            text,
            softWrap: false,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textInverse,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(FlagProperty('locked', value: locked, ifTrue: 'locked'));
  }
}
