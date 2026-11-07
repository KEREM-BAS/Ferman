import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/design/components/annotations/annotation_color.dart'
    as design;
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/design/components/forms/field_input.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/comments/comment_style_bar.dart';
import 'package:ferman/features/comments/comment_time.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the pointer is doing on the page, in displayed points of [page].
sealed class _Gesture {
  const new(this.page);

  /// The page, by its index.
  final int page;
}

/// Drawing a stroke, or dragging out a box, line or callout.
final class _Drawing extends _Gesture {
  new(super.page, Offset start) : points = [start];

  final List<Offset> points;
}

/// Moving or resizing the selected annotation; [handle] null moves it.
final class _Reshaping extends _Gesture {
  new(super.page, this.annotation, this.handle, this.start, this.box);

  final AnnotationInfo annotation;
  final int? handle;
  final Offset start;
  Rect box;
}

/// Text being typed on the page: a new note, text box or callout, or the text
/// of [existing]. Commits on blur, or when the view goes away, never per
/// keystroke (decision 16).
final class _Draft {
  new({
    required this.page,
    required this.box,
    required this.kind,
    this.existing,
    this.leader = const [],
  }) : typed = existing?.contents ?? '';

  final int page;
  final Rect box;
  final AnnotationKind kind;
  final AnnotationInfo? existing;
  final List<Offset> leader;

  /// The text so far.
  String typed;
}

/// Comment mode's layer over the pages (a4-1, a4-1d, a4-2): it finds the marks
/// the engine drew, shows the selected one with its handles and style bar, the
/// notes' pins and open notes, and carries every drag, which commits once at
/// its end (decision 16). Text marks come from the view's own text selection
/// (`DocumentView`), so this layer lets the pointer through for those tools.
///
/// It sits in the canvas's left-to-right geometry, which never mirrors; its
/// bars and cards follow [uiDirection].
class CommentOverlay extends ConsumerStatefulWidget {
  /// The layer over [view].
  const new({
    required this.view,
    required this.uiDirection,
    this.draftKey,
    super.key,
  });

  /// The canvas as it stands.
  final ViewerState view;

  /// The UI's direction.
  final TextDirection uiDirection;

  /// Names the box of the text being typed, whose clicks are its own.
  final GlobalKey? draftKey;

  /// The drawn size of a click's new text box, and the smallest drag that
  /// counts, in points.
  static const double newTextWidth = 180;

  /// See [newTextWidth].
  static const double newTextHeight = 48;

  /// See [newTextWidth].
  static const double smallestDrag = 4;

  /// A note's box in the file, in points.
  static const double noteSize = 24;

  /// a4-1's handles (`width` and `height: 8px`).
  static const double handleSize = 8;

  /// The most points of one stroke.
  static const int mostStrokePoints = 4096;

  @override
  ConsumerState<CommentOverlay> createState() => _CommentOverlayState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ViewerState>('view', view))
      ..add(EnumProperty<TextDirection>('uiDirection', uiDirection))
      ..add(DiagnosticsProperty<GlobalKey?>('draftKey', draftKey));
  }
}

class _CommentOverlayState extends ConsumerState<CommentOverlay> {
  _Gesture? _gesture;
  _Draft? _draft;
  Duration? _lastClick;
  bool _overMark = false;

  /// What [dispose] needs, when `ref` and `context` no longer answer.
  late final CommentCommands _keptCommands;
  AnnotationColor? _draftColor;

  @override
  void initState() {
    super.initState();
    _keptCommands = _commands;
    ref.listenManual(documentAnnotationsProvider, (_, next) {
      final list = next.value;
      if (!next.isLoading && list != null) _selection.listed(list.annotations);
    }, fireImmediately: true);
  }

