import 'dart:ui';

import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:flutter_test/flutter_test.dart';

AnnotationInfo _mark(
  int handle, {
  AnnotationKind kind = AnnotationKind.square,
  Rect rect = const Rect.fromLTWH(0, 0, 100, 100),
  int page = 100,
  int? thread,
  String? state,
  bool resolved = false,
  String? author,
  List<List<Offset>> points = const [],
  DateTime? created,
}) => AnnotationInfo(
  handle: handle,
  page: page,
  kind: kind,
  rect: rect,
  thread: thread ?? handle,
  state: state,
  resolved: resolved,
  author: author,
  points: points,
  created: created,
);

void main() {
  test('threads gather replies and leave state replies out', () {
    final threads = commentThreads([
      _mark(1),
      _mark(2, kind: AnnotationKind.note, thread: 1),
      _mark(3, kind: AnnotationKind.note, thread: 1, state: 'Completed'),
      _mark(4),
    ]);
    expect(threads.map((t) => t.top.handle), [1, 4]);
    expect(threads.first.replies.map((r) => r.handle), [2]);
  });

  group('filters', () {
    final threads = commentThreads([
      _mark(1, page: 101, author: 'Ayşe', created: DateTime(2026)),
      _mark(
        2,
        kind: AnnotationKind.highlight,
        author: 'Mert',
        resolved: true,
        created: DateTime(2026, 3),
      ),
      _mark(3, kind: AnnotationKind.note, author: 'Ayşe', page: 999),
      _mark(4, kind: AnnotationKind.note, author: 'Ayşe'),
    ]);
    int? pageOf(int handle) => switch (handle) {
      100 => 0,
      101 => 1,
      _ => null,
    };
    List<int> shown(CommentFilters filters) => [
      for (final thread in filteredThreads(threads, filters, pageOf))
        thread.top.handle,
    ];

    test('a page no longer there hides its threads, the order is the page', () {
      expect(shown(const CommentFilters(status: CommentStatus.all)), [2, 4, 1]);
    });

    test('status, author and type', () {
      expect(shown(const CommentFilters()), [4, 1]);
      expect(shown(const CommentFilters(status: CommentStatus.resolved)), [2]);
      expect(
        shown(const CommentFilters(status: CommentStatus.all, author: 'Mert')),
        [2],
      );
      expect(shown(const CommentFilters(type: CommentTypeFilter.notes)), [4]);
    });

    test('newest and author', () {
      expect(
        shown(
          const CommentFilters(
            status: CommentStatus.all,
            sort: CommentSort.newest,
          ),
        ).first,
        2,
      );
      expect(
        shown(
          const CommentFilters(
            status: CommentStatus.all,
            sort: CommentSort.author,
          ),
        ).last,
        2,
      );
    });
  });

  group('hit tests', () {
    test('a stroke is found near its line only', () {
      final ink = _mark(
        1,
        kind: AnnotationKind.ink,
        points: const [
          [Offset.zero, Offset(100, 0)],
        ],
      );
      expect(hitsAnnotation(ink, const Offset(50, 2)), isTrue);
      expect(hitsAnnotation(ink, const Offset(50, 50)), isFalse);
    });

    test('a text mark is found on its quads, not in the gap between', () {
      final mark = _mark(
        1,
        kind: AnnotationKind.highlight,
        points: const [
          [Offset.zero, Offset(100, 0), Offset(0, 10), Offset(100, 10)],
          [Offset(0, 50), Offset(100, 50), Offset(0, 60), Offset(100, 60)],
        ],
      );
      expect(hitsAnnotation(mark, const Offset(10, 55)), isTrue);
      expect(hitsAnnotation(mark, const Offset(10, 30)), isFalse);
    });

    test('a polygon is found inside', () {
      final polygon = _mark(
        1,
        kind: AnnotationKind.polygon,
        points: const [
          [Offset.zero, Offset(100, 0), Offset(50, 100)],
        ],
      );
      expect(hitsAnnotation(polygon, const Offset(50, 40)), isTrue);
      expect(hitsAnnotation(polygon, const Offset(5, 90)), isFalse);
    });

    test('of two marks the smaller wins, on its own page', () {
      final threads = commentThreads([
        _mark(1),
        _mark(2, rect: const Rect.fromLTWH(10, 10, 20, 20)),
        _mark(3),
      ]);
      expect(annotationAt(threads, 100, const Offset(15, 15))?.handle, 2);
      expect(annotationAt(threads, 200, const Offset(15, 15)), isNull);
    });
  });

  test('a handle resizes its own sides and never turns the box inside out', () {
    const box = Rect.fromLTRB(10, 10, 110, 110);
    expect(
      resizedBox(box, 4, const Offset(50, 60)),
      const Rect.fromLTRB(10, 10, 50, 60),
    );
    expect(
      resizedBox(box, 1, const Offset(999, 50)),
      const Rect.fromLTRB(10, 50, 110, 110),
    );
    expect(
      resizedBox(box, 0, const Offset(500, 500)),
      const Rect.fromLTRB(106, 106, 110, 110),
    );
  });

  test('what each kind allows', () {
    expect(movable(AnnotationKind.highlight), isFalse);
    expect(movable(AnnotationKind.other), isFalse);
    expect(movable(AnnotationKind.note), isTrue);
    expect(resizable(AnnotationKind.note), isFalse);
    expect(resizable(AnnotationKind.square), isTrue);
    expect(hasStyle(AnnotationKind.stamp), isFalse);
    expect(hasOwnText(AnnotationKind.callout), isTrue);
  });
}
