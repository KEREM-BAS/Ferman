import 'dart:ui' show Rect;

import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The form calls as the fake gives them to the app: a value is one step,
/// undo and redo walk the fields, Clear and Finish are one step each, and the
/// required count follows.
void main() {
  const path = 'form.pdf';
  late FakeEngineService engine;
  late int document;

  setUp(() async {
    engine = FakeEngineService(
      documents: {
        path: const OpenedDocument(
          id: 1,
          pages: [PageInfo(width: 595, height: 842)],
        ),
      },
    );
    final opened = await engine.open(path);
    document = opened.id;
    final widget = FieldWidget(
      page: opened.pageHandle(0),
      rect: const Rect.fromLTRB(50, 100, 200, 117),
    );
    engine.initialFields[document] = [
      FieldInfo(
        handle: 7,
        name: 'adi',
        kind: FieldKind.text,
        required: true,
        widgets: [widget],
      ),
      FieldInfo(
        handle: 8,
        name: 'imza',
        kind: FieldKind.signature,
        widgets: [widget],
      ),
    ];
  });

  test('a value is one step, undone and redone, and counts', () async {
    expect((await engine.formFields(document)).requiredLeft, 1);
    final commit = await engine.setFieldValue(document, 7, [
      'Ayşe',
    ], name: 'Fill');
    expect(commit.revision.current, 1);
    var form = await engine.formFields(document);
    expect(form.fields.first.values, ['Ayşe']);
    expect(form.requiredLeft, 0);
    final same = await engine.setFieldValue(document, 7, [
      'Ayşe',
    ], name: 'Fill');
    expect(same.revision.current, 1);
    await engine.undo(document);
    expect((await engine.formFields(document)).fields.first.values, isEmpty);
    await engine.redo(document);
    await engine.clearForm(document, 'Clear');
    form = await engine.formFields(document);
    expect(form.fields.first.values, isEmpty);
    await engine.finishForm(document, 'Finish');
    expect((await engine.formFields(document)).fields, isEmpty);
    await engine.undo(document);
    expect((await engine.formFields(document)).fields, hasLength(2));
  });

  test('a signature field takes no value', () async {
    expect(
      () => engine.setFieldValue(document, 8, ['x'], name: 'Fill'),
      throwsA(isA<EngineException>()),
    );
  });
}