  /// A view keyed by its document goes when another document shows, and with it
  /// what was being typed unless it is committed here.
  @override
  void dispose() {
    final draft = _draft;
    final color = _draftColor;
    if (draft != null && color != null) {
      final document = _document.id;
      final existing = draft.existing;
      if (existing != null) {
        if (draft.typed != (existing.contents ?? '')) {
          unawaited(
            _keptCommands.updateLeft(
              document,
              existing.handle,
              AnnotationChange(contents: draft.typed),
            ),
          );
        }
      } else if (draft.typed.trim().isNotEmpty) {
        unawaited(
          _keptCommands.addLeft(
            document,
            _document.pageHandle(draft.page),
            (author) => _annotationOf(draft, draft.typed, color, author),
          ),
        );
      }
    }
    super.dispose();
  }

  ViewerState get _view => widget.view;

  CommentCommands get _commands => ref.read(commentCommandsProvider.notifier);

  CommentSelection get _selection =>
      ref.read(commentSelectionProvider.notifier);

  bool get _refused => ref.read(commentRefusalProvider) != null;

  Rect? _pageRect(int page) => _view.placement.rects.elementAtOrNull(page);

  /// The page under [local] and the point in it.
  (int, Offset)? _pageAt(Offset local) {
    final onCanvas = local + _view.offset;
    for (final (page, rect) in _view.placement.rects.indexed) {
      if (rect != null && rect.contains(onCanvas)) {
        return (page, (onCanvas - rect.topLeft) / _view.scale);
      }
    }
    return null;
  }

  /// [local] in the displayed points of [page], kept on the page.
  Offset _onPage(int page, Offset local) {
    final rect = _pageRect(page);
    if (rect == null) return Offset.zero;
    final at = (local + _view.offset - rect.topLeft) / _view.scale;
    return Offset(
      at.dx.clamp(0, rect.width / _view.scale),
      at.dy.clamp(0, rect.height / _view.scale),
    );
  }

  /// [box] of [page] on the canvas.
  Rect _toLocal(int page, Rect box) {
    final rect = _pageRect(page) ?? Rect.zero;
    return Rect.fromLTRB(
      rect.left + box.left * _view.scale,
      rect.top + box.top * _view.scale,
      rect.left + box.right * _view.scale,
      rect.top + box.bottom * _view.scale,
    ).shift(-_view.offset);
  }

  Offset _pointToLocal(int page, Offset point) =>
      (_pageRect(page)?.topLeft ?? Offset.zero) +
      point * _view.scale -
      _view.offset;

  OpenedDocument get _document => _view.document;

  AnnotationColor _toolColor() =>
      markColorOf(ref.read(commentToolProvider).color.resolve(context.ferman));

  CommentThread? _threadOf(int? handle) => handle == null
      ? null
      : ref
            .read(documentThreadsProvider)
            .where((thread) => thread.top.handle == handle)
            .firstOrNull;

  AnnotationInfo? _at(int page, Offset point) => annotationAt(
    ref.read(documentThreadsProvider),
    _document.pageHandle(page),
    point,
  );

