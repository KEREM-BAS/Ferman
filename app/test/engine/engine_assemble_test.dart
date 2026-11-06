import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Combine, Split, Extract, Insert and Replace as the fake gives them to the
/// app: jobs that report through the drawer's stream, previews before them, and
/// a change that waits for [EngineService.applyJobChange].
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
          ],
        ),
      },
    );
    final opened = await engine.open(path);
    document = opened.id;
    handles = [for (var i = 0; i < 2; i++) opened.pageHandle(i)];
  });

  test('previews answer what the test set', () async {
    engine
      ..combinePreviewFound = const CombinePreview(
        files: [
          CombineFileInfo(status: CombineInputStatus.ownerPasswordRequired),
        ],
      )
      ..splitPreviewFound = const SplitPreview(
        files: [SplitFile(name: 'a — 1.pdf', first: 0, last: 1)],
        bookmarks: 1,
      );
    final combine = await engine.combinePreview(const [
      CombineInput.file('b.pdf'),
    ], keepForms: true);
    expect(
      combine.files.single.status,
      CombineInputStatus.ownerPasswordRequired,
    );
    final split = await engine.splitPreview(
      document,
      kind: SplitKind.topBookmarks,
      template: '{document} — {bookmark}',
    );
    expect(split.files.single.name, 'a — 1.pdf');
  });

  test('a job that writes files starts running and ends as told', () async {
    final updates = engine
        .combineJob(
          const [CombineInput.blank(612, 792)],
          keepForms: true,
          paper: ImagePaper.a4,
          output: 'out.pdf',
        )
        .toList();
    expect(engine.assembleJobs.single, 'combine 1 out.pdf');
    engine.endJob(
      const JobUpdate(
        job: 1,
        state: JobState.done,
        outputs: [JobOutputFile(path: 'out.pdf')],
      ),
    );
    final seen = await updates;
    expect(seen.first.state, JobState.running);
    expect(seen.last.outputs.single.path, 'out.pdf');
  });

  test('Split and Extract go through the same jobs', () async {
    engine
      ..splitJob(document, const [
        SplitFile(name: 'a.pdf', first: 0, last: 0),
      ], folder: '/out')
      ..extractPagesJob(document, [handles[1]], output: 'b.pdf');
    expect(engine.assembleJobs, ['split 1 /out', 'extract 1 b.pdf']);
  });

  test('an insert waits for its change, which is one step', () async {
    engine
      ..insertedPages = 2
      ..insertPagesJob(
        document,
        path: 'b.pdf',
        after: handles[0],
        paper: ImagePaper.letter,
        name: 'Inserted',
      );
    expect(engine.assembleJobs.single, 'insert b.pdf');
    final after = order(await engine.applyJobChange(1));
    expect(after.length, 4);
    expect(after.first, handles[0]);
    expect(after.last, handles[1]);
    expect(
      engine.applyJobChange(1),
      throwsA(
        isA<EngineException>().having(
          (error) => error.kind,
          'kind',
          EngineErrorKind.notFound,
        ),
      ),
    );
    final undone = await engine.undo(document);
    expect(order(undone), handles);
  });

  test('a replace keeps the handles of its pages', () async {
    engine.replacePagesJob(
      document,
      [handles[1]],
      path: 'b.pdf',
      name: 'Replaced',
    );
    final after = await engine.applyJobChange(1);
    expect(order(after), handles);
    expect(after.current, 1);
  });
}
