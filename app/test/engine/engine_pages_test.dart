import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page operations as the fake gives them to the app: each is one step,
/// undo and redo walk the page lists, and handles stay with their pages.
void main() {
  const path = 'a.pdf';
  late FakeEngineService engine;
  late int document;
  late List<int> handles;

  List<int> order(RevisionInfo info) => [
    for (final page in info.structure!.pages) page.handle!,
  ];

  setUp(() async {
    engine = FakeEngineService(
      documents: {
        path: const OpenedDocument(
          id: 1,
          pages: [
            PageInfo(width: 100, height: 200),
            PageInfo(width: 100, height: 200),
            PageInfo(width: 100, height: 200),
            PageInfo(width: 100, height: 200),
          ],
        ),
      },
    );
    final opened = await engine.open(path);
    document = opened.id;
    handles = [for (var i = 0; i < 4; i++) opened.pageHandle(i)];
  });

  test('a move goes before its page, and undo and redo walk back', () async {
    final moved = await engine.movePages(
      document,
      [handles[2], handles[3]],
      handles[1],
      'Moved',
    );
    final after = [handles[0], handles[2], handles[3], handles[1]];
    expect(order(moved), after);
    expect(order(await engine.undo(document)), handles);
    expect(order(await engine.redo(document)), after);
    expect((await engine.history(document)).steps.single.pages, [
      handles[2],
      handles[3],
    ]);
  });

  test('a delete, a copy and a blank page change the list', () async {
    final deleted = await engine.deletePages(document, [handles[1]], 'Deleted');
    expect(order(deleted), [handles[0], handles[2], handles[3]]);
    final copied = await engine.duplicatePages(document, [
      handles[0],
    ], 'Duplicated');
    expect(copied.structure!.pages.length, 4);
    expect(order(copied)[0], handles[0]);
    expect(handles, isNot(contains(order(copied)[1])));
    final blank = await engine.insertBlankPages(
      document,
      after: null,
      count: 1,
      width: 50,
      height: 60,
      name: 'Inserted',
    );
    expect(blank.structure!.pages.first.width, 50);
  });

  test('a turn, a crop and a new size change the size', () async {
    final turned = await engine.rotatePages(
      document,
      [handles[0]],
      1,
      'Rotated',
    );
    expect(turned.structure!.pages.first.width, 200);
    expect(turned.structure!.pages[1].width, 100);
    final cropped = await engine.cropPages(document, {
      handles[1]: const PageMargins(left: 10, right: 20, top: 5),
    }, 'Cropped');
    expect(cropped.structure!.pages[1].width, 70);
    expect(cropped.structure!.pages[1].height, 195);
    final sized = await engine.setPageSize(
      document,
      [handles[2]],
      width: 300,
      height: 400,
      fit: PageFit.centre,
      name: 'Resized',
    );
    expect(sized.structure!.pages[2].width, 300);
    expect(await engine.whiteMargins(document, [handles[0]]), [
      engine.whiteMarginsFound,
    ]);
  });

  test('labels are set and read back', () async {
    final info = await engine.setPageLabels(document, const [
      PageLabelRange(start: 0, style: PageLabelStyle.none, prefix: 'Kapak'),
      PageLabelRange(start: 1, prefix: 'Ek-', first: 3),
    ], 'Labels');
    expect(
      [for (final page in info.structure!.pages) page.label],
      ['Kapak', 'Ek-3', 'Ek-4', 'Ek-5'],
    );
    expect(await engine.pageLabelRanges(document), hasLength(2));
  });

  test('what cannot apply is refused and leaves no step', () async {
    await expectLater(
      engine.deletePages(document, handles, 'Deleted'),
      throwsA(isA<EngineException>()),
    );
    await expectLater(
      engine.rotatePages(document, [99], 1, 'Rotated'),
      throwsA(isA<EngineException>()),
    );
    expect((await engine.history(document)).steps, isEmpty);
  });

  test('a signed document waits for its confirmation', () async {
    engine.signed.add(document);
    await expectLater(
      engine.deletePages(document, [handles[0]], 'Deleted'),
      throwsA(
        isA<EngineException>().having(
          (error) => error.kind,
          'kind',
          EngineErrorKind.confirmationRequired,
        ),
      ),
    );
    await engine.confirmEditSigned(document);
    final info = await engine.deletePages(document, [handles[0]], 'Deleted');
    expect(info.current, 1);
  });
}