  // Pointer input.

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    final found = _pageAt(event.localPosition);
    if (event.buttons == kSecondaryMouseButton) {
      if (found != null) _context(found.$1, found.$2, event.position);
      return;
    }
    if (event.buttons != kPrimaryMouseButton) return;
    final last = _lastClick;
    final double_ = last != null && event.timeStamp - last < kDoubleTapTimeout;
    _lastClick = event.timeStamp;
    final tools = ref.read(commentToolProvider);
    if (found == null) {
      _selection.clear();
      return;
    }
    final (page, point) = found;
    switch (tools.tool) {
      case AnnotationTool.select:
        _selectAt(page, point, event.localPosition, opens: double_);
      case AnnotationTool.note when !_refused:
        const side = CommentOverlay.noteSize;
        setState(() {
          _draft = _Draft(
            page: page,
            box: Rect.fromLTWH(point.dx, point.dy, side, side),
            kind: AnnotationKind.note,
          );
        });
      case AnnotationTool.pen || AnnotationTool.text || AnnotationTool.callout
          when !_refused:
        setState(() => _gesture = _Drawing(page, point));
      case _:
    }
  }

  void _selectAt(int page, Offset point, Offset local, {required bool opens}) {
    final selected = _threadOf(ref.read(commentSelectionProvider)?.handle)?.top;
    // The handles of the selected mark come first: they overhang it.
    if (selected != null &&
        _document.pageIndexOf(selected.page) == page &&
        resizable(selected.kind) &&
        !_refused) {
      final box = _toLocal(page, selected.rect);
      for (final (handle, at) in handlesOf(box).indexed) {
        if ((at - local).distance <= CommentOverlay.handleSize) {
          setState(() {
            _gesture = _Reshaping(page, selected, handle, point, selected.rect);
          });
          return;
        }
      }
    }
    final hit = _at(page, point);
    if (hit == null) {
      _selection.clear();
      return;
    }
    _selection.select(hit.handle);
    if (opens && hasOwnText(hit.kind) && hit.kind != AnnotationKind.note) {
      _editText(hit);
      return;
    }
    if (!opens && movable(hit.kind) && !_refused) {
      setState(() {
        _gesture = _Reshaping(page, hit, null, point, hit.rect);
      });
    }
  }

  void _move(PointerMoveEvent event) => _moveTo(event.localPosition);

  void _moveTo(Offset local) {
    final gesture = _gesture;
    switch (gesture) {
      case _Drawing(:final page, :final points):
        final at = _onPage(page, local);
        final pen = ref.read(commentToolProvider).tool == AnnotationTool.pen;
        setState(() {
          if (!pen) {
            points
              ..length = 1
              ..add(at);
          } else if (points.length < CommentOverlay.mostStrokePoints &&
              (at - points.last).distance * _view.scale >= 1) {
            points.add(at);
          }
        });
      case _Reshaping(:final page, :final annotation, :final handle):
        final at = _onPage(page, local);
        setState(() {
          gesture.box = handle == null
              ? _kept(page, annotation.rect.shift(at - gesture.start))
              : resizedBox(annotation.rect, handle, at);
        });
      case null:
    }
  }

  /// A text box of the size a click gives, at [at].
  static Rect _newText(Offset at) => Rect.fromLTWH(
    at.dx,
    at.dy,
    CommentOverlay.newTextWidth,
    CommentOverlay.newTextHeight,
  );

  /// [box] moved back on the page.
  Rect _kept(int page, Rect box) {
    final rect = _pageRect(page) ?? Rect.zero;
    final width = rect.width / _view.scale;
    final height = rect.height / _view.scale;
    return box.shift(
      Offset(
        box.left < 0 ? -box.left : math.min(0, width - box.right),
        box.top < 0 ? -box.top : math.min(0, height - box.bottom),
      ),
    );
  }

  void _up(PointerEvent _) {
    final gesture = _gesture;
    switch (gesture) {
      case _Drawing():
        setState(() => _gesture = null);
        _finishDrawing(gesture);
      case _Reshaping(:final annotation, :final box):
        setState(() => _gesture = null);
        if (box != annotation.rect) {
          unawaited(
            _commands.update(annotation.handle, AnnotationChange(rect: box)),
          );
        }
      case null:
    }
  }

  void _finishDrawing(_Drawing drawing) {
    final tools = ref.read(commentToolProvider);
    final page = drawing.page;
    final handle = _document.pageHandle(page);
    final start = drawing.points.first;
    final end = drawing.points.last;
    final big =
        (end - start).distance * _view.scale >= CommentOverlay.smallestDrag;
    final color = _toolColor();
    switch (tools.tool) {
      case AnnotationTool.pen:
        if (drawing.points.length < 2) return;
        unawaited(
          _commands.add(
            handle,
            (author) => NewAnnotation(
              kind: AnnotationKind.ink,
              color: color,
              author: author,
              points: [drawing.points],
              stroke: 2,
            ),
          ),
        );
      case AnnotationTool.text:
        final box = big ? Rect.fromPoints(start, end) : _newText(start);
        setState(() {
          _draft = _Draft(
            page: page,
            box: _kept(page, box),
            kind: AnnotationKind.freeText,
          );
        });
      case AnnotationTool.callout:
        // The press is what it points at; the release, its text box.
        final box = _kept(page, _newText(end));
        setState(() {
          _draft = _Draft(
            page: page,
            box: box,
            kind: AnnotationKind.callout,
            leader: [start, box.centerLeft],
          );
        });
      case _:
    }
  }

  void _editText(AnnotationInfo annotation) {
    final page = _document.pageIndexOf(annotation.page);
    if (page == null || _refused) return;
    setState(() {
      _draft = _Draft(
        page: page,
        box: annotation.kind == AnnotationKind.note
            ? _newText(annotation.rect.topLeft)
            : annotation.rect,
        kind: annotation.kind,
        existing: annotation,
      );
    });
  }

  /// The annotation [draft] makes of [text].
  static NewAnnotation _annotationOf(
    _Draft draft,
    String text,
    AnnotationColor color,
    String author,
  ) {
    final isNote = draft.kind == AnnotationKind.note;
    return NewAnnotation(
      kind: draft.kind,
      color: color,
      author: author,
      rect: draft.box,
      contents: text,
      points: draft.leader.isEmpty ? const [] : [draft.leader],
      stroke: isNote ? 1 : 2,
      arrow: draft.kind == AnnotationKind.callout,
      icon: isNote ? 'Comment' : null,
    );
  }

  AnnotationColor _colorOf(_Draft draft) => draft.kind == AnnotationKind.note
      ? _toolColor()
      : markColorOf(context.ferman.ramps.annotRed);

  void _commitDraft(_Draft draft, String text) {
    setState(() => _draft = null);
    final existing = draft.existing;
    if (existing != null) {
      if (text != (existing.contents ?? '')) {
        unawaited(
          _commands.update(existing.handle, AnnotationChange(contents: text)),
        );
      }
      return;
    }
    if (text.trim().isEmpty) return;
    final color = _colorOf(draft);
    unawaited(
      _commands.add(
        _document.pageHandle(draft.page),
        (author) => _annotationOf(draft, text, color, author),
      ),
    );
  }

  /// A press on the pin of [note], which sits above this layer: a drag moves
  /// it, and a right click opens G46's menu; a click is the pin's own.
  void _pinDown(AnnotationInfo note, int page, PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event.buttons == kSecondaryMouseButton) {
      _menu(note, event.position);
      return;
    }
    final at = _overlayPoint(event.position);
    if (event.buttons != kPrimaryMouseButton ||
        ref.read(commentToolProvider).tool != AnnotationTool.select ||
        _refused) {
      return;
    }
    _selection.select(note.handle);
    setState(() {
      _gesture = _Reshaping(page, note, null, _onPage(page, at), note.rect);
    });
  }

  Offset _overlayPoint(Offset global) =>
      (context.findRenderObject()! as RenderBox).globalToLocal(global);

  /// G46's context menu on the mark under the pointer.
  void _context(int page, Offset point, Offset position) {
    final hit = _at(page, point);
    if (hit != null) _menu(hit, position);
  }

  void _menu(AnnotationInfo hit, Offset position) {
    _selection.select(hit.handle);
    showCommentMenu(
      context,
      ref,
      hit,
      position,
      onEditText: () => _editText(hit),
      direction: widget.uiDirection,
    );
  }

  void _hover(PointerHoverEvent event) {
    if (ref.read(commentToolProvider).tool != AnnotationTool.select) return;
    final found = _pageAt(event.localPosition);
    final over = found != null && _at(found.$1, found.$2) != null;
    if (over != _overMark) setState(() => _overMark = over);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final tools = ref.watch(commentToolProvider);
    final shown = ref.watch(commentsShownProvider).visible;
    final threads = ref.watch(documentThreadsProvider);
    final selected = ref.watch(commentSelectionProvider);
    final refused = ref.watch(commentRefusalProvider) != null;
    final thread = _threadOf(selected?.handle);
    final top = thread?.top;
    final topPage = top == null ? null : _document.pageIndexOf(top.page);
    final gesture = _gesture;
    final draft = _draft;
    if (draft != null) _draftColor = _colorOf(draft);
    final reshaped = gesture is _Reshaping ? gesture : null;
    final box = topPage == null || top == null
        ? null
        : _toLocal(topPage, reshaped?.box ?? top.rect);
    final viewport = _view.viewport;
    final cursor = switch (tools.tool) {
      AnnotationTool.select =>
        _overMark ? SystemMouseCursors.click : MouseCursor.defer,
      AnnotationTool.pen ||
      AnnotationTool.text ||
      AnnotationTool.callout ||
      AnnotationTool.note => SystemMouseCursors.precise,
      _ => MouseCursor.defer,
    };
    return Stack(
      children: [
        // Hidden comments take no pointer; the view still scrolls and zooms.
        if (shown && !tools.marksText)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: (_) => setState(() => _gesture = null),
              onPointerHover: _hover,
              child: MouseRegion(cursor: cursor),
            ),
          ),
        if (shown)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey<String>('CommentOverlay.marks'),
                painter: _MarksPainter(
                  selected: top == null || topPage == null
                      ? const []
                      : top.points.isNotEmpty && !movable(top.kind)
                      ? [
                          for (final quad in top.points)
                            _toLocal(topPage, boundsOf(quad)),
                        ]
                      : [box ?? Rect.zero],
                  handles: box != null && top != null && resizable(top.kind),
                  ghost: _ghost(gesture, tools),
                  ghostIsLine:
                      tools.tool == AnnotationTool.pen ||
                      tools.tool == AnnotationTool.callout,
                  color: tools.color.resolve(theme),
                  accent: theme.colors.accent,
                  handleFill: theme.pageColors.pageBg,
                  handleSize: CommentOverlay.handleSize,
                ),
              ),
            ),
          ),
        if (shown)
          for (final each in threads)
            if (each.top.kind == AnnotationKind.note)
              if (_document.pageIndexOf(each.top.page) case final page?)
                if (_toLocal(
                      page,
                      reshaped?.annotation.handle == each.top.handle
                          ? reshaped!.box
                          : each.top.rect,
                    )
                    case final at
                    when at.overlaps(Offset.zero & viewport) ||
                        selected?.handle == each.top.handle)
                  Positioned.fill(
                    key: ValueKey<int>(each.top.handle),
                    child: CustomSingleChildLayout(
                      delegate: _NoteLayout(
                        at.topLeft,
                        kept:
                            selected?.handle == each.top.handle &&
                            selected!.noteOpen,
                      ),
                      child: Listener(
                        onPointerDown:
                            selected?.handle == each.top.handle &&
                                selected!.noteOpen
                            ? null
                            : (event) => _pinDown(each.top, page, event),
                        onPointerMove: (event) =>
                            _moveTo(_overlayPoint(event.position)),
                        onPointerUp: _up,
                        onPointerCancel: (_) => setState(() => _gesture = null),
                        child: Directionality(
                          textDirection: widget.uiDirection,
                          child: _Note(
                            thread: each,
                            page: page,
                            open:
                                selected?.handle == each.top.handle &&
                                selected!.noteOpen,
                            onEditText: () => _editText(each.top),
                          ),
                        ),
                      ),
                    ),
                  ),
        if (draft != null)
          if (_toLocal(draft.page, draft.box) case final at)
            PositionedDirectional(
              start: at.left,
              top: at.top,
              child: _TextDraft(
                key: ObjectKey(draft),
                boxKey: widget.draftKey,
                direction: widget.uiDirection,
                draft: draft,
                box: draft.kind == AnnotationKind.note
                    ? _newText(Offset.zero).size
                    : at.size,
                scale: _view.scale,
                onDone: (text) => _commitDraft(draft, text),
                onCancel: () => setState(() => _draft = null),
              ),
            ),
        if (shown &&
            top != null &&
            box != null &&
            !refused &&
            gesture == null &&
            draft == null &&
            !(selected?.noteOpen ?? false))
          PositionedDirectional(
            start: CommentStyleBar.startFor(box, viewport),
            top: CommentStyleBar.topFor(box),
            child: Directionality(
              textDirection: widget.uiDirection,
              child: CommentStyleBar(annotation: top),
            ),
          ),
      ],
    );
  }

  /// The drag or clicks so far, on the canvas.
  List<Offset> _ghost(_Gesture? gesture, CommentTools tools) =>
      switch (gesture) {
        _Drawing(:final page, :final points) => [
          for (final point in points) _pointToLocal(page, point),
        ],
        _ => const [],
      };
}

