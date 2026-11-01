import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/start/start_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../onboarding/ferman_app_harness.dart';

const String _path = '/docs/İmar planı açıklama raporu.pdf';

const OpenedDocument _imar = OpenedDocument(
  id: 4,
  pages: [PageInfo(width: 595, height: 842)],
);

/// Opens [_path] with ⌘O and waits past [DocumentOpener.slowOpen]; the
/// engine answers when [release] completes.
Future<(FakeEngineService, ProviderContainer)> openSlowly(
  WidgetTester tester,
  Completer<void> release,
) async {
  final engine = FakeEngineService(
    documents: {_path: _imar},
    holds: {_path: release.future},
  );
  await pumpFermanApp(
    tester,
    engine: engine,
    picker: FakeFilePickerService(picked: [_path]),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(FmStart)),
  );
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  await tester.pump(DocumentOpener.slowOpen);
  await tester.pump();
  return (engine, container);
}

final Finder _card = find.byType(TaskProgress);

void main() {
  testWidgets('a slow open shows its tab with a spinner and a1-7 card, then '
      'the document', (tester) async {
    final release = Completer<void>();
    final (_, container) = await openSlowly(tester, release);
    expect(find.byType(FmStart), findsNothing);
    // Its tab's spinner follows `loading` (shell_screen_test).
    expect(container.read(shellDocumentsProvider).active!.loading, isTrue);
    expect(
      find.textContaining('İmar planı açıklama raporu.pdf\u2069”'),
      findsOne,
    );

    release.complete();
    await tester.pumpAndSettle();
    expect(_card, findsNothing);
    final active = container.read(shellDocumentsProvider).active!;
    expect(active.loading, isFalse);
    expect(active.document!.id, _imar.id);
    expect(container.read(shellDocumentsProvider).documents, hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Esc cancels: the tab closes, Start shows again and the late '
      'document closes in the engine', (tester) async {
    final release = Completer<void>();
    final (engine, container) = await openSlowly(tester, release);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(container.read(shellDocumentsProvider).documents, isEmpty);
    expect(find.byType(FmStart), findsOne);

    release.complete();
    await tester.pumpAndSettle();
    expect(container.read(shellDocumentsProvider).documents, isEmpty);
    expect(engine.closed, [_imar.id]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("the card's Cancel does the same", (tester) async {
    final release = Completer<void>();
    final (engine, container) = await openSlowly(tester, release);
    await tester.tap(
      find.descendant(of: _card, matching: find.byType(IconButton)),
    );
    await tester.pumpAndSettle();
    release.complete();
    await tester.pumpAndSettle();
    expect(container.read(shellDocumentsProvider).documents, isEmpty);
    expect(engine.closed, [_imar.id]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
