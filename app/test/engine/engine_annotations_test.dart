import 'dart:ui' show Offset, Rect;

import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The annotation calls as the fake gives them to the app: each is one step,
/// and undo and redo walk the list with stable handles.
void main() {
  const path = 'a.pdf';
  const red = AnnotationColor(0.85, 0.22, 0.17);
  late FakeEngineService engine;
  late int document;
  late int page;

  Future<List<AnnotationInfo>> listed() async =>
      (await engine.annotations(document)).annotations;

  setUp(() async {
    engine = FakeEngineService(
      documents: {
        path: const OpenedDocument(
          id: 1,
          pages: [PageInfo(width: 100, height: 200)],
        ),
      },
    );
    final opened = await engine.open(path);
    document = opened.id;
    page = opened.pageHandle(0);
  });

  test('add, change, delete: one step each, undone and redone', () async {
    final made = await engine.addAnnotation(
      document,
      page,
      const NewAnnotation(
        kind: AnnotationKind.square,
        color: red,
        author: 'Ayşe',
        rect: Rect.fromLTRB(10, 10, 50, 50),
      ),
      'Square',
    );
    expect(made.revision.current, 1);
    await engine.updateAnnotation(
      document,
      made.handle,
      const AnnotationChange(contents: 'Bak', stroke: 4),
      'Change',
    );
    expect((await listed()).single.contents, 'Bak');
    expect((await engine.annotations(document)).people, ['Ayşe']);
    await engine.undo(document);
    expect((await listed()).single.contents, '');
    await engine.redo(document);
    expect((await listed()).single.stroke, 4);
    await engine.deleteAnnotation(document, made.handle, 'Delete');
    expect(await listed(), isEmpty);
    await engine.undo(document);
    expect((await listed()).single.handle, made.handle);
  });

  test('a thread is resolved, reopened and deleted whole', () async {
    final top = await engine.addAnnotation(
      document,
      page,
      const NewAnnotation(
        kind: AnnotationKind.highlight,
        color: red,
        author: 'Ayşe',
        points: [
          [Offset.zero, Offset(9, 0), Offset(0, 9), Offset(9, 9)],
        ],
      ),
      'Highlight',
    );
    final reply = await engine.replyToAnnotation(
      document,
      top.handle,
      author: 'Mert',
      text: 'Tamam @Ayşe',
      name: 'Reply',
    );
    final replied = (await listed()).last;
    expect(replied.handle, reply.handle);
    expect(replied.repliesTo, top.handle);
    expect(replied.mentions, ['Ayşe']);
    final done = await engine.setAnnotationResolved(
      document,
      top.handle,
      author: 'Mert',
      resolved: true,
      name: 'Resolve',
    );
    expect((await listed()).first.resolvedBy, 'Mert');
    final again = await engine.setAnnotationResolved(
      document,
      top.handle,
      author: 'Mert',
      resolved: true,
      name: 'Resolve',
    );
    expect(again.current, done.current, reason: 'already so: no step');
    await engine.deleteAnnotation(document, top.handle, 'Delete');
    expect(await listed(), isEmpty);
  });

  test('a squiggly is not created', () async {
    await expectLater(
      engine.addAnnotation(
        document,
        page,
        const NewAnnotation(
          kind: AnnotationKind.squiggly,
          color: red,
          author: 'Ayşe',
        ),
        'Squiggly',
      ),
      throwsA(isA<EngineException>()),
    );
  });
}