/// Where a note sits: at [at], with [kept] (it is open, a card far bigger than
/// its pin) moved back inside the canvas, which scrolls only so far.
class _NoteLayout extends SingleChildLayoutDelegate {
  const new(this.at, {required this.kept});

  final Offset at;
  final bool kept;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => kept
      ? Offset(
          at.dx.clamp(0, math.max(0, size.width - childSize.width)),
          at.dy.clamp(0, math.max(0, size.height - childSize.height)),
        )
      : at;

  @override
  bool shouldRelayout(_NoteLayout oldDelegate) =>
      at != oldDelegate.at || kept != oldDelegate.kept;
}

/// A note's pin, or the note open on the page with its replies (a4-1d). Esc
/// closes it and focus returns to the pin.
class _Note extends ConsumerWidget {
  const new({
    required this.thread,
    required this.page,
    required this.open,
    required this.onEditText,
  });

  final CommentThread thread;
  final int page;
  final bool open;
  final VoidCallback onEditText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final top = thread.top;
    final selection = ref.read(commentSelectionProvider.notifier);
    final refused = ref.watch(commentRefusalProvider) != null;
    final author = top.author ?? '';
    return StickyNote(
      collapsed: !open,
      color: nearestDesignColor(top.color, context.ferman),
      author: author,
      time: commentTime(top, format, l10n),
      text: top.contents ?? '',
      replies: [
        for (final reply in thread.replies)
          NoteReply(
            author: reply.author ?? '',
            time: commentTime(reply, format, l10n),
            text: reply.contents ?? '',
            mentions: reply.mentions,
          ),
      ],
      semanticLabel: l10n.commentNoteFrom(bidiIsolate(author)),
      moreLabel: l10n.commentMore,
      closeLabel: l10n.commentCloseNote,
      replyPlaceholder: refused ? null : l10n.commentReply,
      onToggle: () {
        if (open) {
          selection.select(top.handle);
        } else {
          selection.select(top.handle, noteOpen: true);
        }
      },
      onMore: () => showCommentMenu(
        context,
        ref,
        top,
        (context.findRenderObject() as RenderBox?)?.localToGlobal(
              Offset.zero,
            ) ??
            Offset.zero,
        onEditText: onEditText,
        direction: Directionality.of(context),
      ),
      onReply: refused
          ? null
          : (text) => unawaited(
              ref.read(commentCommandsProvider.notifier).reply(thread, text),
            ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<CommentThread>('thread', thread))
      ..add(IntProperty('page', page))
      ..add(FlagProperty('open', value: open, ifTrue: 'open'))
      ..add(ObjectFlagProperty<VoidCallback>.has('onEditText', onEditText));
  }
}

