import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/design/components/annotations/annotation_color.dart'
    as design;
import 'package:ferman/design/components/annotations/annotation_tool.dart';
import 'package:ferman/design/components/annotations/stamp.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/stamps/comment_tool_menus.dart';
import 'package:ferman/features/stamps/stamp_clock.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/settings/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A shape's stroke as it starts (a4-1's `default-value="2"`).
const double shapeStroke = 2;

/// A dragged mark shorter than this, in points, is a slip, not a mark.
const double smallestShape = 4;

/// The smallest ⌥-drag makes a stamp, against its usual size.
const double minStampScale = 0.4;

/// The largest ⌥-drag makes a stamp, against its usual size.
const double maxStampScale = 8;

/// The new annotation of [shape] from [a] to [b], or through [points] for a
/// polygon, in displayed points.
NewAnnotation shapeAnnotation(
  ShapeTool shape, {
  required AnnotationColor color,
  required String author,
  Offset a = Offset.zero,
  Offset b = Offset.zero,
  List<Offset> points = const [],
}) => switch (shape) {
  ShapeTool.rectangle => NewAnnotation(
    kind: AnnotationKind.square,
    color: color,
    author: author,
    rect: Rect.fromPoints(a, b),
    stroke: shapeStroke,
  ),
  ShapeTool.ellipse => NewAnnotation(
    kind: AnnotationKind.circle,
    color: color,
    author: author,
    rect: Rect.fromPoints(a, b),
    stroke: shapeStroke,
  ),
  ShapeTool.arrow || ShapeTool.line => NewAnnotation(
    kind: AnnotationKind.line,
    color: color,
    author: author,
    points: [
      [a, b],
    ],
    arrow: shape == ShapeTool.arrow,
    stroke: shapeStroke,
  ),
  ShapeTool.polygon => NewAnnotation(
    kind: AnnotationKind.polygon,
    color: color,
    author: author,
    points: [points],
    stroke: shapeStroke,
  ),
};

/// What Enter places without a pointer, centred on [center]: the keyboard's and
/// a screen reader's way to the tool. No board draws it.
NewAnnotation defaultShape(
  ShapeTool shape,
  Offset center, {
  required AnnotationColor color,
  required String author,
}) {
  const half = Offset(72, 36);
  return shapeAnnotation(
    shape,
    color: color,
    author: author,
    a: center - half,
    b: center + half,
    points: [
      for (var i = 0; i < 5; i++)
        center +
            Offset.fromDirection(-math.pi / 2 + i * 2 * math.pi / 5, half.dy),
    ],
  );
}

/// Places what the Shapes and Stamp menus chose, over the reader's pages and in
/// their own geometry, which never mirrors, as `CropOverlay` does. A rectangle,
/// ellipse, arrow or line is dragged; a polygon takes a click per corner and
/// closes on its first corner, a double click or Enter; a stamp takes a click,
/// and ⌥-drag sets its size (a4-3). Each mark commits as one step when it is
/// finished, never during the drag (M4 plan, decision 16), through
/// [CommentCommands.add], which asks for the name once (G46), selects the mark
/// and ends the tool unless kept. Enter with nothing drawn places the mark
/// mid-page; Esc drops the draft, then leaves the tool.
class MarkPlacementOverlay extends ConsumerStatefulWidget {
  /// The overlay for [tool], [AnnotationTool.shapes] or [AnnotationTool.stamp].
  const new({
    required this.tool,
    required this.color,
    this.onFinished,
    super.key,
  });

  /// The active tool; any other than the two places nothing.
  final AnnotationTool tool;

  /// The tool row's colour, for shapes; a stamp has its own ink.
  final design.AnnotationColor color;

  /// Called on Esc with no draft: the tool should end.
  final VoidCallback? onFinished;

  @override
  ConsumerState<MarkPlacementOverlay> createState() =>
      _MarkPlacementOverlayState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<AnnotationTool>('tool', tool))
      ..add(EnumProperty<design.AnnotationColor>('color', color))
      ..add(ObjectFlagProperty<VoidCallback?>.has('onFinished', onFinished));
  }
}

