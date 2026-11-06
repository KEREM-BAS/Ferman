import 'dart:math' as math;

import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/crop_session.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sides a handle moves.
enum _Handle {
  topLeft(l: true, t: true, cursor: SystemMouseCursors.resizeUpLeftDownRight),
  top(t: true, cursor: SystemMouseCursors.resizeUpDown),
  topRight(r: true, t: true, cursor: SystemMouseCursors.resizeUpRightDownLeft),
  left(l: true, cursor: SystemMouseCursors.resizeLeftRight),
  right(r: true, cursor: SystemMouseCursors.resizeLeftRight),
  bottomLeft(
    l: true,
    b: true,
    cursor: SystemMouseCursors.resizeUpRightDownLeft,
  ),
  bottom(b: true, cursor: SystemMouseCursors.resizeUpDown),
  bottomRight(
    r: true,
    b: true,
    cursor: SystemMouseCursors.resizeUpLeftDownRight,
  );

  new({
    required this.cursor,
    this.l = false,
    this.r = false,
    this.t = false,
    this.b = false,
  });

  final MouseCursor cursor;
  final bool l;
  final bool r;
  final bool t;
  final bool b;
}

/// [margins] of a page of [page] points after dragging the sides named by
/// [delta] points: no side past the page's edge or the side across from it.
@visibleForTesting
PageMargins draggedMargins(
  PageMargins margins,
  Size page, {
  required Offset delta,
  bool left = false,
  bool right = false,
  bool top = false,
  bool bottom = false,
}) {
  double moved(double side, double by, double across, double whole) =>
      (side + by).clamp(0, math.max(0, whole - across - smallestCroppedSide));
  return PageMargins(
    left: left
        ? moved(margins.left, delta.dx, margins.right, page.width)
        : margins.left,
    right: right
        ? moved(margins.right, -delta.dx, margins.left, page.width)
        : margins.right,
    top: top
        ? moved(margins.top, delta.dy, margins.bottom, page.height)
        : margins.top,
    bottom: bottom
        ? moved(margins.bottom, -delta.dy, margins.top, page.height)
        : margins.bottom,
  );
}

/// a6-4's crop box over the reader's page, in the canvas's own left-to-right
/// geometry: the scrim outside it, a 2 px accent outline, four corner and four
/// side handles and the live size under it. Its fields in the panel are the
/// keyboard's and screen readers' way to the margins, so this layer is hidden
/// from them, as the board's `aria-hidden` says. Esc closes the tool.
class CropOverlay extends ConsumerWidget {
  /// The overlay.
  const new({super.key});

  /// The corner handle's side, and a side handle's short side.
  static const double handleShort = 14;

  /// A side handle's long side.
  static const double handleLong = 28;

  /// The box's outline and a handle's border (`2px`).
  static const double lineWidth = 2;

  /// The size label's gap under the box.
  static const double labelGap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final session = ref.watch(organizeCropProvider);
    final view = ref.watch(viewerProvider);
    final region = ref.watch(regionProvider);
    if (session == null || view == null) return const SizedBox.shrink();
    final index = view.currentPage;
    final rect = view.placement.rects.elementAtOrNull(index);
    final info = view.document.pages.elementAtOrNull(index);
    if (rect == null || info == null) return const SizedBox.shrink();
    final page = rect.shift(-view.offset);
    final scale = view.scale;
    final handle = view.document.pageHandle(index);
    final margins = session.marginsOf(handle);
    final box = Rect.fromLTRB(
      page.left + margins.left * scale,
      page.top + margins.top * scale,
      page.right - margins.right * scale,
      page.bottom - margins.bottom * scale,
    );
    final format = RegionFormat.forRegion(region.region);
    final crop = ref.read(organizeCropProvider.notifier);
    Widget grip(_Handle which) {
      final wide = which == _Handle.top || which == _Handle.bottom;
      final tall = which == _Handle.left || which == _Handle.right;
      final width = wide ? handleLong : handleShort;
      final height = tall ? handleLong : handleShort;
      final x = which.l
          ? box.left
          : which.r
          ? box.right
          : box.center.dx;
      final y = which.t
          ? box.top
          : which.b
          ? box.bottom
          : box.center.dy;
      return PositionedDirectional(
        start: x - width / 2,
        top: y - height / 2,
        width: width,
        height: height,
        child: MouseRegion(
          cursor: which.cursor,
          child: GestureDetector(
            onPanUpdate: (details) {
              final current = ref.read(organizeCropProvider);
              if (current == null) return;
              crop.change(
                current.copyWith(
                  keepDetected: false,
                  margins: draggedMargins(
                    current.marginsOf(handle),
                    Size(info.width, info.height),
                    delta: details.delta / scale,
                    left: which.l,
                    right: which.r,
                    top: which.t,
                    bottom: which.b,
                  ),
                ),
              );
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.textOnAccent,
                border: Border.all(
                  color: theme.colors.accent,
                  width: lineWidth,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): crop.cancel},
      child: _TakesFocus(
        child: ExcludeSemantics(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CropScrim(
                      box: box,
                      line: theme.colors.accent,
                      scrim: theme.colors.surfaceScrim,
                    ),
                  ),
                ),
              ),
              for (final which in _Handle.values) grip(which),
              PositionedDirectional(
                start: box.left,
                top: box.bottom + labelGap,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colors.accent,
                      borderRadius: BorderRadius.circular(
                        theme.radius.radiusSm,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        vertical: theme.space.space1,
                        horizontal: theme.space.space2,
                      ),
                      child: Text(
                        format.dimensions(
                          box.width / scale,
                          box.height / scale,
                          region.lengthUnit,
                        ),
                        style: theme.typography.caption.copyWith(
                          color: theme.colors.textOnAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Takes focus when the tool opens, so Esc reaches its binding: the canvas
/// already holds it, and `autofocus` does not take it from there.
class _TakesFocus extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  @override
  State<_TakesFocus> createState() => _TakesFocusState();
}

class _TakesFocusState extends State<_TakesFocus> {
  final FocusNode _node = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _node.requestFocus();
    });
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _node, child: widget.child);
}

class _CropScrim extends CustomPainter {
  new({required this.box, required this.line, required this.scrim});

  final Rect box;
  final Color line;
  final Color scrim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRect(box),
        Paint()..color = scrim,
      )
      ..drawRect(
        box,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = CropOverlay.lineWidth,
      );
  }

  @override
  bool shouldRepaint(_CropScrim old) =>
      old.box != box || old.line != line || old.scrim != scrim;
}