/// The palette's colour closest to [color], for a pin or the style bar's
/// swatch; a file's own colours are read, never written back by this.
design.AnnotationColor nearestDesignColor(
  AnnotationColor? color,
  FermanTheme theme,
) {
  if (color == null) return design.AnnotationColor.yellow;
  var best = design.AnnotationColor.yellow;
  var closest = double.infinity;
  for (final each in design.AnnotationColor.values) {
    final value = each.resolve(theme);
    final away =
        math.pow(value.r - color.red, 2) +
        math.pow(value.g - color.green, 2) +
        math.pow(value.b - color.blue, 2);
    if (away < closest) {
      closest = away.toDouble();
      best = each;
    }
  }
  return best;
}

/// G46's on-page text editor: a text annotation's own, multi-line, in the UI's
/// direction. Blur or ⌘↵ commits, Esc drops.
class _TextDraft extends StatefulWidget {
  const new({
    required this.direction,
    required this.draft,
    required this.box,
    required this.scale,
    required this.onDone,
    required this.onCancel,
    this.boxKey,
    super.key,
  });

  final TextDirection direction;
  final GlobalKey? boxKey;
  final _Draft draft;
  final Size box;
  final double scale;
  final ValueChanged<String> onDone;
  final VoidCallback onCancel;

  @override
  State<_TextDraft> createState() => _TextDraftState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<TextDirection>('direction', direction))
      ..add(DiagnosticsProperty<GlobalKey?>('boxKey', boxKey))
      ..add(DiagnosticsProperty<_Draft>('draft', draft))
      ..add(DiagnosticsProperty<Size>('box', box))
      ..add(DoubleProperty('scale', scale))
      ..add(ObjectFlagProperty<ValueChanged<String>>.has('onDone', onDone))
      ..add(ObjectFlagProperty<VoidCallback>.has('onCancel', onCancel));
  }
}