class _MarkPlacementOverlayState extends ConsumerState<MarkPlacementOverlay> {
  /// A click this close to the first corner, on screen, closes the polygon.
  static const double _closeReach = 8;

  final FocusNode _focus = FocusNode(debugLabel: 'MarkPlacementOverlay');

  /// The page of the draft.
  int? _page;

  /// A drag's two ends, in the page's displayed points.
  Offset? _start;
  Offset? _end;

  /// A polygon's corners so far.
  final List<Offset> _corners = [];

  /// Where the pointer is on the page of the draft, for the corner to come.
  Offset? _hover;

  /// The time since the last corner's click and where it was, for a double
  /// click.
  final Stopwatch _sinceClick = Stopwatch();
  Offset? _lastClickAt;

  /// Whether this drag sets a stamp's size.
  bool _sizing = false;

  @override
  void initState() {
    super.initState();
    // Focus stays where it was otherwise, and the keys are the tool's. An open
    // menu keeps it until it closes (`build`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(commentToolMenusProvider).open == null) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  ShapeTool? get _shape => widget.tool == AnnotationTool.shapes
      ? ref.read(commentToolMenusProvider).shape
      : null;

  StampDesign? get _stamp => widget.tool == AnnotationTool.stamp
      ? ref.read(commentToolMenusProvider).stamp
      : null;

  void _clear() => setState(() {
    _page = null;
    _start = null;
    _end = null;
    _hover = null;
    _lastClickAt = null;
    _sizing = false;
    _corners.clear();
  });

  /// The page under [local] and the point on it.
  (int, Offset)? _pointAt(ViewerState view, Offset local) {
    for (final (index, rect) in view.placement.rects.indexed) {
      final page = rect?.shift(-view.offset);
      if (page != null && page.contains(local)) {
        return (index, (local - page.topLeft) / view.scale);
      }
    }
    return null;
  }

  /// [local] as a point of the page [page], kept on it.
  Offset? _onPage(ViewerState view, int page, Offset local) {
    final rect = view.placement.rects
        .elementAtOrNull(page)
        ?.shift(-view.offset);
    final info = view.document.pages.elementAtOrNull(page);
    if (rect == null || info == null) return null;
    final point = (local - rect.topLeft) / view.scale;
    return Offset(
      point.dx.clamp(0, info.width),
      point.dy.clamp(0, info.height),
    );
  }

  void _commit(
    int page,
    NewAnnotation Function(String author) mark,
    String step,
  ) {
    final view = ref.read(viewerProvider);
    if (view == null) return;
    unawaited(
      ref
          .read(commentCommandsProvider.notifier)
          .add(view.document.pageHandle(page), mark, step: step),
    );
    _clear();
  }

  void _placeStamp(
    StampDesign stamp,
    int page,
    Offset center,
    AppLocalizations l10n, {
    double scale = 1,
  }) {
    final info = ref.read(viewerProvider)?.document.pages.elementAtOrNull(page);
    if (info == null) return;
    final theme = context.ferman;
    _commit(
      page,
      (author) => stampAnnotation(
        stamp,
        center: center,
        page: Size(info.width, info.height),
        ink: Stamp.inkOf(stamp.tone, theme),
        author: author,
        now: ref.read(stampClockProvider)(),
        format: RegionFormat.forRegion(ref.read(regionProvider).region),
        style: theme.typography.body,
        scale: scale,
      ),
      l10n.stepAddStamp,
    );
  }

  AnnotationColor _color() =>
      annotationColorOf(widget.color.resolve(context.ferman));

  void _closePolygon(AppLocalizations l10n) {
    final page = _page;
    if (page == null || _corners.length < 3) return;
    final color = _color();
    final corners = List.of(_corners);
    _commit(
      page,
      (author) => shapeAnnotation(
        ShapeTool.polygon,
        color: color,
        author: author,
        points: corners,
      ),
      l10n.stepAddShape,
    );
  }

  void _onTapUp(ViewerState view, TapUpDetails details, AppLocalizations l10n) {
    final at = _pointAt(view, details.localPosition);
    if (_stamp case final stamp?) {
      if (at != null) _placeStamp(stamp, at.$1, at.$2, l10n);
      return;
    }
    if (_shape != ShapeTool.polygon) return;
    final page = _page;
    if (page == null) {
      if (at == null) return;
      setState(() {
        _page = at.$1;
        _corners.add(at.$2);
      });
    } else {
      final point = _onPage(view, page, details.localPosition);
      if (point == null) return;
      final nearFirst =
          _corners.length >= 3 &&
          (point - _corners.first).distance * view.scale <= _closeReach;
      final lastAt = _lastClickAt;
      final twice =
          lastAt != null &&
          _sinceClick.elapsed <= kDoubleTapTimeout &&
          (details.localPosition - lastAt).distance <= kDoubleTapSlop;
      if (nearFirst || twice) {
        _closePolygon(l10n);
        return;
      }
      setState(() => _corners.add(point));
    }
    _sinceClick
      ..reset()
      ..start();
    _lastClickAt = details.localPosition;
  }

  void _onPanStart(ViewerState view, DragStartDetails details) {
    final sizing = _stamp != null && HardwareKeyboard.instance.isAltPressed;
    final shape = _shape;
    if (!sizing && (shape == null || shape == ShapeTool.polygon)) return;
    final at = _pointAt(view, details.localPosition);
    if (at == null) return;
    setState(() {
      _sizing = sizing;
      _page = at.$1;
      _start = at.$2;
      _end = at.$2;
    });
  }

  void _onPanUpdate(ViewerState view, DragUpdateDetails details) {
    final page = _page;
    if (page == null || _start == null) return;
    final point = _onPage(view, page, details.localPosition);
    if (point != null) setState(() => _end = point);
  }

  void _onPanEnd(AppLocalizations l10n) {
    final page = _page;
    final start = _start;
    final end = _end;
    if (page == null || start == null || end == null) return;
    final box = Rect.fromPoints(start, end);
    final stamp = _stamp;
    final shape = _shape;
    if (box.longestSide < smallestShape) {
      _clear();
    } else if (_sizing && stamp != null) {
      final usual = stampBox(
        stamp.capitals,
        stamp.metaAt(
          ref.read(stampClockProvider)(),
          RegionFormat.forRegion(ref.read(regionProvider).region),
          ref.read(settingsProvider).commenterName ?? '',
        ),
        stampFontSize,
        context.ferman.typography.body,
      );
      final scale = math.min(
        box.width / usual.width,
        box.height / usual.height,
      );
      _placeStamp(
        stamp,
        page,
        box.center,
        l10n,
        scale: scale.clamp(minStampScale, maxStampScale),
      );
    } else if (shape != null) {
      final color = _color();
      _commit(
        page,
        (author) => shapeAnnotation(
          shape,
          color: color,
          author: author,
          a: start,
          b: end,
        ),
        l10n.stepAddShape,
      );
    }
  }

  KeyEventResult _onKey(KeyEvent event, AppLocalizations l10n) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final drafting = _page != null;
    if (key == LogicalKeyboardKey.escape) {
      if (drafting) {
        _clear();
      } else {
        widget.onFinished?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace && _corners.isNotEmpty) {
      setState(() {
        _corners.removeLast();
        if (_corners.isEmpty) _page = null;
      });
      return KeyEventResult.handled;
    }
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (drafting) {
      _closePolygon(l10n);
      return KeyEventResult.handled;
    }
    final view = ref.read(viewerProvider);
    final page = view?.currentPage ?? 0;
    final info = view?.document.pages.elementAtOrNull(page);
    if (info == null) return KeyEventResult.ignored;
    final center = Offset(info.width / 2, info.height / 2);
    if (_stamp case final stamp?) {
      _placeStamp(stamp, page, center, l10n);
    } else if (_shape case final shape?) {
      final color = _color();
      _commit(
        page,
        (author) => defaultShape(shape, center, color: color, author: author),
        l10n.stepAddShape,
      );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    final menus = ref.watch(commentToolMenusProvider);
    final view = ref.watch(viewerProvider);
    final shape = widget.tool == AnnotationTool.shapes ? menus.shape : null;
    final stamp = widget.tool == AnnotationTool.stamp ? menus.stamp : null;
    // Back from a menu, the keys are the tool's again.
    ref.listen(commentToolMenusProvider.select((state) => state.open), (
      _,
      open,
    ) {
      if (open == null) _focus.requestFocus();
    });
    if (view == null || (shape == null && stamp == null)) {
      return const SizedBox.shrink();
    }
    final page = _page;
    final origin = page == null
        ? null
        : view.placement.rects.elementAtOrNull(page)?.topLeft;
    return Semantics(
      container: true,
      label: stamp != null
          ? l10n.placeStampHint
          : shape == ShapeTool.polygon
          ? l10n.placePolygonHint
          : l10n.placeShapeHint,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: (_, event) => _onKey(event, l10n),
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          onHover: (event) {
            if (page == null || _corners.isEmpty) return;
            setState(() => _hover = _onPage(view, page, event.localPosition));
          },
          // The view takes focus on a press; the tool's keys come back with it.
          child: Listener(
            onPointerUp: (_) => _focus.requestFocus(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onTapUp: (details) => _onTapUp(view, details, l10n),
              onPanStart: (details) => _onPanStart(view, details),
              onPanUpdate: (details) => _onPanUpdate(view, details),
              onPanEnd: (_) => _onPanEnd(l10n),
              // Every click ends in this, and a polygon's corners stay.
              onPanCancel: () {
                if (_start != null) _clear();
              },
              child: CustomPaint(
                painter: origin == null
                    ? null
                    : _DraftPainter(
                        origin: origin - view.offset,
                        scale: view.scale,
                        color: stamp != null
                            ? Stamp.inkOf(stamp.tone, theme)
                            : widget.color.resolve(theme),
                        shape: _sizing ? ShapeTool.rectangle : shape,
                        start: _start,
                        end: _end,
                        corners: List.of(_corners),
                        hover: _hover,
                      ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark being drawn.
class _DraftPainter extends CustomPainter {
  const new({
    required this.origin,
    required this.scale,
    required this.color,
    required this.shape,
    required this.start,
    required this.end,
    required this.corners,
    required this.hover,
  });

  /// A corner's mark.
  static const double _corner = 6;

  final Offset origin;
  final double scale;
  final Color color;
  final ShapeTool? shape;
  final Offset? start;
  final Offset? end;
  final List<Offset> corners;
  final Offset? hover;

  Offset _at(Offset point) => origin + point * scale;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = shapeStroke * scale;
    if (shape == ShapeTool.polygon) {
      if (corners.isEmpty) return;
      final path = Path()..moveTo(_at(corners.first).dx, _at(corners.first).dy);
      for (final corner in [...corners.skip(1), ?hover]) {
        path.lineTo(_at(corner).dx, _at(corner).dy);
      }
      canvas.drawPath(path, line);
      final dot = Paint()..color = color;
      for (final corner in corners) {
        canvas.drawRect(
          Rect.fromCenter(center: _at(corner), width: _corner, height: _corner),
          dot,
        );
      }
      return;
    }
    final a = start;
    final b = end;
    if (a == null || b == null) return;
    final box = Rect.fromPoints(_at(a), _at(b));
    switch (shape) {
      case ShapeTool.rectangle:
        canvas.drawRect(box, line);
      case ShapeTool.ellipse:
        canvas.drawOval(box, line);
      case ShapeTool.arrow:
        canvas.drawLine(_at(a), _at(b), line);
        final along = (_at(b) - _at(a)).direction;
        final reach = 4 * shapeStroke * scale;
        for (final side in const [-0.5, 0.5]) {
          canvas.drawLine(
            _at(b),
            _at(b) - Offset.fromDirection(along + side, reach),
            line,
          );
        }
      case ShapeTool.line:
        canvas.drawLine(_at(a), _at(b), line);
      case ShapeTool.polygon || null:
        break;
    }
  }

  @override
  bool shouldRepaint(_DraftPainter old) =>
      old.origin != origin ||
      old.scale != scale ||
      old.color != color ||
      old.shape != shape ||
      old.start != start ||
      old.end != end ||
      !listEquals(old.corners, corners) ||
      old.hover != hover;
}
