import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/engine_service_frb.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

TextLine _line(String text, double top) => TextLine(
  text: text,
  bbox: Rect.fromLTWH(72, top, 200, 12),
  baselineStart: Offset(72, top + 10),
  baselineEnd: Offset(272, top + 10),
);

final _page = PageBlocks(
  blocks: [
    TextBlock(
      id: 1,
      frame: const Rect.fromLTWH(72, 72, 200, 26),
      lines: [_line('Madde 4', 72), _line('Kira bedeli 18.500 TL', 86)],
    ),
    TextBlock(
      id: 2,
      frame: const Rect.fromLTWH(72, 120, 200, 12),
      lines: [_line('Scanned stamp', 120)],
      notEditable: NotEditableReason.signatureAppearance,
    ),
  ],
);

Matcher _fails(EngineErrorKind kind, [String? messageKey]) => throwsA(
  isA<EngineException>()
      .having((error) => error.kind, 'kind', kind)
      .having(
        (error) => error.messageKey,
        'messageKey',
        messageKey ?? isNotEmpty,
      ),
);

Future<String> _text(FakeEngineService engine) async =>
    (await engine.textBlocks(7, 0)).blocks.first.text;

void main() {
  test('an edit previews, commits, undoes and redoes', () async {
    final engine = FakeEngineService(pageBlocks: {0: _page});
    final tx = await engine.beginEdit(7, 0, 1);
    final preview = await engine.applyEdit(
      tx,
      'Madde 4\nKira bedeli 18.600 TL',
    );
    expect(preview.page.blocks.first.text, 'Madde 4\nKira bedeli 18.600 TL');
    expect(preview.missing, isEmpty);
    expect(await _text(engine), contains('18.500'), reason: 'not committed');

    final committed = await engine.commitEdit(tx, 'Edited text · Madde 4');
    expect(committed.current, 1);
    expect(committed.renderKey, isNotNull);
    expect(await _text(engine), contains('18.600'));
    // Another document keeps its own blocks.
    expect(
      (await engine.textBlocks(8, 0)).blocks.first.text,
      contains('18.500'),
    );

    final undone = await engine.undo(7);
    expect(undone.current, 0);
    expect(undone.renderKey, greaterThan(committed.renderKey!));
    expect(await _text(engine), contains('18.500'));
    var history = await engine.history(7);
    expect(history.current, 0);
    expect(history.redoable.single.name, 'Edited text · Madde 4');
    await expectLater(engine.undo(7), _fails(EngineErrorKind.invalidInput));

    await engine.redo(7);
    expect(await _text(engine), contains('18.600'));
    await expectLater(engine.redo(7), _fails(EngineErrorKind.invalidInput));

    // A new step after an undo drops the steps undone.
    await engine.undo(7);
    final second = await engine.beginEdit(7, 0, 1);
    await engine.applyEdit(second, 'Madde 5\nKira bedeli 18.500 TL');
    await engine.commitEdit(second, 'Second');
    history = await engine.history(7);
    expect(history.current, 1);
    expect([for (final step in history.steps) step.name], ['Second']);
  });

  test('a rollback or an unchanged commit adds no step', () async {
    final engine = FakeEngineService(pageBlocks: {0: _page});
    var tx = await engine.beginEdit(7, 0, 1);
    await expectLater(
      engine.beginEdit(7, 0, 1),
      _fails(EngineErrorKind.invalidInput),
    );
    await expectLater(engine.undo(7), _fails(EngineErrorKind.invalidInput));
    await engine.applyEdit(tx, 'Madde 9\nKira bedeli 18.500 TL');
    expect((await engine.rollbackEdit(tx)).current, 0);
    expect(await _text(engine), startsWith('Madde 4'));
    await expectLater(
      engine.commitEdit(tx, 'x'),
      _fails(EngineErrorKind.notFound),
    );

    tx = await engine.beginEdit(7, 0, 1);
    final info = await engine.commitEdit(tx, 'Nothing');
    expect(info.current, 0);
    expect(info.renderKey, isNull);
    expect((await engine.history(7)).steps, isEmpty);
  });

  test('text that cannot be edited fails with its reason', () async {
    final engine = FakeEngineService(pageBlocks: {0: _page});
    await expectLater(
      engine.beginEdit(7, 0, 2),
      _fails(EngineErrorKind.notEditable, 'editBodySignature'),
    );
    await expectLater(
      engine.beginEdit(7, 0, 99),
      _fails(EngineErrorKind.notFound),
    );
  });

  test('another number of lines reflows the block', () async {
    final engine = FakeEngineService(pageBlocks: {0: _page});
    final tx = await engine.beginEdit(7, 0, 1);
    var preview = await engine.applyEdit(tx, 'one line');
    expect(preview.page.blocks.first.lines, hasLength(1));
    expect(preview.overflow, isNull);
    preview = await engine.applyEdit(tx, 'Madde 4\nKira bedeli\n18.500 TL');
    final block = preview.page.blocks.first;
    expect(block.lines, hasLength(3));
    expect(block.lines.last.bbox.top, 100);
    expect(block.frame.bottom, greaterThanOrEqualTo(112));
    await expectLater(
      engine.resolveOverflow(tx, OverflowChoice.keep),
      _fails(EngineErrorKind.invalidInput),
    );
  });

  test('an overflow offers its plan and records the hidden lines', () async {
    final engine = FakeEngineService(
      pageBlocks: {0: _page},
      overflows: {1: FakeEngineService.ibanOverflow},
    );
    final tx = await engine.beginEdit(7, 0, 1);
    var preview = await engine.applyEdit(
      tx,
      'Madde 4 Kira bedeli 18.500 TL, her ayın beşinci gününe kadar.',
    );
    final plan = preview.overflow!;
    expect(plan.over, 1);
    expect(plan.extendLines, isNull);
    expect(plan.extendBlocked!.text, startsWith('IBAN'));
    expect(plan.tightenPercent, 0.6);
    expect(plan.allows(OverflowChoice.extend), isFalse);
    expect(preview.chosen, OverflowChoice.keep);
    await expectLater(
      engine.resolveOverflow(tx, OverflowChoice.extend),
      _fails(EngineErrorKind.invalidInput),
    );
    preview = await engine.resolveOverflow(tx, OverflowChoice.tighten);
    expect(preview.chosen, OverflowChoice.tighten);
    preview = await engine.resolveOverflow(tx, OverflowChoice.keep);
    await engine.commitEdit(tx, 'Edited text · Madde 4');
    expect((await engine.history(7)).steps.single.hiddenLines, 1);
  });

  test('a table cell names the cells that depend on it', () async {
    final engine = FakeEngineService(
      pageBlocks: {0: _page},
      dependents: {
        1: [2],
      },
    );
    final tx = await engine.beginEdit(7, 0, 1);
    final preview = await engine.applyEdit(tx, 'Madde 4\nKira bedeli 1 TL');
    expect(preview.dependents.single.id, 2);
    expect(preview.dependents.single.frame, _page.blocks[1].frame);
  });

  test('saves are recorded and can fail', () async {
    final engine = FakeEngineService();
    await engine.save(7);
    await engine.saveAs(7, '/tmp/copy.pdf');
    expect(engine.saves, [(7, null), (7, '/tmp/copy.pdf')]);
    engine.saveFailure = const EngineException(
      kind: EngineErrorKind.io,
      messageKey: 'errorFileRead',
    );
    await expectLater(engine.save(7), _fails(EngineErrorKind.io));
  });

  test('every edit call of the unavailable engine throws its reason', () async {
    const error = EngineUnavailableException(
      EngineUnavailableReason.unsupportedPlatform,
    );
    const service = UnavailableEngineService(error);
    for (final call in <Future<Object?> Function()>[
      () => service.beginEdit(1, 0, 1),
      () => service.applyEdit(1, ''),
      () => service.resolveOverflow(1, OverflowChoice.keep),
      () => service.commitEdit(1, ''),
      () => service.rollbackEdit(1),
      () => service.undo(1),
      () => service.redo(1),
      () => service.history(1),
      () => service.save(1),
      () => service.saveAs(1, '/tmp/a.pdf'),
    ]) {
      await expectLater(call(), throwsA(same(error)));
    }
  });

  test('every error kind of the bridge maps to its namesake', () {
    // NotEditable included: the switch in FrbEngineService covers each one.
    expect(bridgeErrorKinds, {
      for (final kind in EngineErrorKind.values) kind.name: kind,
    });
  });

  test('every reason a block cannot be edited has its message', () {
    // The engine's message keys for NotEditable (MessageKey::not_editable)
    // are these, and each is an English string.
    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    for (final reason in NotEditableReason.values) {
      expect(arb[reason.messageKey], isA<String>(), reason: reason.name);
    }
  });
}