class _TextDraftState extends State<_TextDraft> {
  late final TextEditingController _text = TextEditingController(
    text: widget.draft.existing?.contents ?? '',
  );
  final FocusNode _focus = FocusNode(debugLabel: 'CommentOverlay.draft');
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _end();
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    widget.onDone(_text.text);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _ended = true;
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        (keys.isMetaPressed || keys.isControlPressed)) {
      _end();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final size = (widget.draft.existing?.fontSize ?? 12) * widget.scale;
    final ink = theme.ramps.paper900;
    return Semantics(
      textField: true,
      label: l10n.commentTextField,
      child: Container(
        key: widget.boxKey,
        constraints: BoxConstraints(
          minWidth: widget.box.width,
          maxWidth: widget.box.width,
          minHeight: widget.box.height,
        ),
        padding: EdgeInsetsDirectional.all(theme.space.space1),
        decoration: BoxDecoration(
          color: theme.pageColors.pageBg,
          border: Border.all(
            color: theme.colors.accent,
            width: theme.border.borderWidth,
          ),
        ),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _onKey,
          child: Directionality(
            textDirection: widget.direction,
            child: FieldInput(
              controller: _text,
              focusNode: _focus,
              maxLines: null,
              style: theme.typography.body.copyWith(fontSize: size, color: ink),
              onChanged: (text) => widget.draft.typed = text,
            ),
          ),
        ),
      ),
    );
  }
}

