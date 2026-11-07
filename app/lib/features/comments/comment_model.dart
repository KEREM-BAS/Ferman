import 'dart:math' as math;
import 'dart:ui' show Color, Offset, Rect;

import 'package:ferman/engine/engine_service.dart';
import 'package:flutter/foundation.dart';

/// The Status filter of FmComments.
enum CommentStatus {
  /// Open threads.
  open,

  /// Resolved threads.
  resolved,

  /// Both.
  all,
}

/// The Type filter of FmComments.
enum CommentTypeFilter {
  /// All types.
  all,

  /// Notes, text boxes and callouts.
  notes,

  /// Highlights, underlines and the like.
  markup,

  /// Drawings and shapes.
  drawings,

  /// Stamps.
  stamps,
}

/// The Sort filter of FmComments.
enum CommentSort {
  /// In page order, under each page's heading.
  page,

  /// Newest first.
  newest,

  /// By author.
  author,
}

/// A choice of a4-1's Shapes menu.
enum ShapeTool {
  /// A rectangle.
  rectangle,

  /// An ellipse.
  ellipse,

  /// A line ending in an arrow.
  arrow,

  /// A line.
  line,

  /// A polygon, clicked vertex by vertex.
  polygon,
}

/// What FmComments lists.
@immutable
final class CommentFilters {
  /// The board's defaults: open threads in page order.
  const new({
    this.open = false,
    this.status = CommentStatus.open,
    this.author,
    this.type = CommentTypeFilter.all,
    this.sort = CommentSort.page,
  });

  /// Whether the filter row shows.
  final bool open;

  /// Which threads by status.
  final CommentStatus status;

  /// Whose threads; null for everyone's.
  final String? author;

  /// Which types.
  final CommentTypeFilter type;

  /// Their order.
  final CommentSort sort;

  /// A copy with the given values; [author] replaces when it is given.
  CommentFilters copyWith({
    bool? open,
    CommentStatus? status,
    String? Function()? author,
    CommentTypeFilter? type,
    CommentSort? sort,
  }) => CommentFilters(
    open: open ?? this.open,
    status: status ?? this.status,
    author: author == null ? this.author : author(),
    type: type ?? this.type,
    sort: sort ?? this.sort,
  );
}

/// A comment with its replies, oldest first.
@immutable
final class CommentThread {
  /// A thread.
  const new(this.top, this.replies);

  /// The annotation on the page.
  final AnnotationInfo top;

  /// Its replies, without the state replies that resolve it.
  final List<AnnotationInfo> replies;
}

/// The threads of [annotations], in their order.
List<CommentThread> commentThreads(List<AnnotationInfo> annotations) {
  final replies = <int, List<AnnotationInfo>>{};
  for (final annotation in annotations) {
    if (annotation.thread != annotation.handle && annotation.state == null) {
      (replies[annotation.thread] ??= []).add(annotation);
    }
  }
  return [
    for (final annotation in annotations)
      if (annotation.thread == annotation.handle && annotation.state == null)
        CommentThread(annotation, replies[annotation.handle] ?? const []),
  ];
}

/// Which [CommentTypeFilter] [kind] falls under.
CommentTypeFilter commentTypeOf(AnnotationKind kind) => switch (kind) {
  AnnotationKind.highlight ||
  AnnotationKind.underline ||
  AnnotationKind.strikeOut ||
  AnnotationKind.squiggly => CommentTypeFilter.markup,
  AnnotationKind.ink ||
  AnnotationKind.square ||
  AnnotationKind.circle ||
  AnnotationKind.line ||
  AnnotationKind.polygon => CommentTypeFilter.drawings,
  AnnotationKind.stamp => CommentTypeFilter.stamps,
  AnnotationKind.note ||
  AnnotationKind.freeText ||
  AnnotationKind.callout ||
  AnnotationKind.other => CommentTypeFilter.notes,
};

/// [threads] as [filters] lists them, with [pageOf] saying where a page's
/// handle is now; a thread on a page no longer there is left out.
List<CommentThread> filteredThreads(
  List<CommentThread> threads,
  CommentFilters filters,
  int? Function(int page) pageOf,
) {
  final shown = [
    for (final thread in threads)
      if (pageOf(thread.top.page) != null &&
          switch (filters.status) {
            CommentStatus.open => !thread.top.resolved,
            CommentStatus.resolved => thread.top.resolved,
            CommentStatus.all => true,
          } &&
          (filters.author == null || thread.top.author == filters.author) &&
          (filters.type == CommentTypeFilter.all ||
              commentTypeOf(thread.top.kind) == filters.type))
        thread,
  ];
  int when(CommentThread thread) =>
      (thread.top.modified ?? thread.top.created)?.millisecondsSinceEpoch ?? 0;
  int order(CommentThread a, CommentThread b) => switch (filters.sort) {
    CommentSort.page => pageOf(a.top.page)!.compareTo(pageOf(b.top.page)!),
    CommentSort.newest => when(b).compareTo(when(a)),
    CommentSort.author => (a.top.author ?? '').compareTo(b.top.author ?? ''),
  };
  return mergeSorted(shown, order);
}

/// [items] in [order], those it calls equal staying in their order, which
/// `List.sort` does not promise.
List<T> mergeSorted<T>(List<T> items, int Function(T a, T b) order) {
  final places = {for (final (i, item) in items.indexed) item: i};
  return [...items]..sort((a, b) {
    final first = order(a, b);
    return first != 0 ? first : places[a]!.compareTo(places[b]!);
  });
}

/// How far from a mark's line the pointer still finds it, in points.
const double commentSlack = 3;

