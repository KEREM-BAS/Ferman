import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simple signatures, handwriting styles and saved signatures as the fake
/// gives them to the app: a signature on a field is one step that fills the
/// field, undone with it; a field is signed once; styles say which can write
/// a name; saved files are written, listed by name and deleted.
void main() {
  const path = 'form.pdf';
  late FakeEngineService engine;
  late int document;
  late int page;

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
    page = opened.pageHandle(0);
    engine.initialFields[document] = [
      FieldInfo(
        handle: 8,
        name: 'imza',
        kind: FieldKind.signature,
        required: true,
        widgets: [
          FieldWidget(page: page, rect: const Rect.fromLTRB(50, 700, 230, 736)),
        ],
      ),
    ];
  });

  NewSignature onField(String field) => NewSignature(
    rect: const Rect.fromLTRB(50, 700, 230, 736),
    ink: const TypedInk(text: 'Ayşe Yılmaz', family: 'Caveat'),
    color: const AnnotationColor(0.1, 0.1, 0.4),
    author: 'Ayşe Yılmaz',
    field: field,
  );

  test('a signature on its field is one step that fills it', () async {
    expect((await engine.formFields(document)).requiredLeft, 1);
    final commit = await engine.addSignature(
      document,
      page,
      onField('imza'),
      'Sign',
    );
    expect(commit.revision.current, 1);
    final stamp = (await engine.annotations(document)).annotations.single;
    expect(stamp.kind, AnnotationKind.stamp);
    expect(stamp.icon, signatureStampName);
    final form = await engine.formFields(document);
    expect(form.fields.single.signature, commit.handle);
    expect(form.fields.single.signed, isFalse);
    expect(form.requiredLeft, 0);
    expect(
      () => engine.addSignature(document, page, onField('imza'), 'Sign'),
      throwsA(isA<EngineException>()),
    );
    await engine.undo(document);
    expect((await engine.formFields(document)).requiredLeft, 1);
    expect((await engine.annotations(document)).annotations, isEmpty);
  });

  test('styles say which can write a name', () async {
    final styles = await engine.handwritingStyles('Ayşe Yılmaz');
    expect(styles.map((s) => s.family), [
      'Caveat',
      'Dancing Script',
      'Homemade Apple',
    ]);
    expect(styles.map((s) => s.covered), [true, true, false]);
    final arabic = await engine.handwritingStyles('أحمد');
    expect(arabic.any((s) => s.covered), isFalse);
  });

  test('saved signatures are written, listed and deleted', () async {
    const dir = '/data/signatures';
    await engine.writeSavedSignature(dir, 'b.json', Uint8List.fromList([2]));
    await engine.writeSavedSignature(dir, 'a.json', Uint8List.fromList([1]));
    expect(
      () => engine.writeSavedSignature(dir, '../x', Uint8List(0)),
      throwsA(isA<EngineException>()),
    );
    final saved = await engine.savedSignatures(dir);
    expect(saved.map((s) => s.name), ['a.json', 'b.json']);
    await engine.deleteSavedSignature(dir, 'a.json');
    expect(await engine.savedSignatures(dir), hasLength(1));
  });
}