/// The selection, its handles and what is being drawn (a4-1, a4-2).
class _MarksPainter extends CustomPainter {
  const new({
    required this.selected,
    required this.handles,
    required this.ghost,
    required this.ghostIsLine,
    required this.color,
    required this.accent,
    required this.handleFill,
    required this.handleSize,
  });

  final List<Rect> selected;
  final bool handles;
  final List<Offset> ghost;
  final bool ghostIsLine;
  final Color color;
  final Color accent;
  final Color handleFill;
  final double handleSize;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final box in selected) {
      canvas.drawRect(box.inflate(1), outline);
    }
    if (handles && selected.isNotEmpty) {
      final fill = Paint()..color = handleFill;
      for (final at in handlesOf(selected.first)) {
        final square = Rect.fromCenter(
          center: at,
          width: handleSize,
          height: handleSize,
        );
        canvas
          ..drawRect(square, fill)
          ..drawRect(square, outline);
      }
    }
    if (ghost.length < 2) return;
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (ghostIsLine) {
      canvas.drawPath(Path()..addPolygon(ghost, false), pen);
    } else {
      canvas.drawRect(Rect.fromPoints(ghost.first, ghost.last), pen);
    }
  }

  @override
  bool shouldRepaint(_MarksPainter oldDelegate) => true;
}