double _toSegment(Offset point, Offset a, Offset b) {
  final along = b - a;
  final length = along.distanceSquared;
  if (length == 0) return (point - a).distance;
  final at =
      ((point.dx - a.dx) * along.dx + (point.dy - a.dy) * along.dy) / length;
  return (point - (a + along * at.clamp(0, 1).toDouble())).distance;
}

bool _nearPath(List<Offset> path, Offset point, double reach) {
  for (var i = 0; i + 1 < path.length; i++) {
    if (_toSegment(point, path[i], path[i + 1]) <= reach) return true;
  }
  return false;
}

bool _inPolygon(List<Offset> corners, Offset point) {
  var inside = false;
  for (var i = 0, j = corners.length - 1; i < corners.length; j = i++) {
    final a = corners[i];
    final b = corners[j];
    if ((a.dy > point.dy) != (b.dy > point.dy) &&
        point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// The box around [points].
Rect boundsOf(Iterable<Offset> points) {
  var (left, top) = (double.infinity, double.infinity);
  var (right, bottom) = (double.negativeInfinity, double.negativeInfinity);
  for (final point in points) {
    left = math.min(left, point.dx);
    top = math.min(top, point.dy);
    right = math.max(right, point.dx);
    bottom = math.max(bottom, point.dy);
  }
  return left > right ? Rect.zero : Rect.fromLTRB(left, top, right, bottom);
}

/// Whether [point], in displayed points, is on [annotation]'s drawing.
bool hitsAnnotation(AnnotationInfo annotation, Offset point) {
  final reach = commentSlack + annotation.stroke / 2;
  switch (annotation.kind) {
    case AnnotationKind.highlight ||
        AnnotationKind.underline ||
        AnnotationKind.strikeOut ||
        AnnotationKind.squiggly:
      return annotation.points.isEmpty
          ? annotation.rect.contains(point)
          : annotation.points.any(
              (quad) =>
                  boundsOf(quad).inflate(commentSlack / 2).contains(point),
            );
    case AnnotationKind.ink || AnnotationKind.line:
      return annotation.points.any((path) => _nearPath(path, point, reach));
    case AnnotationKind.polygon when annotation.points.isNotEmpty:
      final corners = annotation.points.first;
      return _inPolygon(corners, point) ||
          _nearPath([...corners, corners.first], point, reach);
    case AnnotationKind.callout when annotation.points.isNotEmpty:
      return annotation.rect.contains(point) ||
          annotation.points.any((path) => _nearPath(path, point, reach));
    case _:
      return annotation.rect.inflate(commentSlack).contains(point);
  }
}

/// The annotation of [threads] on the page [page] under [point]: of the marks
/// there the smallest, so one drawn inside another can be reached.
AnnotationInfo? annotationAt(
  List<CommentThread> threads,
  int page,
  Offset point,
) {
  AnnotationInfo? best;
  var area = double.infinity;
  for (final CommentThread(:top) in threads) {
    if (top.page != page || !hitsAnnotation(top, point)) continue;
    final size = top.rect.width * top.rect.height;
    if (size <= area) {
      area = size;
      best = top;
    }
  }
  return best;
}

/// Whether a drag can move [kind]: a text mark belongs to its text, and an
/// unknown type's drawing is left alone.
bool movable(AnnotationKind kind) => switch (kind) {
  AnnotationKind.highlight ||
  AnnotationKind.underline ||
  AnnotationKind.strikeOut ||
  AnnotationKind.squiggly ||
  AnnotationKind.other => false,
  _ => true,
};

/// Whether handles can resize [kind]: a note is an icon, and a callout's box
/// and leader move as one.
bool resizable(AnnotationKind kind) =>
    movable(kind) &&
    kind != AnnotationKind.note &&
    kind != AnnotationKind.callout;

/// Whether [kind] has a stroke width to choose.
bool hasStroke(AnnotationKind kind) => switch (kind) {
  AnnotationKind.ink ||
  AnnotationKind.square ||
  AnnotationKind.circle ||
  AnnotationKind.line ||
  AnnotationKind.polygon ||
  AnnotationKind.callout ||
  AnnotationKind.freeText => true,
  _ => false,
};

/// Whether a style bar's colour and opacity apply to [kind]: a stamp keeps its
/// own, and an unknown type's drawing is left alone.
bool hasStyle(AnnotationKind kind) =>
    kind != AnnotationKind.stamp && kind != AnnotationKind.other;

/// Whether [kind] has text of its own, edited on the page (G46).
bool hasOwnText(AnnotationKind kind) =>
    kind == AnnotationKind.note ||
    kind == AnnotationKind.freeText ||
    kind == AnnotationKind.callout;

/// [color] as a mark's colour: marks do not change with theme.
AnnotationColor markColorOf(Color color) =>
    AnnotationColor(color.r, color.g, color.b);

/// [box] with its handle [handle], counted clockwise from the top-left corner,
/// dragged to [to]; never smaller than [smallest] a side.
Rect resizedBox(Rect box, int handle, Offset to, {double smallest = 4}) {
  var (left, top, right, bottom) = (box.left, box.top, box.right, box.bottom);
  if (const {0, 6, 7}.contains(handle)) {
    left = math.min(to.dx, right - smallest);
  }
  if (const {2, 3, 4}.contains(handle)) {
    right = math.max(to.dx, left + smallest);
  }
  if (const {0, 1, 2}.contains(handle)) {
    top = math.min(to.dy, bottom - smallest);
  }
  if (const {4, 5, 6}.contains(handle)) {
    bottom = math.max(to.dy, top + smallest);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// The eight handles of [box], clockwise from the top-left corner.
List<Offset> handlesOf(Rect box) => [
  box.topLeft,
  box.topCenter,
  box.topRight,
  box.centerRight,
  box.bottomRight,
  box.bottomCenter,
  box.bottomLeft,
  box.centerLeft,
];
