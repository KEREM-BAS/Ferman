import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/engine/recovery_directory.dart';
import 'package:flutter_test/flutter_test.dart';

const _opened = OpenedDocument(id: 9, pages: []);

void main() {
  group('recoveryDirectory', () {
    test('follows ARCHITECTURE §7.6 on each system', () {
      const support = '/Users/a/Library/Application Support/ferman';
      expect(
        recoveryDirectory(
          os: 'macos',
          environment: const {},
          applicationSupport: support,
        ),
        '$support/Recovery',
      );
      expect(
        recoveryDirectory(
          os: 'windows',
          environment: const {'LOCALAPPDATA': r'C:\Users\a\AppData\Local'},
        ),
        r'C:\Users\a\AppData\Local\Ferman\Recovery',
      );
      expect(
        recoveryDirectory(
          os: 'linux',
          environment: const {'XDG_STATE_HOME': '/s', 'HOME': '/home/a'},
        ),
        '/s/ferman/recovery',
      );
      expect(
        recoveryDirectory(
          os: 'linux',
          environment: const {'XDG_STATE_HOME': 'rel', 'HOME': '/home/a'},
        ),
        '/home/a/.local/state/ferman/recovery',
        reason: 'a relative XDG_STATE_HOME is ignored',
      );
    });

    test('is null without its folder', () {
      expect(recoveryDirectory(os: 'macos', environment: const {}), isNull);
      expect(recoveryDirectory(os: 'windows', environment: const {}), isNull);
      expect(
        recoveryDirectory(os: 'linux', environment: const {'HOME': ''}),
        isNull,
      );
      expect(
        recoveryDirectory(os: 'android', environment: const {'HOME': '/'}),
        isNull,
      );
    });
  });

  test('versions live beside the recovery folder (ADR 0022)', () {
    expect(
      versionsDirectory('/Users/a/Library/Application Support/x/Recovery'),
      '/Users/a/Library/Application Support/x/Versions',
    );
    expect(
      versionsDirectory(r'C:\Users\a\AppData\Local\Ferman\Recovery'),
      r'C:\Users\a\AppData\Local\Ferman\Versions',
    );
    expect(
      versionsDirectory('/home/a/.local/state/ferman/recovery'),
      '/home/a/.local/state/ferman/versions',
    );
  });

  group('FakeEngineService W4', () {
    test('a signed document compresses only with unsign', () async {
      final engine = FakeEngineService()..signed.add(7);
      await expectLater(
        engine.compressJob(
          7,
          preset: CompressPreset.smallest,
          output: '/o.pdf',
        ),
        emitsError(isA<EngineException>()),
      );
      final updates = engine.compressJob(
        7,
        preset: CompressPreset.smallest,
        output: '/o.pdf',
        unsign: true,
      );
      expect((await updates.first).state, JobState.running);
      expect(engine.compressJobs, ['smallest /o.pdf']);
    });

    test('Save as without comments records a copy', () async {
      final engine = FakeEngineService();
      await engine.saveAs(
        7,
        '/a.pdf',
        options: const SaveAsOptions(includeComments: false),
      );
      expect(engine.copies, [(7, '/a.pdf')]);
      expect(engine.saves, isEmpty);
    });

    test('a print streams a page per handle, unless forbidden', () async {
      final engine = FakeEngineService();
      final pages = await engine.printPages(7, pages: [3, 4]).toList();
      expect(pages.map((page) => page.index), [0, 1]);
      engine.printForbidden = true;
      await expectLater(
        engine.printPages(7),
        emitsError(isA<EngineException>()),
      );
    });
  });

  group('FakeEngineService recovery', () {
    FakeEngineService engine() => FakeEngineService()
      ..recoverable.addAll(const [
        RecoverableDocument(
          session: 'a1',
          document: 'b1',
          original: '/docs/kira-tr.pdf',
          changes: 2,
        ),
        RecoverableDocument(
          session: 'a1',
          document: 'b2',
          original: '/docs/iv fatura 4187.pdf',
          originalChanged: true,
          changes: 1,
          encrypted: true,
        ),
      ])
      ..recoveredDocuments.addAll({'b1': _opened, 'b2': _opened})
      ..recoveryPasswords['b2'] = 'secret';

    test('lists nothing before recovery starts', () async {
      final fake = engine();
      expect(await fake.listRecoverable(), isEmpty);
      await expectLater(
        fake.restoreRecovered('a1', 'b1'),
        throwsA(
          isA<EngineException>().having(
            (error) => error.kind,
            'kind',
            EngineErrorKind.notFound,
          ),
        ),
      );
      await fake.startRecovery('/r');
      await fake.startRecovery('/r');
      await expectLater(
        fake.startRecovery('/other'),
        throwsA(isA<EngineException>()),
      );
      expect(await fake.listRecoverable(), hasLength(2));
    });

    test('restores with the password, under a new name when the original '
        'changed', () async {
      final fake = engine();
      await fake.startRecovery('/r');
      final kinds = <EngineErrorKind>[];
      for (final password in [null, 'wrong']) {
        try {
          await fake.restoreRecovered('a1', 'b2', password: password);
        } on EngineException catch (error) {
          kinds.add(error.kind);
        }
      }
      expect(kinds, [
        EngineErrorKind.passwordRequired,
        EngineErrorKind.wrongPassword,
      ]);
      final restored = await fake.restoreRecovered(
        'a1',
        'b2',
        password: 'secret',
      );
      expect(restored.path, '/docs/iv fatura 4187 (recovered).pdf');
      expect(restored.originalChanged, isTrue);
      expect(restored.opened, _opened);
      final kept = await fake.restoreRecovered('a1', 'b1');
      expect(kept.path, '/docs/kira-tr.pdf');
      expect(await fake.listRecoverable(), isEmpty, reason: 'taken over');
    });

    test('discards a document or a whole session', () async {
      final fake = engine();
      await fake.startRecovery('/r');
      await fake.discardRecovery('a1', document: 'b2');
      expect(
        [for (final found in await fake.listRecoverable()) found.document],
        ['b1'],
      );
      await fake.discardRecovery('a1');
      expect(await fake.listRecoverable(), isEmpty);
    });

    test("Don't save closes and records the discard", () async {
      final fake = engine();
      await fake.setRecoveryEnabled(enabled: false);
      expect(fake.recoveryEnabled, isFalse);
      await fake.closeDiscarding(9);
      await fake.close(10);
      expect(fake.closed, [9, 10]);
      expect(fake.closedDiscarding, [9]);
    });
  });
}
